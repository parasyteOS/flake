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
    rev = "b88b215cc9e811d505319ddd36af858e2b1ea3fc";
    hash = "sha256-j+ciE+UcWZHjc8I2Y1wsZirKcNbGYqHpIHpwbdlMDJU=";
  };

  nativeBuildInputs = [pkg-config];
  buildInputs = [openssl];

  makeFlags = ["PREFIX=${placeholder "out"}"];
}
