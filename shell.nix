{ sources ? import ./nix/sources.nix, pkgs ? import sources.nixpkgs { } }:
let
  ps = pkgs.python310Packages;
  spacy-en-core-web-sm = ps.buildPythonPackage rec {
    pname = "en_core_web_sm";
    version = "3.4.0";

    src = fetchTarball {
      url =
        "https://github.com/explosion/spacy-models/releases/download/${pname}-${version}/${pname}-${version}.tar.gz";
      sha256 = "sha256:0fq0ijja5p0qklh0c4z527kgck0ipsyhqvpicah7ii20666wn7vm";
    };

    propagatedBuildInputs = [ ps.spacy ];
  };
  spacy-en-core-web-lg = ps.buildPythonPackage rec {
    pname = "en_core_web_lg";
    version = "3.4.0";

    src = fetchTarball {
      url =
        "https://github.com/explosion/spacy-models/releases/download/${pname}-${version}/${pname}-${version}.tar.gz";
      sha256 = "sha256:19b114g1m52kpvrlz1m6ywd6hghbq0wxb6lny9q83b44rx5499nh";
    };

    propagatedBuildInputs = [ ps.spacy ];
  };
in with pkgs;
mkShell {
  buildInputs = [
    ps.spacy
    spacy-en-core-web-sm
    spacy-en-core-web-lg
    srvc
  ];
}
