# Known Issues - RISC-V Superoptimizer

## Current Status: **Partially Functional**

The RISC-V superoptimizer implementation has core functionality working but encounters issues with certain search strategies due to Rosette 4.1 compatibility.

---

## ✅ What Works

### 1. Core Infrastructure
- ✅ Parser: Correctly parses RISC-V assembly
- ✅ Printer: Encodes/decodes between representations
- ✅ Simulators: Both Rosette and Racket simulators functional for concrete values
- ✅ Machine definition: All 17 instructions defined correctly
- ✅ Test programs: 6/8 programs work correctly (2 limited by fixed shift amount)

### 2. Search Strategies (Partial)
- ✅ **Symbolic Search**: Works! Can synthesize programs
- ⚠️ **Stochastic Search**: Crashes with Rosette arithmetic error
- ⚠️ **Enumerative Search**: Not fully tested
- ⚠️ **Cooperative Search**: Partially working (symbolic component works)

---

## ❌ What Doesn't Work

### Issue #1: Stochastic Search Crashes

**Symptom**:
```
driver-0 is dead.
driver-1 is dead.
driver-2 is dead.
driver-3 is dead.
```

**Error in Log**:
```
[assert] $+: expected real? arguments
  arguments: (input$1)
  ...
  /Users/ruijiegao/dev/greenthumb/riscv/riscv-simulator-rosette.rkt:28:19: bvadd
```

**Root Cause**:
The stochastic search uses the Rosette simulator with concrete random inputs to evaluate candidate programs. However, there's a mismatch between how Rosette 4.1 handles symbolic vs. concrete bitvector operations.

**Technical Details**:
- Rosette 4.1 requires bitvector types for all symbolic data
- The validator generates inputs that may be mixed symbolic/concrete
- When the stochastic simulator tries to add these values using `+`, Rosette complains
- This worked in Rosette 2.0 but breaks in 4.1

**Workaround**:
Use symbolic search instead:
```bash
racket optimize.rkt --sym -p -c 4 -t 120 programs/test_add.s
```

**Status**: Needs deeper investigation into Rosette 4.1 type system

---

### Issue #2: Z3 Solver Shutdown Error

**Symptom** (at end of symbolic search):
```
send: target is not an object
  target: #<z3>
  method name: shutdown
```

**Root Cause**:
API change in Rosette 4.1 - the Z3 solver object no longer has a `shutdown` method, or the calling convention changed.

**Impact**:
- **Minor** - This occurs after optimization completes
- Results are still generated correctly
- Just a cleanup error

**Workaround**:
Ignore the error - the optimization output is still valid.

**Status**: Cosmetic issue, low priority

---

### Issue #3: Hybrid/Cooperative Search

**Symptom**:
All driver processes die immediately when using `--hybrid`.

**Root Cause**:
Since stochastic search is broken (Issue #1), any hybrid search that includes stochastic components will fail.

**Impact**:
Cannot use the recommended `--hybrid` mode which combines all search strategies.

**Workaround**:
Use individual search modes:
- `--sym -p` for symbolic search
- `--enum -p` for enumerative search

**Status**: Blocked by Issue #1

---

## 🔧 Recommended Usage

Until stochastic search is fixed, use these commands:

### Small Programs (≤3 instructions)
```bash
racket optimize.rkt --sym -p -c 2 -t 300 programs/your_program.s
```

### Medium Programs (3-7 instructions)
```bash
racket optimize.rkt --enum -p -c 4 -t 600 programs/your_program.s
```

### Testing/Development
```bash
# Just parse and validate (no optimization)
racket test-simulator.rkt

# Test with example programs
racket test-program.rkt
```

---

## 🐛 Root Cause Analysis

### Rosette 4.1 Migration Incomplete

The main issue is that while the GreenThumb framework was migrated to Rosette 4.1, some subtle type incompatibilities remain:

1. **Bitvector vs. Integer Confusion**
   - Rosette 4.1 treats bitvectors and integers as distinct types
   - Random input generation may produce integers
   - Simulator expects bitvectors
   - Type coercion doesn't happen automatically

2. **Symbolic vs. Concrete Mixing**
   - Stochastic search generates concrete random inputs
   - These inputs go through validator which may symbolize them
   - Simulator then receives mixed symbolic/concrete values
   - Rosette 4.1 arithmetic operations don't handle this well

3. **API Changes**
   - `shutdown` method on solver objects removed/changed
   - May be other API changes we haven't discovered

---

## 💡 Potential Fixes

### For Issue #1 (Stochastic Search)

**Option A: Force Concrete Evaluation**
Ensure all stochastic inputs are truly concrete (not symbolic) before passing to simulator.

**Option B: Use Racket Simulator**
Modify stochastic search to use `riscv-simulator-racket%` instead of Rosette simulator.

**Option C: Explicit Type Conversion**
Add bitvector type assertions/conversions in the simulator for all arithmetic operations.

### For Issue #2 (Z3 Shutdown)

**Option A: Catch Exception**
Wrap solver cleanup in try/catch and ignore shutdown errors.

**Option B: Check Rosette 4.1 API**
Find the correct way to cleanup Z3 solver in Rosette 4.1.

---

## 📊 Test Matrix

| Test | Result | Notes |
|------|--------|-------|
| Parser | ✅ PASS | All test programs parse correctly |
| Printer | ✅ PASS | Encoding/decoding works |
| Racket Simulator | ✅ PASS | Concrete execution works |
| Rosette Simulator (concrete) | ✅ PASS | Direct testing works |
| Rosette Simulator (symbolic) | ✅ PASS | Symbolic execution works |
| Rosette Simulator (stochastic) | ❌ FAIL | Type mismatch error |
| Symbolic Search | ⚠️ PARTIAL | Works but shutdown error |
| Stochastic Search | ❌ FAIL | Crashes immediately |
| Enumerative Search | ❓ UNKNOWN | Not extensively tested |
| Cooperative Search | ❌ FAIL | Depends on stochastic |

---

## 🎯 Priority Fixes

1. **HIGH**: Fix stochastic search Rosette type issue
   - This blocks cooperative search
   - Most important for practical use

2. **LOW**: Fix Z3 shutdown error
   - Cosmetic only
   - Doesn't affect results

3. **MEDIUM**: Test enumerative search thoroughly
   - May work fine
   - Need to verify

---

## 📝 For Developers

If you want to fix these issues:

1. **Start with stochastic search**
   - Look at `/Users/ruijiegao/dev/greenthumb/stochastic.rkt`
   - Check how it generates/uses random inputs
   - Compare with ARM's working implementation
   - Focus on `generate-one-input` and `get-live-in` in validator

2. **Key files to examine**:
   - `validator.rkt` - Input generation
   - `riscv-simulator-rosette.rkt` - Our simulator
   - `arm-simulator-rosette.rkt` - Working reference
   - `stochastic.rkt` - Search strategy

3. **Debugging approach**:
   - Add type checks before arithmetic operations
   - Print types of inputs to simulator
   - Check if inputs are `bv?` or symbolic terms
   - Verify type conversions in validator

---

## 🚀 Bottom Line

**The superoptimizer is functional for symbolic search**, which is often the most powerful technique anyway. While stochastic and cooperative searches don't work due to Rosette 4.1 compatibility issues, you can still:

1. Optimize small programs with symbolic search
2. Test and verify your programs with the simulators
3. Use it for research and development

**Status**: **Usable but not production-ready** - needs Rosette 4.1 compatibility fixes

---

**Last Updated**: 2025-10-02
**Issues**: 3 known
**Severity**: HIGH (stochastic), LOW (z3 shutdown), HIGH (cooperative)
