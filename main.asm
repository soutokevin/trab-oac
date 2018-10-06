.data

# --------------------------------------------------------------------------- #
#                                Image's space reservation                    #
# --------------------------------------------------------------------------- #

  screen: .space 1048576 		# Defines space for the bitmap display at 512x512 starting on static memory address.
  grey_scale_image: .space 1048576	# Space reserved to the grey scale version of the loaded image.
  new_image: .space 1048576		# Space the stores the output of image being processed.

# --------------------------------------------------------------------------- #
#                                 Program mesages                             #
# --------------------------------------------------------------------------- #

  open_error_msg: .asciiz "\nError while opening file\n"
  error_msg: .asciiz "\nInvalid file\n"
  input_msg: .asciiz "Input path: "
  output_msg: .asciiz "Output path: "
  
# --------------------------------------------------------------------------- #
#                                Program variables                            #
# --------------------------------------------------------------------------- #
  
  path: .space 500	# Path where the new image will be stored (includes file extension).
  input: .word 0	  # String to read general inputs.
  output: .word 0   # Output path to the new image file.
  buffer: .space 1536 # Space to read or write an entire line of pixels.
  
# --------------------------------------------------------------------------- #
#                                Kernel variables                             #
# --------------------------------------------------------------------------- #
  
  kernel_size: .word 9			# Total number of elements of the kernel (nXm).
  kernel_columns: .word 3		# Number of columns of kernel's matrix.
  kernel_lines: .word 3			# Number of lines of kernel's matrix.
  kernel_line_number: .word 0		# Holds the number of kernel's line being processed.
  kernel_distribution_number: .word 0	# Number that defines the range of elements around the kernel's center.
  #kernel: .word 1,2,1,2,4,2,1,2,1
  kernel: .word 1,1,1,1,1,1,1,1,1
  #kernel: .word 0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0
  #kernel: .word 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  kernel_gx: .word -1,0,1,-2,0,2,-1,0,1
  kernel_gy: .word 1,2,1,0,0,0,-1,-2,-1  

.text

main:

  # Request input path from the user.

  la $a0, input_msg
  la $a1, input
  move $a2, $zero
  jal open_file

  # Validate input file header.

  lw $a0, input
  jal read_file_header

  # Validate image header.

  lw $a0, input
  jal read_image_header

# Loads the image on BitMap Display and prepares the corresponding grey scale image.

paint:

  la $s0, screen + 1048576   # s0 is the end of the screen.
  li $s1, 512                # s1 will count how many lines are left to paint.

  la $s2, grey_scale_image   # $s2 holds the address to where the gray scale image will be stored.
  addi $s2, $s2, 1048576

  # Constants used to avoid pseudo instructions.

  li $s3, 3
  li $s4, 4
  li $s5, 1
  li $s6, 2048
  li $s7, 1536

  # Load 1536 bytes (a full line) of pixel data into the.

  paint_line:
  
    lw $a0, input
    la $a1, buffer
    move $a2, $s7
    li $v0, 14
    syscall

    bne $v0, $a2, invalid_file # Makes sure a full line was read.

    la $t8, buffer             # Start of loaded file content.
    add $t9, $t8, $s7        # End of loaded file content.

    # The image is written backwards. It starts at the last line, so the address needs to be adjusted to the beginning of the line.

    sub $s0, $s0, $s6       # Screen's address.
    sub $s2, $s2, $s6       # Grey scale image address.

    # Reads the bytes from the buffer, composes the RGB string, calculates the grey value and stores both on their addresses.

    paint_pixel:
  
      lbu $t0, 2($t8)            # Loads red component.
      lbu $t1, 1($t8)            # Loads green component.
      lbu $t2, 0($t8)            # Loads blue component.

      add $t3, $t0, $t1          # Sums the red and green components.
      add $t3, $t3, $t2          # Sums the blue component to the other two.
      div $t3, $t3, $s3            # Gets the average value of the pixel.

      sll $t0, $t0, 16           # Prepares component to be joined (red   <<= 16).
      sll $t1, $t1, 8            # Prepares component to be joined (green <<=  8).

      or $t0, $t0, $t1           # t0 contains red and green components.
      or $t0, $t0, $t2           # t0 contains all rgb components.

      sw $t0, 0($s0)             # Paint pixel by storing on the screen.

      # Do the same process to compose the grey scale RGB string of bits.

      move $t0, $t3               
      sll $t3, $t3, 16
      or $t3, $t3, $t0
      sll $t0, $t0, 8
      or $t3, $t3,$t0

      sw $t3, 0($s2)             # Stores the average pixel on the grey scale image's reserved space.


      add $s0, $s0, $s4           # Updates screen address.
      add $s2, $s2, $s4           # Updates the grey_scale_image pixel address.
      add $t8, $t8, $s3           # Updates file address.
      add $t3, $zero, $zero
      blt $t8, $t9, paint_pixel  # Are we done with this line?

      sub $s0, $s0, $s6
      sub $s2, $s2, $s6
      sub $s1, $s1, $s5          # Finished painting one line, decrement s1
      bnez $s1, paint_line       # Are we done yet?

  #jal edge_detection

  #li $a0, 90
  #la $a1, grey_scale_image
  #la $a2, screen
  
  #jal thresholding_effect

  #jal print_grey_scale_image

  j exit

