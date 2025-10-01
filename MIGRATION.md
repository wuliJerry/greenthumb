# Migration from Racket 6.7 / Rosette 1.1 to Racket 8.17 / Rosette 4.1

## Overview

This document describes the changes made to migrate GreenThumb from Racket 6.7 and Rosette 1.1 to Racket 8.17 and Rosette 4.1.

## Summary of All Changes

| Category | Files Modified | Changes Made |
|----------|---------------|--------------|
| Solver API | 2 files | Kodkod → Z3 |
| Reflection API | 2 files | clear-asserts → clear-vc! |
| Type System | 4 files | number? → integer? |
| Error Handling | 1 file | Exception-based → unsat? checking |
| Operators | 1 file | Removed sym/<< aliases, implemented shift operators |
| Other APIs | 2 files | coerce removal, unsafe-clear-terms! → clear-terms!, solution->list → sat |
| Query APIs | 2 files | verify and synthesize syntax updates |
| Documentation | 2 files | README.md + new MIGRATION.md |

## Key Changes

### 1. Solver Migration (Kodkod → Z3)

**Why**: Rosette 2.0+ removed support for the Kodkod solver. Z3 is now the primary SMT solver.

**Files Modified**:
- `symbolic.rkt`: Changed `(new kodkod%)` to `(z3)`
- `validator.rkt`: Changed `(new kodkod%)` to `(z3)`

**Before**:
```racket
(require rosette/solver/kodkod/kodkod)
(current-solver (new kodkod%))
```

**After**:
```racket
(require rosette/solver/smt/z3)
(current-solver (z3))
```

### 2. Reflection API Updates

**Why**: Rosette 4.0 replaced path condition tracking with verification condition (VC) tracking.

**Files Modified**:
- `symbolic.rkt`: 2 occurrences
- `validator.rkt`: 3 occurrences

**Changes**:
- `clear-asserts` → `clear-vc!`
- `pc` → `vc` (if used)
- `with-asserts` → `with-vc` (if used)

### 3. Type System Updates

**Why**: Rosette 2.0 split `number?` into `integer?` and `real?` for better type precision.

**Files Modified**:
- `validator.rkt`: `sym-input` function
- `symbolic.rkt`: `sym-op` and `sym-arg` functions
- `memory-rosette.rkt`: Test function
- `queue-rosette.rkt`: Test functions (test1, test2)

**Before**:
```racket
(define-symbolic* input number?)
```

**After**:
```racket
(define-symbolic* input integer?)
```

### 4. Solver Error Handling

**Why**: Rosette 2.0+ returns `unsat?` solutions instead of throwing exceptions when no solution is found.

**Files Modified**:
- `validator.rkt`: `adjust-memory-config` and `generate-input-states-slow` functions

**Before**:
```racket
(with-handlers*
 ([exn:fail?
   (lambda (e)
     (if (equal? (exn-message e) "solve: no satisfying execution found")
         ...
         (raise e)))])
 (solve ...))
```

**After**:
```racket
(define sol (solve ...))
(if (unsat? sol)
    ...
    sol)
```

## Testing Recommendations

After migration, thoroughly test:

1. **Symbolic Search** (`--sym` mode)
   - Test with ARM, GA, and LLVM backends
   - Verify synthesis correctness

2. **Stochastic Search** (`--stoch` mode)
   - Verify counterexample generation
   - Check validation logic

3. **Enumerative Search** (`--enum` mode)
   - Test instruction enumeration
   - Verify live variable analysis

4. **Hybrid Search** (`--hybrid` mode)
   - Test cooperative search across all modes

## Known Issues and Considerations

### Bitwidth Behavior
- Rosette 3.0 changed `current-bitwidth` default from a numeric value to `#f`
- Current code explicitly sets bitwidth, so behavior should remain consistent
- However, performance characteristics may differ

### Racket CS Runtime
- Racket 8.0 switched from BC (bytecode) to CS (Chez Scheme) runtime
- Generally compatible but may have performance differences
- No FFI usage detected in codebase, so FFI-related differences don't apply

## Performance Notes

Z3 solver may have different performance characteristics compared to Kodkod:
- Z3 is generally faster for most problems
- Memory usage patterns may differ
- Some queries that were fast with Kodkod may be slower with Z3, and vice versa

## Rollback Procedure

If issues arise, you can rollback by:
1. Reinstalling Racket 6.7
2. Installing Rosette 1.1 manually
3. Reverting git commits from this migration

### 5. Shift Operator Changes

**Why**: Rosette updated how shift operators are provided.

**Files Modified**:
- `ops-rosette.rkt`

**Before**:
```racket
(require (only-in rosette [<< sym/<<] [>>> sym/>>>]))
(define-syntax-rule (<< x y bit) (sym/<< x y))
(define-syntax-rule (>>> x y bit) (sym/>>> x y))
```

**After**:
```racket
(define-syntax-rule (<< x y bit) (arithmetic-shift x y))
(define-syntax-rule (>>> x y bit) (arithmetic-shift x (- y)))
(define (>> x y) (arithmetic-shift x (- y)))
```

### 6. Helper Function Removals

**Why**: Rosette removed several helper functions in newer versions.

**Changes**:
- `coerce` function removed → Use direct `term?` checking
- `unsafe-clear-terms!` → `clear-terms!`
- `solution->list` → `sat`

**Files Modified**:
- `ops-rosette.rkt`: Removed `coerce` usage
- `validator.rkt`: Updated `clear-terms!` and `sat`

### 7. Query API Syntax Updates

**Why**: Rosette 3.0 changed the syntax for `verify` and `synthesize` queries.

**Files Modified**:
- `validator.rkt`: `verify` call
- `symbolic.rkt`: `synthesize` call

**Before**:
```racket
(verify #:assume (interpret-spec!) #:guarantee (compare))
(synthesize #:forall sym-vars #:assume (interpret-spec!) #:guarantee (compare-spec-sketch))
```

**After**:
```racket
(verify (begin (interpret-spec!) (compare)))
(synthesize #:forall sym-vars #:guarantee (begin (interpret-spec!) (compare-spec-sketch)))
```

## Complete File Change List

### Core Framework Files
1. **validator.rkt**
   - Solver: kodkod → z3
   - API: clear-asserts → clear-vc! (3 occurrences)
   - Types: number? → integer?
   - Error handling: Exception-based → unsat? checking (2 places)
   - Functions: unsafe-clear-terms! → clear-terms!, solution->list → sat
   - Query: verify syntax update

2. **symbolic.rkt**
   - Solver: kodkod → z3
   - API: clear-asserts → clear-vc! (2 occurrences)
   - Types: number? → integer? (2 places)
   - Query: synthesize syntax update

3. **ops-rosette.rkt**
   - Removed: sym/<< and sym/>>> imports
   - Added: Custom shift operator implementations
   - Removed: coerce function usage
   - Updated: finitize function

4. **memory-rosette.rkt**
   - Types: number? → integer? (1 test function)

5. **queue-rosette.rkt**
   - Types: number? → integer? (2 test functions)

### Documentation Files
6. **README.md**
   - Updated Racket requirement: 6.7 → 8.1+
   - Updated Rosette requirement: 1.1 → 4.1+
   - Updated installation instructions

7. **MIGRATION.md** (new)
   - Complete migration guide

## Additional Resources

- [Rosette NOTES.md](https://github.com/emina/rosette/blob/master/NOTES.md) - Breaking changes documentation
- [Rosette Documentation](https://docs.racket-lang.org/rosette-guide/)
- [Racket Release Notes](https://docs.racket-lang.org/release/index.html)
