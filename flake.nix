{
  description = "srvc-hello";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      with import nixpkgs { system = system; };
      let
        ps = python310Packages;
        spacy-en-core-web-sm = ps.buildPythonPackage rec {
          pname = "en_core_web_sm";
          version = "3.3.0";

          src = fetchTarball {
            url =
              "https://github.com/explosion/spacy-models/releases/download/${pname}-${version}/${pname}-${version}.tar.gz";
            sha256 =
              "sha256:0jf5rjmca8ybizd780y2x61m1d7sipc57bafrp1qzgxgp0yi1llq";
          };

          propagatedBuildInputs = [ ps.spacy ];
        };
        spacy-en-core-web-lg = ps.buildPythonPackage rec {
          pname = "en_core_web_lg";
          version = "3.3.0";

          src = fetchTarball {
            url =
              "https://github.com/explosion/spacy-models/releases/download/${pname}-${version}/${pname}-${version}.tar.gz";
            sha256 =
              "sha256:1wawkq0glm99jvlycn5z64621i25b02irlddjy8dg5pkra8pnmb5";
          };

          propagatedBuildInputs = [ ps.spacy ];
        };
      in {
        packages = {
          spacy = stdenv.mkDerivation {
            name = "srvc-hello-spacy";
            src = ./src;
            buildInputs =
              [ ps.spacy spacy-en-core-web-sm spacy-en-core-web-lg ];
            installPhase = ''
              mkdir -p $out/bin
              cp spacy-ner.py $out/bin/srvc-hello-spacy
            '';
          };
        };
      });
}
