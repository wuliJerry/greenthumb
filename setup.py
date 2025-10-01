#!/usr/bin/env python3

import sys, os
import os.path

def create(isa,c,filename,lang):
    
    if os.path.isfile("template/"+c+".rkt"):
        filename = "template/"+c+".rkt"
        with open(filename, "r") as fin:
            with open(isa + "/" + isa + "-" + c + ".rkt", "w") as fout:
                text = fin.read().replace("$-", isa+"-")
                print(text, file=fout)
    else:
        with open(filename, "r") as fin:
            with open(isa + "/" + isa + "-" + c + ".rkt", "w") as fout:
                text = fin.read().replace("$1", isa).replace("$2", c)
                print("#lang", lang, file=fout)
                print(text, file=fout)

def main(isa):
    print("Create template files for", isa)
    os.system("mkdir " + isa)

    for name in ["test-simulator.rkt", "test-search.rkt", "main.rkt", "optimize.rkt"]:
        with open("template/" + name, "r") as fin:
            with open(isa + "/" + name, "w") as fout:
                text = fin.read().replace("$", isa)
                print(text, file=fout)

    # racket
    for c in ["machine", "simulator-racket"]:
        create(isa,c,"template/class-constructor.rkt","racket")
        
    for c in ["parser", "printer", "stochastic", "forwardbackward"]:
        create(isa,c,"template/class.rkt","racket")
        
        
    # # rosette
    for c in ["simulator-rosette", "validator"]:
        create(isa,c,"template/class-constructor.rkt","s-exp rosette")
        
    for c in ["symbolic", "inverse", "enumerator"]:
        create(isa,c,"template/class.rkt","s-exp rosette")

if __name__ == "__main__":
    main(sys.argv[1])
