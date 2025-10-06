# Finding Alternative Instruction Implementations

This framework uses the GreenThumb optimizer with custom cost models to discover alternative implementations for RISC-V instructions.

## How It Works

Instead of building a separate equivalence finder, we leverage the optimizer's power:

1. **Make target instructions expensive**: By setting a prohibitively high cost (e.g., 1000 cycles) for specific instructions, we force the optimizer to find alternatives
2. **Run optimization**: The optimizer naturally searches for lower-cost equivalent implementations
3. **Discover alternatives**: The optimizer outputs functionally equivalent programs using different instructions

## Components

### Modified Simulators
- `riscv-simulator-racket.rkt` - Now accepts optional `cost-model` parameter
- `riscv-simulator-rosette.rkt` - Same modification for consistency
- **Backward compatible**: Existing code works without changes

### Test Programs
```
programs/alternatives/
├── single/                    # Single instruction tests
│   ├── add_copy.s           # add x2, x1, x0 (copy operation)
│   └── slli_double.s         # slli x2, x1, 1 (multiply by 2)
└── double/                    # Two instruction sequences
    ├── mul_by_5.s            # slli + add (multiply by 5)
    └── negate.s              # xori + addi (negate value)
```

### Cost Models
```
costs/
├── add-expensive.rkt         # Makes ADD cost 1000
├── slli-expensive.rkt        # Makes SLLI cost 1000
├── shift-add-expensive.rkt   # Makes SLLI and ADD expensive
└── xor-addi-expensive.rkt    # Makes XORI and ADDI expensive
```

### Scripts
- `optimize-with-cost.rkt` - Modified optimizer that loads custom cost models
- `find-alternatives.sh` - Sequential execution of all tests
- `run-alternatives-parallel.sh` - Parallel batch execution

## Usage

### Single Test
```bash
racket optimize-with-cost.rkt programs/alternatives/single/add_copy.s \
    --cost costs/add-expensive.rkt \
    --stoch \
    -c 4 \
    -t 60 \
    -d output/add_copy
```

### Run All Tests (Sequential)
```bash
./find-alternatives.sh
```

### Run All Tests (Parallel)
```bash
./run-alternatives-parallel.sh
```

## Example Results

For `add x2, x1, x0` with ADD made expensive:
- Expected alternatives: `or x2, x1, x0`, `addi x2, x1, 0`, `slli x2, x1, 0`

For `slli x2, x1, 1` with SLLI made expensive:
- Expected alternative: `add x2, x1, x1`

For multiply by 5 (`slli x2, x1, 2; add x2, x2, x1`) with both expensive:
- Possible alternative: Using `mul` instruction with immediate 5

## Creating New Tests

1. **Create test program**:
   ```assembly
   # programs/alternatives/single/my_test.s
   sub x2, x0, x1
   ```

2. **Create info file**:
   ```
   # programs/alternatives/single/my_test.s.info
   2    # live-out register
   1    # live-in register
   ```

3. **Create cost model**:
   ```racket
   # costs/sub-expensive.rkt
   #lang racket
   #hash((sub . 1000)
         (add . 1)
         ; ... other instructions with normal costs
        )
   ```

4. **Run optimization**:
   ```bash
   racket optimize-with-cost.rkt programs/alternatives/single/my_test.s \
       --cost costs/sub-expensive.rkt \
       --hybrid -c 4 -t 60 -d output/my_test
   ```

## Scaling Considerations

### Parallel Execution
- Adjust `MAX_PARALLEL` in `run-alternatives-parallel.sh`
- Each job uses `CORES_PER_JOB` CPU cores
- Total CPU usage: `MAX_PARALLEL * CORES_PER_JOB`

### Time Limits
- Increase `TIME_LIMIT` for complex instructions
- Some alternatives may require longer search times

### Search Modes
- `--stoch`: Good for simple single instructions
- `--hybrid`: Better for complex sequences
- `--sym`: For exhaustive but slower search
- `--enum`: For systematic enumeration

## Extending to All Instructions

To systematically find alternatives for all RV32IM instructions:

1. Generate test programs for each instruction with various operands
2. Create corresponding cost models making each instruction expensive
3. Use parallel batch script to run all tests
4. Aggregate results into equivalence database

The framework is designed to scale to hundreds of test cases running in parallel.