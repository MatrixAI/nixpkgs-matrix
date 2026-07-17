{ pkgs
, topLevelPackages
, legacyPackages
}:

pkgs.runCommand "smoke-vl-convert" { } ''
  "${topLevelPackages.vl-convert}/bin/vl-convert" --help >/dev/null
  "${legacyPackages.vl-convert}/bin/vl-convert" --help >/dev/null
  touch "$out"
''
