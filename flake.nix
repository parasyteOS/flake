{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
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
    pkgs = import nixpkgs {
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
    linkPkgs = pkgs.pkgsCross.aarch64-multiplatform-musl.extend (final: prev: {
      musl = prev.musl.overrideAttrs (p: {patches = p.patches or [] ++ ["${sources.pact}/musl/adapt-seccomp.patch"];});
    });
    vatPkgs = pkgs.pkgsCross.aarch64-linux;
    refPkgs = self.packages.${sys};

    sources = pkgs.callPackage ./sources.nix {};
  in {
    packages.${sys} = {
      pivot = pkgs.callPackage ./crux/pivot {inherit fn sources;};
      deck = pkgs.callPackage ./crux/deck {inherit (gradle2nix.builders.${sys}) buildGradlePackage;};

      cortex = linkPkgs.callPackage ./link/cortex {};
      weave = linkPkgs.callPackage ./link/weave {};
      dial = linkPkgs.callPackage ./link/dial.nix {inherit (refPkgs) cortex weave;};
      grid = linkPkgs.callPackage ./shard/grid/default.nix {};

      inherit (vatPkgs.callPackage ./vat/android-headers {}) android-headers-30;
      libhybris = vatPkgs.callPackage ./vat/libhybris.nix {android-headers = refPkgs.android-headers-30;};
    };

    formatter.${sys} = pkgs.alejandra;
  };
}
