{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  source,
}:
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
  ldflags = ["-s" "-w"];

  meta = {
    description = "Radius CLI";
    homepage = "https://radius.dev";
    changelog = "https://github.com/radius-project/radius/releases/tag/${source.rev}";
    license = lib.licenses.asl20;
    mainProgram = "rad";
    platforms = ["x86_64-linux" "aarch64-linux"];
  };
}
