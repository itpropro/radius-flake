{
  description = "Standalone Nix flake for the Radius rad CLI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    lib = nixpkgs.lib;
    defaultChannel = "stable";
    sources = builtins.fromJSON (builtins.readFile ./nix/sources.json);
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

    homeManagerModules = let
      rad = import ./nix/modules/home-manager.nix {inherit self;};
    in {
      default = rad;
      inherit rad;
    };

    formatter = forAllSystems (pkgs: _system: pkgs.alejandra);

    checks = forAllSystems (
      pkgs: system: let
        packages = self.packages.${system};
        homeModule = self.homeManagerModules.default;
        evalHomeModule = config:
          lib.evalModules {
            modules = [
              homeModule
              {
                options.home.packages = lib.mkOption {
                  type = lib.types.listOf lib.types.package;
                  default = [];
                };

                config = config;
              }
            ];

            specialArgs = {
              inherit pkgs;
            };
          };
      in {
        smoke-version =
          pkgs.runCommand "rad-version" {
            nativeBuildInputs = [packages.rad pkgs.jq];
          } ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"

            version_json="$(${packages.rad}/bin/rad version --cli --output json)"

            if ! printf '%s' "$version_json" | jq -e --arg release '${sources.stable.version}' --arg version '${sources.stable.rev}' --arg commit '${sources.stable.commit}' '.release == $release and .version == $version and .commit == $commit' >/dev/null; then
              printf 'Unexpected version output:\n%s\n' "$version_json" >&2
              exit 1
            fi

            touch $out
          '';
        smoke-version-rc =
          pkgs.runCommand "rad-version-rc" {
            nativeBuildInputs = [packages."rad-rc" pkgs.jq];
          } ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"

            version_json="$(${packages."rad-rc"}/bin/rad version --cli --output json)"

            if ! printf '%s' "$version_json" | jq -e --arg release '${sources.rc.version}' --arg version '${sources.rc.rev}' --arg commit '${sources.rc.commit}' '.release == $release and .version == $version and .commit == $commit' >/dev/null; then
              printf 'Unexpected RC version output:\n%s\n' "$version_json" >&2
              exit 1
            fi

            touch $out
          '';
        smoke-home-manager-default = let
          eval = evalHomeModule {
            programs.rad.enable = true;
          };
        in
          assert builtins.length eval.config.home.packages == 1;
            pkgs.runCommand "rad-home-manager-default" {} ''
              test "${builtins.elemAt eval.config.home.packages 0}" = "${packages.rad}"
              touch $out
            '';
        smoke-home-manager-rc-override = let
          eval = evalHomeModule {
            programs.rad.enable = true;
            programs.rad.package = packages."rad-rc";
          };
        in
          assert builtins.length eval.config.home.packages == 1;
            pkgs.runCommand "rad-home-manager-rc-override" {} ''
              test "${builtins.elemAt eval.config.home.packages 0}" = "${packages."rad-rc"}"
              touch $out
            '';
      }
    );
  };
}
