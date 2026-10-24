{ pkgs, resources, tools }:
let
  specs = {
    piccolo = { dir = "piccolo-test"; deps = [ "attacker-test-common" ]; atom = "piccolo_test"; };
    rocket = { dir = "rocket-test"; deps = []; atom = "rocket_test"; };
    ibex = { dir = "ibex-test"; deps = [ "attacker-test-common" ]; atom = "ibex_test"; };
    ibex-mult-div = { dir = "ibex-test"; deps = [ "attacker-test-common" ]; atom = "ibex_mult_div_test"; variant = "MULT_DIV"; };
    ibex-cache = { dir = "ibex-test"; deps = [ "attacker-test-common" ]; atom = "ibex_cache_test"; variant = "CACHE"; };
    sodor-5 = { dir = "sodor-test"; deps = [ "sodor-5" "attacker-test-common" ]; atom = "sodor_5_test"; variant = "5"; };
    darkriscv-3 = { dir = "darkriscv-test"; deps = [ "darkriscv-3" "attacker-test-common" ]; atom = "darkriscv_3_test"; variant = "3"; };
    cva6 = { dir = "cva6-test"; deps = [ "cva6" "attacker-test-common" ]; atom = "cva6_test"; };
    hazard3 = { dir = "hazard3-test"; deps = [ "hazard3" "attacker-test-common" ]; atom = "hazard3_test"; };
    proteus = { dir = "proteus-test"; deps = [ "attacker-test-common" ]; atom = "proteus_test"; };
    sodor-2 = { dir = "sodor-test"; deps = [ "sodor-2" "attacker-test-common" ]; atom = "sodor_2_test"; };
    darkriscv-2 = { dir = "darkriscv-test"; deps = [ "darkriscv-2" "attacker-test-common" ]; atom = "darkriscv_2_test"; };
    fwrisc = { dir = "fwrisc-test"; deps = [ "attacker-test-common" ]; atom = "fwrisc_test"; };
    cv32e40p = { dir = "cv32e40p-test"; deps = [ "attacker-test-common" ]; atom = "cv32e40p_test"; };
    cv32e40s = { dir = "cv32e40s-test"; deps = [ "attacker-test-common" ]; atom = "cv32e40s_test"; };
  };
  build = name: spec: pkgs.stdenv.mkDerivation ({
    pname = "contractgen-attacker-${name}";
    version = "1";
    src = resources.assemble ([ spec.dir ] ++ spec.deps);
    nativeBuildInputs = tools.simulation;
    dontUnpack = true;
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      cp -rL $src resources
      chmod -R u+w resources
      cd resources
      export CONTRACTGEN_RESOURCE_ROOT="$PWD"
      export CONTRACT_BUILD_JOBS="$NIX_BUILD_CORES"
      bash ${spec.dir}/compile-verilator.sh "$PWD/${spec.dir}" "$PWD/build"${pkgs.lib.optionalString (spec ? variant) " ${pkgs.lib.escapeShellArg spec.variant}"}
      runHook postBuild
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp build/libcontract_${spec.atom}_attacker.so $out/lib/
    '';
    passthru = { inherit (spec) atom; };
  } // pkgs.lib.optionalAttrs (name == "cva6") {
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      $CXX -std=c++17 -O2 -UNDEBUG -I"$(verilator -getenv VERILATOR_ROOT)/include" \
        cva6-test/tests/wide_constant_test.cpp -o wide-constant-test
      ./wide-constant-test
      python3 cva6-test/tests/timing.py build/libcontract_cva6_test_attacker.so
      runHook postCheck
    '';
  } // pkgs.lib.optionalAttrs (name == "piccolo") {
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      $CXX -std=c++17 -O2 -UNDEBUG -Ipiccolo-test/verif \
        piccolo-test/tests/axi_memory_test.cpp -o axi-memory-test
      ./axi-memory-test
      python3 piccolo-test/tests/runtime.py build/libcontract_piccolo_test_attacker.so
      runHook postCheck
    '';
  } // pkgs.lib.optionalAttrs (name == "rocket") {
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      $CXX -std=c++17 -O2 -UNDEBUG -pthread -Ibuild/obj_dir \
        -I"$(verilator -getenv VERILATOR_ROOT)/include" -Irocket-test/verif \
        rocket-test/tests/timing_test.cpp build/libcontract_rocket_test_attacker.so \
        -Wl,-rpath,"$PWD/build" -o independent-timing-test
      ./independent-timing-test
      runHook postCheck
    '';
  });
in pkgs.lib.mapAttrs build specs
