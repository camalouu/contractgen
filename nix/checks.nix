{ pkgs, java, native, tools, attackers, application, resources }:
let
  inherit (pkgs) lib;
in {
  help = pkgs.runCommand "contractgen-help" {} ''
    cd "$TMPDIR"
    ${application}/bin/contractgen --help > $out
  '';
  native-smoke = pkgs.runCommand "contractgen-native-smoke" {
    nativeBuildInputs = [ pkgs.jdk21_headless ];
    JAVA_TOOL_OPTIONS = "-Djna.boot.library.path=${native}/lib -Djava.library.path=${native}/lib";
    LD_LIBRARY_PATH = "${native}/lib";
    CONTRACT_SPIKE_LIB = "${tools.spike}/lib/libcontract_spike_atom.so";
  } (lib.concatStringsSep "\n" (lib.mapAttrsToList (_: drv:
      "export CONTRACT_${lib.toUpper drv.atom}_LIB=${drv}/lib/libcontract_${drv.atom}_attacker.so") attackers) + "\n" + ''
    mkdir -p 'work with spaces'
    cd 'work with spaces'
    cp ${./NativeSmoke.java} NativeSmoke.java
    javac -cp '${java}/share/java/contractgen.jar:${java}/share/java/lib/*' NativeSmoke.java
    for target in ortools ${lib.concatStringsSep " " (lib.mapAttrsToList (_: drv: drv.atom) attackers)} spike; do
      java -cp '.:${java}/share/java/contractgen.jar:${java}/share/java/lib/*' NativeSmoke "$target"
    done
    touch $out
  '');
  workflow-smoke = pkgs.runCommand "contractgen-workflow-smoke" {} ''
    run_workflow() {
      processor="$1"
      isa="$2"
      timing="$3"
      output="$PWD/$processor-$timing"
      extra=()
      if [ "$processor" = IBEX_TEST ]; then
        # An explicit CLI library must win over an environment override.
        export CONTRACT_IBEX_TEST_LIB=/does/not/exist
        extra=(--ibex-test-lib ${attackers.ibex}/lib/libcontract_ibex_test_attacker.so)
      fi
      ${application}/bin/contractgen synth_new \
        --processor "$processor" --isa "$isa" --contract BASE \
        -n 1 -t 2 -s 35 --output-dir "$output" \
        --disable-adaptive-skipping \
        --cv32e40s-data-independent-timing "$timing" \
        "''${extra[@]}"
      unset CONTRACT_IBEX_TEST_LIB
      test -s "$output/contract.json"
      test -s "$output/testcases.json"
      test -s "$output/summary.txt"
      grep -q '"testResults"' "$output/contract.json"
      grep -q '"observations"' "$output/contract.json"
      grep -q "Processor: $processor" "$output/summary.txt"
      grep -q 'Count: 1' "$output/summary.txt"
      grep -q 'RTL Executed: 1' "$output/summary.txt"
    }

    run_workflow IBEX_TEST BASE,M off
    run_workflow CVA6_TEST BASE,M off
    run_workflow HAZARD3_TEST BASE,M off
    run_workflow PROTEUS_TEST BASE,M off
    run_workflow SODOR_2_TEST BASE off
    run_workflow DARKRISCV_2_TEST BASE off
    run_workflow FWRISC_TEST BASE,M off
    run_workflow CV32E40P_TEST BASE,M off
    run_workflow CV32E40S_TEST BASE,M off
    run_workflow CV32E40S_TEST BASE,M on
    touch $out
  '';
  formal = pkgs.runCommand "contractgen-formal-smoke" {
    nativeBuildInputs = [ tools.yosys pkgs.sby pkgs.z3 ];
  } ''
    cat > counter.sv <<'SV'
    module counter(input clk);
      reg [2:0] count = 0;
      always @(posedge clk) begin
        count <= count + 1;
        assert(count <= 7);
        cover(count == 3);
      end
    endmodule
    SV
    for mode in bmc cover; do
      cat > "$mode.sby" <<SBY
    [options]
    mode $mode
    depth 8
    [engines]
    smtbmc z3
    [script]
    read -formal counter.sv
    prep -top counter
    [files]
    counter.sv
    SBY
      sby -f "$mode.sby"
    done
    touch $out
  '';
  legacy-iverilog = pkgs.runCommand "contractgen-legacy-iverilog-smoke" {
    nativeBuildInputs = tools.runtime;
  } ''
    run_legacy() {
      core="$1"
      variant="$2"
      executable="$3"
      label="$core''${variant:+-$variant}"
      source="$PWD/source-$label"
      compiled="$PWD/compiled-$label"
      cp -rL --no-preserve=mode "${resources.all}/$core" "$source"
      chmod -R u+w "$source"
      if [ -n "$variant" ]; then
        bash "$source/compile.sh" "$source" "$compiled" "$variant"
      else
        bash "$source/compile.sh" "$source" "$compiled"
      fi

      # The legacy testbenches load two register images, two instruction
      # memories, and a cycle bound from their working directory.
      for id in 1 2; do
        for _ in $(seq 1 32); do echo 00000000; done > "$compiled/init_$id.dat"
        for _ in $(seq 1 128); do echo 00000013; done > "$compiled/memory_$id.dat"
      done
      echo 00000020 > "$compiled/count.dat"
      set +e
      (cd "$compiled" && timeout 20 "./$executable" > simulation.log)
      result=$?
      set -e
      if [ "$result" -eq 124 ]; then
        echo TIMEOUT >> "$compiled/simulation.log"
      elif [ "$result" -ne 0 ]; then
        return "$result"
      fi
      grep -Eq 'SUCCESS|FAIL|FALSE_POSITIVE|ERROR|TIMEOUT' "$compiled/simulation.log"
    }

    run_legacy ibex BASE ibex
    run_legacy ibex CACHE ibex
    run_legacy ibex SMALL ibex
    run_legacy cva6 "" ariane
    run_legacy hazard3 "" hazard3
    run_legacy sodor-2 "" sodor-2
    run_legacy sodor-5 "" sodor-5
    run_legacy darkriscv-2 "" darkriscv-2
    run_legacy darkriscv-3 "" darkriscv-3
    touch $out
  '';
  legacy-verilator = pkgs.runCommand "contractgen-legacy-verilator-smoke" {
    nativeBuildInputs = tools.runtime;
    CONTRACT_BUILD_JOBS = builtins.toString 4;
  } ''
    run_legacy() {
      core="$1"
      variant="$2"
      executable="$3"
      label="$core''${variant:+-$variant}"
      source="$PWD/source-$label"
      compiled="$PWD/compiled-$label"
      cp -rL --no-preserve=mode "${resources.all}/$core" "$source"
      chmod -R u+w "$source"
      if [ -n "$variant" ]; then
        bash "$source/compile-verilator.sh" "$source" "$compiled" "$variant"
      else
        bash "$source/compile-verilator.sh" "$source" "$compiled"
      fi
      for id in 1 2; do
        for _ in $(seq 1 32); do echo 00000000; done > "$compiled/init_$id.dat"
        for _ in $(seq 1 128); do echo 00000013; done > "$compiled/memory_$id.dat"
      done
      echo 00000020 > "$compiled/count.dat"
      set +e
      (cd "$compiled" && timeout 20 "./$executable" > simulation.log)
      result=$?
      set -e
      if [ "$result" -eq 124 ]; then
        echo TIMEOUT >> "$compiled/simulation.log"
      elif [ "$result" -ne 0 ]; then
        return "$result"
      fi
      grep -Eq 'SUCCESS|FAIL|FALSE_POSITIVE|ERROR|TIMEOUT' "$compiled/simulation.log"
    }

    run_legacy ibex BASE ibex
    run_legacy ibex CACHE ibex
    run_legacy ibex SMALL ibex
    run_legacy cva6 "" ariane
    run_legacy hazard3 "" hazard3
    touch $out
  '';
}
