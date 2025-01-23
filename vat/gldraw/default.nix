{
  stdenv,
  pkg-config,
  libGL,
  libdrm,
  fetchFromGitHub
}:
let
  evdilib = stdenv.mkDerivation (finalAttrs: {
    pname = "evdilib";
    version = "1.14.8";

    src = fetchFromGitHub {
      owner = "DisplayLink";
      repo = "evdi";
      tag = "v${finalAttrs.version}";
      hash = "sha256-57DP8kKsPEK1C5A6QfoZZDmm76pn4SaUKEKu9cicyKI=";
    };

    buildInputs = [libdrm];
    buildFlags = ["library"];

    installPhase = ''
      make -C library PREFIX=${placeholder "out"}
      install -D library/evdi_lib.h "${placeholder "out"}/include"
    '';
  });
in
stdenv.mkDerivation {
  pname = "gldraw";
  version = "0.0.1";

  src = ./src;

  nativeBuildInputs = [pkg-config];
  buildInputs = [libGL libdrm];
  makeFlags = ["PREFIX=${placeholder "out"}" "EVDI=${evdilib}"];
}
