# Info File Format Documentation

## Basic Syntax

The `.info` file must have the same name as the assembly file with `.info` appended.
For example: `program.s` → `program.s.info`

## Format

```
<live-out-registers>
<live-in-registers>
```

### Line 1: Live-out Registers
- Comma-separated list of register numbers that contain the final output
- Empty line means no output registers
- Examples:
  - `3` - Only register x3 contains output
  - `0,1` - Registers x0 and x1 contain output
  - `2,3,4` - Registers x2, x3, and x4 contain output

### Line 2: Live-in Registers
- Comma-separated list of register numbers that contain input values
- Currently not used by GreenThumb (but still required in file)
- Examples:
  - `1` - Only register x1 contains input
  - `1,2` - Registers x1 and x2 contain input

## Examples

### Example 1: Double a value
**File: double.s**
```assembly
add x2, x1, x1    # x2 = x1 + x1 = 2*x1
```

**File: double.s.info**
```
2
1
```
- Output: x2 (register 2)
- Input: x1 (register 1)

### Example 2: Quadruple a value
**File: quadruple.s**
```assembly
add x2, x1, x1    # x2 = 2*x1
add x3, x2, x2    # x3 = 2*x2 = 4*x1
```

**File: quadruple.s.info**
```
3
1
```
- Output: x3 (register 3)
- Input: x1 (register 1)

### Example 3: Double negation (identity)
**File: double_negate.s**
```assembly
xori x2, x1, -1      # x2 = ~x1
addi x3, x2, 1       # x3 = -x1
xori x4, x3, -1      # x4 = ~(-x1)
addi x5, x4, 1       # x5 = -(-x1) = x1
```

**File: double_negate.s.info**
```
5
1
```
- Output: x5 (register 5) - final result
- Input: x1 (register 1) - initial value

### Example 4: Multiple outputs
**File: swap.s**
```assembly
add x3, x1, x0    # x3 = x1
add x4, x2, x0    # x4 = x2
add x1, x4, x0    # x1 = x4 (originally x2)
add x2, x3, x0    # x2 = x3 (originally x1)
```

**File: swap.s.info**
```
1,2
1,2
```
- Output: x1, x2 (swapped values)
- Input: x1, x2 (original values)

## How GreenThumb Uses This Information

1. **Optimization Target**: The optimizer tries to find a shorter/faster program that produces the same values in the live-out registers.

2. **Register Allocation**: The optimizer knows it can use any registers not in the live-out set as temporaries.

3. **Equivalence Checking**: When verifying correctness, only the live-out registers need to match between original and optimized programs.

4. **Dead Code Elimination**: Instructions that don't affect live-out registers can potentially be removed.

## Important Notes

1. **Register x0 in RISC-V**: Since x0 is hardwired to zero, it should never be in the live-out set (any writes to it are ignored).

2. **Register Numbers**: Use the numeric register ID, not the ABI name:
   - Use `1` not `x1` or `ra`
   - Use `2` not `x2` or `sp`

3. **Order doesn't matter**: `1,2,3` is the same as `3,1,2`

4. **No spaces**: Use `1,2,3` not `1, 2, 3`

## Determining Live-out Registers

To determine which registers should be live-out:

1. **Return value**: If the code computes a return value, that register is live-out
2. **Modified parameters**: If the code modifies input parameters that need to be preserved
3. **Side effects**: Any register whose value is used after this code segment

## Example: Creating a Test Program

Let's create a program that computes (x1 + x2) * 2:

**Step 1: Write the assembly (add_double.s)**
```assembly
add x3, x1, x2    # x3 = x1 + x2
add x4, x3, x3    # x4 = x3 + x3 = 2*(x1+x2)
```

**Step 2: Create the info file (add_double.s.info)**
```
4
1,2
```
- Live-out: x4 (contains the final result)
- Live-in: x1, x2 (input values)

**Step 3: Run the optimizer**
```bash
racket optimize.rkt --stoch -o -c 1 -t 60 programs/add_double.s
```

The optimizer might find a more efficient implementation, such as:
```assembly
slli x3, x1, 1    # x3 = x1 << 1 = 2*x1
slli x4, x2, 1    # x4 = x2 << 1 = 2*x2
add x4, x3, x4    # x4 = 2*x1 + 2*x2
```

Or even better:
```assembly
add x3, x1, x2    # x3 = x1 + x2
slli x4, x3, 1    # x4 = x3 << 1 = 2*(x1+x2)
```