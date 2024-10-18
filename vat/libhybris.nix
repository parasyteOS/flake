{
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
  wayland,
  wayland-scanner,
  xorg,
  android-headers,
}:
let
  inherit (stdenv) targetPlatform buildPlatform;
  libPrefix = if targetPlatform == buildPlatform then ""
    else targetPlatform.config;
in
stdenv.mkDerivation {
  pname = "libhybris";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "parasyteOS";
    repo = "libhybris";
    rev = "667243f6151b328685b264ec7d6395a602aa10c3";
    hash = "";
  };
  sourceRoot = "source/hybris";

  nativeBuildInputs = [autoreconfHook pkg-config wayland-scanner];
  buildInputs = [wayland xorg.libX11 xorg.libXext xorg.libxcb];

  configureFlags = [
    "--enable-wayland"
    "--enable-experimental"
    "--with-android-headers=${android-headers}/include/android"
    "--enable-arch=arm64"
  ];

  NIX_LDFLAGS = [
    # For libsupc++.a
    "-L${stdenv.cc.cc.out}/${libPrefix}/lib/"
  ];
}
