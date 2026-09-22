{ pkgs, inputs }:
let
  inherit (pkgs) lib;
  upstream = {
    "ibex/core" = inputs.ibex-src;
    "ibex-test/core" = inputs.ibex-src;
    "hazard3/core" = inputs.hazard3-src;
    "cva6/core" = inputs.cva6-legacy-src;
    "cva6/cva6" = inputs.cva6-src;
    "fwrisc-test/core" = inputs.fwrisc-src;
    "cv32e40p-test/core" = inputs.cv32e40p-src;
    "cv32e40s-test/core" = inputs.cv32e40s-src;
  };
  localSource = name: builtins.path {
    path = ../src/main/resources + "/${name}";
    name = "contractgen-${name}-resources";
    filter = path: type:
      let base = baseNameOf path;
      in path == toString (../src/main/resources + "/${name}") || !(builtins.elem base [ ".git" "obj_dir" "obj_dir_shared" "compiled" "simulation" "target" ])
        && !(builtins.hasAttr "${name}/${base}" upstream && type == "directory")
        && !(lib.hasSuffix ".vcd" base || lib.hasSuffix ".log" base || lib.hasSuffix ".so" base);
  };
  assemble = names: pkgs.runCommand "contractgen-resources-${lib.concatStringsSep "-" names}" {} (
    "mkdir -p $out\n" + lib.concatMapStringsSep "\n" (name: ''
      mkdir -p $out/${name}
      cp -rL ${localSource name}/. $out/${name}/
    '' + lib.concatStringsSep "\n" (lib.mapAttrsToList (path: source:
      lib.optionalString (lib.hasPrefix "${name}/" path) ''
        mkdir -p $out/${path}
        # Flake inputs can contain repository symlinks whose targets are not
        # part of the checkout (CVA6 has optional boot-ROM build products of
        # this kind).  Copy the fetched tree into this resource artifact and
        # omit only those dangling links. Valid relative links remain internal
        # to the materialized tree and are dereferenced by writable consumers.
        cp -r --no-preserve=mode ${source}/. $out/${path}/
        find $out/${path} -xtype l -delete
      '') upstream)) names
  );
  names = [ "ibex" "ibex-test" "cva6" "cva6-test" "hazard3" "hazard3-test"
    "proteus-test" "sodor-2" "sodor-5" "sodor-test" "darkriscv-2" "darkriscv-3"
    "darkriscv-test" "fwrisc-test" "cv32e40p-test" "cv32e40s-test" "attacker-test-common" "simple" ];
in { inherit assemble; all = assemble names; }
