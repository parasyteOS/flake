{
  stdenv,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:
stdenv.mkDerivation {
  pname = "cortex";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "parasyteOS";
    repo = "cortex";
    rev = "2deab607940d8d51d90f9d3fea853d85facc9d8d";
    hash = "sha256-TKxit3VmgbzwoNE8q+6NBo7fUICfawIh/zKBURMIFKs=";
  };

  nativeBuildInputs = [pkg-config];
  buildInputs = [openssl];

  makeFlags = ["PREFIX=${placeholder "out"}"];
}