# --------------------------------------------------------------------------- #
#                                 Output file                                 #
# --------------------------------------------------------------------------- #
continue:

  # Request output path from the user
  la $a0, output_msg
  la $a1, output
  li $a2, 1
  jal open_file

  lw $a0, output
  jal write_file_header

  lw $a0, output
  jal write_image_header

  la $s0, screen + 1046528   # s0 is the start of the last line of the screen
  li $s1, 512                # How many lines are left?
  li $s2, 512                # How many pixels are left in the current line?
  li $a2, 1536               # The size of each line when written in the file

  lw $a0, output             # Load file decriptor
  la $a1, buffer             # Load buffer address

write:
  lw $t0, 0($s0)             # Get color value

  sb $t0, 0($a1)             # Write blue component
  srl $t0, $t0, 8            # Prepare green component
  sb $t0, 1($a1)             # Write green component
  srl $t0, $t0, 8            # Prepare red component
  sb $t0, 2($a1)             # Write red component

  addi $s0, $s0, 4           # Update pointer to the screen
  addi $a1, $a1, 3           # Update pointer to output buffer
  addi $s2, $s2, -1          # Decrement counter of pixels written
  bnez $s2, write            # Are we done with this line?

  li $s2, 512                # Reset pixels counter
  la $a1, buffer             # Reset buffer pointer
  addi $s0, $s0, -4096       # Update pointer to the start of the previous line

  li $v0, 15                 # Write file syscall code
  syscall

  addi $s1, $s1, -1          # Decrement line counter
  bnez $s1, write            # Are we done?

# --------------------------------------------------------------------------- #
#                                  Functions                                  #
# --------------------------------------------------------------------------- #

exit:
  li $v0, 10
  syscall

# a0: Address of a message to present the user
# a1: Address to store the file descriptor
# a2: Open mode

open_file:
  addi $sp, $sp, -12
  sw $ra, 0($sp)
  sw $a1, 4($sp)
  sw $a2, 8($sp)

  # Request path from the user
  li $v0, 4
  syscall

  # Get user input
  la $a0, path
  li $a1, 500
  li $v0, 8
  syscall

  jal remove_char            # Remove ending \n from the input

  la $a0, path               # Set image path
  lw $a1, 8($sp)             # Get open mode
  li $a2, 0                  # ??
  li $v0, 13                 # Open file syscall code
  syscall

  blt $v0, $zero, open_error # Stop program if failed to open the file

  lw $t0, 4($sp)             # Get file descriptor address
  sw $v0, ($t0)              # Store file descriptor

  # a1 and a2 are not restored
  lw $ra, 0($sp)
  addi $sp, $sp, 12
  jr $ra

