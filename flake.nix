{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  inputs.gradle2nix = {
    url = "github:tadfisher/gradle2nix/v2";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.fun.url = "github:Ninlives/fn";

  outputs = {
    self,
    nixpkgs,
    gradle2nix,
    fun,
  }: let
    fn = fun.c {inherit (nixpkgs) lib;};
    sys = "x86_64-linux";
    buildPkgs = import nixpkgs {
      system = sys;
      config = {
        android_sdk.accept_license = true;
        allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "android-sdk-cmdline-tools"
            "android-sdk-tools"
          ];
      };
    };
    ovl = final: prev: {
      # mesa = prev.mesa.overrideAttrs (p: { patches = p.patches or [] ++ [./mesa.patch]; });
      wlroots_0_18 = prev.wlroots_0_18.overrideAttrs (p: { patches = p.patches or [] ++ [./wlroots.patch]; });
    };
    linkPkgs = buildPkgs.pkgsCross.aarch64-multiplatform-musl;
    vatPkgs = nixpkgs.legacyPackages.aarch64-linux.extend ovl;
    refPkgs = self.packages.${sys};

    sources = buildPkgs.callPackage ./sources.nix {};
    jar = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ({
          pkgs,
          lib,
          modulesPath,
          ...
        }: {
          # nixpkgs.crossSystem.system = "aarch64-linux";

          imports = [(modulesPath + "/profiles/minimal.nix")];

          boot.isContainer = true;
          console.enable = true;
          environment.systemPackages = [
            pkgs.tmux
            pkgs.neofetch
            pkgs.neovim
            pkgs.glmark2
            pkgs.niri
            pkgs.vkmark
            pkgs.kitty
            pkgs.weston
            pkgs.alacritty
            refPkgs.dive
            refPkgs.mew
          ];
          nixpkgs.overlays = [ovl];
          networking.useDHCP = false;

          users.mutableUsers = false;
          users.users.root.password = "1234";
          users.users.droid = {
            isNormalUser = true;
            createHome = true;
            extraGroups = ["wheel"];
            password = "1123";
          };
          users.users.system = {
            isSystemUser = true;
            uid = 1000;
            group = "system";
          };
          users.groups.system.gid = 1000;
          hardware.graphics.enable = true;
          
          # DNS
          networking.resolvconf.useLocalResolver = true;
          services.smartdns = {
            enable = true;
            settings = {
              server = [
                "1.1.1.1:53"
                "8.8.8.8:53"
                "9.9.9.9:53"
                "149.112.112.112:53"

                "114.114.114.114:53 -group cn"
                "114.114.115.115:53 -group cn"
                "119.29.29.29:53 -group cn"
                "223.5.5.5:53 -group cn"
                "223.6.6.6:53 -group cn"
              ];
              server-tls = ["1.1.1.1:853" "8.8.8.8:853" "9.9.9.9:853" "149.112.112.112:853"];
              server-https = [
                "https://cloudflare-dns.com/dns-query -group doh"
                "https://dns.quad9.net/dns-query -group doh"
              ];
              nameserver = "/.onion/doh";
              bind = "127.0.0.1:53";
              prefetch-domain = true;
              speed-check-mode = "tcp:443,tcp:80,ping";
              audit-enable = true;
              dualstack-ip-selection = true;
            };
          };
        })
      ];
    };
  in {
    packages.${sys} = {
      pivot = buildPkgs.callPackage ./crux/pivot {inherit fn sources;};
      ishtar = (refPkgs.pivot.ishtar
                .withLocalVersion "-android13-8-00004-ge488687c12ef-ab11838684")
                .withTsu { key = "BGLbMCkiwVeIgE3epuOBE5pu9GrDPNpzsqU9flhTD3bWlH7gMEmDInjGu2jtQBboPRYbRBXGfiIb5FNcbaPTaSo="; };
      deck = buildPkgs.callPackage ./crux/deck {inherit (gradle2nix.builders.${sys}) buildGradlePackage;};

      cortex = linkPkgs.callPackage ./link/cortex {};
      weave = linkPkgs.callPackage ./link/weave {};
      sheath = linkPkgs.callPackage ./link/sheath {};
      qemu = buildPkgs.pkgsCross.aarch64-multiplatform.callPackage ./link/qemu {};

      dial = linkPkgs.callPackage ./link/dial.nix {inherit (refPkgs) cortex weave;};
      surge = linkPkgs.callPackage ./link/surge.nix {inherit (refPkgs) cortex sheath;};
      grid = linkPkgs.callPackage ./shard/grid/default.nix {};

      dive = vatPkgs.callPackage ./vat/dive {};
      mew = vatPkgs.callPackage ./vat/mew {};
      phantom = vatPkgs.callPackage ./vat/phantom.nix {inherit jar;};
    };

    formatter.${sys} = buildPkgs.alejandra;
  };
}
