{
  description = "Standalone Nix flake for the Radius rad CLI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    lib = nixpkgs.lib;
    defaultChannel = "stable";
    systems = import ./nix/systems.nix;
    forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system} system);
  in {
    packages = forAllSystems (
      pkgs: system:
        import ./default.nix {
          inherit pkgs system defaultChannel;
        }
    );

    apps = forAllSystems (
      _pkgs: system: let
        packages = self.packages.${system};
        mkApp = package: {
          type = "app";
          program = "${package}/bin/rad";
        };
      in {
        default = mkApp packages.default;
        rad = mkApp packages.rad;
        "rad-rc" = mkApp packages."rad-rc";
      }
    );

    overlays.default = final: _prev:
      import ./default.nix {
        pkgs = final;
        system = final.stdenv.hostPlatform.system;
        inherit defaultChannel;
      };

    formatter = forAllSystems (pkgs: _system: pkgs.alejandra);

    checks = forAllSystems (
      pkgs: system: let
        packages = self.packages.${system};
      in {
        rad = packages.rad;
        "rad-rc" = packages."rad-rc";
        smoke-help =
          pkgs.runCommand "rad-help" {
            nativeBuildInputs = [packages.rad];
          } ''
            ${packages.rad}/bin/rad --help >/dev/null
            touch $out
          '';
      }
    );
  };
}
