{
  pkgs,
}:
let
  lib = pkgs.lib;
in
rec {
  mkXenConfig =
    file: cfg:
    let
      ini = pkgs.formats.iniWithGlobalSection { };
      escapeStrings = a: if lib.isList then map (e: "'${e}'") a else "'${a}'";
    in
    ini.generate "${file}.cfg" (
      lib.mapAttrs (
        path: value:
        if lib.isList value then
          "[ ${lib.strings.concatStringsSep " " (escapeStrings value)} ]"
        else
          (escapeStrings value)
      ) cfg
    );

  evalSystem =
    nixpkgs: modules:
    import "${nixpkgs}/nixos/lib/eval-config.nix" {
      system = null;
      inherit lib;
      modules = modules;
    };
  #build system's rootfs
  buildStore =
    system:
    pkgs.stdenvNoCC.mkDerivation {
      name = "store.erofs";

      dontUnpack = true;
      dontPatch = true;
      dontConfigure = true;
      dontFixup = true;
      dontInstall = true;

      exportReferencesGraph = [
        "graph"
        system.config.system.build.toplevel
      ];
      nativeBuildInputs = [
        pkgs.erofs-utils
        pkgs.breakpointHook
      ];
      buildPhase = ''
        #get only lines
        grep / graph | tar --transform="s,^nix/,," --keep-directory-symlink -cf - -T - | mkfs.erofs $out --tar=-
      '';
    };
  buildInitrd = system: system.config.system.build.initialRamdisk;
  buildKernel = system: system.config.system.build.kernel;

  #needs some more love later for proper overrides
  buildXenConfig =
    name: store: init: kernel: ramdisk: options:
    mkXenConfig name {
      inherit name;
      type = "phv";
      disks = [
        "format=raw,vdev=xvda,access=r,target=${store}"
      ];
      inherit ramdisk;
      inherit kernel;
      #for now use system toplevel as the init is stored there
      cmdline = "init=${init} console=hvc0";
      serial = "pty";
    }
    // options;

  buildXenVM =
    nixpkgs: modules: settings:
    let
      system = evalSystem nixpkgs modules;
      kernel = buildKernel system;
      initrd = buildInitrd system;
      store = buildStore system;
    in
    pkgs.linkFarm "vm-system" [
      {
        name = "kernel";
        path = kernel;
      }
      {
        name = "initrd";
        path = initrd;
      }
      {
        name = "store.erofs";
        path = store;
      }
      {
        name = "config.cfg";
        path = buildXenConfig "meow" store "${system}/init" kernel initrd settings;
      }
    ];
}
