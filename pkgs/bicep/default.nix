{
  lib,
  stdenvNoCC,
  fetchurl,
}: let
  version = "0.41.2";
  releases = {
    x86_64-linux = {
      asset = "bicep-linux-x64";
      hash = "sha256-z+UlMvd9nRgzKffpSn/JJooY19nbqp7CjWMnNM2/1Y4=";
    };
    aarch64-linux = {
      asset = "bicep-linux-arm64";
      hash = "sha256-b647nzGYUDH5GWVT0vEieZ3aFzr7gidwrmQ1if70nQo=";
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
