# GOOMY (General Out-of-Order Execution "gOoOE")
![goomy "his ass is not X" meme](https://github.com/achen0044/goomy/blob/2b935bde1aa278bdb13890ea66670d3a4f277899/babey.png?raw=true)

## THE PLAN
To implement (or at least get as much done as possible) an OOO processor (as per Tomasulo's algorithm) in SystemVerilog. Reduced scope: misalignment and self-modification both disallowed.

## CURRENT FEATURES
Makefile & tooling; you can now instantiate storage memory.
Generic & modular reservation stations for holding instructions. ROB also functional.
All instructions in custom ISA implemented (see [reference.txt](reference.txt)).

Limited "ld after st" handling through a scuffed store buffer. Naive UID-based older/newer check in store buffer.
> Unknown if can commit multiple stores on the same cycle. Similarly, probably cannot finish a load and store on same cycle.

Queues for multiple resolves and commits per cycle.
No multi-fetch/decode in this commit.

Full flush for branching.
No branch predictor.
Instant write, delayed read (~50 cycles).

## Test Components:
testname.hex - the test case, written in hex (see [reference.txt](reference.txt))
> note that misalignment and self-modifying code are not allowed and will not act as expected
> any lines that start with “- ” will be omitted from the .out (but in the .raw) (this was to omit output from verilator)
testname.mem - initial values for any memory, as everything in the .hex will only be in the instruction memory and can't be read from/written to by the user
testname.ok - the intended output.
