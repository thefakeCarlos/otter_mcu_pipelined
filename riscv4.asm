lui x15, 0x11000
addi x15, x15, 0x20
li x10, 5
li x8, 0
beqz x8, test
addi x10, zero, 16
addi x10, zero, 17
sw x10, 0(x15)
ret
test:
sw x10, 0(x15)