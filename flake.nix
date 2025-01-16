{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";
  inputs.gradle2nix = {
    url = "github:tadfisher/gradle2nix/v2";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.fun.url = "github:Ninlives/fn";

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
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
    linkPkgs = buildPkgs.pkgsCross.aarch64-multiplatform-musl.extend (final: prev: {
      musl = prev.musl.overrideAttrs (p: {patches = p.patches or [] ++ ["${sources.pact}/musl/adapt-seccomp.patch"];});
    });
    vatPkgs = nixpkgs.legacyPackages.aarch64-linux;
    refPkgs = self.packages.${sys};

    sources = buildPkgs.callPackage ./sources.nix {};
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

      dial = linkPkgs.callPackage ./link/dial.nix {inherit (refPkgs) cortex weave;};
      surge = linkPkgs.callPackage ./link/surge.nix {inherit (refPkgs) cortex sheath;};
      grid = linkPkgs.callPackage ./shard/grid/default.nix {};

      dive = vatPkgs.callPackage ./vat/dive {};
      phantom = vatPkgs.callPackage ./vat/phantom.nix {};
    };

    formatter.${sys} = buildPkgs.alejandra;
  };
}
