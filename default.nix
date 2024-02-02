{ nixpkgs ? import ./nixpkgs.nix }:

import nixpkgs {
  overlays = import ./overlays.nix;
}
