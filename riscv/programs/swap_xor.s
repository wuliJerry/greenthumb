# XOR swap: swap x0 and x1 without temporary
# Initial: x0=a, x1=b
# Final: x0=b, x1=a
xor x0, x0, x1   # x0 = a ^ b
xor x1, x0, x1   # x1 = (a ^ b) ^ b = a
xor x0, x0, x1   # x0 = (a ^ b) ^ a = b
