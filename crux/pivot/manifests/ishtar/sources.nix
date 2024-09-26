{pkgs, ...}: {
  sources = {
    "build/kernel" = {
      repo = "kernel/build";
      rev = "32d2db6179111b26cf1f523de91e1fe67fec4c29";
      hash = "sha256-WeJKaqNW/iRZkrWGuu6IeEHf3VfiqwlobQeMuoutILg=";
      patches = [./fix-build.patch];
      fixup = true;
      links = {
        "tools/bazel" = "kleaf/bazel.sh";
        "WORKSPACE" = "kleaf/bazel.WORKSPACE";
        "build/build.sh" = "build.sh";
        "build/build_abi.sh" = "build_abi.sh";
        "build/build_test.sh" = "build_test.sh";
        "build/build_utils.sh" = "build_utils.sh";
        "build/config.sh" = "config.sh";
        "build/envsetup.sh" = "envsetup.sh";
        "build/_setup_env.sh" = "_setup_env.sh";
        "build/multi-switcher.sh" = "multi-switcher.sh";
        "build/abi" = "abi";
        "build/static_analysis" = "static_analysis";
      };
    };
    "common" = {
      repo = "kernel/common";
      rev = "3ca6a2912c7e6f416930ce3dbb26381cb04ec8d5";
      hash = "sha256-8hBCkwknNW4lZdOAU7E4NHtuJ7CSf7sMpV3ZgBhR2vo=";
      fixup = true;
      links = {
        ".source_date_epoch_dir" = ".";
      };
    };
    "kernel/tests" = {
      repo = "kernel/tests";
      rev = "42a77670ce44d6e19a6fbb8b93fa0b06f009a3a4";
      hash = "sha256-8rNkUbQp7uA43R/PFQPIEdZyUpALfEef0f00hTmLzPA=";
    };
    "kernel/configs" = {
      repo = "kernel/configs";
      rev = "b3cc2bc03dab303c54a9ce1f709f8ee315eb311d";
      hash = "sha256-eYuxFfmNG2PGNlqPME4g2xIoEvH+/c8634ZQ2YngNFY=";
    };
    "common-modules/virtual-device" = {
      repo = "kernel/common-modules/virtual-device";
      rev = "deede4fddac274575cb0e26498fc0f4a718229fb";
      hash = "sha256-puK1adjMIEztxJFPdCsVLKwUstXW+Dcb/YcjGobLo50=";
    };
    "tools/mkbootimg" = {
      repo = "platform/system/tools/mkbootimg";
      rev = "2208a03d874255af1e4eaf6cf7c156fe1dc98943";
      hash = "sha256-6P/TNGeYgBbh27tvamqFg7vvtahrmf6Y3F3uNb01HKc=";
      fixup = true;
    };
    "external/bazel-skylib" = {
      repo = "platform/external/bazel-skylib";
      rev = "f1fb8167b4ed64feb494fd1ea6a8a619bbb549de";
      hash = "sha256-rsl1XpgvKt2cQbgzcEJsvwMbd8LohwJchBOMYv62za4=";
    };
    "build/bazel_common_rules" = {
      repo = "platform/build/bazel_common_rules";
      rev = "ddd2d82d10e21fb4137d2db3c1b848d6f1832acc";
      hash = "sha256-WmkEBitkyZQFMQqx+tlnR1hpdx5gRqg4wA2EJSUwo4s=";
    };
    "external/stardoc" = {
      repo = "platform/external/stardoc";
      rev = "b6ef2c6b6e39087f7396aaeb13c83464dfce4a19";
      hash = "sha256-VZaFpHUvELqZcAqnHmCWInnVXwgfI4zGyLZwsxQ2z8s=";
    };
    "external/python/absl-py" = {
      repo = "platform/external/python/absl-py";
      rev = "63f98de5b158481877489ca39158ed691f7551e1";
      hash = "sha256-9a2vZrURkZZpB+9XPaWEBvUJyEQoIP/wr7b0N37/aXQ=";
    };

    # TODO: Avoid prebuilt binaries
    "prebuilts/clang/host/linux-x86" = {
      repo = "platform/prebuilts/clang/host/linux-x86";
      rev = "9f759dee5cdc5f85d076c642a192f6a9232f7058";
      hash = "sha256-3xuJibLDfoZn3PbBtjCNfBiKsiZuNMmdxY9wEKG0nqc=";
      fixup = true;
    };
    "prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8" = {
      repo = "platform/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8";
      rev = "007101a451907c5369db5002ddf7b14dcefb7864";
      hash = "sha256-xSiEg+muBtpGJXoUiekpi0ePm/6kEQvu3dGjfbuyXkg=";
      fixup = true;
    };
    "prebuilts/build-tools" = {
      repo = "platform/prebuilts/build-tools";
      rev = "f6813860e16b2fa1461a15e7b8a3127dfdee021a";
      hash = "sha256-eTZWpMqywQHXmcPF+6EtRCK5A4cjIo+Dl2ysPJGW3dA=";
      fixup = true;
    };
    "prebuilts/kernel-build-tools" = {
      repo = "kernel/prebuilts/build-tools";
      rev = "083e34d8c2c4239be4967172427268c267585951";
      hash = "sha256-iNyTOnc1r+GjnwGnoEnq/yfEN8jb98iZrMGuJ3YGQlI=";
      fixup = true;
    };
    "prebuilts/ndk-r23" = {
      repo = "toolchain/prebuilts/ndk/r23";
      rev = "93532f3052c14fbb337ff57d5732128dc7481ee6";
      hash = "sha256-BIZeRhT8/wsZT4s9tXNbYLDdHmV7HNic7nyqkPUk4QU=";
      fixup = true;
    };
  };
}
