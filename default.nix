{
  pkgs ? import <nixpkgs> {},
  system ? pkgs.stdenv.hostPlatform.system,
  defaultChannel ? "stable",
}: let
  sources = builtins.fromJSON (builtins.readFile ./nix/sources.json);

  mkRadPackages = source: rec {
    unwrapped = pkgs.callPackage ./pkgs/rad/unwrapped.nix {
      inherit source;
    };

    wrapped = pkgs.callPackage ./pkgs/rad/default.nix {
      inherit source;
      bicep = bicep;
      radUnwrapped = unwrapped;
    };
  };

  bicep = pkgs.callPackage ./pkgs/bicep/default.nix {};
  stable = mkRadPackages sources.stable;
  rc = mkRadPackages sources.rc;
  defaultPackage =
    if defaultChannel == "rc"
    then rc.wrapped
    else stable.wrapped;
in {
  inherit bicep;
  rad = stable.wrapped;
  rad-unwrapped = stable.unwrapped;
  "rad-rc" = rc.wrapped;
  "rad-rc-unwrapped" = rc.unwrapped;
  default = defaultPackage;
}
