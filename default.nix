{ sources ? import ./nix/sources.nix, pkgs ? import sources.nixpkgs { } }:
let
  srvc = pkgs.rustPlatform.buildRustPackage rec {
    pname = "srvc";
    version = "0.6.0";

    src = pkgs.fetchFromGitHub {
      owner = "insilica";
      repo = "rs-srvc";
      rev = "v${version}";
      sha256 = "sha256-PBs86cvEacvCt/2JnURL4qKvXGXRZHWaGYrPUSsnt0I=";
    };

    cargoSha256 = "sha256-5CUbfI67gsINdHcxN8KbIN10Mu90rAU53DbmQ5QotWg=";
  };
  ps = pkgs.python310Packages;
  spacy-en-core-web-sm = ps.buildPythonPackage rec {
    pname = "en_core_web_sm";
    version = "3.3.0";

    src = fetchTarball {
      url =
        "https://github.com/explosion/spacy-models/releases/download/${pname}-${version}/${pname}-${version}.tar.gz";
      sha256 = "sha256:0jf5rjmca8ybizd780y2x61m1d7sipc57bafrp1qzgxgp0yi1llq";
    };

    propagatedBuildInputs = [ ps.spacy ];
  };
  spacy-en-core-web-lg = ps.buildPythonPackage rec {
    pname = "en_core_web_lg";
    version = "3.3.0";

    src = fetchTarball {
      url =
        "https://github.com/explosion/spacy-models/releases/download/${pname}-${version}/${pname}-${version}.tar.gz";
      sha256 = "sha256:1wawkq0glm99jvlycn5z64621i25b02irlddjy8dg5pkra8pnmb5";
    };

    propagatedBuildInputs = [ ps.spacy ];
  };
in with pkgs;
mkShell {
  buildInputs =
    [ babashka ps.spacy rlwrap spacy-en-core-web-sm spacy-en-core-web-lg srvc ];
}
