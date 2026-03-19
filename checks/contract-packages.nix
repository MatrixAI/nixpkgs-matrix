{ lib
, pkgs
, topLevelPackages
, legacyPackages
}:

let
  topLevelPackageNames = builtins.attrNames topLevelPackages;

  packagesInvariant =
    assert builtins.isAttrs topLevelPackages;
    assert builtins.isAttrs legacyPackages;
    assert builtins.all (name: builtins.hasAttr name legacyPackages) topLevelPackageNames;
    assert builtins.all (name: lib.isDerivation topLevelPackages.${name}) topLevelPackageNames;
    assert builtins.all (name: lib.isDerivation legacyPackages.${name}) topLevelPackageNames;
    true;
in
pkgs.runCommand "contract-packages" { } ''
  ${if packagesInvariant then "true" else "false"}
  touch "$out"
''
