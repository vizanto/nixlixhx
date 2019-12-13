self: super:

with super;
let
  gitsrc = name:
    let attrs = builtins.fromJSON (builtins.readFile (./. + "/${name}.json"));
  in fetchgit {
    inherit (attrs) url rev sha256 fetchSubmodules leaveDotGit;
    inherit name;
  } // { inherit (attrs) date; };

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
      matches = match "([^:]+):([^#]+)#?(.*)?" uri;
      schema = head matches;
      path = elemAt matches 1;
      version = elemAt matches 2;
      esc = e: builtins.replaceStrings ["."] [","] e;
    in
    {
      # Supported lix URIs
      gh = stdenv.mkDerivation ({
        name = "gh-${name}-${version}.git";
        inherit version;
        NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
        buildInputs = [ nix-prefetch-git ];
        buildCommand = ''
          nix-prefetch-git --rev ${version} --url 'https:${path}.git' 2>&1 |tee prefetch.out
          store=$(cat prefetch.out |grep 'path is /nix/store/' |cut -d ' ' -f 3);
          echo downloaded $uri rev: $version to: $store
          ln -sv $store $out
        '';
      } // buildOverrides);

      https = let
        name = baseNameOf path;
        fetched = stdenv.mkDerivation {
          inherit version;
          pname = "https-${name}";
          NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
          buildInputs = [ nix ];
          buildCommand = ''
            HASH_ZIP=$(nix-prefetch-url --name '${name}' --print-path '${uri}');
            arr=($HASH_ZIP)
            echo downloaded https ''${arr[1]} with SHA256 ''${arr[0]};
            ln -sv ''${arr[1]} $out
          '';
        };
      in
      stdenv.mkDerivation ({
        inherit name version;
        buildInputs = [ unzip ];
        src = fetched;
        installPhase = ''
          mkdir $out
          mv -v * $out/
        '';
      } // buildOverrides);

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
        sourceRoot = ".";
        installPhase = ''
          echo installing haxelib $name
          mkdir $out
          mv -v * $out/
        '';
      } // buildOverrides);
    }."${schema}";

  fetch_haxe_libraries = { parent_name, haxelibs_json, exclude ? [], buildOverridesMap ? {} }:
    let
      json = builtins.readFile haxelibs_json;
      libs = builtins.fromJSON json;
      libraries = lib.mapAttrs
                    (k: v: fetch_haxe_library (v // { buildOverrides = buildOverridesMap."${k}" or {}; }))
                    (builtins.removeAttrs libs (["src"] ++ exclude));
    in
    {
      inherit libraries;
      bashArray = ''
        declare -A libraries;
        ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "libraries['${key}']='${value}'; libraries['${key}.hxml']='${value}';") libraries)}
      '';
    };

  fetch_haxe_libraries_dir = { name, src, buildOverridesMap ? {},  exclude ? [] } @ attrs: fetch_haxe_libraries {
    parent_name = name;
    haxelibs_json = haxe_libraries_json { inherit name src; };
    inherit buildOverridesMap exclude;
  };

  patch_haxe_libraries_dir = fetched_haxe_libraries: writeScript "patch_haxe_libraries_dir" ''
    cd haxe_libraries
    echo --------------------------
    ${fetched_haxe_libraries.bashArray}
    echo
    for lib in *; do
      dest=''${libraries[$lib]}
      if [[ -d $dest/src ]]; then dest="$dest/src"; fi
      if [[ -d $dest/std ]]; then dest="$dest/std"; fi
      grep cp $lib
      echo fixup $lib path to: $dest
      sed -i s"|-cp \''$.*|-cp $dest|" $lib
      echo
    done
    echo --------------------------
  '';

  haxe4-attributes = {
    propagatedBuildInputs = [ neko ];

    buildInputs =
      [ git neko pcre zlib ] ++
      (with self.ocamlPackages; [
        dune findlib
        ocaml
        camlp5
        sedlex
        uchar
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
  };
in
{
  ocamlPackages = ocamlPackages // extraOcamlPackages;

  haxe_4_0_3-bin = haxe.overrideAttrs (old: { version = "4.0.3"; src = gitsrc "haxe-4.0.3"; } // haxe4-attributes);
  haxe_4_1_nightly-bin = haxe.overrideAttrs (old: { version = "4.1.0-nightly"; src = gitsrc "haxe"; } // haxe4-attributes);

  inherit haxe_libraries_json;

  haxeshim = haxe:
    let
      name = "haxeshim";
      haxeshim-git = gitsrc "haxeshim";
      shim_haxe_libraries = fetch_haxe_libraries_dir { inherit name; src = haxeshim-git; };

      patched-src = with self; stdenv.mkDerivation
      {
        pname = name;
        version = haxeshim-git.rev;
        src = haxeshim-git;

        patchPhase = ''
          echo patching HAXE_LIBCACHE location
          sed -i src/haxeshim/Scope.hx \
              -e s"|\(this.haxelibRepo =\) \([^;]\+\);|\1 env('HAXELIB_PATH').or(\2);|" \
              -e s"|\(this.libCache =\) \([^;]\+\);|\1 env('HAXE_LIBCACHE').or(\2);|"
          grep this. src/haxeshim/Scope.hx |grep haxeshimRoot
          ${patch_haxe_libraries_dir shim_haxe_libraries}
          echo replacing -lib with hxml paths
          sed -i s"|-lib \(.*\)|./haxe_libraries/\1.hxml|" common.hxml
        '';

        buildPhase = "";

        installPhase = ''
          mkdir $out
          cp -a * $out/
        '';
      };

      tool = with self; stdenv.mkDerivation
      {
        inherit name;
        src = patched-src;
        version = patched-src.version;

        buildInputs = [ haxe nodejs ];

        buildPhase = ''
          haxe all.hxml
          chmod +x bin/*
        '';

        installPhase = ''
          mkdir -p $out/share
          mv bin/postinstall* $out/share
          cp -a bin $out
        '';
      };

      scoped = runCommand "${haxe.name}-scoped" (with builtins;
      {
        inherit haxe tool;
        published = haxe.src.date;
        version = substring 0 7 haxe.src.rev;
      })
      ''
        mkdir $out
        cd $out

        # Link neko and tools where haxeshim expects them
        find $(sed s'| |/bin|' $haxe/nix-support/propagated-build-inputs) -maxdepth 1 -not -type d -exec ln -vs '{}' ';'

        mkdir $out/bin
        for f in $tool/bin/*; do
          cp -av $f $out/bin/$(basename $f "shim.js")
        done;

        # Configure haxeshim
        echo -n '{"version":"'$version'","resolveLibs":"scoped"}' > .haxerc
        mkdir haxelib nix-support
        cat > nix-support/setup-hook <<______
        # Set unwritable lix and haxelib caches by default
        export HAXE_ROOT=$out
        ______

        # Set up Haxe
        mkdir -p versions/$version
        pushd versions/$version
          echo '{"published": "'$(date -ud "$published" +'%Y-%m-%d %H:%M:%S')'"}' > version.json
          for f in $haxe/lib/haxe/*; do
            [[ -e `basename $f` ]] || ln -vs $f;
          done;
      '';
    in {
      inherit tool scoped;

      src = patched-src;

      lix = let
        name = "lix";
        lixsrc = gitsrc "lix";
        lix_haxe_libraries = fetch_haxe_libraries_dir { inherit name; src = lixsrc; exclude = ["haxeshim"]; };
      in stdenv.mkDerivation
      {
        inherit name tool;
        src = lixsrc;

        haxe = scoped;
        propagatedBuildInputs = [ neko ];
        nativeBuildInputs = [ makeWrapper ];
        buildInputs = [ scoped git nodejs ]; #TODO: ++ (with nodePackages; [ ncc graceful-fs tar yauzl ]);

        patchPhase = ''
          ${patch_haxe_libraries_dir lix_haxe_libraries}
          sed -i s"|-cp.*|-cp ${patched-src}/src|" haxe_libraries/haxeshim.hxml
          # Don't dowload into the nix store, but into HAXE_LIBCACHE/.downloads
          sed -i s"|haxeshimRoot + '/downloads/|libCache + '/.downloads/|" \
            src/lix/client/{Libraries.hx,haxe/Switcher.hx}
        '';

        buildPhase = ''
          cp -v $haxe/.haxerc . # set scope to Haxe version
          # make sure postinstall.js exists for npm install to work
          mkdir bin
          cp -av $tool/share/postinstall.js bin
          # install js dependencies
          HOME=. npm install
          # build
          haxe --run Build
        '';

        installPhase = ''
          rm bin/postinstall.js
          mkdir -p $out/bin

          # copy optimized haxe shims
          for f in $tool/bin/haxe*shim.js; do
            cp -av $f $out/bin/$(basename $f "shim.js")
          done;

          # copy lix
          cp -av bin/lix.js $out/bin/lix

          # wrap lix and shims to provide user-friendly default cache locations
          for prog in $out/bin/{haxe,haxelib,lix}; do
            wrapProgram $prog \
              --run 'export HAXE_CACHE=''${HAXE_CACHE-$HOME/${if stdenv.isDarwin then "Library/Caches/haxe" else "haxe"}}' \
              --run 'export HAXE_LIBCACHE=''${HAXE_LIBCACHE-$HAXE_CACHE/haxe_libraries}' \
              --run 'export HAXELIB_PATH=''${HAXELIB_PATH-$HAXE_CACHE/haxelib}'
          done;

          # copy Haxe shim support
          cp -av $haxe/nix-support $out
        '';
      };
    };

  # lixified Haxe 4.1 (development branch)
  haxeshim-haxe4_1 = with self; (haxeshim haxe_4_1_nightly-bin);
  haxe4_1 = self.haxeshim-haxe4_1.scoped;
  lix-nightly = self.haxeshim-haxe4_1.lix;

  # lixified Haxe 4
  haxeshim-haxe4 = with self; (haxeshim haxe_4_0_3-bin);
  haxe4 = self.haxeshim-haxe4.scoped;
  lix = self.haxeshim-haxe4.lix;

  hashlink = stdenv.mkDerivation {
    name = "hashlink";
    version = "git";
    src = gitsrc "hashlink";

    buildInputs = [
        cmake
        libjpeg_turbo
        libogg
        libpng
        libuv
        libvorbis
        mbedtls
        openalSoft
        SDL2
      ] ++
      (with pkgs.darwin.apple_sdk.frameworks; [ Cocoa ]);

    postInstall = ''
      cd ..
      cp -v src/hlc_main.c $out/include
    '';
  };
}
