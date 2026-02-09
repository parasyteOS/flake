{ qemu, fetchFromGitHub }:
  (qemu.override { hostCpuOnly = true; minimal = true; }).overrideAttrs (_: {
      src = fetchFromGitHub {
        owner = "parasyteOS";
        repo = "qemu";
        private = true;
        rev = "e39774f2db43677d53489343ad46ef537bbce5d2";
        hash = "sha256-ewhZlhL2qv3Rr4XcfoXXVA+Gg1jZK8qk27caNeVyjzg=";
      };
  })
