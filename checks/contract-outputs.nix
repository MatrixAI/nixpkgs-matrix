{ system
, pkgs
, publicLib
, defaultOverlay
, topLevelPackages
, legacyPackages
, templatesSet
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
    assert builtins.isAttrs templatesSet;
    assert builtins.hasAttr "oss" templatesSet;
    assert builtins.hasAttr "default" templatesSet;
    assert templatesSet.default.path == templatesSet.oss.path;
    assert templatesSet.default.path == ../templates/oss;
    assert builtins.pathExists (templatesSet.default.path + "/flake.nix");
    true;
in
pkgs.runCommand "contract-outputs" { } ''
  ${if contractInvariant then "true" else "false"}
  touch "$out"
''
