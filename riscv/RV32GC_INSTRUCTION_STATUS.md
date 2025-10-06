# RV32GC Instruction Implementation Status

## Bitwidth Configuration Analysis

### Current Implementation
- **Currently hardcoded to 64-bit** (RV64I)
- Set in `riscv-machine.rkt` line 36: `(unless bitwidth (set! bitwidth 64))`
- Used throughout simulators and tests with `(current-bitwidth 64)`

### Changes Needed for RV32
1. Change default bitwidth in `riscv-machine.rkt` from 64 to 32
2. Update all test files to use `(current-bitwidth 32)`
3. Adjust immediate values and shift amounts for 32-bit architecture
4. Update shift amount constraint (currently fixed at 32, might need adjustment)

**Verdict**: The bitwidth change is relatively straightforward - it's a configuration parameter that can be easily modified.

---

## Currently Implemented Instructions (✅)

### Base Integer Instructions (RV32I)
#### Arithmetic
- ✅ `ADD rd, rs1, rs2` - Addition
- ✅ `ADDI rd, rs1, imm` - Add immediate
- ✅ `SUB rd, rs1, rs2` - Subtraction

#### Logical
- ✅ `AND rd, rs1, rs2` - Bitwise AND
- ✅ `ANDI rd, rs1, imm` - AND immediate
- ✅ `OR rd, rs1, rs2` - Bitwise OR
- ✅ `ORI rd, rs1, imm` - OR immediate
- ✅ `XOR rd, rs1, rs2` - Bitwise XOR
- ✅ `XORI rd, rs1, imm` - XOR immediate

#### Shifts
- ✅ `SLL rd, rs1, rs2` - Shift left logical
- ✅ `SLLI rd, rs1, shamt` - Shift left logical immediate
- ✅ `SRL rd, rs1, rs2` - Shift right logical
- ✅ `SRLI rd, rs1, shamt` - Shift right logical immediate
- ✅ `SRA rd, rs1, rs2` - Shift right arithmetic
- ✅ `SRAI rd, rs1, shamt` - Shift right arithmetic immediate

#### Comparison
- ✅ `SLT rd, rs1, rs2` - Set less than
- ✅ `SLTI rd, rs1, imm` - Set less than immediate
- ✅ `SLTU rd, rs1, rs2` - Set less than unsigned
- ✅ `SLTIU rd, rs1, imm` - Set less than immediate unsigned

#### Upper Immediate
- ✅ `LUI rd, imm` - Load upper immediate

#### Pseudo-instructions
- ✅ `NEG rd, rs` - Negate (pseudo)
- ✅ `NOT rd, rs` - Bitwise NOT (pseudo)
- ✅ `SEQZ rd, rs` - Set if equal zero (pseudo)
- ✅ `SNEZ rd, rs` - Set if not equal zero (pseudo)

#### Other
- ✅ `NOP` - No operation

### Extension M (Integer Multiply/Divide)
- ✅ `MUL rd, rs1, rs2` - Multiplication (lower 32 bits)

---

## Instructions TO BE IMPLEMENTED for RV32GC

### RV32I Base Integer Instructions (❌)

#### Load Instructions
- ❌ `LB rd, offset(rs1)` - Load byte
- ❌ `LH rd, offset(rs1)` - Load halfword
- ❌ `LW rd, offset(rs1)` - Load word
- ❌ `LBU rd, offset(rs1)` - Load byte unsigned
- ❌ `LHU rd, offset(rs1)` - Load halfword unsigned

#### Store Instructions
- ❌ `SB rs2, offset(rs1)` - Store byte
- ❌ `SH rs2, offset(rs1)` - Store halfword
- ❌ `SW rs2, offset(rs1)` - Store word

#### Branch Instructions
- ❌ `BEQ rs1, rs2, offset` - Branch if equal
- ❌ `BNE rs1, rs2, offset` - Branch if not equal
- ❌ `BLT rs1, rs2, offset` - Branch if less than
- ❌ `BGE rs1, rs2, offset` - Branch if greater or equal
- ❌ `BLTU rs1, rs2, offset` - Branch if less than unsigned
- ❌ `BGEU rs1, rs2, offset` - Branch if greater or equal unsigned

#### Jump Instructions
- ❌ `JAL rd, offset` - Jump and link
- ❌ `JALR rd, rs1, offset` - Jump and link register

#### Upper Immediate
- ❌ `AUIPC rd, imm` - Add upper immediate to PC

