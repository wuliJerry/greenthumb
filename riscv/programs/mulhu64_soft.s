# Multiply high unsigned (64-bit x 64-bit -> high 64 bits)
# Computes high 64 bits of x10 * x11 (a0 * a1)
# Software implementation of 64-bit unsigned multiply high

srli x6, x10, 32
addi x29, x0, -1
srli x29, x29, 32
and  x5, x10, x29

srli x28, x11, 32
and  x7, x11, x29

mul x29, x5, x7
mul x30, x5, x28
mul x31, x6, x7
mul x10, x6, x28

srli x5, x29, 32
add  x30, x30, x5
sltu x5, x30, x5

add  x6, x30, x31
sltu x7, x6, x31
add  x5, x5, x7

slli x5, x5, 32
srli x6, x6, 32
or   x5, x5, x6
add  x10, x10, x5
