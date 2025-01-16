{
  lib,
  writeShellScriptBin,
  cortex,
  weave,
}: let
  inherit (lib) mapCartesianProduct;
  type = con: attr: ["type ${con} ${attr}"];
  permissive = con: ["permissive ${con}"];
  typeattribute = cons: attrs:
    mapCartesianProduct ({
      con,
      attr,
    }: "typeattribute ${con} ${attr}") {
      con = cons;
      attr = attrs;
    };
  allow = srcs: tgts: clses: perms:
    mapCartesianProduct ({
      src,
      tgt,
      cls,
      perm,
    }: "allow ${src} ${tgt} ${cls} ${perm}") {
      src = srcs;
      tgt = tgts;
      cls = clses;
      perm = perms;
    };
  allowxperm = srcs: tgts: clses: oprs: perms:
    mapCartesianProduct ({
      src,
      tgt,
      cls,
      opr,
      perm,
    }: "allowxperm ${src} ${tgt} ${cls} ${opr} ${perm}") {
      src = srcs;
      tgt = tgts;
      cls = clses;
      opr = oprs;
      perm = perms;
    };
  constructArgs = lib.concatMapStringsSep " \\\n" (rule: "'${rule}'");

  svcmgrs = ["servicemanager" "vndservicemanager" "hwservicemanager"];
  tmnt = "terminator";
  all = "*";

  rules = lib.concatLists [
    (type tmnt "domain")
    (typeattribute [tmnt] ["mlstrustedsubject" "netdomain" "appdomain"])
    (allow [tmnt] [all] [all] [all])
    (allowxperm [tmnt] [all] [all] ["ioctl"] [all])
    (permissive tmnt)

    (allow svcmgrs [tmnt] ["dir"] ["search"])
    (allow svcmgrs [tmnt] ["file"] ["open" "read" "map"])
    (allow svcmgrs [tmnt] ["process"] ["getattr"])
    (allow ["domain"] [tmnt] ["binder"] ["call" "transfer"])
    (allow ["domain"] [tmnt] ["process"] ["sigchld"])
    (allow ["domain"] [tmnt] ["fd"] ["use"])
    (allow ["domain"] [tmnt] ["fifo_file"] ["write" "read" "open" "getattr"])

    (allow ["zygote" "shell" "platform_app" "system_app" "priv_app" "untrusted_app" "untrusted_app_all"]
      [tmnt] ["unix_stream_socket"] ["connectto" "getopt"])
  ];
in
  writeShellScriptBin "dial" ''
    PRIV_KEY=$1
    ${cortex}/bin/cortex "$PRIV_KEY" dump |\
    ${weave}/bin/weave --load /dev/stdin --save /dev/stdout \
      ${constructArgs rules} |\
    ${cortex}/bin/cortex "$PRIV_KEY" load
  ''
