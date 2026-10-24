# Native Ibex, Sodor and DarkRISCV variants

These processor names use the existing Spike → native RTL attacker → shared
adaptive runner → ILP pipeline. Variant selection changes hardware or its memory
timing configuration, not Spike semantics, contract atoms, or scheduling.

| Processor | Nix package | Configuration | ISA |
|---|---|---|---|
| `IBEX_SMALL_TEST` | `attacker-ibex-small` | Two-stage Ibex, `RV32MFast`, no cache | BASE,M |
| `IBEX_MULT_DIV_TEST` | `attacker-ibex-mult-div` | Two-stage Ibex, `RV32MSlow`, no cache | BASE,M |
| `IBEX_CACHE_TEST` | `attacker-ibex-cache` | `RV32MFast` with the legacy external data-cache timing model | BASE,M |
| `SODOR_2_TEST` | `attacker-sodor-2` | Sodor two-stage | BASE |
| `SODOR_5_TEST` | `attacker-sodor-5` | Sodor five-stage | BASE |
| `DARKRISCV_2_TEST` | `attacker-darkriscv-2` | DarkRISCV two-stage | BASE |
| `DARKRISCV_3_TEST` | `attacker-darkriscv-3` | DarkRISCV three-stage | BASE |

`IBEX_TEST` and `attacker-ibex` remain compatibility names for `IBEX_SMALL_TEST`.
The small variant retains `libcontract_ibex_test_attacker.so` and its existing
batch ABI. Other Ibex variants share that ABI but have distinct library files.
Sodor and DarkRISCV share the simple attacker ABI and export the architectural
trace diagnostic ABI. All variants have separate local build directories.

The names follow the rewrite: legacy `IBEX` is now `IBEX_SMALL_TEST`, and legacy
`IBEX_SMALL` (slow multiplier/divider) is `IBEX_MULT_DIV_TEST`.

## Cache model

Legacy `IBEX_CACHE` selected an external data-memory timing model, not Ibex's
internal instruction cache. The native variant preserves its one-address read
cache idea: a hit returns without an extra wait, a miss adds one enabled core
cycle, and stores bypass the tag and invalidate it. The tag starts invalid for
each testcase. This is a synthetic timing model, not a cache with configurable
lines, associativity or replacement. All Ibex variants keep `WritebackStage=0`,
internal `ICache=0`, and `SecureIbex=0`.

Storage follows `rv32-v1`: separate code/data, zero-filled untouched data,
persistent byte-strobed writes, and fresh memory/model/cache state per testcase.
The broken legacy finite store history and address-derived default data are not
used. Cache grants correspond to the current request; delayed reads cannot
inherit a preceding store's grant, including during split misaligned accesses.

## Sodor and DarkRISCV adapters

The native builds use the checked-in RTL versions. Transformations apply only to
disposable build copies: Verilog declaration/array normalization, reset address
0x80, and diagnostic wiring. The legacy resources remain untouched.

Sodor five-stage diagnostics retain actual register-file write events alongside
retirement metadata. Its native data adapter uses raw byte addresses and sign/
zero extension, matching the core interface. Both Sodor variants and both
DarkRISCV variants reject M-extension programs and mark reached misaligned data
accesses unsupported before RTL execution.

DarkRISCV three-stage uses registered instruction memory, as required by its PC
pipeline. The adapter holds the fetch address through the first flush bubble and
aligns the next-PC register through reset/branch flushes, preventing skipped reset
and target instructions. Like the two-stage native build, its disposable copy
corrects SLTIU's sign-extended immediate and clears JALR target bit zero. Diagnostic
probes use actual commit signals and the three-stage packed register file.

## Commands and library precedence

```bash
nix build .#attacker-ibex-mult-div .#attacker-ibex-cache \
  .#attacker-sodor-5 .#attacker-darkriscv-3

nix run . -- synth_new -p IBEX_MULT_DIV_TEST -i BASE,M \
  -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE -n 500 -t 2 -s 35 \
  --output-dir results/ibex-mult-div-example --disable-adaptive-skipping

nix run . -- replay_synthesize_spike -p IBEX_MULT_DIV_TEST -i BASE,M \
  -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE -t 1 \
  -e results/ibex-mult-div-example/testcases.json \
  -o results/ibex-mult-div-example/replayed.json --disable-adaptive-skipping
```

Synthesis and replay accept `--ibex-small-test-lib`, `--ibex-mult-div-test-lib`,
`--ibex-cache-test-lib`, `--sodor-5-test-lib`, and `--darkriscv-3-test-lib`.
Precedence is explicit CLI path → corresponding `CONTRACT_<PROCESSOR>_LIB`
environment variable → local compilation. `IBEX_SMALL_TEST` also accepts the
legacy `--ibex-test-lib`/`CONTRACT_IBEX_TEST_LIB` fallback; `IBEX_TEST` retains its
old environment-variable precedence. Packaged applications set defaults for all
variants. For Sodor/DarkRISCV use `-i BASE`.

## Verification

`nix flake check` includes native/JNA smoke tests, synthesis/replay, architectural
agreement with Spike, JALR regressions, and a variant timing/isolation check.
Directed architectural checks cover all supported integer operations, M division
edge cases where applicable, branches, register overwrites, persistent memory,
code/data overlap, and misaligned accesses on Ibex. Timing fixtures exercise the
slow multiplier, cache hit/miss, and branch pipelines; sequential and concurrent
repeats check that predecessor testcases do not contaminate labels. Invalid
retirement bounds and insufficient cycle budgets produce errors/timeouts.
