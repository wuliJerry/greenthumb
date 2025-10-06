#!/bin/bash

# Create cost model files where each instruction is made expensive (cost=1000)

DIR="costs"
mkdir -p "$DIR"

# Function to create a cost model file
create_cost_model() {
    local inst=$1
    local filename="$DIR/${inst}-expensive.rkt"

    cat > "$filename" << EOF
;; Cost model making $inst very expensive to find alternatives
#hash(
  ;; RV32I Arithmetic
  (add . $([ "$inst" = "add" ] && echo 1000 || echo 1))
  (sub . $([ "$inst" = "sub" ] && echo 1000 || echo 1))
  (sll . $([ "$inst" = "sll" ] && echo 1000 || echo 1))
  (slt . $([ "$inst" = "slt" ] && echo 1000 || echo 1))
  (sltu . $([ "$inst" = "sltu" ] && echo 1000 || echo 1))
  (xor . $([ "$inst" = "xor" ] && echo 1000 || echo 1))
  (srl . $([ "$inst" = "srl" ] && echo 1000 || echo 1))
  (sra . $([ "$inst" = "sra" ] && echo 1000 || echo 1))
  (or . $([ "$inst" = "or" ] && echo 1000 || echo 1))
  (and . $([ "$inst" = "and" ] && echo 1000 || echo 1))

  ;; RV32I Immediate
  (addi . $([ "$inst" = "addi" ] && echo 1000 || echo 1))
  (slti . $([ "$inst" = "slti" ] && echo 1000 || echo 1))
  (sltiu . $([ "$inst" = "sltiu" ] && echo 1000 || echo 1))
  (xori . $([ "$inst" = "xori" ] && echo 1000 || echo 1))
  (ori . $([ "$inst" = "ori" ] && echo 1000 || echo 1))
  (andi . $([ "$inst" = "andi" ] && echo 1000 || echo 1))
  (slli . $([ "$inst" = "slli" ] && echo 1000 || echo 1))
  (srli . $([ "$inst" = "srli" ] && echo 1000 || echo 1))
  (srai . $([ "$inst" = "srai" ] && echo 1000 || echo 1))

  ;; RV32I Upper immediate
  (lui . $([ "$inst" = "lui" ] && echo 1000 || echo 1))
  (auipc . $([ "$inst" = "auipc" ] && echo 1000 || echo 1))

  ;; RV32M Extension (normally higher cost)
  (mul . $([ "$inst" = "mul" ] && echo 1000 || echo 4))
  (mulh . $([ "$inst" = "mulh" ] && echo 1000 || echo 4))
  (mulhsu . $([ "$inst" = "mulhsu" ] && echo 1000 || echo 4))
  (mulhu . $([ "$inst" = "mulhu" ] && echo 1000 || echo 4))
  (div . $([ "$inst" = "div" ] && echo 1000 || echo 32))
  (divu . $([ "$inst" = "divu" ] && echo 1000 || echo 32))
  (rem . $([ "$inst" = "rem" ] && echo 1000 || echo 32))
  (remu . $([ "$inst" = "remu" ] && echo 1000 || echo 32))
)
EOF

    echo "Created: $filename"
}

echo "Creating cost model files..."

# Create cost models for all instructions
# Skip add and slli since they already exist
for inst in sub sll slt sltu xor srl sra or and \
            addi slti sltiu xori ori andi srli srai \
            lui auipc \
            mul mulh mulhsu mulhu div divu rem remu; do
    create_cost_model "$inst"
done

echo ""
echo "All cost model files created in $DIR/"
echo "Note: add-expensive.rkt and slli-expensive.rkt already exist"