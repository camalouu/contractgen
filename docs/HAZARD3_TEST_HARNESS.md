# HAZARD3_TEST attacker-only harness

`HAZARD3_TEST` is the new Hazard3 backend for `synth_new` and
`replay_synthesize_spike`. It leaves the legacy `HAZARD3` integration intact.

The responsibilities are deliberately split:

- Spike executes both programs and determines contract-atom
  distinguishability.
- Two synchronized Hazard3 RTL instances execute the programs under Verilator
  and return only attacker distinguishability.
- Java merges the Spike atom set and RTL attacker label into the existing
  `RISCVTestResult`/ILP pipeline.

The RTL harness does not extract contract observations. Its `ctr` module is a
constant-equivalence stub. Hazard3's RVFI valid signals remain connected only
to synchronize paired retirement and determine completion, as in the existing
attacker harnesses; no RVFI fields become contract atoms.

## Commands

Generate tests and synthesize a contract:

```sh
java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main synth_new \
  -p HAZARD3_TEST -i BASE,M \
  -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE \
  -n 10000 -t 8 -s 51 -o hazard3-test-results.json \
  --txt hazard3-test-results.txt --disable-adaptive-skipping
```

`synth_new` always writes the exact generated testcase set before starting
Spike or RTL execution. For the command above the default path is
`hazard3-test-results-testcases.json`. Select another path with
`--testcases-output hazard3-testcases.json`. The file uses the same
`RISCVTestCaseIO` JSON format as `export_tests` and can be passed directly to
`replay_synthesize_spike -e`.

Replay an exported testcase set:

```sh
java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main \
  replay_synthesize_spike -p HAZARD3_TEST -i BASE,M \
  -c BASE,ALIGNED,BRANCH,DEPENDENCIES,VALUE -t 8 \
  -e testcases.json -o hazard3-test-results.json
```

The shared library is resolved in this order:

1. `--hazard3-test-lib`
2. `CONTRACT_HAZARD3_TEST_LIB`
3. `/home/yosys/output/hazard3-test/compiled/libcontract_hazard3_test_attacker.so`

If the default library does not exist, it is built automatically from
`src/main/resources/hazard3-test/` and the existing legacy Hazard3 RTL tree.
The native API transports both 2048-word program images directly; it does not
create per-test `.dat` files or VCD traces.

`SUCCESS` is attacker-indistinguishable and `FAIL` is
attacker-distinguishable. `TIMEOUT` and `ERROR` are rejected and never used as
contract evidence.
