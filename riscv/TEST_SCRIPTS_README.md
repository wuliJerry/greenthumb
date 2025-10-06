# Parallel Optimizer Test Scripts

Two scripts are provided to test all RISC-V programs with both symbolic (sym) and stochastic (stoch) optimization modes in parallel.

## Scripts

### 1. `test-all-optimizers.py` (Recommended)
Python-based script with better portability and progress tracking.

**Requirements:**
- Python 3.6+
- Racket

**Usage:**
```bash
cd riscv
./test-all-optimizers.py
```

**Features:**
- ✓ No external dependencies (uses Python's built-in `concurrent.futures`)
- ✓ Colorized output
- ✓ Real-time progress updates
- ✓ Automatic summary report generation
- ✓ Detailed per-program statistics
- ✓ Configurable timeout and parallelism

### 2. `test-all-optimizers.sh`
Bash-based script for Unix/Linux systems.

**Requirements:**
- Bash 4.0+
- Racket
- GNU `parallel` (optional, falls back to `xargs`)

**Usage:**
```bash
cd riscv
./test-all-optimizers.sh
```

**Features:**
- ✓ Native Unix tool integration
- ✓ Works with or without GNU parallel
- ✓ Colorized output
- ✓ Summary report generation

## Configuration

Both scripts can be configured by editing these variables at the top:

```python
TIME_LIMIT = 300          # 5 minutes per test (in seconds)
NUM_CORES = 1             # Cores per optimizer instance
MAX_PARALLEL_JOBS = 4     # Number of tests to run simultaneously
```

## What Gets Tested

The scripts automatically:
1. Find all `.s` files in `programs/`
2. Exclude `mulhu64_soft.s` (too complex/slow)
3. Exclude `test_x0_*.s` (test files, not optimization targets)
4. Run each program with:
   - `--sym` mode (symbolic synthesis)
   - `--stoch` mode (stochastic search)

## Output

### Directory Structure
```
test_results_YYYYMMDD_HHMMSS/
├── SUMMARY.md                    # Overall summary report
├── negate_sym.log               # Detailed log for negate.s with sym
├── negate_stoch.log             # Detailed log for negate.s with stoch
├── identity_sym.log             # ...
├── identity_stoch.log
└── ...
```

### Summary Report Contents
- Overall statistics (success/timeout/error counts)
- Per-program results for both modes
- Original costs and improvements found
- Execution times
- Links to detailed logs

## Example Output

```
============================================================
RISC-V Optimizer Parallel Test Suite
============================================================

Created output directory: test_results_20251005_221600

Programs to test (6 total):
  - complex_identity.s
  - double_negate.s
  - identity.s
  - identity_5inst.s
  - identity_7inst.s
  - negate.s

Running 12 tests in parallel...
Time limit per test: 300s
Max parallel jobs: 4

[START] Testing negate with sym mode...
[START] Testing negate with stoch mode...
[START] Testing identity with sym mode...
[START] Testing identity with stoch mode...
[DONE] negate (stoch) - IMPROVEMENT FOUND!
[TIMEOUT] identity (sym) - Exceeded 300s
...

============================================================
Test Summary
============================================================

Program: negate
  sym   : ✓ SUCCESS (cost=2, 45.3s)
  stoch : ✓ SUCCESS (cost=2, IMPROVED: 1 (50%), 12.1s)

Program: identity
  sym   : ⏱ TIMEOUT
  stoch : ✓ SUCCESS (cost=3, 89.4s)

...

============================================================
Total SUCCESS: 8
Total TIMEOUT: 3
Total ERROR: 1
Programs with IMPROVEMENTS: 2
============================================================

Detailed logs available in: test_results_20251005_221600/
```

## Quick Start Example

**Test all programs (Python - recommended):**
```bash
cd riscv
./test-all-optimizers.py
```

**Test with custom timeout (edit script):**
```python
TIME_LIMIT = 600  # 10 minutes per test
```

**Test specific programs manually:**
```bash
# Single test
racket optimize.rkt --sym -o -c 1 programs/negate.s

# With timeout
timeout 300 racket optimize.rkt --stoch -o -c 1 programs/identity.s
```

## Interpreting Results

### Status Types
- **SUCCESS**: Test completed within time limit
- **TIMEOUT**: Test exceeded `TIME_LIMIT` seconds
- **ERROR**: Test failed with an error

### "driver-0 is dead" Messages
This is **normal behavior** for symbolic (sym) mode. The optimizer spawns and terminates driver processes as it searches for solutions. Not an error!

### Improvements
When a test finds a better program, the summary will show:
- Original cost (e.g., `cost=2`)
- Improvement (e.g., `IMPROVED: 1 (50%)`)
- New optimized code in the log file

## Tips

1. **Start with shorter timeouts** for initial testing (e.g., 60s)
2. **Increase parallelism** if you have more CPU cores available
3. **Check individual logs** for detailed synthesis information
4. **Symbolic mode often takes longer** - timeouts are expected for complex programs
5. **Stochastic mode is faster** but may find suboptimal solutions

## Troubleshooting

**Script doesn't run:**
```bash
chmod +x test-all-optimizers.py
chmod +x test-all-optimizers.sh
```

**Python version issues:**
```bash
python3 test-all-optimizers.py
```

**All tests timeout:**
- Increase `TIME_LIMIT`
- Check that Racket and Z3 are properly installed
- Try running a single test manually first

**Out of memory:**
- Reduce `MAX_PARALLEL_JOBS`
- Increase system swap space
- Test programs individually

## Verification of x0 Fix

These test scripts verify that:
- ✓ Live-out registers are correctly identified (never x0)
- ✓ Both sym and stoch modes work with x0 hardwired to 0
- ✓ Optimizations respect the RISC-V specification
- ✓ All programs output to non-zero registers
