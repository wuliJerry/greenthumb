# Clear the rightmost set bit
# x0 = x1 & (x1 - 1)
# For example: x1 = 0b10110 -> x0 = 0b10100

addi x2, x1, -1      # x2 = x1 - 1
and x0, x1, x2       # x0 = x1 & (x1 - 1)
