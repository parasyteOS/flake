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
    rev = "fe6c448a6a4f0fce07020f6527cba62c959366a5";
    hash = "sha256-s28/gKa93MnABZFn/TnYIU9HvbIvTZBi9d/IGTM269k=";
  };

  nativeBuildInputs = [pkg-config];
  buildInputs = [openssl];

  makeFlags = ["PREFIX=${placeholder "out"}"];
}
