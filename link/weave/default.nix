{
  stdenv,
  fetchFromGitHub,
  pkg-config,
  libsepol,
}: let
  libsepol' = libsepol.overrideAttrs (prev: {
    src = fetchFromGitHub {
      owner = "topjohnwu";
      repo = "selinux";
      rev = "8c6acc0d7792cda5f203dfd8e94c633e9dbfdeae";
      hash = "sha256-vV4YgttEJUI6epVUMzYyjX8mtiMhSixbawga7fN+7GA=";
    };
    sourceRoot = "source/libsepol";
    patches = prev.patches or [] ++ [./export-all-syms.patch];
  });
in
  stdenv.mkDerivation {
    pname = "weave";
    version = "0.0.1";

    src = fetchFromGitHub {
      owner = "parasyteOS";
      repo = "weave";
      rev = "fd6fce1053d6387b5b1afa45ed5bb8bc77ec863b";
      hash = "sha256-HpZeNed+QhfLWuTHi2pM3sfXS1i55MdPizjKeg5Jrn4=";
    };

    nativeBuildInputs = [pkg-config];
    buildInputs = [libsepol'];
    makeFlags = ["PREFIX=${placeholder "out"}"];
  }
