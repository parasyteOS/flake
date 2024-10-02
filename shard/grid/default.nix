{ bash, coreutils, neovim, writeShellScriptBin, buildEnv }:
let
  login = writeShellScriptBin "login" ''
    env   
    exec ${bash}/bin/bash
  '';
in
buildEnv {
  name = "usr";
  paths = [ coreutils neovim login ];
  postBuild = ''
    cat > bootstrap <<EOF
    #!${bash}/bin/bash
    ln -sf ${placeholder "out"} /data/data/com.termux/files/usr
    EOF
    chmod +x bootstrap
  '';
}
