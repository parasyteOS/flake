{
  lib,
  androidenv,
  runCommand,
  buildGradlePackage,
  autoPatchelfHook,
  fetchurl,
  fetchFromGitHub,
  gradle_7,
  openjdk11,
}: let
  env = androidenv.composeAndroidPackages {
    buildToolsVersions = ["30.0.2"];
    platformVersions = ["28" "30"];
    includeNDK = true;
    ndkVersions = ["22.1.7171670"];
  };
  downloadBootstrap = arch: version: sha256:
    fetchurl {
      url = "https://github.com/termux/termux-packages/releases/download/bootstrap-${version}/bootstrap-${arch}.zip";
      inherit sha256;
    };
  version = "2024.06.17-r1+apt-android-7";
  bootstraps = {
    "aarch64" = downloadBootstrap "aarch64" version "91a90661597fe14bb3c3563f5f65b243c0baaec42f2bc3d2243ff459e3942fb6";
    "arm" = downloadBootstrap "arm" version "d54b5eb2a305d72f267f9704deaca721b2bebbd3d4cca134aec31da719707997";
    "i686" = downloadBootstrap "i686" version "06a51ac1c679d68d52045509f1a705622c8f41748ef753660e31e3b6a846eba2";
    "x86_64" = downloadBootstrap "x86_64" version "4c8e43474c8d9543e01d4cbf3c4d7f59bbe4d696c38f6dece2b6ab3ba8881f2e";
  };
in
  buildGradlePackage {
    pname = "grid";
    version = "0.118.1";
    src = fetchFromGitHub {
      owner = "parasyteOS";
      repo = "grid";
      rev = "43317b78c920a48254f8846f5e14b5f873faa271";
      hash = "sha256-Es1eSADqrUR940V9g1T0AxohLGluBvpCLBak6Jotj5A=";
    };
    lockFile = ./gradle.lock;
    overrides = {
      "com.android.tools.build:aapt2:4.2.2-7147631" = {
        "aapt2-4.2.2-7147631-linux.jar" = src:
          runCommand src.name {
            nativeBuildInputs = [openjdk11 autoPatchelfHook];
            dontAutoPatchelf = true;
            autoPatchelfIgnoreMissingDeps = ["libgcc_s.so.1"];
          } ''
            cp ${src} aapt2.jar
            jar xf aapt2.jar aapt2
            chmod +x aapt2
            autoPatchelf aapt2
            jar uf aapt2.jar aapt2
            cp aapt2.jar $out
          '';
      };
    };

    ANDROID_SDK_ROOT = "${env.androidsdk}/libexec/android-sdk";

    preBuild = with lib;
      concatStringsSep "\n" (mapAttrsToList (arch: zip: ''
          cp --no-preserve=all ${zip} app/src/main/cpp/bootstrap-${arch}.zip
        '')
        bootstraps);

    gradle = gradle_7;
    gradleBuildFlags = ["assembleRelease"];
    buildJdk = openjdk11;

    installPhase = ''
      mkdir -p $out
      cp app/build/outputs/apk/release/*.apk $out
    '';
  }
