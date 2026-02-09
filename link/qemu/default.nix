{ qemu, fetchFromGitHub, fetchFromGitLab }:
let
  dtc = fetchFromGitLab {
    owner = "qemu-project";
    repo = "dtc";
    rev = "b6910bec11614980a21e46fbccc35934b671bd81";
    hash = "sha256-gx9LG3U9etWhPxm7Ox7rOu9X5272qGeHqZtOe68zFs4=";
  };
  keycodemapdb = fetchFromGitLab {
    owner = "qemu-project";
    repo = "keycodemapdb";
    rev = "f5772a62ec52591ff6870b7e8ef32482371f22c6";
    hash = "sha256-GbZ5mrUYLXMi0IX4IZzles0Oyc095ij2xAsiLNJwfKQ=";
  };
  berkeley-softfloat-3 = fetchFromGitLab {
    owner = "qemu-project";
    repo = "berkeley-softfloat-3";
    rev = "b64af41c3276f97f0e181920400ee056b9c88037";
    hash = "sha256-Yflpx+mjU8mD5biClNpdmon24EHg4aWBZszbOur5VEA=";
  };
  berkeley-testfloat-3 = fetchFromGitLab {
    owner = "qemu-project";
    repo = "berkeley-testfloat-3";
    rev = "e7af9751d9f9fd3b47911f51a5cfd08af256a9ab";
    hash = "sha256-inQAeYlmuiRtZm37xK9ypBltCJ+ycyvIeIYZK8a+RYU=";
  };
in
  (qemu.override { hostCpuOnly = true; minimal = true; }).overrideAttrs (p: {
      src = fetchFromGitHub {
        owner = "parasyteOS";
        repo = "qemu";
        private = true;
        rev = "e39774f2db43677d53489343ad46ef537bbce5d2";
        hash = "sha256-ewhZlhL2qv3Rr4XcfoXXVA+Gg1jZK8qk27caNeVyjzg=";
      };
      prePatch = p.prePatch or "" + ''
        cp --no-preserve=all -R ${dtc} subprojects/dtc
        cp --no-preserve=all -R ${keycodemapdb} subprojects/keycodemapdb
        cp --no-preserve=all -R ${berkeley-softfloat-3} subprojects/berkeley-softfloat-3
        cp subprojects/packagefiles/berkeley-softfloat-3/* subprojects/berkeley-softfloat-3
        cp --no-preserve=all -R ${berkeley-testfloat-3} subprojects/berkeley-testfloat-3
        cp subprojects/packagefiles/berkeley-testfloat-3/* subprojects/berkeley-testfloat-3
      '';
  })