# $a0: file descriptor
read_file_header:
  # Load file header info
  la $a1, buffer
  li $a2, 14
  li $v0, 14
  syscall

  tnei $v0, 14 # Trap in case of error

  # The first byte must be a letter 'B'
  lbu $t0, 0($a1)
  bne $t0, 'B', invalid_file

  # The second byte must be a letter 'M'
  lbu $t0, 1($a1)
  bne $t0, 'M', invalid_file

  jr $ra

# $a0: file descriptor
read_image_header:
  # Load image header
  la $a1, buffer
  li $a2, 40
  li $v0, 14
  syscall

  lw $t0, 0($a1)                 # Load actual header size
  addi $a2, $t0, -40             # How many bytes are left to read?

  lw $t0, 4($a1)                 # Load image width
  bne $t0, 512, invalid_file     # Image width must be 512

  lw $t0, 8($a1)                 # Load image height
  bne $t0, 512, invalid_file     # Image height also must be 512

  lhu $t0, 14($a1)               # Load pixel size in bits
  bne $t0, 24, invalid_file      # Only 24-bit images are supported

  bne $a2, $zero, discard_header # Do we have any more header data to read?
  jr $ra

# $a0: file descriptor
# $a1: buffer to be used
# $a2: bytes left
discard_header:
  tgei $t0, 1536                 # Trap if header is too big

  # Discard the rest of the header
  li $v0, 14
  syscall

  jr $ra

# $a0: file descriptor
write_file_header:
  la $a1, buffer

  # The first byte is a letter 'B'
  li $t0, 'B'
  sb $t0, 0($a1)

  # The second byte is a letter 'M'
  li $t0, 'M'
  sb $t0, 1($a1)

  # Total file size
  li $t0, 786486
  usw $t0, 2($a1)

  # Reserved bytes (must be zero)
  sh $zero, 6($a1)
  sh $zero, 8($a1)

  # Offset
  li $t0, 54
  usw $t0, 10($a1)

  # Write file header
  li $a2, 14
  li $v0, 15
  syscall

  tnei $v0, 14 # Trap in case of error

  jr $ra

# $a0: file descriptor
write_image_header:
  la $a1, buffer
  li $a2, 40

  # Total header size
  sw $a2, 0($a1)

  # Image size
  li $t0, 512
  sw $t0, 4($a1)
  sw $t0, 8($a1)

  # Image planes
  li $t0, 1
  sh $t0, 12($a1)

  # Image bit count
  li $t0, 24
  sh $t0, 14($a1)

  # Image compression
  sw $zero, 16($a1)

  # Image size (2)
  sw $zero, 20($a1)

  # Image preferred resolution
  sw $zero, 24($a1)
  sw $zero, 28($a1)

  # Image colors
  sw $zero, 32($a1)
  sw $zero, 36($a1)

  # Write image header
  li $v0, 15
  syscall

  tnei $v0, 40 # Trap in case of error

  jr $ra

invalid_file:
  li $v0, 4
  la $a0, error_msg
  syscall

  li $v0, 17
  li $a0, 1
  syscall

open_error:
  li $v0, 4
  la $a0, open_error_msg
  syscall

  li $v0, 17
  li $a0, 2
  syscall

# a0: address to a null-terminated string; MUST HAVE LENGTH >= 1
remove_char:
  lbu $t0, 0($a0)
  addiu $a0, $a0, 1
  bnez $t0, remove_char

  sb $zero, -2($a0)
  jr $ra

print_image:
  move $s0, $a0
  la $s1, screen
  addi $s2, $s1, 1048576

  transfer:
    lw $t1, 0($s0)
    sw $t1, 0($s1)

    addi $s0, $s0, 4
    addi $s1, $s1, 4

    bne $s2, $s1, transfer
    jr $ra

# Retrieves the address to the first element o of the image corresponding to the convolution matrix.
first_kernel_element_address_offset:

  move $t5, $a0		# Proportional value of columns to the left or right.
  move $t6, $a1		# Kernel's line number.

  mul $t6, $t6, -2048
  mul $t5, $t5, 4

  sub $v0, $t6, $t5

  jr $ra

