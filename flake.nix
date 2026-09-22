{
  description = "Contract synthesis for RISC-V (x86-64 Linux)";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    verilator-src = { url = "github:verilator/verilator/v5.008"; flake = false; };
    yosys-src = { url = "git+https://github.com/YosysHQ/yosys?ref=refs/tags/v0.59&submodules=1"; flake = false; };
    spike-src = { url = "github:camalouu/riscv-isa-sim/28893f6bfd8ce1659919a8dabdae8ce3db4a11a6"; flake = false; };
    ibex-src = { url = "github:lowRISC/ibex/95b85ddd1c995ace9f89ee42530f9e24820c1051"; flake = false; };
    hazard3-src = { url = "git+https://github.com/Wren6991/Hazard3?rev=8af992930f71a69b0e06c38734c1094f41a05ca0&submodules=1"; flake = false; };
    cva6-src = { url = "git+https://github.com/openhwgroup/cva6?rev=2ef1c1b1fca419354920c5487293bc605294904e&submodules=1"; flake = false; };
    cva6-legacy-src = { url = "git+https://github.com/openhwgroup/cva6?rev=853fb4bee5ca6e36e39dc3c272a97f49d95c3c1d&submodules=1"; flake = false; };
    fwrisc-src = { url = "github:featherweight-ip/fwrisc/0e21466336c9d611c2b465dcb0de04572b6ebbcf"; flake = false; };
    cv32e40p-src = { url = "github:openhwgroup/cv32e40p/360d272898d81806be3377193870dbf83a3ea79f"; flake = false; };
    cv32e40s-src = { url = "github:openhwgroup/cv32e40s/d45d7b4c02a353d093de3efdf0569486d9a506c5"; flake = false; };
    synlig-src = { url = "github:chipsalliance/synlig/2023-06-30-eceb24b"; flake = false; };
    synlig-surelog-src = { url = "git+https://github.com/chipsalliance/Surelog?rev=bf13c8316ededdad863c35826d804493001d1b37&submodules=1"; flake = false; };
    synlig-yosys-src = { url = "git+https://github.com/YosysHQ/yosys?rev=8b2a0010216f9a15c09bd2f4dc63691949b126df&submodules=1"; flake = false; };
    synlig-abc-src = { url = "github:YosysHQ/abc/1de4eaf"; flake = false; };
    synlig-plugins-src = { url = "git+https://github.com/chipsalliance/yosys-f4pga-plugins?rev=73038124b0a2943fe9d591c43f46292bcbf82105&submodules=1"; flake = false; };
    proteus-src = { url = "github:proteus-core/proteus/0f489fc5cfddabca93ae01880374385fcb649660"; flake = false; };
  };
  outputs = inputs@{ self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      project = import ./nix { inherit pkgs inputs; };
    in {
      packages.${system} = project.packages;
      apps.${system}.default = { type = "app"; program = "${project.packages.default}/bin/contractgen"; };
      devShells.${system}.default = project.shell;
      checks.${system} = project.checks;
    };
}
