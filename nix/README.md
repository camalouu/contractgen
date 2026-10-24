# Nix environment

The flake targets x86-64 Linux. Tool and RTL inputs are pinned in `flake.lock`;
Java dependency versions and Maven plugin versions are defined in `pom.xml`.

```sh
nix build
nix run . -- --help
nix develop
nix build .#attacker-ibex-small .#attacker-ibex-mult-div .#attacker-ibex-cache
nix build .#spike
nix flake check
```

`run-nix.sh` locates the repository independently of the current working directory.
Experiment output remains relative to the caller's directory. Runtime resource
lookup uses `CONTRACTGEN_RESOURCE_ROOT` (default `./src/main/resources`), and
editable copies and legacy simulator builds use `CONTRACTGEN_WORK_ROOT`
(default `./results/.work`). The packaged launcher supplies immutable resources
and cached attacker libraries. Explicit CLI library arguments override
`CONTRACT_*_LIB` environment settings; user environment settings override the
launcher's defaults.

The development shell supplies resources, tools, Spike, and patched OR-Tools/JNA
libraries without setting attacker library overrides. Re-enter it after changing
harness sources. `CONTRACT_BUILD_JOBS` bounds runtime compilation (default 4).
Nix simulator builds use `NIX_BUILD_CORES`; use `--cores` to bound those builds.
The shell copies the fixed Maven repository to
`${XDG_CACHE_HOME:-$HOME/.cache}/contractgen/maven-repository` and forces Maven
offline. Set `CONTRACTGEN_MAVEN_REPO` to choose another writable cache path.

Each attacker derivation includes only its own harness and required RTL resources.
Java sources and experiment outputs do not form part of simulator derivations.
The Maven package excludes RTL from the JAR. Its fixed-output dependency fetch is
followed by an offline build. Keep the Maven dependency hash in `nix/java.nix`
in sync with changes to dependencies or plugin versions.

Use `-Dcontractgen.build.directory=/tmp/contractgen-build` for direct Maven
validation when the existing `target/` is owned by Docker. Do not change its
ownership or remove it.

RTL regeneration outputs belong in the Nix store. Copy a regenerated artifact
back into `src/main/resources` explicitly after reviewing it. Normal experiments
never modify the Nix store.

## Validation

`nix flake check` runs Java tests, CLI help, a native OR-Tools solve, parallel
Spike extraction, all native attacker variants, deterministic synthesis/replay
workflows, both CV32E40S timing settings, the legacy Icarus and Verilator
matrices, and formal BMC/cover checks. RTL regeneration remains available as
the separate `proteus-rtl` and `cva6-verilog` package builds because those are
large deliverable artifacts rather than routine smoke checks.

## Shared reference and Rocket

The Spike derivation applies the checked-in `patches/spike-execution-model.patch`
without changing its source revision or any simulator pin. Both C ABI entry
points execute the sole shared `rv32-v1` reference using Spike instruction
handlers. All Spike-backed workflows use it by default:

```sh
nix run . -- synth_new -p ROCKET_TEST -i BASE,M -c BASE \
  -n 64 -t 2 -s 1 \
  --output-dir results/rocket-test/64 --disable-adaptive-skipping
```

`attacker-rocket` compiles the imported generated RTL; it does not require the
Scala elaboration toolchain. `shared-reference-conformance`, `rocket-conformance`
and `rocket-workflow` are part of `nix flake check`. See
[execution semantics and migration](../docs/EXECUTION_MODEL.md) and
[Rocket usage](../docs/ROCKET_TEST_HARNESS.md).

The Spike build strips generated debug sections before installation to avoid
copying the large debug artifacts twice before Nix's normal fixup. Simulator
revisions and compilation flags are unchanged. Native reference checks run before
that stripping step.
