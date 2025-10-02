# RISC-V Superoptimizer for GreenThumb

This directory contains a RISC-V instruction subset implementation for the GreenThumb superoptimizer framework.

## Instruction Set

This implementation includes the following RISC-V instructions:

### Arithmetic (R-type and I-type)
- `ADD rd, rs1, rs2` - Addition (register)
- `ADDI rd, rs1, imm` - Addition (immediate)
- `SUB rd, rs1, rs2` - Subtraction
- `MUL rd, rs1, rs2` - Multiplication (low 64-bit product)

### Shift Operations
- `SLL rd, rs1, rs2` - Shift left logical (register)
- `SLLI rd, rs1, shamt` - Shift left logical (immediate, shamt=32)
- `SRL rd, rs1, rs2` - Shift right logical (register)
- `SRLI rd, rs1, shamt` - Shift right logical (immediate, shamt=32)
- `SRA rd, rs1, rs2` - Shift right arithmetic (register)
- `SRAI rd, rs1, shamt` - Shift right arithmetic (immediate, shamt=32)

### Logical Operations
- `AND rd, rs1, rs2` - Bitwise AND (register)
- `ANDI rd, rs1, imm` - Bitwise AND (immediate)
- `OR rd, rs1, rs2` - Bitwise OR (register)
- `ORI rd, rs1, imm` - Bitwise OR (immediate)
- `XOR rd, rs1, rs2` - Bitwise XOR (register)
- `XORI rd, rs1, imm` - Bitwise XOR (immediate)

## Architecture Specification

- **Bitwidth**: 64-bit registers
- **Shift amount**: Fixed at 32 for immediate shifts (configurable in machine definition)
- **Register naming**: Supports both `x0-x31` and `r0-r31` notation
- **No memory operations**: This subset focuses on arithmetic, logical, and shift operations

## Files

### Core Implementation
- `riscv-machine.rkt` - ISA definition, instruction classes, and program state structure
- `riscv-parser.rkt` - Assembly language parser
- `riscv-printer.rkt` - IR encoder/decoder between source ↔ string-IR ↔ encoded-IR
- `riscv-simulator-rosette.rkt` - Symbolic simulator (for symbolic search and validation)
- `riscv-simulator-racket.rkt` - Concrete simulator (for stochastic and enumerative search)

### Testing
- `test-simulator.rkt` - Unit tests for parser, printer, and simulators
- `test-program.rkt` - Tests for example programs
- `programs/` - Directory with example RISC-V programs and test cases

## Quick Start

### Testing the Implementation

Run the basic tests:
```bash
cd riscv
racket test-simulator.rkt
```

Test example programs:
```bash
racket test-program.rkt
```

### Using in Code

```racket
#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-rosette.rkt")

(current-bitwidth 64)

;; Create components
(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 4]))  ; 4 registers
(define printer (new riscv-printer% [machine machine]))
(define simulator (new riscv-simulator-rosette% [machine machine]))

;; Parse and run code
(define code (send parser ir-from-string "add x0, x1, x2"))
(define encoded (send printer encode code))
(define result (send simulator interpret encoded input-state))
```

## Example Programs

See `programs/` directory for example RISC-V programs:

- `test_add.s` - Simple addition
- `negate.s` - Two's complement negation
- `multiply_by_3.s` - Constant multiplication
- `clear_rightmost_bit.s` - Bit manipulation
- And more...

Each `.s` file has a corresponding `.s.info` file with live-in/live-out register information.

## Implementation Notes

### Shift Amount Configuration

The shift amount for immediate shift instructions is configured to be 32 in the machine definition. This was a design choice to reduce the search space. You can modify this in `riscv-machine.rkt`:

```racket
(define-arg-type 'shamt (lambda (config) '(32)))
```

### Register State

The program state consists of:
- A vector of 64-bit registers (size determined by `config` parameter)
- A memory object (included but not used in this instruction subset)

### Instruction Encoding

Instructions follow RISC-V naming conventions:
- Register-only operations: `add`, `sub`, `sll`, etc.
- Immediate operations: `addi`, `slli`, `andi`, etc.

The printer automatically handles encoding/decoding between assembly syntax and internal representation.

## Future Extensions

To enable full superoptimization:

1. **Validator** (`riscv-validator.rkt`) - Implement equivalence checking
2. **Search Strategies**:
   - `riscv-symbolic.rkt` - Symbolic search
   - `riscv-stochastic.rkt` - Stochastic search
   - `riscv-forwardbackward.rkt` - Enumerative search
3. **Cooperative Search** - Implement live-out parsing and search coordination

## References

- [GreenThumb: Superoptimizer Construction Framework (CC'16)](http://www.eecs.berkeley.edu/~mangpo/www/papers/greenthumb_cc2016.pdf)
- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- [GreenThumb Documentation](../documentation/new-isa.md)
