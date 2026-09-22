{ pkgs, resources, synlig }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "cva6-verilog";
  version = "853fb4b";
  src = resources.assemble [ "cva6" ];
  nativeBuildInputs = [ pkgs.bash pkgs.patch pkgs.haskellPackages.sv2v synlig ];
  dontUnpack = true;
  dontConfigure = true;
  buildPhase = ''
    cp -rL $src/cva6 source
    chmod -R u+w source
    bash source/generate-verilog.sh "$PWD/source" "$PWD/generated"
  '';
  installPhase = ''
    mkdir -p $out
    cp generated/cva6.v $out/
  '';
}
