# Compute average of two numbers without overflow
# x0 = (x1 + x2) / 2
# Uses: (a + b) / 2 = (a & b) + (a ^ b) >> 1

and x3, x1, x2       # x3 = common bits
xor x4, x1, x2       # x4 = differing bits
slli x4, x4, 32      # Shift by 32 (arithmetic right shift by 1 would be srli x4, x4, 1)
add x0, x3, x4       # x0 = common + (diff >> 1)
