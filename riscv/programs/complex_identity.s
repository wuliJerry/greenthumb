# Complex identity (6 instructions -> 1)
# Compute x0 = x1 via redundant operations
# x1 + 1 - 1 + 2 - 2 + 0 = x1

addi x2, x1, 1       # x2 = x1 + 1
addi x3, x2, -1      # x3 = x1
addi x4, x3, 1       # x4 = x1 + 1
addi x5, x4, -1      # x5 = x1
addi x6, x5, 1       # x6 = x1 + 1
addi x0, x6, -1      # x0 = x1
