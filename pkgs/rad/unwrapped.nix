{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  source,
}: let
  release = lib.removePrefix "v" source.rev;
  channel =
    if lib.hasInfix "-" release
    then release
    else builtins.head (builtins.match "([0-9]+\\.[0-9]+)\\..*" release);
  versionPackage = "github.com/radius-project/radius/pkg/version";
in
  buildGo126Module {
    pname = "rad-unwrapped";
    inherit (source) version;

    src = fetchFromGitHub {
      owner = "radius-project";
      repo = "radius";
      inherit (source) rev;
      hash = source.srcHash;
    };

    subPackages = ["cmd/rad"];
    vendorHash = source.vendorHash;
    ldflags = [
      "-s"
      "-w"
      "-X"
      "${versionPackage}.channel=${channel}"
      "-X"
      "${versionPackage}.commit=${source.commit}"
      "-X"
      "${versionPackage}.release=${release}"
      "-X"
      "${versionPackage}.version=${source.rev}"
    ];

    meta = {
      description = "Radius CLI";
      homepage = "https://radius.dev";
      changelog = "https://github.com/radius-project/radius/releases/tag/${source.rev}";
      license = lib.licenses.asl20;
      mainProgram = "rad";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  }
