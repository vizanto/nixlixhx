# This defines a function taking `pkgs` as parameter, and uses
# `nixpkgs` by default if no argument is passed to it.
{ pkgsPath ? <nixpkgs> }:

with import pkgsPath { overlays = [ (import ./nixpkgs-overlay) ]; };

mkShell {
  buildInputs = [
    coreutils
    gnumake
    git
    haxe4_1
  ];
}
