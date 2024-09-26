{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.prebuilts = mkOption {
    type = types.attrsOf types.path;
    default = {};
  };
}
