{ pkgs, inputs }:
let
  sbt = pkgs.sbt.override { jre = pkgs.jdk8; };
  prepare = ''
    mkdir -p src/main/scala/contractgen/proteus project
    cp ${../src/main/resources/proteus-test/generator/ProteusContractCore.scala} src/main/scala/contractgen/proteus/ProteusContractCore.scala
    echo 'sbt.version=${sbt.version}' > project/build.properties
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
  '';
  settings = cache: ''
    export COURSIER_CACHE=${cache}/coursier
    export SBT_OPTS="-Dsbt.boot.directory=${cache}/boot -Dsbt.ivy.home=${cache}/ivy -Dsbt.global.base=${cache}/global -Dsbt.supershell=false"
  '';
  dependencies = pkgs.stdenvNoCC.mkDerivation {
    pname = "proteus-sbt-dependencies";
    version = "0f489fc";
    src = inputs.proteus-src;
    nativeBuildInputs = [ sbt pkgs.cacert ];
    buildPhase = prepare + settings "$out" + ''
      sbt -batch compile
    '';
    installPhase = ''
      find $out -type f \( -name '*.lock' -o -name '*.log' \) -delete
      rm -rf $out/global/streams $out/global/target
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-A10RWK4eaK4Fgl+NaI4fUkBaBhKVV/LJochdrpDNTwM=";
  };
in pkgs.stdenvNoCC.mkDerivation {
  pname = "proteus-rtl";
  version = "0f489fc";
  src = inputs.proteus-src;
  nativeBuildInputs = [ sbt ];
  patches = [ ./proteus-java8.patch ];
  buildPhase = prepare + ''
    cp -r ${dependencies} cache
    chmod -R u+w cache
  '' + settings "$PWD/cache" + ''
    sbt -batch 'set offline := true' 'runMain contractgen.proteus.ProteusContractCoreGenerator generated'
  '';
  installPhase = ''
    mkdir -p $out
    cp generated/ProteusContractCore.v $out/
    cd $out
    sha256sum ProteusContractCore.v > ProteusContractCore.v.sha256
  '';
  passthru = { inherit dependencies; };
}
