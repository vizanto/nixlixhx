# This defines a function taking `pkgs` as parameter, and uses
# `nixpkgs` by default if no argument is passed to it.
{ pkgsPath ? <nixpkgs> }:

with import pkgsPath { overlays = [ (import ./nixpkgs-overlay) ]; };

let
  packages = [
    coreutils-full # includes man pages
    gnumake
    git
    lix
    hashlink
    neko
  ];
  symlinks = buildEnv {
    name = "mdhx-bin";
    paths = packages;
    pathsToLink = ["/bin"];
  };
in mkShell {
  buildInputs = packages;
  inherit symlinks;
}