# a0: Pixel line counter.
# a1: Kernel's line number.
first_element_line_offset:
  mul $a1, $a1, -2048
  sub $a0, $a0, 1
  mul $a0, $a0, 4

  sub $v0, $a1, $a0

  jr $ra

# Retieves the value used to define how many columns are to the left or to the right.
# a0: Number of elements of the kernel.
# a1: Number of columns in the kernel.
distribution_column_value:
  div $a0, $a0, 2
  add $a0, $a0, 1

  subtraction_loop:
    sub $a0, $a0, $a1
    bgez $a0, subtraction_loop

  mul $v0, $a0, -1

  jr $ra

print_new_image:

  la $a0, new_image
  sub $sp, $sp, 4
  sw $ra, 0($sp)

  jal print_image

  lw $ra, 0($sp)
  add $sp, $sp, 4

  jr $ra

print_grey_scale_image:

  la $a0, grey_scale_image
  sub $sp, $sp, 4
  sw $ra, 0($sp)

  jal print_image

  lw $ra, 0($sp)
  add $sp, $sp, 4

  jr $ra

# --------------------------------------------------------------------------- #
#                                 Blur Effect                                 #
# --------------------------------------------------------------------------- #
blur_effect:

  sub $sp, $sp, 4
  sw $ra, 0($sp)
  move $s0, $zero		# $s0 has the kernel value.
  la $s1, kernel		# $s1 will keep the kernel address.
  move $s2, $a0			# $s2 will keep the initial adress of the original image.
  addi $s3, $s2, 1048576	# $s3 will keep the final address of the original image.
  la $s4, new_image		# $s4 has the new image's address.
  li $t0, 1			# $t0 will perform as a pixel line counter (1 - 512).
  li $t1, 0			# $t1 will be our counter for the kernel pixel line.
  move $t3, $s2			# Address to retrieved pixel.
  li $t9, 0			# $t9 will hold the number of processed elements of the kernel.

  la $t5, kernel_size
  la $t6, kernel_columns
  lw $t5, 0($t5)
  lw $t6, 0($t6)

  move $a0, $t5			# Number of kernel's elements.
  move $a1, $t6			# Number of kernel's columns.

  jal distribution_column_value

  move $t5, $v0

  la $t6, kernel_distribution_number
  sw $t5, 0($t6)

  move $a0, $t5			# Number of proportional columns to the right or lefft of the center of the convolution matrix.

  la $t6, kernel_line_number
  sw $t5, 0($t6)

  move $a1, $t5			# First line number is the number of lines of the convolution matrix.

  jal first_kernel_element_address_offset

  move $t8, $v0
  la $t5, kernel_columns
  lw $t7, 0($t5)

  move $t2, $zero	# $t2 will be used to accumulate the kernel value.
  move $s5, $zero	# $s5 will keep the sum's result of red component.
  move $s6, $zero	# $s6 will keep the sum's result of green component.
  move $s7, $zero	# $s7 will keep the sum's result of blue component.

  pixel_processing:

    beq $t1, $t7, end_line

    add $t4, $t3, $t8	# $t4 is the matching pixel to the convolution matrix.
    addi $t8, $t8, 4	# Increment to define the next pixel address offset.
    addi $t1, $t1, 1	# Increment on the kernel's pixel line counter.
    addi $t9, $t9, 1	# Increment on the number of kernel elements processed.

    blt $t4, $s2, pixel_processing	# Ignores pixel with address lower than the beginning of the image.
    bgt $t4, $s3, pixel_processing	# Ignores pixel with address higher than the end of the image.

    la $t6, kernel_line_number
    lw $t5, 0($t6)

    move $a0, $t0
    move $a1, $t5

    jal first_element_line_offset

    add $t6, $t3, $v0

    blt $t4, $t6, pixel_processing

    addi $t6, $t6, 2048

    bgt $t4, $t6, pixel_processing

    move $t5, $t4		# $t5 holds the address of the pixel.

    lbu $t6, 2($t5)		# $t6 holds the component value.
    sll $t4, $t9, 2
    sub $t4, $t4, 4
    add $t4, $t4, $s1
    lw $t4, 0($t4)		# Now $t4 holds the kernel element value.

    mul $t6, $t6, $t4		# Multiplication of kernel value by the pixel red component value.
    add $s5, $s5, $t6

    lbu $t6, 1($t5)
    mul $t6, $t6, $t4		# Multiplication of kernel value by the pixel gree component value.
    add $s6, $s6,$t6

    lbu $t6, 0($t5)
    mul $t6, $t6, $t4		# Multiplication of kernel value by the pixel blue component value.
    add $s7, $s7, $t6

    add $t2, $t2, $t4		# Sums the kernel element value to compose the total of the valid kernel.

    j pixel_processing

    end_line:

      la $t6, kernel_size	# Checks if all elements of kernel were processed.
      lw $t5, 0($t6)
      move $a0, $t5
      beq $t9, $t5, end_load

      li $t1, 0					# $t1 will be our counter for the kernel pixel line.
      la $t6, kernel_line_number
      lw $t5, 0($t6)
      addi $t5, $t5, -1
      sw $t5, 0($t6)
      move $a1, $t5

      la $t6, kernel_distribution_number
      lw $t5, 0($t6)
      move $a0, $t5

      jal first_kernel_element_address_offset

      move $t8, $v0

      j pixel_processing

    end_load:

    divu $s5, $s5, $t2
    divu $s6, $s6, $t2
    div $s7, $s7, $t2

    move $t5, $s5

    sll $t5, $t5, 16           # Prepare component to be joined; red   <<= 16
    sll $s6, $s6, 8            # Prepare component to be joined; green <<=  8

    or $t5, $t5, $s6           # t0 contains red and green components
    or $t5, $t5, $s7           # t0 contains all rgb components

    sw $t5, 0($s4)			# Stores the new pixel on the new_image address.

    addi $s4, $s4, 4			# Increment on the new_image address to point to the next pixel.
    addi $t3, $t3, 4			# Increment on the image next pixel.
    addi $t0, $t0, 1			# Increment on the pixel line counter.
    la $t5, kernel_columns		# Retrieves the number of columns of the kernel.
    lw $t7, 0($t5)			# Resets the limit of elements in one line f the kernel.

    la $t6, kernel_distribution_number	# Retieves the kernel distribution number address.
    lw $t5, 0($t6)			# Retieves the kernel distribution number value.
    move $a0, $t5			# Sets the distribution number.

    la $t6, kernel_line_number		# Gets the address of the kernel line number.
    sw $t5, 0($t6)			# Resets the kernel line number.

    move $a1, $t5			# Sets the number of the line.

    jal first_kernel_element_address_offset

    move $t8, $v0

    move $t2, $zero	# $t2 will be used to accumulate the kernel value.
    move $s5, $zero	# $s5 will keep the sum's result of red component.
    move $s6, $zero	# $s6 will keep the sum's result of green component.
    move $s7, $zero	# $s7 will keep the sum's result of blue component.
    move $t9, $zero
    move $t1, $zero

    bgt $t3, $s3, end_blur
    blt $t0, 513, pixel_processing

    li $t0, 1
    j pixel_processing

    end_blur:

      lw $ra, 0($sp)
      add $sp, $sp, 4
      jr $ra

