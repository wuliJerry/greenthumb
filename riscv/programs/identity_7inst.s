# Long identity chain (7 instructions -> 1)
# Compute x8 = x1 through redundant operations
# x1 + 3 - 2 - 1 + 0 = x1

addi x2, x1, 1       # x2 = x1 + 1
addi x3, x2, 1       # x3 = x1 + 2
addi x4, x3, 1       # x4 = x1 + 3
addi x5, x4, -1      # x5 = x1 + 2
addi x6, x5, -1      # x6 = x1 + 1
addi x7, x6, -1      # x7 = x1
addi x8, x7, 0       # x8 = x1
