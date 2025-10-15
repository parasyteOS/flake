{
  writeText,
  writeShellScript,
  coreutils,
  util-linux,
  bashInteractive,
  iproute2,
  iptables,
  gnugrep,
  gnused,
  lib,
  lxc,
  jar,
}: let
  ip = "${iproute2}/bin/ip";
  sed = "${gnused}/bin/sed";
  grep = "${gnugrep}/bin/grep";
  iptables' = "${iptables}/bin/iptables-legacy";
  bottle = writeText "bottle" ''
    lxc.arch = arm64
    lxc.uts.name = nixos
    lxc.rootfs.path = dir:/jar
    lxc.tty.dir = lxc
    lxc.tty.max = 6
    lxc.pty.max = 1024

    lxc.environment = TERM

    lxc.mount.auto = proc:rw sys:rw
    lxc.mount.entry = /nix nix none rbind,create=dir
    lxc.mount.entry = /hat hat none rbind,create=dir
    lxc.mount.entry = /mnt mnt none rbind,create=dir
    lxc.mount.entry = /mnt/data/data/com.termux/files/usr/tmp tmp/h none rbind,create=dir
    lxc.mount.entry = /mnt/dev/dri      dev/dri      none rbind,create=dir
    lxc.mount.entry = /mnt/dev/dma_heap dev/dma_heap none rbind,optional,create=dir
    lxc.mount.entry = /mnt/dev/kgsl-3d0 dev/kgsl-3d0 none rbind,optional,create=file

    lxc.net.0.type = veth
    lxc.net.0.link = lxcbr0
    lxc.net.0.flags = up
    lxc.net.0.ipv4.address = 10.0.3.100/24
    lxc.net.0.ipv4.gateway = 10.0.3.1
    lxc.hook.pre-start = ${writeShellScript "lxc-bridge-up" ''
      exec 2>&1
      set -x
      ${ip} link add lxcbr0 type bridge
      ${ip} link set lxcbr0 up
      ${ip} addr add 10.0.3.1/24 dev lxcbr0
      ${ip} rule add from 10.0.3.0/24 lookup main pref 1
      ${ip} rule add to   10.0.3.0/24 lookup main pref 1
      ${ip} rule add from 10.0.3.0/24 lookup default pref 2
      ${ip} rule add to   10.0.3.0/24 lookup default pref 2
      echo 1 > /proc/sys/net/ipv4/ip_forward
    ''}
    lxc.net.0.script.up = ${writeShellScript "lxc-net-up" ''
      exec 2>&1
      set -x
      ${iptables'} -t nat -I POSTROUTING -s 10.0.3.0/24 ! -d 10.0.3.0/24 -j MASQUERADE
      ${iptables'} -I FORWARD -i lxcbr0 -j ACCEPT
      ${iptables'} -I FORWARD -o lxcbr0 -j ACCEPT
    ''}
    lxc.net.0.script.down = ${writeShellScript "lxc-net-down" ''
      exec 2>&1
      set -x
      ${iptables'} -D FORWARD -o lxcbr0 -j ACCEPT
      ${iptables'} -D FORWARD -i lxcbr0 -j ACCEPT
      ${iptables'} -t nat -D POSTROUTING -s 10.0.3.0/24 ! -d 10.0.3.0/24 -j MASQUERADE
    ''}
    lxc.hook.post-stop = ${writeShellScript "lxc-bridge-down" ''
      exec 2>&1
      set -x
      ${ip} rule del to   10.0.3.0/24 lookup default pref 2
      ${ip} rule del from 10.0.3.0/24 lookup default pref 2
      ${ip} rule del to   10.0.3.0/24 lookup main pref 1
      ${ip} rule del from 10.0.3.0/24 lookup main pref 1
      ${ip} link set lxcbr0 down
      ${ip} link delete lxcbr0
    ''}

    lxc.init.cmd = ${jar.config.system.build.toplevel}/init systemd.unified_cgroup_hierarchy=1
  '';
in
  writeShellScript "simulate" ''
    set -mex

    ${coreutils}/bin/mkdir -m 0755 /lxc
    ${coreutils}/bin/mkdir -m 0755 /run
    ${coreutils}/bin/mkdir -m 0755 /bin
    ${coreutils}/bin/mkdir -m 0755 /jar

    ${coreutils}/bin/mkdir -m 0755 /proc
    ${util-linux}/bin/mount -t proc proc /proc

    ${coreutils}/bin/mkdir -m 0755 /sys
    # TODO: what exactly is required to make iptables work
    ${util-linux}/bin/mount --rbind /mnt/sys /sys

    ${coreutils}/bin/mkdir -m 0755 /dev
    ${util-linux}/bin/mount -t devtmpfs devtmpfs /dev
    ${coreutils}/bin/mkdir -m 0755 -p /dev/pts
    ${util-linux}/bin/mount -t devpts devpts /dev/pts

    ${coreutils}/bin/ln -s ${lib.getExe' bashInteractive "sh"} /bin/sh

    ${coreutils}/bin/sync

    ${writeShellScript "fix-route" ''
      fixRoute(){
        ROUTE=$(${ip} route get 8.8.8.8)
        GATEWAY=$(echo $ROUTE|${sed} -nE 's/.*via ([^ ]+).*/\1/p') 
        DEVICE=$(echo $ROUTE|${sed} -nE 's/.*dev ([^ ]+).*/\1/p') 
        if [[ -z "$GATEWAY" || -z "$DEVICE" ]];then
          return
        fi

        if ! ${ip} route | ${grep} -q "default via $GATEWAY dev $DEVICE";then
          ${ip} route replace default via "$GATEWAY" dev "$DEVICE"
        fi
      }

      fixRoute

      ${ip} monitor route|while read -r change;do
        ${coreutils}/bin/sleep 1
        fixRoute
      done
    ''} &
    FIXROUTE_PID=$!

    ${lxc}/bin/lxc-start -F -n bottle --lxcpath /lxc -f "${bottle}" "$@"

    ${coreutils}/bin/kill -- "-$FIXROUTE_PID"
  ''
