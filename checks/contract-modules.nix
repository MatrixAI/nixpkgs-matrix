{ lib
, system
, pkgs
, nixosModulesSet
, homeModulesSet
}:

let
  nixosModule = nixosModulesSet.default;
  homeModule = homeModulesSet.default;

  allNixosModules = builtins.attrValues nixosModulesSet;
  allHomeModules = builtins.attrValues homeModulesSet;

  modulesInvariant =
    assert builtins.isAttrs nixosModulesSet;
    assert builtins.hasAttr "default" nixosModulesSet;
    assert builtins.isAttrs homeModulesSet;
    assert builtins.hasAttr "default" homeModulesSet;
    assert builtins.isFunction nixosModule;
    assert builtins.isFunction homeModule;
    assert builtins.all builtins.isFunction allNixosModules;
    assert builtins.all builtins.isFunction allHomeModules;
    assert builtins.all
      (module: builtins.isAttrs (lib.nixosSystem {
        inherit system;
        modules = [ module ];
      }))
      allNixosModules;
    assert builtins.isAttrs (homeModule { });
    assert builtins.isAttrs (lib.nixosSystem {
      inherit system;
      modules = [ nixosModule ];
    });
    true;
in
pkgs.runCommand "contract-modules" { } ''
  ${if modulesInvariant then "true" else "false"}
  touch "$out"
''
