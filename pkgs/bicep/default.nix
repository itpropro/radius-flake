{
  autoPatchelfHook,
  lib,
  icu,
  openssl,
  stdenv,
  stdenvNoCC,
  fetchurl,
  source,
}: let
  inherit (source) version;
  releases = {
    x86_64-linux = {
      asset = "bicep-linux-x64";
      hash = source.hashes."x86_64-linux";
    };
    aarch64-linux = {
      asset = "bicep-linux-arm64";
      hash = source.hashes."aarch64-linux";
    };
    aarch64-darwin = {
      asset = "bicep-osx-arm64";
      hash = source.hashes."aarch64-darwin";
    };
  };
  release =
    releases.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system for bicep: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation {
    pname = "bicep";
    inherit version;

    src = fetchurl {
      url = "https://github.com/Azure/bicep/releases/download/v${version}/${release.asset}";
      hash = release.hash;
    };

    dontUnpack = true;
    dontStrip = true;

    nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [autoPatchelfHook];
    buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [stdenv.cc.cc.lib];
    runtimeDependencies = lib.optionals stdenvNoCC.hostPlatform.isLinux [
      icu
      (lib.getLib openssl)
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/bicep
      runHook postInstall
    '';

    meta = {
      description = "Domain Specific Language for deploying Azure resources declaratively";
      homepage = "https://github.com/Azure/bicep";
      changelog = "https://github.com/Azure/bicep/releases/tag/v${version}";
      license = lib.licenses.mit;
      mainProgram = "bicep";
      platforms = builtins.attrNames releases;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
