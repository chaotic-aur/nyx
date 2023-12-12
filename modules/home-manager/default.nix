fromFlakes:
let
  modulesPerFile = {
    nyx-cache = import ./nyx-cache.nix fromFlakes;
    nyx-overlay = import ../common/nyx-overlay.nix fromFlakes;
  };

  default = { ... }: {
    imports = builtins.attrValues modulesPerFile;
  };
in
modulesPerFile // { inherit default; }
