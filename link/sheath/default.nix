{
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation {
  pname = "sheath";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "parasyteOS";
    repo = "sheath";
    rev = "6e17df6223519e1bab4b00215da5635859520872";
    hash = "sha256-m3PVZT32SjUOi6WPBhfqaoE/I4GJD32sq50CIVhGoYM=";
  };

  makeFlags = ["PREFIX=${placeholder "out"}"];
}
