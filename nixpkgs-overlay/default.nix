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

  haxe_libraries_json = { name, src }:
    runCommand "${name}.json" { inherit src; } ./src_haxe_libraries_to_out_json.sh;

  fetch_haxe_library = with builtins; { name, uri, dest, buildOverrides }:
    let
      matches = match "([^:]+):([^#]+)#(.*)" uri;
      schema = head matches;
      path = elemAt matches 1;
      version = elemAt matches 2;
      esc = e: builtins.replaceStrings ["."] [","] e;
    in {
      # Supported lix URIs
      haxelib = let
        zip = stdenv.mkDerivation {
          name = "haxelib-${name}-${version}.zip";
          inherit version;
          NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
          buildInputs = [ nix ];
          buildCommand = ''
            HASH_ZIP=$(nix-prefetch-url --print-path --name '${name}-${version}.zip' 'https://lib.haxe.org/files/3.0/${esc name}-${esc version}.zip');
            arr=($HASH_ZIP)
            echo downloaded haxelib ''${arr[1]} with SHA256 ''${arr[0]};
            ln -sv ''${arr[1]} $out
          '';
        };
      in
      stdenv.mkDerivation ({
        name = "haxelib-${name}-${version}";
        inherit version;
        buildInputs = [ unzip ];
        src = zip;
        installPhase = ''
          echo installing haxelib $name
          mkdir $out
          cd $out
          unzip $src
        '';
      } // buildOverrides);
    }."${schema}";

  fetch_haxe_libraries = { parent_name, haxelibs_json, buildOverridesMap ? {} }:
    let
      libs = builtins.fromJSON (builtins.readFile haxelibs_json);
      libraries = lib.mapAttrs
                    (k: v: fetch_haxe_library (v // { buildOverrides = buildOverridesMap."${k}" or {}; }))
                    (builtins.removeAttrs libs ["src"]);
    in
    {
      inherit libraries;
      bashArray = ''
        declare -A libraries;
        ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "libraries['${key}']='${value}'; libraries['${key}.hxml']='${value}';") libraries)}
      '';
    };

in
{
  ocamlPackages = ocamlPackages // extraOcamlPackages;

  haxe_4_nightly = haxe.overrideAttrs (old: {
    version = "4.1.0-nightly";
    src = gitsrc "haxe";

    propagatedBuildInputs = [ neko ];

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

  inherit haxe_libraries_json;

  haxeshim =
    let
      name = "haxeshim";
      version = "git";
      src = gitsrc "haxeshim";
      haxelibs_json = haxe_libraries_json { inherit name src; };
      haxe_libraries = fetch_haxe_libraries { parent_name = "haxeshim"; inherit haxelibs_json; };
    in {

      inherit src haxe_libraries;

      tool = with self; stdenv.mkDerivation {
        inherit name version src;

        buildInputs = [ nodejs haxe_4_nightly ];

        patchPhase = ''
          ${haxe_libraries.bashArray}
          cd haxe_libraries
          echo --------------------------
          echo
          for lib in *; do
            dest=''${libraries[$lib]}
            if [[ -d $dest/src ]]; then
              dest="$dest/src"
            fi
            grep cp $lib
            echo fixup $lib path to: $dest
            sed -i s"|-cp .*|-cp $dest|" $lib
            echo
          done
          echo --------------------------
          cd ..

          echo replacing -lib with hxml paths
          sed -i s"|-lib \(.*\)|./haxe_libraries/\1.hxml|" common.hxml
        '';

        buildPhase = ''
          haxe all.hxml
          chmod +x bin/*
        '';

        installPhase = ''
          mkdir $out
          cp -a * $out
        '';
      };
    };
}
