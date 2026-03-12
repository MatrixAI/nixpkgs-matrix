{ }:

let
  registry = {
    topLevel = {
      matrixai-public-hello = ./top-level/matrixai-public-hello.nix;
      polykey-cli = ./top-level/polykey-cli.nix;
    };

    scopes = {
      python3Packages = {
        jsonpyth = ./development/python-modules/jsonpyth;
        procpath = ./development/python-modules/procpath;
      };
    };
  };

  loadDefs = pkgSet: defs:
    builtins.mapAttrs (_: path: pkgSet.callPackage path { }) defs;
in {
  exportTopLevel = pkgs:
    loadDefs pkgs registry.topLevel;

  overlay = final: prev:
    loadDefs final registry.topLevel
    // builtins.mapAttrs
      (scopeName: defs:
        prev.${scopeName}.overrideScope
          (scopeFinal: _scopePrev: loadDefs scopeFinal defs))
      registry.scopes;
}
