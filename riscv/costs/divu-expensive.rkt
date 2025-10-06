;; Cost model making divu very expensive to find alternatives
#hash(
  ;; RV32I Arithmetic
  (add . 1)
  (sub . 1)
  (sll . 1)
  (slt . 1)
  (sltu . 1)
  (xor . 1)
  (srl . 1)
  (sra . 1)
  (or . 1)
  (and . 1)

  ;; RV32I Immediate
  (addi . 1)
  (slti . 1)
  (sltiu . 1)
  (xori . 1)
  (ori . 1)
  (andi . 1)
  (slli . 1)
  (srli . 1)
  (srai . 1)

  ;; RV32I Upper immediate
  (lui . 1)
  (auipc . 1)

  ;; RV32M Extension (normally higher cost)
  (mul . 4)
  (mulh . 4)
  (mulhsu . 4)
  (mulhu . 4)
  (div . 32)
  (divu . 1000)
  (rem . 32)
  (remu . 32)
)
