# RISC-V Test Programs

This directory contains test programs for the RISC-V superoptimizer.

## File Format

- `.s` files contain RISC-V assembly code
- `.s.info` files contain metadata in the format:
  ```
  <live-out registers>
  <live-in registers>
  ```
  Where registers are comma-separated indices (e.g., `0,1`)

## Test Programs

### 1. `test_add.s`
Simple addition test.
- **Input**: x1, x2
- **Output**: x0 = x1 + x2
- **Purpose**: Basic functional test

### 2. `swap_xor.s`
XOR-based swap without temporary variable.
- **Input**: x0, x1
- **Output**: x0 and x1 swapped
- **Purpose**: Classic bit manipulation pattern, already optimal

### 3. `average.s`
Compute average of two numbers.
- **Input**: x1, x2
- **Output**: x0 = (x1 + x2) / 2
- **Purpose**: Shows shift operations (note: uses shift by 32 as configured)

### 4. `absolute_diff.s`
Compute absolute difference |x1 - x2|.
- **Input**: x1, x2
- **Output**: x0 = |x1 - x2|
- **Purpose**: Intentionally inefficient, good candidate for optimization

### 5. `multiply_by_3.s`
Multiply by constant 3.
- **Input**: x1
- **Output**: x0 = x1 * 3
- **Purpose**: Simple pattern, already near-optimal

### 6. `clear_rightmost_bit.s`
Clear the rightmost set bit.
- **Input**: x1
- **Output**: x0 = x1 & (x1 - 1)
- **Purpose**: Bit manipulation idiom

### 7. `negate.s`
Two's complement negation.
- **Input**: x1
- **Output**: x0 = -x1
- **Purpose**: Shows use of immediate XOR and ADD

### 8. `mask_low_bits.s`
Create a bitmask with lower bits set.
- **Input**: none
- **Output**: x0 = 0xFF (255)
- **Purpose**: Demonstrates constant generation

### 9. `is_power_of_2.s`
Check if number is power of 2.
- **Input**: x1
- **Output**: partial computation (needs conditionals)
- **Purpose**: Demonstrates limitation of instruction subset

## Running Tests

To test the parser and simulator on these programs:

```racket
(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))
(define printer (new riscv-printer% [machine machine]))

(define code (send parser ir-from-file "programs/test_add.s"))
(send printer print-syntax code)

(define encoded-code (send printer encode code))
(define simulator (new riscv-simulator-rosette% [machine machine]))
; ... create input state and run
```

## Notes

- All programs use the configured shift amount of 32
- Register naming: both `x0-x31` and `r0-r31` are supported
- Comments start with `#`
- No load/store operations (not in this subset)
