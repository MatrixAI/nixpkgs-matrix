{ system
, pkgs
, publicLib
, defaultOverlay
, topLevelPackages
, legacyPackages
}:

let
  contractInvariant =
    assert builtins.isFunction defaultOverlay;
    assert builtins.isAttrs publicLib;
    assert builtins.hasAttr "mkPkgs" publicLib;
    assert builtins.isFunction publicLib.mkPkgs || builtins.isAttrs publicLib.mkPkgs;
    assert builtins.isAttrs (publicLib.mkPkgs { inherit system; });
    assert builtins.hasAttr "matrixai-public-hello" topLevelPackages;
    assert builtins.hasAttr "polykey-cli" topLevelPackages;
    assert builtins.hasAttr "python3Packages" legacyPackages;
    assert builtins.hasAttr "jsonpyth" legacyPackages.python3Packages;
    assert builtins.hasAttr "procpath" legacyPackages.python3Packages;
    true;
in
pkgs.runCommand "contract-outputs" { } ''
  ${if contractInvariant then "true" else "false"}
  touch "$out"
''
