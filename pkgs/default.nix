{ system }:

let
  defs = {
    topLevel = pkgs:
      let
        polykey-cli-flake = builtins.getFlake
          "github:MatrixAI/Polykey-CLI/b72e05b3709dcc862fac428022c4b8bbe3e35f6e";
      in {
        matrixai-public-hello = pkgs.hello;
        polykey-cli = polykey-cli-flake.packages.${system}.default;
        polykey-cli-docker = polykey-cli-flake.packages.${system}.docker;
      };

    scopes = {
      python3Packages = pyPkgs: {
        jsonpyth = pyPkgs.callPackage ./development/python-modules/jsonpyth { };
        procpath = pyPkgs.callPackage ./development/python-modules/procpath { };
      };
    };
  };

  applyScopesOverlay = final: prev: scopes:
    builtins.mapAttrs
      (scopeName: mkScope:
        prev.${scopeName}.overrideScope
          (scopeFinal: _scopePrev: mkScope scopeFinal))
      scopes;

  applyScopesProject = pkgs: scopes:
    builtins.mapAttrs
      (scopeName: mkScope: mkScope pkgs.${scopeName})
      scopes;
in {
  overlay = final: prev:
    defs.topLevel final
    // applyScopesOverlay final prev defs.scopes;

  project = pkgs:
    defs.topLevel pkgs
    // applyScopesProject pkgs defs.scopes;
}