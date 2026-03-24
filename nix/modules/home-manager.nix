{self}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkPackageOption;

  cfg = config.programs.rad;
in {
  options.programs.rad = {
    enable = mkEnableOption "Radius CLI";

    package = mkPackageOption self.packages.${pkgs.stdenv.hostPlatform.system} "rad" {
      default = "default";
      pkgsText = "radius-flake.packages.\${pkgs.stdenv.hostPlatform.system}";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [cfg.package];
  };
}
