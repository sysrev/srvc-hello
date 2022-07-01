{ sources ? import ./nix/sources.nix, pkgs ? import sources.nixpkgs { } }:
let
  jdk = pkgs.openjdk17;
  ps = pkgs.python310Packages;
  spacy-en-core-web-sm = ps.buildPythonPackage rec {
    pname = "en_core_web_sm";
    version = "3.3.0";

    src = fetchTarball {
      url = "https://github.com/explosion/spacy-models/releases/download/${pname}-${version}/${pname}-${version}.tar.gz";
      sha256 = "sha256:0jf5rjmca8ybizd780y2x61m1d7sipc57bafrp1qzgxgp0yi1llq";
    };

    propagatedBuildInputs = [ ps.spacy ];
  };
in with pkgs;
mkShell {
  buildInputs = [
    babashka
    jdk
    ps.spacy
    rlwrap
    spacy-en-core-web-sm
  ];
}
