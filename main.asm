.data
  screen: .space 1048576 # Reserve space for the bitmap display at 512x512
  open_error_msg: .asciiz "\nError while opening file\n"
  error_msg: .asciiz "\nInvalid file\n"
  path: .asciiz "images/lena.bmp"
  width: .word 0
  height: .word 0
  file: .word 0
  buffer: .space 1536

.text
  la $a0, path # set image path
  li $a1, 0    # read only mode
  li $a2, 0    # ??
  li $v0, 13   # open file syscall code
  syscall

  blt $v0, $zero, open_error # Stop program if failed to open the file
  sw $v0, file               # Store file descriptor

  # Load file header info
  move $a0, $v0
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
  lw $a0, file
  li $a2, 40
  li $v0, 14
  syscall

  la $s0, buffer             # Load header base address

  lw $t0, 0($s0)             # Load actual header size
  bne $t0, 40, invalid_file  # Header size must be 40

  lw $a0, 4($s0)             # Load image width
  sw $a0, width              # Store image width

  lw $a0, 8($s0)             # Load image height
  sw $a0, height             # Store image height

  lhu $t0, 14($s0)           # Load pixel size in bits
  bne $t0, 24, invalid_file  # Only 24-bit images are supported

  la $s0, screen             # s0 is the base address of the screen
  addi $s0, $s0, 1048576
  lw $s1, height             # s1 will count how many lines are left to paint

paint_line:
  # Load 1536 bytes (a full line) of pixel data
  lw $a0, file
  la $a1, buffer
  li $a2, 1536
  li $v0, 14
  syscall

  la $t8, buffer             # Start of loaded file content
  la $t9, buffer + 1536      # End of loaded file content

paint_pixel:
  lbu $t0, 2($t9)            # Load red component
  lbu $t1, 1($t9)            # Load green component
  lbu $t2, 0($t9)            # Load blue component

  sll $t0, $t0, 16           # Prepare component to be joined; red   <<= 16
  sll $t1, $t1, 8            # Prepare component to be joined; green <<=  8

  or $t0, $t0, $t1           # t0 contains red and green components
  or $t0, $t0, $t2           # t0 contains all rgb components

  sw $t0, 0($s0)             # Paint pixel

  addi $s0, $s0, -4           # Update screen address
  addi $t9, $t9, -3           # Update file address
  blt $t8, $t9, paint_pixel  # Are we done with this line?

  addi $s1, $s1, -1          # Finished painting one line, decrement s1
  bnez $s1, paint_line       # Are we done yet?

exit:
  li $v0, 10
  syscall

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
