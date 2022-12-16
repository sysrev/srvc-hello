{
  description = "srvc-hello";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    flake-utils.url = "github:numtide/flake-utils";
    pypi-deps-db = {
      url = "github:DavHau/pypi-deps-db";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.mach-nix.follows = "mach-nix";
    };
    mach-nix = {
      url = "github:DavHau/mach-nix/3.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.pypi-deps-db.follows = "pypi-deps-db";
    };
  };
  outputs = { self, nixpkgs, flake-utils, mach-nix, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      with import nixpkgs { inherit system; };
      let
        mach = import mach-nix {
          inherit pkgs;
          pypiDataRev = "e9571cac25d2f509e44fec9dc94a3703a40126ff";
          pypiDataSha256 =
            "sha256:1rbb0yx5kjn0j6lk0ml163227swji8abvq0krynqyi759ixirxd5";
        };
        reqs = builtins.readFile ./requirements.txt;
        spacy-en-core-web-sm = mach.buildPythonPackage rec {
          pname = "en_core_web_sm";
          version = "3.4.0";

          src = fetchTarball {
            url =
              "https://github.com/explosion/spacy-models/releases/download/${pname}-${version}/${pname}-${version}.tar.gz";
            sha256 =
              "sha256:0fq0ijja5p0qklh0c4z527kgck0ipsyhqvpicah7ii20666wn7vm";
          };
          requirements = reqs;
        };
        spacy-en-core-web-lg = mach.buildPythonPackage rec {
          pname = "en_core_web_lg";
          version = "3.4.0";

          src = fetchTarball {
            url =
              "https://github.com/explosion/spacy-models/releases/download/${pname}-${version}/${pname}-${version}.tar.gz";
            sha256 =
              "sha256:19b114g1m52kpvrlz1m6ywd6hghbq0wxb6lny9q83b44rx5499nh";
          };
          requirements = reqs;
        };
        spacy-python = mach.mkPython {
          requirements = reqs;
          packagesExtra = [ spacy-en-core-web-sm spacy-en-core-web-lg ];
        };
        spacy = stdenv.mkDerivation {
          pname = "spacy";
          version = "0.1.0";
          src = ./src;
          buildInputs = [ spacy-python ];
          installPhase = ''
            mkdir -p $out/bin
            cp spacy-ner.py $out/bin/spacy
          '';
        };
      in { packages = { inherit spacy spacy-python; }; });
}
