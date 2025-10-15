{
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  wayland-scanner,
  scdoc,
  makeWrapper,
  wlroots_0_18,
  wayland,
  wayland-protocols,
  pixman,
  libxkbcommon,
  xcbutilwm,
  systemd,
  libGL,
  libX11,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "mew";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "parasyteOS";
    repo = "mew";
    rev = "e1b01f48c7e622101a1b494f16c4a4368be3a6b7";
    hash = "sha256-xbTfHAwZkF2bRFJlYL3ASZx419mpTj9DSXLRsrg/DvA=";
  };

  depsBuildBuild = [
    pkg-config
  ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    wayland-scanner
    scdoc
    makeWrapper
  ];

  buildInputs = [
    wlroots_0_18
    wayland
    wayland-protocols
    pixman
    libxkbcommon
    xcbutilwm
    systemd
    libGL
    libX11
  ];
})

