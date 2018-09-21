.data
  error_msg: .asciiz "\nInvalid file\n"
  path: .asciiz "images/lena.bmp"
  file: .word 0
  size: .word 0
  header: .space 40

.text
  la $a0, path # set image path
  li $a1, 0    # read only mode
  li $a2, 0    # ??
  li $v0, 13   # open file syscall code
  syscall

  tlt $v0, $zero # Force program to stop if failed to open the file
  sw $v0, file   # Store file descriptor

  # Load file header info
  move $a0, $v0
  la $a1, header
  li $a2, 14
  li $v0, 14
  syscall

  # The first byte must be a letter 'B'
  lbu $t1, 0($a1)
  li $t2, 'B'
  tne $t1, $t2

  # The second byte must be a letter 'M'
  lbu $t1, 1($a1)
  li $t2, 'M'
  tne $t1, $t2

  # Load image header
  lw $a0, file
  li $a2, 40
  li $v0, 14
  syscall

  la $s0, header             # Load header base address

  lhu $a0, 14($s0)           # Load pixel size in bits
  li $v0, 1                  # Print Integer syscall
  syscall                    # Print read pixel size
  bne $a0, 24, invalid_file  # Only 24-bit images are supported

  # Print a single space char
  li $a0, ' '
  li $v0, 11
  syscall

  lw $a0, 4($s0)             # Load image width
  li $v0, 1                  # Print Integer syscall
  syscall                    # Print image width

  # Print a single 'x' char
  li $a0, 'x'
  li $v0, 11
  syscall

  lw $a0, 8($s0)             # Load image height
  li $v0, 1                  # Print Integer syscall
  syscall                    # Print image height

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

