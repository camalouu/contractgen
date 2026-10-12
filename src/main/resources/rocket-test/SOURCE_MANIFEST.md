# Rocket source manifest

Upstream: https://github.com/chipsalliance/rocket-chip
Revision: `55bcad0f59436de98ea510334121de8546b9e9d7`

Generator: Mill 0.11.12; Scala 2.13.12; Chisel 6.7.0; firtool 1.62.0.
Host generation: Java 21. Native compilation: Verilator 5.034, C++17.

The wrapper disables `DebugModuleKey` as well as core `useDebug` so the low
image address range is executable. All other subsystem keys inherit
`BaseSubsystemConfig`. Complete tile parameters and clients are in
`generator/parameters.lock`; recursive source revisions are in
`generator/submodules.lock`. Generated file hashes are in `generated.sha256`.

Upstream parameter-definition file hashes at the pinned revision:

| File | SHA-256 |
| --- | --- |
| `src/main/scala/rocket/RocketCore.scala` | `2f88a01afa8da2a4dd9706e19a1707aeac4f1edbfc0d3659e8252de76b5ce243` |
| `src/main/scala/rocket/ICache.scala` | `1dd3bb8a11eed246f400788c4daf894ef4af1ade5c5d7230238f00f3511a6da7` |
| `src/main/scala/rocket/HellaCache.scala` | `74d2d44341413b5950855af44dd1fefc2429bb25dbbcbcc171756f6501df9353` |
| `src/main/scala/rocket/BTB.scala` | `7235b7334e3da918d7a375dbd6d304cadd2ed01ad6df10ef4d35e39b49d5f1c5` |
| `src/main/scala/rocket/Multiplier.scala` | `6a12af5508adc292c77b58cb31697c93c49e65c937590441c83b8e4cb825851a` |
| `src/main/scala/tile/RocketTile.scala` | `f752c2cd986092553cd56c660243565a4b62acf28a1db003eb28f740ef58225e` |
| `src/main/scala/subsystem/Configs.scala` | `9845b3dc40053663eef26cbaecde52c11caa241e152f6b63619921d6cc51f72b` |

Licenses: Rocket includes BSD-style Berkeley, SiFive, and IBM licenses.
Chisel is Apache-2.0; CDE and Diplomacy use their upstream licenses; HardFloat
uses its Berkeley license. Corresponding notices are retained under `licenses/`.

The shared reference is supplied by `nix/patches/spike-execution-model.patch`
against the existing pinned adapted Spike revision. Rocket requires the generic
`rv32-v1` execution specification; see `docs/EXECUTION_MODEL.md`. No Rocket-specific
reference patch is applied.
