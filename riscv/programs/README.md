# RISC-V Test Programs for Superoptimization

This directory contains optimizable test programs of varying lengths (2-7 instructions) for testing the superoptimizer.

## File Format

- `.s` files contain RISC-V assembly code
- `.s.info` files contain metadata in the format:
  ```
  <live-out registers>
  <live-in registers>
  ```
  Where registers are space-separated indices (e.g., `0` for x0 output, `1` for x1 input)

## Test Programs (by complexity)

### 2 Instructions → 1 ⭐
**negate.s** - Two's complement negation
- **Unoptimized**: `xori x2,x1,-1; addi x0,x2,1` (manual two's complement)
- **Optimal**: `neg x0, x1` (pseudo-instruction)
- **Expected speedup**: 2x reduction
- **Difficulty**: Easy (symbolic search finds it in ~6 seconds)

### 3 Instructions → 1
**identity.s** - Identity function via redundant additions
- **Unoptimized**: `addi x2,x1,1; addi x3,x2,1; addi x0,x3,-2` (computes x1+2-2 = x1)
- **Optimal**: `addi x0, x1, 0` or equivalent
- **Difficulty**: Medium (may require hybrid search)

### 4 Instructions → 1
**double_negate.s** - Double negation equals identity
- **Unoptimized**: Two applications of two's complement (-(-x) computed manually)
- **Optimal**: `addi x0, x1, 0` or equivalent move
- **Difficulty**: Hard (requires pattern recognition)

### 5 Instructions → 1
**identity_5inst.s** - Medium identity chain
- **Unoptimized**: Chain of additions/subtractions that cancel out
- **Optimal**: Move or add zero
- **Difficulty**: Hard (best with stochastic or hybrid)

### 6 Instructions → 1
**complex_identity.s** - Complex redundant operations
- **Unoptimized**: Longer chain: x1+1-1+1-1+1-1 = x1
- **Optimal**: Move or add zero
- **Difficulty**: Very Hard (requires longer timeouts)

### 7 Instructions → 1
**identity_7inst.s** - Long identity chain
- **Unoptimized**: x1+1+1+1-1-1-1+0 = x1
- **Optimal**: Move or add zero
- **Difficulty**: Very Hard (primarily for stochastic search)

## Search Strategy Recommendations

### Quick Test (Symbolic Search)
```bash
racket optimize.rkt --sym -l -c 1 -t 60 programs/negate.s
```
- **Best for**: 2-3 instruction programs
- **Expected time**: 5-15 seconds for negate.s
- **Success rate**: High for simple patterns

### Medium Programs (Hybrid Search) ⭐ Recommended
```bash
racket optimize.rkt --hybrid -p -c 4 -t 120 programs/double_negate.s
```
- **Best for**: 3-5 instruction programs
- **Expected time**: 30-90 seconds
- **Success rate**: Good (combines all search strategies)

### Long Programs (Stochastic Search)
```bash
racket optimize.rkt --stoch -o -c 8 -t 300 programs/identity_7inst.s
```
- **Best for**: 5-7 instruction programs
- **Expected time**: Variable (randomized search)
- **Success rate**: Moderate (depends on luck and time)

## Known Limitations

1. **Arithmetic reasoning**: The symbolic solver may struggle with programs requiring arithmetic identities (e.g., x+1-1=x) because:
   - Constants are limited to `'(0 1 -1 -2 -8)`
   - SMT solver needs to reason about bitvector arithmetic

2. **Shift constraints**: All immediate shift amounts are fixed at 32

3. **Search space**: Longer programs (5+ instructions) have exponentially larger search spaces

## Success Criteria

- ✅ **Perfect**: Finds the 1-instruction optimal solution
- ✅ **Good**: Finds any shorter correct solution
- ⚠️ **Timeout**: Returns original program (no optimization found in time limit)

## Running Tests

### Quick verification (all programs)
```bash
cd riscv
racket test-program.rkt
```

### Optimize specific program
```bash
cd riscv
racket optimize.rkt --hybrid -p -c 4 -t 120 programs/negate.s
```

### Check optimization result
```bash
cat output/0/best-1.s        # View optimized program
cat output/0/summary         # View cost,len,time,source
```
