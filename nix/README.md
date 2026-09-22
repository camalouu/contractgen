# Nix environment

The flake targets x86-64 Linux. Tool and RTL inputs are pinned in `flake.lock`;
Java dependency versions and Maven plugin versions are defined in `pom.xml`.

```sh
nix build
nix run . -- --help
nix develop
nix build .#attacker-ibex
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
Spike extraction, all nine attacker harnesses, deterministic synthesis/replay
workflows, both CV32E40S timing settings, the legacy Icarus and Verilator
matrices, and formal BMC/cover checks. RTL regeneration remains available as
the separate `proteus-rtl` and `cva6-verilog` package builds because those are
large deliverable artifacts rather than routine smoke checks.
