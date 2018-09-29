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
  # Request input path from the user
  la $a0, input_msg
  la $a1, input
  li $a2, 0
  jal open_file

  # Request output path from the user
  la $a0, output_msg
  la $a1, output
  li $a2, 1
  jal open_file

  # Load file header info
  lw $a0, input
  la $a1, buffer
  li $a2, 14
  li $v0, 14
  syscall

  # The first byte must be a letter 'B'
  lbu $t1, 0($a1)
  li $t2, 'B'
  bne $t1, $t2, invalid_file

  # The second byte must be a letter 'M'
  lbu $t1, 1($a1)
  li $t2, 'M'
  bne $t1, $t2, invalid_file

  # Load image header
  lw $a0, input
  li $a2, 40
  li $v0, 14
  syscall

  la $s0, buffer             # Load header base address

  lw $t0, 4($s0)             # Load image width
  bne $t0, 512, invalid_file # Image width must be 512
  lw $t0, 8($s0)             # Load image height
  bne $t0, 512, invalid_file # Image height also must be 512

  lhu $t0, 14($s0)           # Load pixel size in bits
  bne $t0, 24, invalid_file  # Only 24-bit images are supported

  lw $t0, 0($s0)             # Load actual header size
  addi $t0, $t0, -40         # How many bytes are left to read?

  beq $t0, $zero, paint      # Do we have any more header data to read?
  tgei $t0, 1536             # Trap if header is too big

  # Just discard the rest of the header
  lw $a0, input
  move $a2, $t0
  li $v0, 14
  syscall

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
