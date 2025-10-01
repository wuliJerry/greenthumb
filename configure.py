#!/usr/bin/env python3

import subprocess

# Create path.rtk
result = subprocess.run(["pwd"], capture_output=True, text=True)
abs_path = result.stdout.strip()
with open("path.rkt", "w") as f:
    f.write("#lang racket\n")
    f.write("(provide (all-defined-out))\n")
    f.write("(define srcpath \"" + abs_path + "\")\n")
print("path.rkt is created.")
