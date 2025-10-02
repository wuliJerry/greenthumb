# Multiply by 3: x0 = x1 * 3
# Inefficient implementation for superoptimizer to improve

add x2, x1, x1       # x2 = x1 * 2
add x0, x2, x1       # x0 = x1 * 2 + x1 = x1 * 3
