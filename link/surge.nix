{
  writeShellScriptBin,
  cortex,
  sheath,
}:
writeShellScriptBin "surge" ''
  ${cortex}/bin/cortex "$1" su ${sheath}/bin/sheath
''
