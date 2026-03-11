/*
  Constructing the lib attribute set.
*/

{ lib
, overlay
, mkPkgsUpstream
}:

lib.makeScope lib.callPackageWith (self: {
  inherit lib;

  # Explicit DI entrypoint for library files
  callLib = self.callPackage;

  # Library exports
  mkPkgs = self.callPackage ./mkPkgs.nix {
    mkPkgsUpstream = mkPkgsUpstream;
    overlay = overlay;
  };
})
