{ nixpkgs ? import <nixpkgs> { overlays = import ./overlays.nix; } }:

nixpkgs.mkShell {
  buildInputs = with nixpkgs; [
    polykey-cli
  ];
}

