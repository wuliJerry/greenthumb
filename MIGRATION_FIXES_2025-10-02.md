# Migration Fixes - October 2, 2025

## Summary

This document describes the fixes applied to complete the Rosette 4.1 migration that was initially incomplete, causing driver crashes during superoptimization.

## Problem

After the initial migration from Rosette 1.1 to Rosette 4.1, running the ARM superoptimizer resulted in all driver processes crashing with:
```
uncaught exception: "memory-rosette: memory size is too large."
```

## Root Cause Analysis

The migration document incorrectly stated that `solution->list` should be replaced with `sat`. This is **wrong**.

In Rosette 4.1:
- `model` extracts bindings from a satisfiable solution (returns a hash)
- `sat?` checks if a solution is satisfiable (returns boolean)
- There is NO `sat` function for extracting bindings

The incorrect usage of `sat` caused the validator to fail when extracting solution bindings, which led to infinite memory size increases during the `adjust-memory-config` phase.

## Fixes Applied

### 1. Fixed Solution API Usage (`validator.rkt`)

**Lines changed: 176, 219, 240, 243, 421**

| Before (Incorrect) | After (Correct) |
|-------------------|-----------------|
| `(sat sol)` | `(hash->list (model sol))` |
| `(sat (make-immutable-hash ...))` | `(make-immutable-hash ...)` |

**Details:**
- Line 176: Extract solution bindings for input generation
- Line 219: Extract bindings for constraint construction
- Lines 240, 243: Removed incorrect `sat` wrapper
- Line 421: Added compatibility check for hash vs solution object

### 2. Added Safety Limits (`validator.rkt`)

Added iteration limit to `adjust-memory-config` to prevent infinite loops:

```racket
(define max-iterations 12) ; Allow up to 2^12 = 4096 memory size
(define iteration 0)
...
(when (>= iteration max-iterations)
  (raise (format "adjust-memory-config: Failed after ~a iterations. Memory requirement too large." max-iterations)))
```

### 3. Increased Memory Limits (`memory-rosette.rkt`)

```racket
; Before
(when (> memory-size 100) (raise "memory-rosette: memory size is too large."))

; After
(when (> memory-size 4096)
  (raise (format "memory-rosette: memory size ~a exceeds limit 4096. Program may use too much stack memory." memory-size)))
```

Also added optional parameter to `init-memory-size`:
```racket
(define (init-memory-size [initial-size 1])
  (set! memory-size initial-size))
```

### 4. Fixed Missed Type Migration (`arm/test-simulator.rkt`)

Line 24:
```racket
; Before
(define-symbolic* input number?)

; After
(define-symbolic* input integer?)
```

This was missed in the initial migration and caused test failures.

## Files Modified

1. `/Users/ruijiegao/dev/greenthumb/validator.rkt`
   - Fixed 5 instances of incorrect `sat` usage
   - Added iteration limits and error handling

2. `/Users/ruijiegao/dev/greenthumb/memory-rosette.rkt`
   - Increased memory limit from 100 to 4096
   - Improved error messages
   - Added optional initial-size parameter

3. `/Users/ruijiegao/dev/greenthumb/arm/test-simulator.rkt`
   - Fixed missed `number?` → `integer?` migration

4. `/Users/ruijiegao/dev/greenthumb/MIGRATION.md`
   - Corrected section 6 about helper function removals
   - Added "Additional Fixes" section documenting these changes

## Correct API Mapping Reference

For future reference, the correct Rosette 1.1 → 4.1 API mappings are:

| Rosette 1.1 | Rosette 4.1 | Notes |
|------------|-------------|-------|
| `solution->list` | `hash->list (model sol)` | Extract bindings as list of pairs |
| `(new kodkod%)` | `(z3)` | Solver instantiation |
| `clear-asserts` | `clear-vc!` | Clear verification conditions |
| `unsafe-clear-terms!` | `clear-terms!` | Clear terms |
| `number?` | `integer?` or `real?` | Type predicates |
| `verify #:assume A #:guarantee G` | `verify (begin A G)` | Query syntax |
| `synthesize #:forall V #:assume A #:guarantee G` | `synthesize #:forall V #:guarantee (begin A G)` | Query syntax |

## Testing

After applying these fixes:

1. ✅ Basic demo runs successfully: `racket arm/demo.rkt`
2. ✅ Simulator test works: `racket arm/test-simulator.rkt`
3. ⚠️ Optimizer still hits memory limits on some programs (see Known Issues)

## Known Issues

### Memory Explosion for Stack-Heavy Programs

Programs that use extensive stack memory (e.g., `p14_floor_avg_o0.s` with many `str`/`ldr` instructions) still fail because:

1. The ARM progstate always includes symbolic memory, even for register-only programs
2. The validator tries to model all possible memory addresses symbolically
3. This causes exponential growth in solver complexity

**Workaround:** Use the optimized versions of programs that use fewer memory operations:
```bash
racket optimize.rkt --stoch -o -c 2 -t 60 programs/p14_floor_avg.s  # Register-only version
```

**Future Fix:** Implement memory usage detection and skip memory modeling for register-only programs.

## Verification

To verify these fixes work:

```bash
cd /Users/ruijiegao/dev/greenthumb/arm

# Test basic functionality
racket demo.rkt

# Test simulator
racket test-simulator.rkt

# Test optimizer on register-only program
racket optimize.rkt --stoch -o -c 2 -t 30 programs/p14_floor_avg.s
```

## Conclusion

The migration is now functionally complete for most use cases. The main fix was correcting the `sat` → `model` API usage. Additional safety limits prevent infinite loops, though some stack-heavy programs may still fail due to fundamental symbolic memory modeling limitations in Rosette 4.1.
