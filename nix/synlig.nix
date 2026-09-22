{ pkgs, inputs }:
pkgs.stdenv.mkDerivation {
  pname = "synlig";
  version = "2023-06-30-eceb24b";
  src = inputs.synlig-src;
  nativeBuildInputs = with pkgs; [
    cmake gnumake pkg-config
    (python3.withPackages (p: with p; [ orderedmultidict psutil ]))
    jdk21_headless bison flex git
  ];
  buildInputs = with pkgs; [ readline libffi tcl zlib gmp boost ];
  dontUseCmakeConfigure = true;
  dontConfigure = true;
  dontMoveLib64 = true;
  postPatch = ''
    cp -r ${inputs.synlig-surelog-src}/. Surelog/
    cp -r ${inputs.synlig-yosys-src}/. yosys/
    cp -r ${inputs.synlig-abc-src}/. yosys/abc/
    cp -r ${inputs.synlig-plugins-src}/. yosys-f4pga-plugins/
    chmod -R u+w Surelog yosys yosys-f4pga-plugins
    echo 1de4eaf > yosys/abc/.gitcommit
    # CMake 4 removed policy compatibility below 3.5.  The bundled Cap'n
    # Proto project predates that change but configures correctly with the 3.5
    # policy floor recommended by CMake.
    sed -i '1s/VERSION [^)]*/VERSION 3.5/' \
      Surelog/third_party/UHDM/third_party/capnproto/CMakeLists.txt
    grep -q 'cmake_minimum_required(VERSION 3.5)' \
      Surelog/third_party/UHDM/third_party/capnproto/CMakeLists.txt
    patchShebangs .
    substituteInPlace build_binaries.sh \
      --replace-fail 'make -C $PWD/yosys-f4pga-plugins/ install -j$(nproc)' \
      'make -C $PWD/yosys-f4pga-plugins/ install_systemverilog -j$(nproc)'
    substituteInPlace build_binaries.sh --replace-fail '$(nproc)' "$NIX_BUILD_CORES"
    substituteInPlace build_binaries.sh \
      --replace-fail 'cmake -DCMAKE_BUILD_TYPE=Release' \
      'cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release'
    substituteInPlace yosys-f4pga-plugins/Makefile_plugin.common \
      --replace-fail 'SHELL := /usr/bin/env bash' 'SHELL := ${pkgs.bash}/bin/bash'
    substituteInPlace yosys/misc/yosys-config.in \
      --replace-fail '#!/usr/bin/env bash' '#!${pkgs.bash}/bin/bash'
  '';
  buildPhase = ''
    runHook preBuild
    export INSTALL_PATH=$out
    export YOSYS_PATH=$out
    export PLUGIN_ASAN=0
    export CASTOR=0
    bash build_binaries.sh
    runHook postBuild
  '';
  dontInstall = true;
}