#### System Instructions
- ❌ `ECALL` - Environment call
- ❌ `EBREAK` - Environment break

---

### RV32M Extension - Integer Multiply/Divide (❌)

- ❌ `MULH rd, rs1, rs2` - Multiply high (signed×signed)
- ❌ `MULHSU rd, rs1, rs2` - Multiply high (signed×unsigned)
- ❌ `MULHU rd, rs1, rs2` - Multiply high (unsigned×unsigned)
- ❌ `DIV rd, rs1, rs2` - Division
- ❌ `DIVU rd, rs1, rs2` - Division unsigned
- ❌ `REM rd, rs1, rs2` - Remainder
- ❌ `REMU rd, rs1, rs2` - Remainder unsigned

---

### RV32A Extension - Atomic Instructions (❌)

#### Atomic Memory Operations
- ❌ `LR.W rd, (rs1)` - Load reserved word
- ❌ `SC.W rd, rs2, (rs1)` - Store conditional word
- ❌ `AMOSWAP.W rd, rs2, (rs1)` - Atomic swap
- ❌ `AMOADD.W rd, rs2, (rs1)` - Atomic add
- ❌ `AMOXOR.W rd, rs2, (rs1)` - Atomic XOR
- ❌ `AMOAND.W rd, rs2, (rs1)` - Atomic AND
- ❌ `AMOOR.W rd, rs2, (rs1)` - Atomic OR
- ❌ `AMOMIN.W rd, rs2, (rs1)` - Atomic minimum
- ❌ `AMOMAX.W rd, rs2, (rs1)` - Atomic maximum
- ❌ `AMOMINU.W rd, rs2, (rs1)` - Atomic minimum unsigned
- ❌ `AMOMAXU.W rd, rs2, (rs1)` - Atomic maximum unsigned

---

### RV32F Extension - Single-Precision Floating-Point (❌)

#### Load/Store
- ❌ `FLW fd, offset(rs1)` - Load float word
- ❌ `FSW fs2, offset(rs1)` - Store float word

#### Arithmetic
- ❌ `FADD.S fd, fs1, fs2` - Add float
- ❌ `FSUB.S fd, fs1, fs2` - Subtract float
- ❌ `FMUL.S fd, fs1, fs2` - Multiply float
- ❌ `FDIV.S fd, fs1, fs2` - Divide float
- ❌ `FSQRT.S fd, fs1` - Square root float

#### Fused Multiply-Add
- ❌ `FMADD.S fd, fs1, fs2, fs3` - Multiply-add
- ❌ `FMSUB.S fd, fs1, fs2, fs3` - Multiply-subtract
- ❌ `FNMSUB.S fd, fs1, fs2, fs3` - Negative multiply-subtract
- ❌ `FNMADD.S fd, fs1, fs2, fs3` - Negative multiply-add

#### Sign Manipulation
- ❌ `FSGNJ.S fd, fs1, fs2` - Sign injection
- ❌ `FSGNJN.S fd, fs1, fs2` - Sign injection negate
- ❌ `FSGNJX.S fd, fs1, fs2` - Sign injection XOR

#### Comparison
- ❌ `FEQ.S rd, fs1, fs2` - Float equal
- ❌ `FLT.S rd, fs1, fs2` - Float less than
- ❌ `FLE.S rd, fs1, fs2` - Float less or equal
- ❌ `FMIN.S fd, fs1, fs2` - Float minimum
- ❌ `FMAX.S fd, fs1, fs2` - Float maximum

#### Conversion
- ❌ `FCVT.W.S rd, fs1` - Convert float to int
- ❌ `FCVT.WU.S rd, fs1` - Convert float to unsigned int
- ❌ `FCVT.S.W fd, rs1` - Convert int to float
- ❌ `FCVT.S.WU fd, rs1` - Convert unsigned int to float

#### Move/Class
- ❌ `FMV.X.W rd, fs1` - Move float to integer register
- ❌ `FMV.W.X fd, rs1` - Move integer to float register
- ❌ `FCLASS.S rd, fs1` - Classify float

---

### RV32D Extension - Double-Precision Floating-Point (❌)

#### Load/Store
- ❌ `FLD fd, offset(rs1)` - Load float double
- ❌ `FSD fs2, offset(rs1)` - Store float double

#### Arithmetic
- ❌ `FADD.D fd, fs1, fs2` - Add double
- ❌ `FSUB.D fd, fs1, fs2` - Subtract double
- ❌ `FMUL.D fd, fs1, fs2` - Multiply double
- ❌ `FDIV.D fd, fs1, fs2` - Divide double
- ❌ `FSQRT.D fd, fs1` - Square root double

