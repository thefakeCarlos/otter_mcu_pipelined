addi x7, zero, 7
lui  x8, 0x11000
addi x8, x8, 0x20
addi x10, zero, 10
or x11, x7, x10
sw x11, 0(x8)