# --------------------------------------------------------------------------- #
#                               Edge Detection                                #
# --------------------------------------------------------------------------- #

edge_detection:

  sub $sp, $sp, 4
  sw $ra, 0($sp)

  # Apply blur effect on grey scale image.

  la $a0, grey_scale_image
  jal blur_effect

  la $a0, new_image
  jal print_image

  # Build new image G(x). Vertical edges.

  la $a0, new_image
  la $a1, kernel_gx
  la $a2, screen
  la $a3, kernel_gy

  jal edge_convolution

  #la $a0, vertical_edge_image

  #jal print_image

  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra

  # Build new image G(y). Horizontal edges.

  # Compute the magnetude of the gradient and stores on the new image allocated space.

edge_convolution:

  sub $sp, $sp, 4		# Opens an space for one element on the stack.
  sw $ra, 0($sp)		# Stores the return address on the stack.

  move $s0, $a1			# $s0 will keep the G(x) kernel's address.
  move $s1, $a0			# $s1 will keep the initial adress of the image being analyzed.
  addi $s2, $s1, 1048576	# $s2 will keep the final address of the original image.
  move $s3, $a2			# $s3 has the initial address of the output image.
  move $s4, $zero		# $s4 will keep the result of the vertical convolution.
  move $s5, $a3     		# $s5 will keep the G(y) kernel's address.
  move $s6, $zero		# $s6 will store the result of the horizontal convolution.


  li $t0, 1			# $t0 will perform as a pixel line counter (1 - 512). Tells wich pixel we're analyzing on the line.
  li $t1, 0			# $t1 will be our counter for the kernel pixel line. Tells wich element of the kernel line is being used.
  move $t3, $s1			# Address to retrieved pixel. That's the address of the ppixel being analyzed.
  li $t9, 0			# $t9 will hold the number of processed elements of the kernel.

  la $t5, kernel_size
  la $t6, kernel_columns
  lw $t5, 0($t5)
  lw $t6, 0($t6)

  move $a0, $t5			# Number of kernel's elements.
  move $a1, $t6			# Number of kernel's columns.

  jal distribution_column_value

  move $t5, $v0

  la $t6, kernel_distribution_number
  sw $t5, 0($t6)

  move $a0, $t5			# Number of proportional columns to the right or lefft of the center of the convolution matrix.

  la $t6, kernel_line_number
  sw $t5, 0($t6)

  move $a1, $t5			# First line number is the number of lines of the convolution matrix.

  jal first_kernel_element_address_offset

  move $t8, $v0
  la $t5, kernel_columns
  lw $t7, 0($t5)

  j end_pixel_convolution

  pixel_convolution:

    beq $t1, $t7, end_kernel_line

    add $t4, $t3, $t8	# $t4 is the matching pixel to the convolution matrix.
    addi $t8, $t8, 4	# Increment to define the next pixel address offset.
    addi $t1, $t1, 1	# Increment on the kernel's pixel line counter.
    addi $t9, $t9, 1	# Increment on the number of kernel elements processed.

    blt $t4, $s1, pixel_convolution	# Ignores pixel with address lower than the beginning of the image.
    bgt $t4, $s2, pixel_convolution	# Ignores pixel with address higher than the end of the image.

    la $t6, kernel_line_number
    lw $t5, 0($t6)

    move $a0, $t0
    move $a1, $t5

    jal first_element_line_offset

    add $t6, $t3, $v0

    blt $t4, $t6, pixel_convolution

    addi $t6, $t6, 2048

    bgt $t4, $t6, pixel_convolution

    move $t5, $t4		# $t5 holds the address of the pixel.

    lbu $t6, 0($t5)		# $t6 holds the component value.

    sll $t4, $t9, 2
    sub $t4, $t4, 4
    add $t4, $t4, $s0
    lw $t4, 0($t4)		# Now $t4 holds the vertical kernel element value.

    mul $t6, $t6, $t4		# Multiplication of kernel value by the pixel red component value.
    add $s4, $s4, $t6

    sll $t4, $t9, 2
    sub $t4, $t4, 4
    add $t4, $t4, $s5
    lw $t4, 0($t4)		# Now $t4 holds the vertical kernel element value.

    mul $t6, $t6, $t4		# Multiplication of kernel value by the pixel red component value.
    add $s6, $s6, $t6

    j pixel_convolution

    end_kernel_line:

      la $t6, kernel_size	# Checks if all elements of kernel were processed.
      lw $t5, 0($t6)
      move $a0, $t5
      beq $t9, $t5, end_pixel_convolution

      li $t1, 0					# $t1 will be our counter for the kernel pixel line.
      la $t6, kernel_line_number
      lw $t5, 0($t6)
      addi $t5, $t5, -1
      sw $t5, 0($t6)
      move $a1, $t5

      la $t6, kernel_distribution_number
      lw $t5, 0($t6)
      move $a0, $t5

      jal first_kernel_element_address_offset

      move $t8, $v0

      j pixel_convolution

    end_pixel_convolution:

    abs $s4, $s4
    abs $s6, $s6

    add $s4, $s4, $s6

    andi $s4, $s4, 255

    move $t5, $s4			# Moves the result of the convolution on the pixel to $t5.

    sll $t5, $t5, 16           		# Fills the red component with $t5 value.
    or $t5, $t5, $s4           		# Fills the blue component with $t5 value.
    sll $s4, $s4, 8            		# Prepares the green component to be allocated on the pixel word.
    or $t5, $t5, $s4           		# Fills the green component with $t5 value.

    sw $t5, 0($s3)			# Stores the new pixel value on the output image address.

    addi $s3, $s3, 4			# Increment on the output image address to point to the next pixel.
    addi $t3, $t3, 4			# Increment on the image next pixel.
    addi $t0, $t0, 1			# Increment on the pixel line counter.
    la $t5, kernel_columns		# Retrieves the number of columns of the kernel.
    lw $t7, 0($t5)			# Resets the limit of elements in one line of the kernel.

    la $t6, kernel_distribution_number	# Retieves the kernel distribution number address.
    lw $t5, 0($t6)			# Retieves the kernel distribution number value.
    move $a0, $t5			# Sets the distribution number to $a0.

    la $t6, kernel_line_number		# Gets the address of the kernel line number.
    sw $t5, 0($t6)			# Resets the kernel line number with the distribution value.

    move $a1, $t5			# Sets the number of the line.

    jal first_kernel_element_address_offset

    move $t8, $v0

    move $s4, $zero	# Resets the x gradient value.
    move $s6, $zero	# Resets the y gradient value.
    move $t9, $zero	# Resets the value that idicates wich kernel element is being analyzed.
    move $t1, $zero	# Resets the counter for the element of the kernel line.

    beq $t0, 512, end_pixel_convolution
    bgt $t3, $s2, end_edge_convolution
    blt $t0, 513, pixel_convolution

    li $t0, 1
    beq $t0, 1, end_pixel_convolution
    j pixel_convolution

    end_edge_convolution:

      lw $ra, 0($sp)
      add $sp, $sp, 4
      jr $ra

