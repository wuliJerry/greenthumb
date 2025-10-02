# Compute absolute difference: |x1 - x2|
# Inefficient version that can be optimized

sub x3, x1, x2       # x3 = x1 - x2
sub x4, x2, x1       # x4 = x2 - x1
srai x5, x3, 32      # x5 = sign extend of (x1-x2)
and x6, x5, x4       # x6 = (x2-x1) if x3<0, else 0
xor x7, x5, x5       # x7 = 0
sub x8, x7, x5       # x8 = -sign
and x9, x8, x3       # x9 = (x1-x2) if x3>=0, else 0
or x0, x6, x9        # x0 = absolute difference
