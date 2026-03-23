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
  inputs.radius-flake.url = "github:<owner>/radius-flake";

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

## Install From `rc`

The `rc` branch changes only the default aliases. Its default package points to the latest RC:

```nix
{
  inputs.radius-flake.url = "github:<owner>/radius-flake/rc";
}
```

Then use either:

```nix
radius-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
```

or:

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

## Overlay Usage

```nix
{
  nixpkgs.overlays = [ radius-flake.overlays.default ];
}
```

This exposes `pkgs.rad`, `pkgs.rad-rc`, and `pkgs.bicep`.

## Notes

- Supported systems in the first iteration are `x86_64-linux` and `aarch64-linux`.
- Bicep is bundled as a separate package and wired into `rad` with `BICEP`.
- This repository does not add a Home Manager module in the first iteration.
