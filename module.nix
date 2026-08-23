{ lib, ... }: {
  options.virtualisation.xen.domu = lib.mkOption {
    description = "Guest domU nixos systems";
    default = { };
    type = lib.types.submodule { };
  };
}
