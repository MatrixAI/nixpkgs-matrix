{ system
, pkgs
, publicLib
, defaultOverlay
, topLevelPackages
, legacyPackages
, templatesSet
}:

let
  topLevelPackageNames = builtins.attrNames topLevelPackages;

  contractInvariant =
    assert builtins.isFunction defaultOverlay;
    assert builtins.isAttrs publicLib;
    assert builtins.hasAttr "gitignore" publicLib;
    assert builtins.isAttrs publicLib.gitignore;
    assert builtins.hasAttr "gitignoreSource" publicLib.gitignore;
    assert builtins.hasAttr "gitignoreFilter" publicLib.gitignore;
    assert builtins.isFunction publicLib.gitignore.gitignoreSource;
    assert builtins.isFunction publicLib.gitignore.gitignoreFilter;
    assert builtins.hasAttr "mkPkgs" publicLib;
    assert builtins.isFunction publicLib.mkPkgs || builtins.isAttrs publicLib.mkPkgs;
    assert builtins.isAttrs (publicLib.mkPkgs { inherit system; });
    assert builtins.isAttrs topLevelPackages;
    assert builtins.isAttrs legacyPackages;
    assert builtins.all (name: builtins.hasAttr name legacyPackages) topLevelPackageNames;
    assert builtins.isAttrs templatesSet;
    assert builtins.hasAttr "default" templatesSet;
    assert builtins.hasAttr "path" templatesSet.default;
    assert builtins.pathExists (templatesSet.default.path + "/flake.nix");
    true;
in
pkgs.runCommand "contract-outputs" { } ''
  ${if contractInvariant then "true" else "false"}
  touch "$out"
''
