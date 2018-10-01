.data
  screen: .space 1048576 # Reserve space for the bitmap display at 512x512
  open_error_msg: .asciiz "\nError while opening file\n"
  error_msg: .asciiz "\nInvalid file\n"
  input_msg: .asciiz "Input path: "
  output_msg: .asciiz "Output path: "
  path: .space 500
  input: .word 0
  output: .word 0
  buffer: .space 1536
  new_image: .space 1048576
  kernel: .word 1,2,1,2,4,2,1,2,1
  #kernel: .word 1,1,1,1,1,1,1,1,1
  #kernel: .word 0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0
  #kernel: .word 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
  kernel_size: .word 9			# Total number of elements of the kernel (nXm).
  kernel_columns: .word 3		# Number of columns of kernel's matrix.
  kernel_lines: .word 3			# Number of lines of kernel's matrix.
  kernel_line_number: .word 0		# Holds the number of kernel's line being processed.
  kernel_distribution_number: .word 0	# Number that defines the range of elements around the kernel's center.

.text

main:
  # Request input path from the user
  la $a0, input_msg
  la $a1, input
  li $a2, 0
  jal open_file

  # Validate input file header
  lw $a0, input
  jal read_file_header

  # Validate image header
  lw $a0, input
  jal read_image_header

paint:
  la $s0, screen + 1048576   # s0 is the end of the screen
  li $s1, 512                # s1 will count how many lines are left to paint

paint_line:
  # Load 1536 bytes (a full line) of pixel data into the buffer
  lw $a0, input
  la $a1, buffer
  li $a2, 1536
  li $v0, 14
  syscall

  la $t8, buffer             # Start of loaded file content
  la $t9, buffer + 1536      # End of loaded file content

  addi $s0, $s0, -2048

paint_pixel:
  lbu $t0, 2($t8)            # Load red component
  lbu $t1, 1($t8)            # Load green component
  lbu $t2, 0($t8)            # Load blue component

  sll $t0, $t0, 16           # Prepare component to be joined; red   <<= 16
  sll $t1, $t1, 8            # Prepare component to be joined; green <<=  8

  or $t0, $t0, $t1           # t0 contains red and green components
  or $t0, $t0, $t2           # t0 contains all rgb components

  sw $t0, 0($s0)             # Paint pixel

  addi $s0, $s0, 4           # Update screen address
  addi $t8, $t8, 3           # Update file address
  blt $t8, $t9, paint_pixel  # Are we done with this line?

  addi $s0, $s0, -2048
  addi $s1, $s1, -1          # Finished painting one line, decrement s1
  bnez $s1, paint_line       # Are we done yet?

  j blur_effect

continue:
  # Request output path from the user
  la $a0, output_msg
  la $a1, output
  li $a2, 1
  jal open_file

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

#Here we apply the blur effect over the input image.
blur_effect:

  move $s0, $zero		# $s0 has the kernel value.
  la $s1, kernel		# $s1 will keep the kernel address.
  la $s2, screen		# $s2 will keep the initial adress of the original image.
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

    bgt $t3, $s3, print_blured_image
    blt $t0, 513, pixel_processing

    li $t0, 1
    j pixel_processing

print_blured_image:

  la $s0, new_image
  la $s1, screen
  addi $s2, $s1 1048576

  transfer:

    beq $s2, $s1, continue

    lw $t1, 0($s0)
    sw $t1, 0($s1)

    addi $s0, $s0, 4
    addi $s1, $s1, 4

    j transfer

# Retrieves the address to the first element o of the image corresponding to the convolution matrix.
first_kernel_element_address_offset:

  move $t5, $a0		# Proportional value of columns to the left or right.
  move $t6, $a1		# Kernel's line number.

  mul $t6, $t6, -2048
  mul $t5, $t5, 4

  sub $v0, $t6, $t5

  jr $ra

first_element_line_offset:

  move $t5, $a0		# Pixel line counter.
  move $t6, $a1		# Kernel's line number.

  mul $t6, $t6, -2048
  sub $t5, $t5, 1
  mul $t5, $t5, 4

  sub $v0, $t6, $t5

  jr $ra

#Retieves the value used to define how many columns are to the left or to the right.
distribution_column_value:

  move $t5, $a0		# Number of elements of the kernel.
  move $t6, $a1		# Number of columns in the kernel.

  div $t5, $t5, 2
  add $t5, $t5, 1

  subtraction_loop:

    sub $t5, $t5, $t6
    bltz $t5, end_subtraction_loop
    j subtraction_loop

  end_subtraction_loop:

  mul $v0, $t5, -1

  jr $ra
