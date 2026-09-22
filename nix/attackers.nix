{ pkgs, resources, tools }:
let
  specs = {
    ibex = { dir = "ibex-test"; deps = []; atom = "ibex_test"; };
    cva6 = { dir = "cva6-test"; deps = [ "cva6" ]; atom = "cva6_test"; };
    hazard3 = { dir = "hazard3-test"; deps = [ "hazard3" ]; atom = "hazard3_test"; };
    proteus = { dir = "proteus-test"; deps = []; atom = "proteus_test"; };
    sodor-2 = { dir = "sodor-test"; deps = [ "sodor-2" "attacker-test-common" ]; atom = "sodor_2_test"; };
    darkriscv-2 = { dir = "darkriscv-test"; deps = [ "darkriscv-2" "attacker-test-common" ]; atom = "darkriscv_2_test"; };
    fwrisc = { dir = "fwrisc-test"; deps = [ "attacker-test-common" ]; atom = "fwrisc_test"; };
    cv32e40p = { dir = "cv32e40p-test"; deps = [ "attacker-test-common" ]; atom = "cv32e40p_test"; };
    cv32e40s = { dir = "cv32e40s-test"; deps = [ "attacker-test-common" ]; atom = "cv32e40s_test"; };
  };
  build = name: spec: pkgs.stdenv.mkDerivation {
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
      bash ${spec.dir}/compile-verilator.sh "$PWD/${spec.dir}" "$PWD/build"
      runHook postBuild
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp build/libcontract_${spec.atom}_attacker.so $out/lib/
    '';
    passthru = { inherit (spec) atom; };
  };
in pkgs.lib.mapAttrs build specs
