# Double negation (3 instructions -> 1)
# Compute x0 = -(-x1) = x1
# Inefficient: manually compute two's complement twice

xori x2, x1, -1      # x2 = ~x1
addi x3, x2, 1       # x3 = -x1
xori x4, x3, -1      # x4 = ~(-x1)
addi x0, x4, 1       # x0 = -(-x1) = x1
