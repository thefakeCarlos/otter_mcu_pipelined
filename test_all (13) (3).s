###############################################################################
# Title: Square matrix multiplier
#
# Description:
#   Computes C = A * B for two square integer matrices of any size N.
#   The result is stored in matrix C. Uses inline repeated addition for
#   multiplication and row/column offset calculation to avoid hardcoded
#   values, supporting any NxN matrix.
#
#   On completion, writes a 1 to MMIO address 0x11000020 to signal the
#   testbench (or external observer) that the matrix multiplication is done.
#
# Register Usage:
#   s0 = base address of A
#   s1 = base address of B
#   s2 = base address of C
#   s3 = N (number of rows/cols)
#   s4 = i (row index)
#   s5 = j (column index)
#   s6 = k (dot product element index)
#   s7 = accumulator for dot product result
#   t1 = current element of A
#   t2 = current element of B
#   t3 = product of t1 * t2
#   t4 = multiply loop counter (copy of t1)
#   t5 = address scratch for A and C indexing
#   t6 = address scratch for B indexing
###############################################################################

.data
# to use a larger matrix change these values and update ROWS_COLS
# example 3x3:
#   A: .word 1, 2, 3, 4, 5, 6, 7, 8, 9
#   B: .word 9, 8, 7, 6, 5, 4, 3, 2, 1
#   C: .word 0, 0, 0, 0, 0, 0, 0, 0, 0
#   ROWS_COLS: .word 3
A: .word 1, 2, 3, 4, 5, 6, 7, 8, 9
B: .word 9, 8, 7, 6, 5, 4, 3, 2, 1
C: .word 0, 0, 0, 0, 0, 0, 0, 0, 0
ROWS_COLS: .word 3

.text

init:
    # allocate stack frame: 9 registers * 4 bytes = 36 bytes
    addi sp, sp, -36
    sw   ra, 32(sp)            # save return address
    sw   s0, 28(sp)            # save s0 - s7
    sw   s1, 24(sp)
    sw   s2, 20(sp)
    sw   s3, 16(sp)
    sw   s4, 12(sp)
    sw   s5,  8(sp)
    sw   s6,  4(sp)
    sw   s7,  0(sp)

   
    # load base matrix addresses
    la   s0, A
    la   s1, B
    la   s2, C
    la   t0, ROWS_COLS
    lw   s3, 0(t0)             # s3 = N

    li   s4, 0                 # i = 0, start at first row

###############################################################################
# rowLoop
# Outer loop -- iterates over each row i of matrix A
###############################################################################
rowLoop:
    bge  s4, s3, done          # if i >= N, all rows done
    li   s5, 0                 # j = 0, start at first column

###############################################################################
# colLoop
# Middle loop -- iterates over each column j of matrix B
# Each iteration computes one element C[i][j]
# Row start of A computed as A + i*N*4 using inline loop (no mul)
# Col start of B computed as B + j*4
###############################################################################
colLoop:
    bge  s5, s3, nextRow       # if j >= N, move to next row

    li   s7, 0                 # clear accumulator for this dot product
    li   s6, 0                 # k = 0, start at first element

    # compute row start address of A: &A[i][0] = A + i*N*4
    # i*N computed via repeated addition since no mul instruction
    li   t5, 0                 # t5 = row offset accumulator
    li   t4, 0                 # t4 = loop counter
rowOffsetLoop:
    bge  t4, s4, rowOffsetDone # if counter >= i, done
    add  t5, t5, s3            # t5 += N
    addi t4, t4, 1             # counter++
    j    rowOffsetLoop
rowOffsetDone:
    slli t5, t5, 2             # t5 = i*N*4 byte offset
    add  t5, s0, t5            # t5 = &A[i][0]

    # compute col start address of B: &B[0][j] = B + j*4
    slli t6, s5, 2             # t6 = j*4
    add  t6, s1, t6            # t6 = &B[0][j]

###############################################################################
# dotProduct
# Inner loop -- computes dot product of row i of A with column j of B
# Steps through row of A by +4 bytes each element
# Steps through col of B by +N*4 bytes each element (column stride)
# Accumulates A[i][k] * B[k][j] for all k into s7
###############################################################################
dotProduct:
    bge  s6, s3, storeResult   # if k >= N, dot product is complete

    lw   t1, 0(t5)             # t1 = A[i][k]
    lw   t2, 0(t6)             # t2 = B[k][j]

    # inline multiply: t3 = t1 * t2 via repeated addition
    # uses t4 as counter to avoid destroying t1
    li   t3, 0                 # clear product
    mv   t4, t1                # copy t1 into t4 as multiply counter
    beqz t4, skipMultiply      # if count == 0, skip multiply
    beqz t2, skipMultiply      # if value == 0, skip multiply
multiplyLoop:
    add  t3, t3, t2            # t3 += t2
    addi t4, t4, -1            # decrement counter
    bnez t4, multiplyLoop      # if counter != 0, loop back
skipMultiply:
    add  s7, s7, t3            # accumulator += product

    addi t5, t5, 4             # advance to next element in row of A (+4 bytes)
    slli t0, s3, 2             # t0 = N*4 (column stride in bytes)
    add  t6, t6, t0            # advance to next element in col of B (+N*4 bytes)

    addi s6, s6, 1             # k++
    j    dotProduct            # next element in dot product

###############################################################################
# storeResult
# Dot product for C[i][j] is complete -- store accumulator into C[i][j]
# C[i][j] address computed same way as A[i][0] but with j added
###############################################################################
storeResult:
    # compute &C[i][j] = C + i*N*4 + j*4
    li   t5, 0                 # t5 = row offset accumulator
    li   t4, 0                 # t4 = loop counter
cRowOffsetLoop:
    bge  t4, s4, cRowOffsetDone # if counter >= i, done
    add  t5, t5, s3            # t5 += N
    addi t4, t4, 1             # counter++
    j    cRowOffsetLoop
cRowOffsetDone:
    add  t5, t5, s5            # t5 = i*N + j
    slli t5, t5, 2             # t5 = (i*N + j)*4 byte offset
    add  t5, s2, t5            # t5 = address of C[i][j]
    sw   s7, 0(t5)             # C[i][j] = accumulator

    addi s5, s5, 1             # j++
    j    colLoop               # compute next element in this row

nextRow:
    addi s4, s4, 1             # i++
    j    rowLoop               # process next row

###############################################################################
# done
# All elements of C computed -- signal completion via MMIO, then
# restore registers and return.
###############################################################################
done:
    # Signal completion: write 1 to MMIO address 0x11000020
    # 0x11000020 doesn't fit in a 12-bit immediate, so split into
    # upper 20 bits (LUI) + lower 12 bits (ADDI).
    lui  t0, 0x11000           # t0 = 0x11000000
    addi t0, t0, 0x020         # t0 = 0x11000020 (MMIO completion address)
    addi t1, x0, 1             # t1 = 1 (completion value)
    sw   t1, 0(t0)             # *(0x11000020) = 1

    lw   s7,  0(sp)            # restore s7 - s0
    lw   s6,  4(sp)
    lw   s5,  8(sp)
    lw   s4, 12(sp)
    lw   s3, 16(sp)
    lw   s2, 20(sp)
    lw   s1, 24(sp)
    lw   s0, 28(sp)
    lw   ra, 32(sp)            # restore return address
    addi sp, sp, 36            # deallocate stack frame
    ret