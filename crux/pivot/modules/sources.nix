{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types mkDefault;
  config' = config;
  srcType = types.submodule ({
    name,
    config,
    options,
    ...
  }: {
    options = {
      path = mkOption {
        type = types.str;
        default = name;
      };
      remote = mkOption {
        type = types.str;
        default = "aosp";
      };
      repo = mkOption {
        type = types.str;
        default = null;
      };
      rev = mkOption {
        type = types.str;
        default = null;
      };
      hash = mkOption {
        type = types.str;
        default = "";
      };
      patches = mkOption {
        type = types.listOf types.path;
        default = [];
      };
      postPatch = mkOption {
        type = types.lines;
        default = "";
      };
      fixup = mkOption {
        type = types.bool;
        default = false;
      };
      shebangs = mkOption {
        type = types.listOf types.package;
      };
      links = mkOption {
        type = types.attrsOf types.str;
        default = {};
      };
      src = mkOption {
        type = types.path;
      };
      final = mkOption {
        type = types.path;
      };
    };
    config = {
      shebangs = with pkgs; [python3 perl];
      src = mkIf (config.repo != null) (
        mkDefault (pkgs.fetchgit {
          url = "${config'.remote.${config.remote}.fetch}/${config.repo}";
          inherit (config) rev hash;
        })
      );
      final =
        if (with config; (patches == [] && postPatch == "" && !fixup))
        then config.src
        else
          pkgs.stdenv.mkDerivation {
            name = "${config.src.name}-patched";
            inherit (config) src patches postPatch;
            nativeBuildInputs = [pkgs.patchelf];
            buildInputs = config.shebangs;
            dontBuild = true;
            installPhase = "cp -R ./ $out";
            postFixup = ''
              INTERP=$(cat $NIX_BINTOOLS/nix-support/dynamic-linker|tr -d '[:space:]')
              RPATHS=${lib.makeLibraryPath (map lib.getLib config'.hostLibs)}

              tmpFile=$(mktemp)
              for f in $(find $out -type f);do
                if isELF "$f";then
                  patchelf --print-interpreter "$f" > /dev/null 2>&1 || continue
                  echo Patching "$f"

                  fmode=$(stat -c '%a' "$f")
                  # https://github.com/nix-community/robotnix/blob/master/scripts/patchelf-prefix.sh
                  elfHeader=$(readelf -h "$f")
                  sectionHeadersOffset=$(echo "$elfHeader" | sed -En "s/Start of section headers:\W+([0-9]*).*$/\1/p")
                  sectionHeadersSize=$(echo "$elfHeader" | sed -En "s/Size of section headers:\W+([0-9]*).*$/\1/p")
                  sectionHeadersNum=$(echo "$elfHeader" | sed -En "s/Number of section headers:\W+([0-9]*).*$/\1/p")
                  offset=$(("$sectionHeadersOffset" + "$sectionHeadersSize" * "$sectionHeadersNum"))

                  dd if="$f" of="$tmpFile" bs=$offset count=1 >/dev/null
                  patchelf --set-interpreter $INTERP "$tmpFile" && patchelf --add-rpath "$RPATHS" "$tmpFile"
                  dd if="$f" of="$tmpFile" bs=$offset skip=1 conv=notrunc oflag=append >/dev/null
                  cp "$tmpFile" "$f"
                  chmod "$fmode" "$f"
                fi
              done

              rm "$tmpFile"
            '';
          };
    };
  });
in {
  options = {
    sources = mkOption {
      type = types.attrsOf srcType;
      default = {};
    };
    hostLibs = mkOption {
      type = types.listOf types.package;
    };
  };

  config = {
    hostLibs = [pkgs.zlib];
  };
}
