{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = {
    self,
    nixpkgs,
  }: let
    sys = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${sys};
    linkPkgs = pkgs.pkgsCross.aarch64-multiplatform-musl;
    vatPkgs = pkgs.pkgsCross.aarch64-linux;
    refPkgs = self.packages.${sys};
  in {
    packages.${sys} = {
      cortex = linkPkgs.callPackage ./link/cortex {};
      weave = linkPkgs.callPackage ./link/weave {};
      dial = linkPkgs.callPackage ./link/dial.nix {inherit (refPkgs) cortex weave;};

      inherit (vatPkgs.callPackage ./vat/android-headers {}) android-headers-30;
      libhybris = vatPkgs.callPackage ./vat/libhybris.nix {android-headers = refPkgs.android-headers-30;};
    };

    formatter.${sys} = pkgs.alejandra;
  };
}
