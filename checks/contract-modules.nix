{ lib
, system
, pkgs
, nixosModule
, homeModule
}:

let
  modulesInvariant =
    assert builtins.isFunction nixosModule;
    assert builtins.isFunction homeModule;
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
