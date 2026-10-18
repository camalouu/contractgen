# CVA6 native simulator build

`compile-verilator.sh` builds the standalone simulator and batch attacker library
with the pinned Verilator. Testcase images are supplied at runtime.

Before C++ compilation, `fix-wide-constants.py` makes implicit high zero words
explicit in generated `VL_CONSTHI_W_nX` initializers. In Verilator 5.008,
`VL_CONSTHI_W_nX` offsets its output pointer, but its `VL_C_END_` clearing loop
uses an absolute word index relative to that already-offset pointer. A partial
high chunk can therefore write outside its buffer. CVA6's generated 17,111-bit
configuration constants trigger this and can overwrite the testcase instruction
image on the host stack. Generated code receives the same constant value after
the workaround; the RTL, instruction vocabulary and simulator pin are unchanged.

The canary regression demonstrates the pinned helper's overrun and the safe
initializer. Native timing regressions cover identical taken-branch programs
that reach the formerly overwritten image area, repeated and concurrent cases,
and a positive branch-prediction timing control. They run as Nix package checks.
