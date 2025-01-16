{ lib, writeShellScriptBin, util-linux, coreutils }:
let
  inherit (lib) getExe getExe';
  lvl1 = writeShellScriptBin "dive" ''
    ${getExe' util-linux "unshare"} -m "${getExe lvl2}" "$@"
  '';
  lvl2 = let 
    mktemp = getExe' coreutils "mktemp";
    basename = getExe' coreutils "basename";
    ln = getExe' coreutils "ln";
    readlink = getExe' coreutils "readlink";
    mkdir = getExe' coreutils "mkdir";
    touch = getExe' coreutils "touch";
    mount = getExe' util-linux "mount";
    chroot = getExe' coreutils "chroot";
  in writeShellScriptBin "lvl2" ''
    ROOT="$(${mktemp} -d)"
    for path in /mnt/*;do
      base=$(${basename} "$path")
      if [[ -L "$path" ]];then
        ${ln} -s "$(${readlink} "$path")" "$ROOT/$base"
      else
        if [[ -d "$path" ]];then
          ${mkdir} -p "$ROOT/$base"
        else
          ${touch} "$ROOT/$base"
        fi
        ${mount} --rbind "$path" "$ROOT/$base"
      fi
    done
    ${mkdir} -p "$ROOT/nix"
    ${mount} --rbind /nix "$ROOT/nix"
    ${mkdir} -p /run/outerspace
    ${mkdir} -p "$ROOT/innerspace"
    ${mount} --rbind /run/outerspace "$ROOT/innerspace"
    ${chroot} "$ROOT" "$@"
  '';
in
  lvl1
