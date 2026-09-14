{
  pkgs,
}:
let
  lib = pkgs.lib;
  depLaundry =
    drv:
    pkgs.stdenvNoCC.mkDerivation {
      inherit (drv) name;
      dontUnpack = true;
      buildPhase = "${pkgs.coreutils}/bin/cp -r ${drv.out} $out";
      __structuredAttrs = true;
      unsafeDiscardReferences.out = true;
    };
in
rec {
  mkXenConfig =
    file: cfg:
    let
      ini = pkgs.formats.iniWithGlobalSection { };
      escapeStrings = a: if lib.isList a then map (e: "'${toString e}'") a else "'${toString a}'";
    in
    ini.generate "${file}.cfg" {
      globalSection = lib.mapAttrs (
        path: value:
        if lib.isList value then
          "[ ${lib.strings.concatStringsSep "," (escapeStrings value)} ]"
        else if lib.isString value then
          (escapeStrings value)
        else
          (toString value)
      ) cfg;
    };

  evalSystem =
    nixpkgs: modules:
    import "${nixpkgs}/nixos/lib/eval-config.nix" {
      system = null;
      lib = (import nixpkgs { inherit (pkgs.stdenv.hostPlatform) system; }).lib;
      modules = modules;
    };
  #build system's rootfs
  buildStore =
    system:
    let
      graph = pkgs.stdenvNoCC.mkDerivation {
        name = "store-graph";
        dontUnpack = true;
        dontPatch = true;
        dontConfigure = true;
        dontFixup = true;
        dontInstall = true;
        # using unsafeDiscardReferences seems to disable the graph, soo lets just build it seperately...
        exportReferencesGraph = [
          "store"
          system.config.system.build.toplevel
        ];
        buildPhase = ''
          mv store $out
        '';
      };
    in
    pkgs.stdenvNoCC.mkDerivation {
      name = "store.erofs";

      dontUnpack = true;
      dontPatch = true;
      dontConfigure = true;
      dontFixup = true;
      dontInstall = true;

      store = graph;

      __structuredAttrs = true;
      unsafeDiscardReferences.out = true;

      nativeBuildInputs = [
        pkgs.erofs-utils
        pkgs.breakpointHook
      ];
      buildPhase = ''
        # get only store paths not node id's
        # use a static uuid and lable for now to make the builds more reproduceable
        grep / $store | tar --transform="s,^nix/,," --keep-directory-symlink -cf - -T - | mkfs.erofs -L erofs-store -U 6ea01cdf-a710-4216-94cb-fad6ed852312 -z zstd  $out --tar=-
      '';
    };
  buildInitrd = system: system.config.system.build.initialRamdisk;
  buildKernel = system: system.config.system.build.kernel;
  #maybe only use init later?
  buildToplevel = system: system.config.system.build.toplevel;

  #needs some more love later for proper overrides
  buildXenConfig =
    name: store: init: kernel: ramdisk: options:
    mkXenConfig name (
      {
        inherit name;
        type = "pvh";
        disk = [
          "format=raw,vdev=xvda,access=r,target=${store}"
        ];
        inherit ramdisk;
        inherit kernel;
        #for now use system toplevel as the init is stored there
        cmdline = "init=${init} console=hvc0";
        serial = "pty";
      }
      // options
    );

  buildXenVM =
    nixpkgs: modules: settings:
    let
      system = evalSystem nixpkgs modules;
      store = buildStore system;
      toplevel = buildToplevel system;
      kernel = buildKernel system;
      initrd = buildInitrd system;
    in
    buildXenConfig "meow" store "${builtins.unsafeDiscardOutputDependency toplevel}/init"
      "${kernel}/bzImage"
      "${initrd}/initrd"
      settings;

  buildXenVMLinks =
    nixpkgs: modules: settings:
    let
      system = evalSystem nixpkgs modules;
      toplevel = buildToplevel system;
      comps = rec {
        store = buildStore system;
        kernel = buildKernel system;
        initrd = buildInitrd system;
        "vm.cfg" = depLaundry (
          buildXenConfig "meow" store "${toplevel}/init" "${kernel}/bzImage" "${initrd}/initrd" settings
        );
      };
      mkEntry = e: lib.mapAttrsToList (name: path: { inherit name path; }) e;
    in
    pkgs.linkFarm "xen-vm-components" (mkEntry comps);
}
