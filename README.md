# radius-flake

Standalone Nix flake for the `rad` CLI from `radius-project/radius`.

## What It Provides

- stable `rad` package bound to the latest supported stable Radius tag on `main`
- `rad-rc` package bound to the latest supported Radius prerelease tag on `main`
- wrapped `rad` binaries that expose Bicep through `BICEP`
- an overlay for consumers that prefer overlay-based package access

## Install From `main`

Use the stable package:

```nix
{
  inputs.radius-flake.url = "github:itpropro/radius-flake";

  outputs = { nixpkgs, radius-flake, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            radius-flake.packages.${pkgs.stdenv.hostPlatform.system}.rad
          ];
        })
      ];
    };
  };
}
```

Or use the RC package from `main`:

```nix
radius-flake.packages.${pkgs.stdenv.hostPlatform.system}."rad-rc"
```

## Commands

```bash
nix build .#rad
nix build .#rad-rc
nix run .#rad -- --help
nix run .#rad-rc -- --help
```

## Home Manager Usage

Import the module from this flake and enable `rad`:

```nix
{ ... }: {
  imports = [ radius-flake.homeManagerModules.default ];

  programs.rad.enable = true;
}
```

The module installs this flake's default package, which is stable `rad`.

To use the RC package explicitly from `main`, override the package:

```nix
{ pkgs, ... }: {
  imports = [ radius-flake.homeManagerModules.default ];

  programs.rad = {
    enable = true;
    package = radius-flake.packages.${pkgs.stdenv.hostPlatform.system}."rad-rc";
  };
}
```

## Overlay Usage

```nix
{
  nixpkgs.overlays = [ radius-flake.overlays.default ];
}
```

This exposes `pkgs.rad`, `pkgs.rad-rc`, and `pkgs.bicep`.

## Notes

- Supported systems in the first iteration are `x86_64-linux` and `aarch64-linux`.
- CI publishes build outputs to the public Cachix cache at `https://itpropro.cachix.org`.
- Bicep is bundled as a separate package and wired into `rad` with `BICEP`.
- The Home Manager module only installs the wrapped CLI package and exposes a package override.
