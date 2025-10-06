# RV32IM Instructions To Implement (No Memory Operations)

## Current Status Summary
- **Already Implemented**: 19 RV32I + 1 RV32M = 20 instructions
- **To Be Implemented**: 7 RV32I + 7 RV32M = 14 instructions
- **Total Target**: 34 instructions (RV32IM without memory/branch/jump)

---

## ✅ Already Implemented (20 instructions)

### Arithmetic (3)
- ✅ `ADD rd, rs1, rs2` - rd = rs1 + rs2
- ✅ `ADDI rd, rs1, imm12` - rd = rs1 + sign_ext(imm12)
- ✅ `SUB rd, rs1, rs2` - rd = rs1 - rs2

### Logical (6)
- ✅ `AND rd, rs1, rs2` - rd = rs1 & rs2
- ✅ `ANDI rd, rs1, imm12` - rd = rs1 & sign_ext(imm12)
- ✅ `OR rd, rs1, rs2` - rd = rs1 | rs2
- ✅ `ORI rd, rs1, imm12` - rd = rs1 | sign_ext(imm12)
- ✅ `XOR rd, rs1, rs2` - rd = rs1 ^ rs2
- ✅ `XORI rd, rs1, imm12` - rd = rs1 ^ sign_ext(imm12)

### Shifts (6)
- ✅ `SLL rd, rs1, rs2` - rd = rs1 << (rs2 & 0x1F)
- ✅ `SLLI rd, rs1, shamt` - rd = rs1 << shamt
- ✅ `SRL rd, rs1, rs2` - rd = rs1 >> (rs2 & 0x1F) (logical)
- ✅ `SRLI rd, rs1, shamt` - rd = rs1 >> shamt (logical)
- ✅ `SRA rd, rs1, rs2` - rd = rs1 >>> (rs2 & 0x1F) (arithmetic)
- ✅ `SRAI rd, rs1, shamt` - rd = rs1 >>> shamt (arithmetic)

### Comparison (4)
- ✅ `SLT rd, rs1, rs2` - rd = (rs1 < rs2) ? 1 : 0 (signed)
- ✅ `SLTI rd, rs1, imm12` - rd = (rs1 < sign_ext(imm12)) ? 1 : 0 (signed)
- ✅ `SLTU rd, rs1, rs2` - rd = (rs1 < rs2) ? 1 : 0 (unsigned)
- ✅ `SLTIU rd, rs1, imm12` - rd = (rs1 < sign_ext(imm12)) ? 1 : 0 (unsigned)

### Upper Immediate (1)
- ✅ `LUI rd, imm20` - rd = imm20 << 12

### Multiply (1)
- ✅ `MUL rd, rs1, rs2` - rd = (rs1 * rs2)[31:0]

---

## ❌ To Be Implemented (14 instructions)

### 🔴 RV32I Base Instructions (7)

#### 1. **AUIPC** - Add Upper Immediate to PC
```
AUIPC rd, imm20
```
- **Encoding**: U-type
- **Operation**: `rd = PC + (imm20 << 12)`
- **Description**: Forms 32-bit offset from PC, used for position-independent code
- **Implementation Notes**:
  - Requires program counter (PC) tracking
  - PC should be instruction address in the program
  - Used with JALR for long jumps

#### 2. **JAL** - Jump And Link
```
JAL rd, offset
```
- **Encoding**: J-type (special immediate encoding)
- **Operation**: `rd = PC + 4; PC = PC + sign_ext(offset)`
- **Description**: Unconditional jump, saves return address
- **Implementation Notes**:
  - For superoptimizer, might handle as special case
  - Could limit to straight-line code initially

#### 3. **JALR** - Jump And Link Register
```
JALR rd, rs1, offset
```
- **Encoding**: I-type
- **Operation**: `rd = PC + 4; PC = (rs1 + sign_ext(offset)) & ~1`
- **Description**: Jump to address in register + offset
- **Implementation Notes**:
  - The LSB is cleared to ensure alignment
  - Used for returns, indirect calls, and computed jumps

#### 4. **BEQ** - Branch Equal
```
BEQ rs1, rs2, offset
```
- **Encoding**: B-type (special immediate encoding)
- **Operation**: `if (rs1 == rs2) PC = PC + sign_ext(offset)`
- **Description**: Conditional branch if equal
- **Implementation Notes**: Requires control flow support

#### 5. **BNE** - Branch Not Equal
```
BNE rs1, rs2, offset
```
- **Encoding**: B-type
- **Operation**: `if (rs1 != rs2) PC = PC + sign_ext(offset)`
- **Description**: Conditional branch if not equal

#### 6. **BLT** - Branch Less Than
```
BLT rs1, rs2, offset
```
- **Encoding**: B-type
- **Operation**: `if (rs1 < rs2) PC = PC + sign_ext(offset)` (signed comparison)
- **Description**: Branch if less than (signed)

#### 7. **BGE** - Branch Greater or Equal
```
BGE rs1, rs2, offset
```
- **Encoding**: B-type
- **Operation**: `if (rs1 >= rs2) PC = PC + sign_ext(offset)` (signed comparison)
- **Description**: Branch if greater or equal (signed)