#### Fused Multiply-Add
- ❌ `FMADD.D fd, fs1, fs2, fs3` - Multiply-add double
- ❌ `FMSUB.D fd, fs1, fs2, fs3` - Multiply-subtract double
- ❌ `FNMSUB.D fd, fs1, fs2, fs3` - Negative multiply-subtract double
- ❌ `FNMADD.D fd, fs1, fs2, fs3` - Negative multiply-add double

#### Sign Manipulation
- ❌ `FSGNJ.D fd, fs1, fs2` - Sign injection double
- ❌ `FSGNJN.D fd, fs1, fs2` - Sign injection negate double
- ❌ `FSGNJX.D fd, fs1, fs2` - Sign injection XOR double

#### Comparison
- ❌ `FEQ.D rd, fs1, fs2` - Double equal
- ❌ `FLT.D rd, fs1, fs2` - Double less than
- ❌ `FLE.D rd, fs1, fs2` - Double less or equal
- ❌ `FMIN.D fd, fs1, fs2` - Double minimum
- ❌ `FMAX.D fd, fs1, fs2` - Double maximum

#### Conversion
- ❌ `FCVT.W.D rd, fs1` - Convert double to int
- ❌ `FCVT.WU.D rd, fs1` - Convert double to unsigned int
- ❌ `FCVT.D.W fd, rs1` - Convert int to double
- ❌ `FCVT.D.WU fd, rs1` - Convert unsigned int to double
- ❌ `FCVT.S.D fd, fs1` - Convert double to single
- ❌ `FCVT.D.S fd, fs1` - Convert single to double

#### Move/Class
- ❌ `FMV.X.D rd, fs1` - Move double to integer register (RV64 only)
- ❌ `FMV.D.X fd, rs1` - Move integer to double register (RV64 only)
- ❌ `FCLASS.D rd, fs1` - Classify double

---

### RV32C Extension - Compressed Instructions (❌)

The C extension provides 16-bit compressed versions of common instructions. This is a large set (40+ instructions) that maps to regular 32-bit instructions but saves code space.

Examples:
- ❌ `C.ADDI` - Compressed ADDI
- ❌ `C.LW` - Compressed load word
- ❌ `C.SW` - Compressed store word
- ❌ `C.J` - Compressed jump
- ❌ `C.BEQZ` - Compressed branch if zero
- And many more...

---

## Summary Statistics

### Current Implementation
- **RV32I**: 22 out of 40 instructions (55%)
- **RV32M**: 1 out of 8 instructions (12.5%)
- **RV32A**: 0 out of 11 instructions (0%)
- **RV32F**: 0 out of 30 instructions (0%)
- **RV32D**: 0 out of 32 instructions (0%)
- **RV32C**: 0 out of 40+ instructions (0%)

### Total for RV32GC
- **Implemented**: ~23 instructions
- **Remaining**: ~140+ instructions
- **Completion**: ~14%

---

## Implementation Priority Recommendations

### Phase 1: Complete RV32I Base (High Priority)
1. **Memory Operations** (Load/Store) - Essential for real programs
2. **Control Flow** (Branch/Jump) - Essential for loops and functions
3. **AUIPC** - Needed for position-independent code

### Phase 2: Complete RV32M (Medium Priority)
- Division and remainder operations
- High multiplication variants

### Phase 3: Memory Model (Required for A extension)
- Implement proper memory model
- Add memory fence instructions

### Phase 4: Floating-Point (Lower Priority for superoptimizer)
- RV32F single-precision
- RV32D double-precision

### Phase 5: Compressed Instructions (Optional)
- RV32C compressed instructions (mostly encoding variants)

---

## Technical Challenges

### 1. Memory System
Current implementation has memory infrastructure but no load/store instructions. Need to:
- Implement memory addressing modes
- Handle alignment requirements
- Add memory operation semantics to simulators

### 2. Control Flow
Superoptimizer typically works on straight-line code. Adding branches requires:
- Program counter management
- Control flow graph representation
- Modified search strategies

### 3. Floating-Point
Would require:
- Floating-point register file (f0-f31)
- IEEE 754 semantics
- Rounding modes and exception flags

### 4. Atomic Operations
Would require:
- Memory reservation mechanism
- Atomic operation semantics
- Memory ordering constraints