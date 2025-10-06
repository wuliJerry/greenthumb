# RV32IM Implementation Changes

## Branch: `haoran_egraph`

This document summarizes the changes made to support RV32IM (32-bit RISC-V with Integer and Multiply extensions) without pseudo instructions.

## Changes Made

### 1. Bitwidth Configuration (32-bit)

#### `riscv-machine.rkt`
- Line 36: Changed from `(set! bitwidth 64)` to `(set! bitwidth 32)`
- Line 61: Updated shift amounts from fixed `'(32)` to `'(1 8 16 31)` for RV32 compatibility

#### Test Files
- `test-simulator.rkt`: Line 10: Changed `(current-bitwidth 64)` to `(current-bitwidth 32)`
- `test-program.rkt`: Line 7: Changed `(current-bitwidth 64)` to `(current-bitwidth 32)`
- `test-individual.rkt`: Line 6: Changed `(current-bitwidth 64)` to `(current-bitwidth 32)`

### 2. Removed Pseudo Instructions

#### `riscv-machine.rkt`
Removed the following pseudo instruction class (lines 124-131):
- `NEG rd, rs` - Negate (was: SUB rd, x0, rs)
- `NOT rd, rs` - Bitwise NOT (was: XORI rd, rs, -1)
- `SEQZ rd, rs` - Set if equal zero (was: SLTIU rd, rs, 1)
- `SNEZ rd, rs` - Set if not equal zero (was: SLTU rd, x0, rs)

#### `riscv-simulator-rosette.rkt`
Removed pseudo instruction implementations (lines 130-133)

#### `riscv-simulator-racket.rkt`
Removed pseudo instruction implementations (lines 128-131)

## Current Instruction Set (RV32IM Subset)

### Implemented Instructions

#### Arithmetic (RV32I)
- ✅ `ADD rd, rs1, rs2` - Addition
- ✅ `ADDI rd, rs1, imm` - Add immediate
- ✅ `SUB rd, rs1, rs2` - Subtraction

#### Logical (RV32I)
- ✅ `AND rd, rs1, rs2` - Bitwise AND
- ✅ `ANDI rd, rs1, imm` - AND immediate
- ✅ `OR rd, rs1, rs2` - Bitwise OR
- ✅ `ORI rd, rs1, imm` - OR immediate
- ✅ `XOR rd, rs1, rs2` - Bitwise XOR
- ✅ `XORI rd, rs1, imm` - XOR immediate

#### Shifts (RV32I)
- ✅ `SLL rd, rs1, rs2` - Shift left logical
- ✅ `SLLI rd, rs1, shamt` - Shift left logical immediate (shamt ∈ {1, 8, 16, 31})
- ✅ `SRL rd, rs1, rs2` - Shift right logical
- ✅ `SRLI rd, rs1, shamt` - Shift right logical immediate
- ✅ `SRA rd, rs1, rs2` - Shift right arithmetic
- ✅ `SRAI rd, rs1, shamt` - Shift right arithmetic immediate

#### Comparison (RV32I)
- ✅ `SLT rd, rs1, rs2` - Set less than (signed)
- ✅ `SLTI rd, rs1, imm` - Set less than immediate (signed)
- ✅ `SLTU rd, rs1, rs2` - Set less than unsigned
- ✅ `SLTIU rd, rs1, imm` - Set less than immediate unsigned

#### Upper Immediate (RV32I)
- ✅ `LUI rd, imm` - Load upper immediate

#### Multiply (RV32M - partial)
- ✅ `MUL rd, rs1, rs2` - Multiplication (lower 32 bits)

#### Other
- ✅ `NOP` - No operation

### Missing from Full RV32IM

#### RV32I Base
- ❌ Load instructions (LB, LH, LW, LBU, LHU)
- ❌ Store instructions (SB, SH, SW)
- ❌ Branch instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
- ❌ Jump instructions (JAL, JALR)
- ❌ AUIPC instruction

#### RV32M Extension
- ❌ `MULH rd, rs1, rs2` - Multiply high (signed×signed)
- ❌ `MULHSU rd, rs1, rs2` - Multiply high (signed×unsigned)
- ❌ `MULHU rd, rs1, rs2` - Multiply high (unsigned×unsigned)
- ❌ `DIV rd, rs1, rs2` - Division
- ❌ `DIVU rd, rs1, rs2` - Division unsigned
- ❌ `REM rd, rs1, rs2` - Remainder
- ❌ `REMU rd, rs1, rs2` - Remainder unsigned

## Testing

All tests pass with the new configuration:

1. ✅ `test-simulator.rkt` - Basic instruction simulation works
2. ✅ `test-individual.rkt` - Individual program testing works
3. ✅ `optimize.rkt` - Superoptimization functionality intact
4. ✅ Created and tested `rv32im_test.s` - New test program using only RV32IM instructions

## Example Test Program

Created `programs/rv32im_test.s`:
```assembly
addi x3, x1, 0     # x3 = x1
slli x4, x1, 1     # x4 = x1 << 1 = x1 * 2
add x5, x3, x4     # x5 = x1 + (x1 * 2) = x1 * 3
srli x6, x2, 1     # x6 = x2 >> 1
add x0, x5, x6     # x0 = (x1 * 3) + (x2 >> 1)
```

With inputs x1=42, x2=10:
- Result: x0 = 131 (0x83)
- Calculation: (42 * 3) + (10 >> 1) = 126 + 5 = 131 ✓

## Summary

The implementation has been successfully modified to:
1. Use 32-bit registers instead of 64-bit
2. Remove all pseudo instructions (NEG, NOT, SEQZ, SNEZ)
3. Support valid RV32IM instructions only
4. Maintain compatibility with the superoptimizer framework

The system is now ready for RV32IM-specific optimization tasks.