#### 8. **BLTU** - Branch Less Than Unsigned
```
BLTU rs1, rs2, offset
```
- **Encoding**: B-type
- **Operation**: `if (rs1 < rs2) PC = PC + sign_ext(offset)` (unsigned comparison)
- **Description**: Branch if less than (unsigned)

#### 9. **BGEU** - Branch Greater or Equal Unsigned
```
BGEU rs1, rs2, offset
```
- **Encoding**: B-type
- **Operation**: `if (rs1 >= rs2) PC = PC + sign_ext(offset)` (unsigned comparison)
- **Description**: Branch if greater or equal (unsigned)

---

### 🔴 RV32M Extension Instructions (7)

#### 1. **MULH** - Multiply High Signed×Signed
```
MULH rd, rs1, rs2
```
- **Encoding**: R-type
- **Operation**: `rd = (rs1 * rs2)[63:32]` (signed × signed)
- **Description**: Returns upper 32 bits of 64-bit product
- **Use Case**: Full 64-bit multiplication results, overflow detection
- **Implementation**:
  ```python
  result = sign_ext(rs1, 64) * sign_ext(rs2, 64)
  rd = result >> 32
  ```

#### 2. **MULHSU** - Multiply High Signed×Unsigned
```
MULHSU rd, rs1, rs2
```
- **Encoding**: R-type
- **Operation**: `rd = (rs1 * rs2)[63:32]` (signed × unsigned)
- **Description**: Upper 32 bits of mixed sign multiplication
- **Implementation**:
  ```python
  result = sign_ext(rs1, 64) * zero_ext(rs2, 64)
  rd = result >> 32
  ```

#### 3. **MULHU** - Multiply High Unsigned×Unsigned
```
MULHU rd, rs1, rs2
```
- **Encoding**: R-type
- **Operation**: `rd = (rs1 * rs2)[63:32]` (unsigned × unsigned)
- **Description**: Upper 32 bits of unsigned multiplication
- **Implementation**:
  ```python
  result = zero_ext(rs1, 64) * zero_ext(rs2, 64)
  rd = result >> 32
  ```

#### 4. **DIV** - Signed Division
```
DIV rd, rs1, rs2
```
- **Encoding**: R-type
- **Operation**: `rd = rs1 / rs2` (signed)
- **Special Cases**:
  - Division by zero: `rd = -1`
  - Overflow (−2³¹ ÷ −1): `rd = −2³¹`
- **Implementation Notes**: Rounds toward zero

#### 5. **DIVU** - Unsigned Division
```
DIVU rd, rs1, rs2
```
- **Encoding**: R-type
- **Operation**: `rd = rs1 / rs2` (unsigned)
- **Special Cases**:
  - Division by zero: `rd = 2³²−1`

#### 6. **REM** - Signed Remainder
```
REM rd, rs1, rs2
```
- **Encoding**: R-type
- **Operation**: `rd = rs1 % rs2` (signed)
- **Special Cases**:
  - Division by zero: `rd = rs1`
  - Overflow (−2³¹ ÷ −1): `rd = 0`
- **Implementation Notes**: Sign of result equals sign of dividend

#### 7. **REMU** - Unsigned Remainder
```
REMU rd, rs1, rs2
```
- **Encoding**: R-type
- **Operation**: `rd = rs1 % rs2` (unsigned)
- **Special Cases**:
  - Division by zero: `rd = rs1`

---

## Implementation Priority Recommendations

### Phase 1: Complete RV32M (Highest Priority for Arithmetic)
These are purely arithmetic and easiest to add:
1. `MULH` - Important for full multiplication
2. `MULHU` - Common in cryptography
3. `MULHSU` - Less common but completes multiply set
4. `DIV` - Essential arithmetic operation
5. `DIVU` - Important for unsigned arithmetic
6. `REM` - Useful for modulo operations
7. `REMU` - Completes division set

### Phase 2: AUIPC (Medium Priority)
- `AUIPC` - Useful for large constants and addressing
- Can work without control flow initially
- Just adds immediate to a program counter value

### Phase 3: Control Flow (Lower Priority for Superoptimizer)
Since superoptimizers typically work on straight-line code:
- `JAL`, `JALR` - Could be treated as special terminators
- `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` - Requires control flow graph

---

## Summary for Implementation

### Immediate Next Steps (RV32M completion):
- **7 instructions to add**: MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
- **All are R-type**: Same format as existing MUL
- **Pure arithmetic**: No control flow complexity

### Optional Next Steps:
- **AUIPC**: Simple PC-relative addressing
- **Branches/Jumps**: Only if control flow needed

### Final Instruction Count:
- **Current**: 20 instructions
- **After RV32M**: 27 instructions
- **With AUIPC**: 28 instructions
- **Full (with branches/jumps)**: 34 instructions

This gives you a solid arithmetic-focused instruction set perfect for superoptimization tasks without the complexity of memory operations or control flow.