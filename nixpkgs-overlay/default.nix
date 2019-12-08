self: super:

with super;
let
  gitsrc = name: fetchgit {
    inherit (builtins.fromJSON (builtins.readFile (./. + "/${name}.json"))) url rev sha256 fetchSubmodules leaveDotGit;
    inherit name;
  };

  extraOcamlPackages = with ocamlPackages; {
    sedlex = buildDunePackage {
      pname = "sedlex";
      version = "2.1";
      src = fetchzip {
        url = "https://github.com/ocaml-community/sedlex/archive/v2.1.zip";
        sha256 = "05f6qa8x3vhpdz1fcnpqk37fpnyyq13icqsk2gww5idjnh6kng26";
      };

      propagatedBuildInputs = [ gen ppx_tools_versioned ];
    };

    sha = buildDunePackage {
      pname = "sha";
      version = "1.12";
      src = fetchzip {
        url = "https://github.com/djs55/ocaml-sha/releases/download/v1.12/sha-1.12.tbz";
        sha256 = "063pbpghlhpx49z524cnqjdn6prkrl76c7pmn3c1x1h2x64c4kry";
      };

      propagatedBuildInputs = [ ];
    };
  };

in
{
  ocamlPackages = ocamlPackages // extraOcamlPackages;

  haxe_4_nightly = haxe.overrideAttrs (old: {
    version = "4.1.0-nightly";
    src = gitsrc "haxe";

    buildInputs =
      [ git neko pcre zlib ] ++
      (with self.ocamlPackages; [
        dune findlib
        ocaml
        camlp5
        sedlex
        ppx_tools_versioned
        xml-light
        ocaml_extlib
        ptmap
        sha
      ] );

    prePatch = ''
      sed -i -e 's|/usr/local|'"$out"'|g' Makefile
      sed -i -e 's|"neko"|"${neko}/bin/neko"|g' extra/haxelib_src/src/haxelib/client/Main.hx
    '';
  });
}
