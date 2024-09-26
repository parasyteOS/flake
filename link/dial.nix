{
  writeShellScriptBin,
  cortex,
  weave,
}:
writeShellScriptBin "dial" ''
  PRIV_KEY=$1
  ${cortex}/bin/cortex "$PRIV_KEY" dump |\
  ${weave}/bin/weave --load /dev/stdin --save /dev/stdout \
    'type terminator domain' \
    'allow terminator * * *' \
    'allowxperm terminator * * ioctl *' \
    'permissive terminator' |\
  ${cortex}/bin/cortex "$PRIV_KEY" load
''
