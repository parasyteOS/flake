{
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
  wayland,
  xorg,
  android-headers,
}:
stdenv.mkDerivation {
  pname = "libhybris";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "parasyteOS";
    repo = "libhybris";
    rev = "a70e5cbb0b5384a1b4687f4fc9e49679ebf5ee5f";
    hash = "sha256-USnNEQu9H+21NRvf4+kYR8OCGU18FhENXEWQmX7zToA=";
  };
  sourceRoot = "source/hybris";

  nativeBuildInputs = [autoreconfHook pkg-config];
  buildInputs = [wayland xorg.libX11 xorg.libXext xorg.libxcb];

  configureFlags = [
    "--enable-wayland"
    "--enable-experimental"
    "--with-android-headers=${android-headers}/include/android"
    "--enable-arch=arm64"
  ];

  NIX_LDFLAGS = [
    # For libsupc++.a
    "-L${stdenv.cc.cc}/lib/"
  ];
}
