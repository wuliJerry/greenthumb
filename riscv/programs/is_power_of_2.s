# Check if x1 is a power of 2 (has exactly one bit set)
# Result: x0 = 1 if power of 2, 0 otherwise
# Uses property: x & (x-1) == 0 for powers of 2

addi x2, x1, -1      # x2 = x1 - 1
and x3, x1, x2       # x3 = x1 & (x1 - 1), should be 0 for power of 2
xori x4, x3, 0       # x4 = x3 (identity, but shows comparison with 0)
# In a real implementation, we'd need conditional logic which isn't in our subset
# This is a partial implementation to demonstrate the concept
