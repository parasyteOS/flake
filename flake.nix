{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.fun.url = "github:Ninlives/fn";

  outputs = {
    self,
    nixpkgs,
    fun,
  }: let
    fn = fun.c {inherit (nixpkgs) lib;};
    sys = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${sys};
    linkPkgs = pkgs.pkgsCross.aarch64-multiplatform-musl;
    vatPkgs = pkgs.pkgsCross.aarch64-linux;
    refPkgs = self.packages.${sys};
  in {
    packages.${sys} = {
      pivot = pkgs.callPackage ./crux/pivot {inherit fn;};

      cortex = linkPkgs.callPackage ./link/cortex {};
      weave = linkPkgs.callPackage ./link/weave {};
      dial = linkPkgs.callPackage ./link/dial.nix {inherit (refPkgs) cortex weave;};

      inherit (vatPkgs.callPackage ./vat/android-headers {}) android-headers-30;
      libhybris = vatPkgs.callPackage ./vat/libhybris.nix {android-headers = refPkgs.android-headers-30;};
    };

    formatter.${sys} = pkgs.alejandra;
  };
}
