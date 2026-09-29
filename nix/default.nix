{ pkgs, inputs }:
let
  inherit (pkgs) lib;
  resources = import ./resources.nix { inherit pkgs inputs; };
  synlig = import ./synlig.nix { inherit pkgs inputs; };
  tools = import ./tools.nix { inherit pkgs inputs; };
  attackers = import ./attackers.nix { inherit pkgs resources tools; };
  java = import ./java.nix { inherit pkgs; };
  native = pkgs.runCommand "contractgen-native" {
    nativeBuildInputs = [ pkgs.unzip pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
  } ''
    mkdir -p $out/lib
    unzip -j ${java}/share/java/lib/ortools-linux-x86-64-*.jar '*.so*' -d $out/lib
    unzip -j ${java}/share/java/lib/jna-5.14.0.jar 'com/sun/jna/linux-x86-64/libjnidispatch.so' -d $out/lib
    autoPatchelf $out
  '';
  practicalBenchmarkDriver = pkgs.stdenv.mkDerivation {
    pname = "contractgen-practical-benchmark-driver";
    version = "1";
    src = ./practical-benchmark-driver.cpp;
    dontUnpack = true;
    buildPhase = ''
      $CXX -O2 -std=c++17 "$src" -ldl -o practical-benchmark-driver
    '';
    installPhase = ''
      install -Dm755 practical-benchmark-driver $out/bin/practical-benchmark-driver
    '';
  };
  legacyBenchmark = import ./legacy-benchmark.nix { inherit pkgs resources tools; };
  application = pkgs.runCommand "contractgen" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper ${pkgs.jdk21_headless}/bin/java $out/bin/contractgen \
      --prefix PATH : ${lib.makeBinPath tools.runtime} \
      --prefix LD_LIBRARY_PATH : ${native}/lib \
      --prefix JAVA_TOOL_OPTIONS ' ' '-Djna.boot.library.path=${native}/lib -Djava.library.path=${native}/lib' \
      --set-default CONTRACTGEN_SYNLIG_YOSYS ${synlig}/bin/yosys \
      --set-default CONTRACTGEN_RESOURCE_ROOT ${resources.all} \
      --set-default CONTRACT_SPIKE_LIB ${tools.spike}/lib/libcontract_spike_atom.so \
      ${lib.concatStringsSep " \\\n      " (lib.mapAttrsToList (_: drv: "--set-default CONTRACT_${lib.toUpper drv.atom}_LIB ${drv}/lib/libcontract_${drv.atom}_attacker.so") attackers)} \
      --add-flags '-cp ${java}/share/java/contractgen.jar:${java}/share/java/lib/* contractgen.Main'
  '';
in {
  packages = { default = application; inherit java native; practical-benchmark-driver = practicalBenchmarkDriver; resources = resources.all;
    legacy-benchmark-ibex = legacyBenchmark "ibex";
    legacy-benchmark-cva6 = legacyBenchmark "cva6";
    inherit (tools) spike verilator yosys;
    inherit synlig;
    cva6-verilog = import ./cva6-verilog.nix { inherit pkgs resources synlig; };
    proteus-rtl = import ./proteus.nix { inherit pkgs inputs; };
  } // lib.mapAttrs' (name: value: lib.nameValuePair "attacker-${name}" value) attackers;
  shell = pkgs.mkShell {
    packages = tools.runtime ++ [ synlig pkgs.jdk21 pkgs.maven tools.spike ];
    CONTRACTGEN_SYNLIG_YOSYS = "${synlig}/bin/yosys";
    CONTRACTGEN_RESOURCE_ROOT = resources.all;
    CONTRACT_SPIKE_LIB = "${tools.spike}/lib/libcontract_spike_atom.so";
    LD_LIBRARY_PATH = "${native}/lib";
    JAVA_TOOL_OPTIONS = "-Djna.boot.library.path=${native}/lib -Djava.library.path=${native}/lib";
    shellHook = ''
      contractgen_maven_repo="''${CONTRACTGEN_MAVEN_REPO:-''${XDG_CACHE_HOME:-$HOME/.cache}/contractgen/maven-repository}"
      contractgen_maven_settings="''${TMPDIR:-/tmp}/contractgen-maven-settings-$UID.xml"
      mkdir -p "$contractgen_maven_repo"
      cp -r --no-preserve=mode ${java.fetchedMavenDeps}/.m2/. "$contractgen_maven_repo/"
      chmod -R u+w "$contractgen_maven_repo"
      cat > "$contractgen_maven_settings" <<EOF
<settings>
  <localRepository>$contractgen_maven_repo</localRepository>
  <offline>true</offline>
</settings>
EOF
      export MAVEN_ARGS="--offline --settings=$contractgen_maven_settings ''${MAVEN_ARGS:-}"
      export CONTRACTGEN_MAVEN_REPO="$contractgen_maven_repo"
      unset contractgen_maven_repo contractgen_maven_settings
    '';
  };
  checks = import ./checks.nix { inherit pkgs java native tools attackers application resources; };
}
