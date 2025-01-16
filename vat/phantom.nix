{
  writeText,
  writeShellScript,
  coreutils,
  util-linux,
  lxc,
  jar,
}: let
  bottle = writeText "bottle" ''
    lxc.arch = arm64
    lxc.uts.name = nixos
    lxc.rootfs.path = dir:/jar
    lxc.tty.dir = lxc
    lxc.tty.max = 6
    lxc.pty.max = 1024

    lxc.mount.auto = proc:rw sys:rw

    lxc.mount.entry = /mnt/dev/dma_heap dev/dma_heap none bind,optional,create=dir
    lxc.mount.entry = /mnt/dev/kgsl-3d0 dev/kgsl-3d0 none bind,optional,create=file

    lxc.net.0.type = none
    lxc.init.cmd = ${jar.config.system.build.toplevel}/init systemd.unified_cgroup_hierarchy=1
  '';
in
  writeShellScript "simulate" ''
    set -ex

    ${coreutils}/bin/mkdir -m 0755 /lxc
    ${coreutils}/bin/mkdir -m 0755 /run
    ${coreutils}/bin/mkdir -m 0755 /run/pivot

    ${coreutils}/bin/mkdir -m 0755 /jar
    ${coreutils}/bin/mkdir -m 0755 /jar/{hat,nix,tmp,mnt}
    ${util-linux}/bin/mount --rbind /nix /jar/nix
    ${util-linux}/bin/mount --rbind /hat /jar/hat
    ${util-linux}/bin/mount --rbind /mnt /jar/mnt
    ${util-linux}/bin/mount --rbind /mnt/data/data/com.termux/files/usr/tmp /jar/tmp

    ${coreutils}/bin/mkdir -m 0755 /proc
    ${util-linux}/bin/mount -t proc proc /proc

    ${coreutils}/bin/mkdir -m 0755 /sys
    ${util-linux}/bin/mount -t sysfs sysfs /sys

    ${coreutils}/bin/mkdir -m 0755 /dev
    ${util-linux}/bin/mount -t devtmpfs devtmpfs /dev
    ${coreutils}/bin/mkdir -m 0755 -p /dev/pts
    ${util-linux}/bin/mount -t devpts devpts /dev/pts

    exec ${lxc}/bin/lxc-start -F -n bottle --lxcpath /lxc -f "${bottle}" "$@"
  ''
