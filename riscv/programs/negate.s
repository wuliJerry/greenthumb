# Negate a number: x3 = -x1
# Using two's complement: -x = ~x + 1

xori x2, x1, -1      # x2 = ~x1 (flip all bits)
addi x3, x2, 1       # x3 = ~x1 + 1 = -x1
