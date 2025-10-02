# Create a mask with lower N bits set
# This example sets lower 8 bits
# Could be optimized to use shifts more efficiently

addi x2, x0, 1       # x2 = 1
slli x2, x2, 32      # x2 = 1 << 8 = 256
addi x0, x2, -1      # x0 = 256 - 1 = 255 (0xFF)
