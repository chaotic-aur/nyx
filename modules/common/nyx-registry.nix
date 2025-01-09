{ flakes }: { config, lib, ... }:
let
  registryCfg = config.chaotic.nyx.registry;
  pathCfg = config.chaotic.nyx.nixPath;
in
{
  options = with lib; {
    chaotic.nyx = {
      registry.enable =
        mkOption {
          default = true;
          example = false;
          type = types.bool;
          description = ''
            Whether to add Chaotic-Nyx to `nix.registry`.
          '';
        };
      nixPath.enable =
        mkOption {
          default = true;
          example = false;
          type = types.bool;
          description = ''
            Whether to add Chaotic-Nyx to `nix.nixPath`.
          '';
        };
    };
  };
  config = {
    nix.nixPath = lib.lists.optionals registryCfg.enable [
      "chaotic=${flakes.self}"
    ];
    nix.registry = lib.mkIf pathCfg.enable {
      chaotic.flake.path = flakes.self;
    };
  };
}
