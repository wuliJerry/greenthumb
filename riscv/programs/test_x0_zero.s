# Test that x0 is hardwired to zero
# This program attempts to write to x0 and verifies it stays 0

# Try to write 42 to x0 (should be discarded)
addi x0, x0, 42

# Try to add two numbers to x0 (should be discarded)
addi x1, x0, 10      # x1 = 0 + 10 = 10
addi x2, x0, 20      # x2 = 0 + 20 = 20
add x0, x1, x2       # x0 should remain 0 (write discarded)

# Verify x0 is still 0 by using it in computation
add x3, x0, x1       # x3 = 0 + 10 = 10
sub x4, x3, x0       # x4 = 10 - 0 = 10

# x0 should be 0, x1=10, x2=20, x3=10, x4=10
