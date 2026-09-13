# FWRISC attacker-only integration

The upstream core remains pinned and unmodified in `core/`. Contract synthesis
needs local RV32M decode and arithmetic corrections; they live in
`patches/rv32m-correctness.patch` rather than in the submodule.

`compile-verilator.sh` copies the selected core tree into the compilation output
directory as `core-patched/`, applies the patch there, and compiles that staged
copy. This also applies when `CONTRACT_FWRISC_CORE_ROOT` selects another clean
checkout. The source checkout must match the revision against which the patch
was created; patch failure stops the build rather than silently compiling the
unmodified core.
