# Hardware-Software Leakage Contract Synthesis Toolchain

Also available on Zenodo (including
results): [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.10491534.svg)](https://doi.org/10.5281/zenodo.10491534)

## Background

Leakage contracts have been presented
in [Hardware-Software Contracts for Secure Speculation](https://doi.org/10.1109/SP40001.2021.00036) and allow to capture
microarchitectural leakages through side channels at the ISA-level. While ideally a processor is designed with a
specific contract in mind, correct leakage contracts rarely exist for existing microarchitectures.

This toolchain allows to generate a leakage contract candidate based on a set of testcases. These test cases are
automatically generated and try to surface common leakages.

Every testcase is composed of two programs which are evaluated in parallel. The simulation shows whether the two
programs are distinguishable by an adversary and using the simulation trace and
the [RISC-V Formal Interface](https://github.com/SymbioticEDA/riscv-formal/blob/master/docs/rvfi.md), possible additions
to the contract, i.e. a set of contract atoms, can be extracted.

Eventually, these results are used to synthesize a contract using [Google OR-Tools](https://github.com/google/or-tools).

## Getting started

The supported environment is an x86-64 Linux system with Nix and flakes enabled.
All source revisions, build tools, Java dependencies, native libraries, and RTL
inputs are locked by `flake.lock`.

```sh
nix build
nix run . -- --help
./run-nix.sh --help
```

`nix run . --` accepts the existing CLI commands and options. For example, a
small attacker-harness synthesis run is:

```sh
nix run . -- synth_new \
  --processor IBEX_TEST \
  --isa BASE,M \
  --contract BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE \
  -n 100 -t 8 -s 35 \
  --output-dir results/ibex-test-100-seed35
```

The packaged launcher uses cached Spike and attacker libraries. It writes
temporary compilation and simulation files below `./results/.work` by default;
set `CONTRACTGEN_WORK_ROOT` to use another writable location. Explicit CLI
library paths such as `--spike-lib` and `--ibex-test-lib` take precedence over
the corresponding `CONTRACT_*_LIB` environment variables.

Use the development shell for Java, harness, legacy simulator, or formal work:

```sh
nix develop
mvn -Dcontractgen.build.directory=/tmp/contractgen-build test
```

The alternate Maven build directory avoids changing an existing `target/` from
an older environment. The shell provides JDK 21 while Maven emits Java 18
compatible bytecode.

Independent build targets include:

```sh
nix build .#spike
nix build .#attacker-cva6
nix build .#proteus-rtl
nix build .#cva6-verilog
nix flake check
```

The nine attacker packages are `attacker-ibex`, `attacker-cva6`,
`attacker-hazard3`, `attacker-proteus`, `attacker-sodor-2`,
`attacker-darkriscv-2`, `attacker-fwrisc`, `attacker-cv32e40p`, and
`attacker-cv32e40s`. RTL regeneration produces store artifacts; copying one
back into `src/main/resources` is an explicit review step. See
[`nix/README.md`](nix/README.md) for package and contributor details.

The results mentioned in the paper can be found on [Zenodo](https://doi.org/10.5281/zenodo.10491534).

## Adding support for new microarchitectures

Support for a new microarchitecture requires only a few steps:

- Embed two instances of the core in a testbench and ensure that the insturctions can be loaded into memory. Take a look
  at the Ibex core integration for an up-to-date example.
- Implement the adversary model and provide its observations as signals to the adversary module.
- Provide a way to extract the architectural state e.g.
  the [RISC-V Formal Interface](https://github.com/SymbioticEDA/riscv-formal/blob/master/docs/rvfi.md).
- Implement the microarchitecture as a new class in Java and provide the required functionality to compile the
  testbench, simulate a testcase and extract possible observations from a trace.

## Paper

This project was used in the paper "Synthesizing Hardware-Software Leakage Contracts for RISC-V Open-Source Processors"
by Gideon Mohr, Marco Guarnieri and Jan Reineke presented at DATE 2024.
