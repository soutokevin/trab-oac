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

  bne $v0, $a2, invalid_file # Make sure a full line was read

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

# --------------------------------------------------------------------------- #
#                                 Output file                                 #
# --------------------------------------------------------------------------- #

  # Request output path from the user
  la $a0, output_msg
  la $a1, output
  li $a2, 1
  jal open_file

  lw $a0, output
  jal write_file_header

  lw $a0, output
  jal write_image_header

  la $s0, screen             # s0 is the start of the screen
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
