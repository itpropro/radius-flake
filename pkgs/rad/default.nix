{
  lib,
  symlinkJoin,
  makeWrapper,
  source,
  bicep,
  radUnwrapped,
}:
symlinkJoin {
  name = "rad-${source.version}";
  paths = [radUnwrapped];
  nativeBuildInputs = [makeWrapper];

  postBuild = ''
    wrapProgram $out/bin/rad \
      --set BICEP ${bicep}/bin/bicep
  '';

  passthru = {
    inherit bicep;
    unwrapped = radUnwrapped;
  };

  meta =
    radUnwrapped.meta
    // {
      description = "Radius CLI with Bicep wired via BICEP";
    };
}
