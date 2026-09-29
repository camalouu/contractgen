{ pkgs, inputs }:
let
  verilator = pkgs.verilator.overrideAttrs (old: {
    version = "5.008";
    VERILATOR_SRC_VERSION = "v5.008";
    src = inputs.verilator-src;
    patches = [];
    postPatch = ''patchShebangs bin test_regress'';
    doCheck = false;
  });
  yosys = pkgs.yosys.overrideAttrs (old: {
    version = "0.59";
    src = inputs.yosys-src;
    patches = [];
    postPatch = ''
      patchShebangs tests misc/yosys-config.in
      # Git flakes retain the recursively fetched ABC tree but intentionally
      # omit its .git metadata.  Give Yosys the exact gitlink revision so its
      # release-source guard accepts the bundled ABC checkout.
      echo 1c5ed1ce378cc04beac30bb31abc4c37c8467042 > abc/.gitcommit
    '';
    # Nixpkgs 25.11 enables the current Pyosys/uv build.  Yosys 0.59 predates
    # that build path, and the command-line binary used by sby does not need
    # the Python module.
    preBuild = ''
      chmod -R u+w .
      make config-gcc
      grep -q "YOSYS_VER := $version" Makefile
    '';
    doCheck = false;
  });
  spike = pkgs.stdenv.mkDerivation {
    pname = "contract-spike";
    version = "28893f6";
    src = inputs.spike-src;
    nativeBuildInputs = with pkgs; [ autoconf automake libtool pkg-config ];
    buildInputs = with pkgs; [ boost gmp dtc ];
    preConfigure = ''mkdir build; cd build; configureScript=../configure'';
    # This fork carries an older Autoconf macro which probes for the C `exit`
    # symbol inside libboost_regex when no exact name is supplied.  Naming the
    # library selects the macro's working link test instead.
    configureFlags = [ "--with-boost-regex=boost_regex" ];
    env.CXXFLAGS = "-O2 -fPIC";
    env.CFLAGS = "-O2 -fPIC";
    buildFlags = [ "all" "libcontract_spike_atom.so" ];
    enableParallelBuilding = true;
    postInstall = ''install -Dm755 libcontract_spike_atom.so $out/lib/libcontract_spike_atom.so'';
  };
  iverilog = pkgs.iverilog.overrideAttrs (old: {
    version = "14.0-devel-5591c2d";
    src = inputs.iverilog-src;
    patches = [];
    doCheck = false;
    doInstallCheck = false;
  });
in {
  inherit verilator yosys spike iverilog;
  simulation = with pkgs; [ bash coreutils findutils gnugrep gnused gawk diffutils patch
    perl python3 gcc gnumake haskellPackages.sv2v verilator ];
  runtime = (with pkgs; [ bash coreutils findutils gnugrep gnused gawk diffutils patch
    perl python3 gcc gnumake haskellPackages.sv2v sby yices z3 ]) ++ [ iverilog verilator yosys ];
}
