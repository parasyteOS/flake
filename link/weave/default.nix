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
      rev = "cdc49e96a245229ff4e04c645bb564cc50b95fc7";
      hash = "sha256-uLbrVOEFjrZ2Yta+ZjVGGCcUxE3tXcetIfTb1xBXwt4=";
    };

    nativeBuildInputs = [pkg-config];
    buildInputs = [libsepol'];
    makeFlags = ["PREFIX=${placeholder "out"}"];
  }
