# Complete RV32IM Single Instruction Test Suite

## Summary
Created a comprehensive test suite for finding alternative implementations for ALL RV32IM instructions.

## Files Created

### 1. Single Instruction Assembly Programs
Located in `programs/alternatives/single/`:

**RV32I Arithmetic (R-type):**
- `add.s` - Add operation
- `sub.s` - Subtraction
- `sll.s` - Shift left logical
- `slt.s` - Set less than (signed)
- `sltu.s` - Set less than (unsigned)
- `xor.s` - XOR operation
- `srl.s` - Shift right logical
- `sra.s` - Shift right arithmetic
- `or.s` - OR operation
- `and.s` - AND operation

**RV32I Immediate (I-type):**
- `addi.s` - Add immediate
- `slti.s` - Set less than immediate (signed)
- `sltiu.s` - Set less than immediate (unsigned)
- `xori.s` - XOR immediate
- `ori.s` - OR immediate
- `andi.s` - AND immediate
- `slli_double.s` - Shift left logical immediate (multiply by 2)
- `srli.s` - Shift right logical immediate
- `srai.s` - Shift right arithmetic immediate

**RV32I Upper Immediate (U-type):**
- `lui.s` - Load upper immediate
- `auipc.s` - Add upper immediate to PC

**RV32M Extension:**
- `mul.s` - Multiplication (lower 32 bits)
- `mulh.s` - Multiplication (upper 32 bits, signed×signed)
- `mulhsu.s` - Multiplication (upper 32 bits, signed×unsigned)
- `mulhu.s` - Multiplication (upper 32 bits, unsigned×unsigned)
- `div.s` - Division (signed)
- `divu.s` - Division (unsigned)
- `rem.s` - Remainder (signed)
- `remu.s` - Remainder (unsigned)

### 2. Cost Model Files
Located in `costs/`:
- One file per instruction named `<instruction>-expensive.rkt`
- Each makes the specific instruction cost 1000 (while others remain at normal cost)
- Example: `xor-expensive.rkt` makes XOR cost 1000, all others normal

### 3. Scripts

**Helper Scripts:**
- `create-single-inst.sh` - Creates all single instruction test programs
- `create-cost-models.sh` - Creates all cost model files

**Execution Scripts:**
- `run-alternatives-parallel.sh` - Updated with cores support (CORES=4 variable)
- `run-all-alternatives.sh` - New comprehensive script to test ALL instructions

## Usage

### Run All Tests
```bash
./run-all-alternatives.sh
```
This will:
- Test all 29 single instructions
- Use 4 cores per test
- Run up to 16 tests in parallel
- Generate results in `alternatives-all/` directory

### Run Specific Test
```bash
racket optimize-alt.rkt -p 4 -t 120 --cost costs/xor-expensive.rkt -d output programs/alternatives/single/xor.s
```

### Key Features
- **Cores Support**: Use `-p <num>` to control parallel search instances
- **Cost Models**: Each instruction has its own "expensive" cost model
- **Comprehensive Coverage**: All RV32IM instructions included
- **Parallel Execution**: Can run multiple tests simultaneously

## Statistics
- **Total Instructions**: 29 RV32IM instructions
- **Test Files Created**: 58 files (29 .s files + 29 .info files)
- **Cost Models**: 29 cost model files
- **Scripts**: 4 executable scripts