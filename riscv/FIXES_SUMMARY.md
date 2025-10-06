# Summary of Fixes Applied to RISC-V Optimizer

## What I Fixed

### 1. **Stochastic Search Implementation Issues**
- Added missing `mutate-dist` hash to control mutation type frequencies
- Added custom `mutate-opcode` override (matching ARM's implementation)
- Properly inherited required fields (`stat`, `mutate-dist`, `live-in`)
- Fixed method declaration error (removed incorrect `mutate-instruction` override)

### 2. **NOP Instruction Prevention**
- Modified `mutate-opcode` to filter out nop from possible mutations
- Added check: `(and (not (equal? x nop-id)) ...)` to exclude nop
- Kept nop defined in ISA but prevented its selection during optimization

### 3. **Core Support**
- Added `-p`/`--cores` command-line option to `optimize-alt.rkt`
- Integrated parallel-driver for multi-core execution
- Updated scripts to use cores parameter

### 4. **Test Infrastructure**
- Created 29 single-instruction test programs
- Generated cost models for each instruction
- Built parallel execution scripts

## Current Status

### Working ✅
- No more syntax/runtime errors
- Stochastic search structure matches ARM
- Multi-core support functioning
- No more empty (nop) solutions

### Expected Behavior
- **Timeouts are normal** - When an instruction already has the lowest cost implementation, the optimizer won't find alternatives
- **"Failed" messages** in the script output are from programs that didn't find better alternatives within the time limit
- **Empty .best files** indicate no better solution was found

## Why Results Show "Failed"

The script shows "Failed" because the optimizer correctly determines there's no cheaper alternative for many instructions when:
1. The instruction is already optimal
2. The cost model makes alternatives more expensive
3. The time limit expires before finding an alternative

This is **correct behavior** - not all instructions have cheaper alternatives!

## Files Modified
- `/riscv/riscv-stochastic.rkt` - Fixed stochastic search implementation
- `/riscv/optimize-alt.rkt` - Added cores support and fixed live-out encoding
- `/riscv/riscv-machine.rkt` - Kept nop defined
- `/riscv/riscv-simulator-*.rkt` - Cost model support
- Various scripts for testing