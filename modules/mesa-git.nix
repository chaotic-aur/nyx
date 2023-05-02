{ inputs }: { config, lib, pkgs, ... }:
let
  cfg = config.chaotic.mesa-git;

  replacement = { original = pkgs.mesa; replacement = pkgs.mesa_git; };
in
{
  options = {
    chaotic.mesa-git.enable =
      lib.mkOption {
        default = false;
        description = ''
          Whether to use latest Mesa drivers.

          NOTE: Since Mesa 23.0+ loaders prohibit verison mixing, you'll now need `--impure`.
        '';
      };
  };

  config = {
    system.replaceRuntimeDependencies = lib.mkIf cfg.enable [ replacement ];

    hardware.opengl = lib.mkIf cfg.enable {
      package = pkgs.mesa_git.drivers;
      package32 = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isx86) pkgs.mesa32_git.drivers;
      extraPackages = [ pkgs.mesa_git.opencl ];
    };

    specialisation.stable-mesa = lib.mkIf cfg.enable {
      configuration = {
        system.nixos.tags = [ "stable-mesa" ];
        hardware.opengl.package = lib.mkForce pkgs.mesa.drivers;
        hardware.opengl.package32 = lib.mkForce pkgs.pkgsi686Linux.mesa.drivers;
        system.replaceRuntimeDependencies = lib.mkForce [ ];
      };
    };
  };
}
