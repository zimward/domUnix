{
  nixpkgs ? <nixpkgs>,
}:
let
  pkgs = import nixpkgs { };
  lib = pkgs.lib;
  # modules:
  system = import "${nixpkgs}/nixos/lib/eval-config.nix" {
    system = null;
    inherit lib;
    modules = [ (import ./testSystem.nix) ];
  };
in
system.config.system.build.initialRamdisk
