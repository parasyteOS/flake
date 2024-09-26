{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.remote = mkOption {
    type = types.attrsOf (types.submodule ({
      name,
      config,
      ...
    }: {
      options = {
        fetch = mkOption {
          type = types.str;
        };
      };
    }));
    default = {aosp.fetch = "https://android.googlesource.com";};
  };
}
