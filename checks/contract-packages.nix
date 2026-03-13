{ pkgs
, topLevelPackages
, legacyPackages
}:

let
  packagesInvariant =
    assert builtins.hasAttr "matrixai-public-hello" topLevelPackages;
    assert builtins.hasAttr "polykey-cli" topLevelPackages;
    assert builtins.hasAttr "matrixai-public-hello" legacyPackages;
    assert builtins.hasAttr "polykey-cli" legacyPackages;
    assert builtins.hasAttr "python3Packages" legacyPackages;
    assert builtins.hasAttr "jsonpyth" legacyPackages.python3Packages;
    assert builtins.hasAttr "procpath" legacyPackages.python3Packages;
    true;
in
pkgs.runCommand "contract-packages" { } ''
  ${if packagesInvariant then "true" else "false"}
  touch "$out"
''
