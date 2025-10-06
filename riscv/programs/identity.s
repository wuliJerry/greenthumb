# Identity with add/sub (3 instructions -> 1)
# Compute x4 = (x1 + 2) - 2 = x1
# Inefficient: add then subtract same value

addi x2, x1, 1       # x2 = x1 + 1
addi x3, x2, 1       # x3 = x1 + 2
addi x4, x3, -2      # x4 = x1 + 2 - 2 = x1
