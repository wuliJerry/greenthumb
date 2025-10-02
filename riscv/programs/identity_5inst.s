# Medium identity chain (5 instructions -> 1)
# Compute x0 = x1 through redundant operations
# x1 + 2 - 1 + 1 - 2 + 0 = x1

addi x2, x1, 1       # x2 = x1 + 1
addi x3, x2, 1       # x3 = x1 + 2
addi x4, x3, -1      # x4 = x1 + 1
addi x5, x4, -1      # x5 = x1
addi x0, x5, 0       # x0 = x1
