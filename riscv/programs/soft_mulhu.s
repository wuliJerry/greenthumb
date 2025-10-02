# Software implementation of MULHU (multiply high unsigned) - SIMPLIFIED
# NOTE: This is a simplified version using only the available instruction subset.
# The original algorithm requires SLTU (set less than unsigned) which is not implemented.
# This version computes a partial result without carry handling.
#
# Input: x10 (a0), x11 (a1) - 64-bit unsigned integers
# Output: x10 (a0) - approximation of upper 64 bits of the 128-bit product
# Uses temporary registers: x5-x7, x28-x31 (t0-t6)

srli x6, x10, 32      # t1 = a0 >> 32 (high 32 bits of a0)
addi x29, x0, -1      # t4 = -1 (0xFFFFFFFFFFFFFFFF)
srli x29, x29, 32     # t4 = 0x00000000FFFFFFFF (mask for low 32 bits)
and  x5, x10, x29     # t0 = a0 & mask (low 32 bits of a0)

srli x28, x11, 32     # t3 = a1 >> 32 (high 32 bits of a1)
and  x7, x11, x29     # t2 = a1 & mask (low 32 bits of a1)

mul x29, x5, x7       # t4 = t0 * t2 (low*low)
mul x30, x5, x28      # t5 = t0 * t3 (low*high)
mul x31, x6, x7       # t6 = t1 * t2 (high*low)
mul x10, x6, x28      # a0 = t1 * t3 (high*high)

srli x5, x29, 32      # t0 = t4 >> 32
add  x30, x30, x5     # t5 = t5 + t0
# NOTE: Original has SLTU here for carry - not available in our subset

add  x6, x30, x31     # t1 = t5 + t6
# NOTE: Original has SLTU here for carry - not available in our subset

slli x5, x5, 32       # t0 = t0 << 32 (reusing t0, not accurate without carry)
srli x6, x6, 32       # t1 = t1 >> 32
or   x5, x5, x6       # t0 = (t0 << 32) | (t1 >> 32)
add  x10, x10, x5     # a0 = a0 + t0
