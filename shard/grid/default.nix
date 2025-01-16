{
  bash,
  coreutils,
  vim,
  writeShellScriptBin,
  buildEnv,
}: let
  login = writeShellScriptBin "login" ''
    env
    exec ${bash}/bin/bash
  '';
in
  buildEnv {
    name = "usr";
    paths = [coreutils vim login];
    postBuild = ''
      cat > ${placeholder "out"}/bootstrap <<EOF
      #!${bash}/bin/bash
      ${coreutils}/bin/chmod -R u-w ${builtins.storeDir}
      ${coreutils}/bin/chmod u+w ${builtins.storeDir}
      ${coreutils}/bin/rm -rf /data/data/com.termux/files/usr
      ${coreutils}/bin/ln -sf ${placeholder "out"} /data/data/com.termux/files/usr
      EOF
      chmod +x ${placeholder "out"}/bootstrap
    '';
  }
