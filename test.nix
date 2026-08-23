{
  nixpkgs ? <nixpkgs>,
}:
let
  pkgs = import nixpkgs { };
  vmLib = import ./lib.nix { inherit pkgs; };
in
vmLib.buildXenVM <nixpkgs> [ (import ./testSystem.nix) ] {
  memory = 4096;
  vcpus = 2;
}
