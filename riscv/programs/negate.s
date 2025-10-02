# Negate a number: x0 = -x1
# Using two's complement: -x = ~x + 1

xori x2, x1, -1      # x2 = ~x1 (flip all bits)
addi x0, x2, 1       # x0 = ~x1 + 1 = -x1