# --------------------------------------------------------------------------- #
#                                 Thresholding                                #
# --------------------------------------------------------------------------- #

thresholding_effect:

  move $s0, $a0			# User's defined threshold value.
  move $s1, $a1			# Image's address.
  move $s2, $a2			# Output's address.
  addi $s3, $s1, 1048576	# Image's final address.
  li $s4, 4			# Constant defined on register to improve performance.

  sub $sp, $sp, $s4		# Stores the return address on the stack until the end of the procedure.
  sw $ra, 0($sp)

  threshold:

    lbu $t0, 0($s1)		# Gets the pixel's component value.

    blt $t0, $s0, low_threshold	# If the component is less than threshold the new value will be 0.
    li $t1, 255			# If the component is greater than threshold the new value will be 255.
    j pixel_assembly

    low_threshold:		# If the new component's value is 0, there is no need to mount the RGB string.

      move $t0, $zero
      j pixel_writting

    pixel_assembly:		# If the new value is not zero, we mount the RGB string.

      move $t0, $t1
      sll $t0, $t0, 16
      or $t0, $t0, $t1
      sll $t1, $t1, 8
      or $t0, $t0, $t1

    pixel_writting:		# Stores the new component's value on the given output address.

      sw $t0, 0($s2)
      add $s1, $s1, $s4
      add $s2, $s2, $s4

      beq $s1, $s3, end_threshold
      j threshold		

      end_threshold:		# Resume to the caller.

        lw $ra, 0($sp)
        add $sp, $sp, $s4
        jr $ra




