(
  {
    pkgs,
    modulesPath,
    ...
  }:
  {
    imports = [
      "${modulesPath}/profiles/minimal.nix"
      "${modulesPath}/profiles/bashless.nix"
      "${modulesPath}/virtualisation/xen-domU.nix"
    ];
    config = {
      boot.loader.grub.enable = false;
      boot.loader.generic-extlinux-compatible.enable = true;
      fileSystems."/" = {
        device = "tmpfs";
        fsType = "tmpfs";
      };
      fileSystems."/nix" = {
        device = "/dev/disk/by-label/erofs-store";
        fsType = "erofs";
      };
      users.users.root = {
        password = "123";
        shell = pkgs.nushell;
      };

      security.account-utils.enable = true;
      boot.initrd.systemd.emergencyAccess = true;

      nixpkgs.hostPlatform = "x86_64-linux";

      environment.systemPackages = [ pkgs.bottom ];
    };
  }
)
