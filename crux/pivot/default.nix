{
  fn,
  lib,
  pkgs,
  callPackage,
  runCommandNoCC,
  which,
  coreutils,
  bintools,
  git,
  perl,
  rsync,
  gnutar,
}: let
  mkCmdsFromAttrs = attrs: func: with lib; concatStringsSep "\n" (mapAttrsToList func attrs);
  sources = callPackage ./sources.nix {};
  buildImage = {
    manifests,
    parasytePatches,
    tsuPatches,
    kernelDir ? "common",
  }: let
    eval = lib.evalModules {
      modules =
        [
          ./modules/remote.nix
          ./modules/sources.nix
          ./modules/prebuilts.nix
        ]
        ++ (fn.dotNixFromRecursive manifests);
      specialArgs = {inherit lib pkgs;};
    };
    hostLibPaths = with lib; concatStringsSep "," (map (p: "-rpath,${getLib p}/lib") eval.config.hostLibs);
    mkImage = {
      applyParasytePatches ? true,
      extraPatches ? [],
      enableTsu ? false,
      tsuKey ? null,
      lto ? "full"
    } @ args: let
      patches = (lib.optionals applyParasytePatches parasytePatches) ++ (lib.optionals enableTsu tsuPatches) ++ extraPatches;
    in
      runCommandNoCC "image" {
        nativeBuildInputs = [which coreutils bintools git perl rsync gnutar];
        passthru = {
          vanilla = mkImage (args // {applyParasytePatches = false;});
          withPatches = patches: mkImage (args // {extraPatches = patches;});
          withThinLTO = mkImage (args // {lto = "thin";});
          withTsu = {key}:
            mkImage (args
              // {
                enableTsu = true;
                tsuKey = key;
              });
        };
      } ''
        mkdir -p $out
        ${mkCmdsFromAttrs eval.config.sources (_: source:
          ''
            mkdir -p $PWD/${dirOf source.path}
            rsync -a --chmod=+w ${source.final}/ $PWD/${source.path}
          ''
          + (mkCmdsFromAttrs source.links (target: relpath: ''
            mkdir -p $PWD/${dirOf target}
            ln -s $PWD/${source.path}/${relpath} $PWD/${target}
          '')))}
        ${mkCmdsFromAttrs eval.config.prebuilts (dest: src: ''
          mkdir -p $PWD/prebuilts/${dirOf dest}
          ln -s ${src} $PWD/prebuilts/${dest}
        '')}
        ${lib.optionalString enableTsu ''
          rsync -a --chmod=+w ${sources.neuro}/ ${kernelDir}/drivers/terminalsu
        ''}
        ${lib.concatMapStringsSep "\n" (patch: ''
            patch -p 1 < ${patch}
          '')
          patches}
        NIX_DYNAMIC_LINKER="$(cat $NIX_BINTOOLS/nix-support/dynamic-linker|tr -d '[:space:]')"
        PRE_DEFCONFIG_CMDS='export HOSTLDFLAGS="$HOSTLDFLAGS -Wl,${hostLibPaths} -Wl,-dynamic-linker='"$NIX_DYNAMIC_LINKER"'"' \
        LTO=${lto} DIST_DIR=$out BUILD_CONFIG=common/build.config.gki.aarch64 build/build.sh ${lib.optionalString enableTsu "TSU_PUB_KEY=${tsuKey}"}
      '';
  in
    mkImage {};
in {
  ishtar = buildImage {
    manifests = ./manifests/ishtar;
    parasytePatches = ["${sources.pact}/ishtar/parasyte.patch"];
    tsuPatches = ["${sources.pact}/ishtar/tsu.patch"];
  };
}
