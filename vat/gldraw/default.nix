{
  stdenv,
  pkg-config,
  libGL,
}:
stdenv.mkDerivation {
  pname = "gldraw";
  version = "0.0.1";

  src = ./src;

  nativeBuildInputs = [pkg-config];
  buildInputs = [libGL];
  makeFlags = ["PREFIX=${placeholder "out"}"];
}
