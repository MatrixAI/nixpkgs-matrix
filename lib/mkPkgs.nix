/*
  Construct a package set augmenting an existing package set.

  Signature:

    mkPkgs :: { system, overlays ? [ ], config ? { } } -> pkgs

  Construction-time arguments:
    lib:
      nixpkgs lib, used for assertion helpers.

    mkPkgsUpstream:
      Upstream package-set constructor.

    overlay:
      Overlay of packages applied by default.

  Call-time arguments:
    system:
      Target system string, e.g. "x86_64-linux".

    overlays:
      Additional overlays applied after the default overlay.

    config:
      nixpkgs config attrset passed through to mkPkgsUpstream.

  Result:
    A package set that should be layered like:

      starting at nixpkgs
        -> prior overlay(s)
        -> default overlay
        -> caller-supplied overlays
*/

{ lib
, overlay
, mkPkgsUpstream
}:

assert lib.asserts.assertMsg (builtins.isFunction mkPkgsUpstream)
  "mkPkgsUpstream must be a function";
assert lib.asserts.assertMsg (builtins.isFunction overlay)
  "overlay must be a function";

{ system
, overlays ? [ ]
, config ? { }
}:

assert lib.asserts.assertMsg (builtins.isString system)
  "system must be a string";
assert lib.asserts.assertMsg (builtins.isList overlays)
  "overlays must be a list";
assert lib.asserts.assertMsg (builtins.isAttrs config)
  "config must be an attrset";

mkPkgsUpstream {
  inherit system config;
  overlays = [ overlay ] ++ overlays;
}
