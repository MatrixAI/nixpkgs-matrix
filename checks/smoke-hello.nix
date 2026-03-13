{ pkgs
, topLevelPackages
, legacyPackages
}:

pkgs.runCommand "smoke-hello" { } ''
  "${topLevelPackages."matrixai-public-hello"}/bin/hello" >/dev/null
  "${legacyPackages."matrixai-public-hello"}/bin/hello" >/dev/null
  touch "$out"
''
