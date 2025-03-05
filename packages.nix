{ system, lib }:

let
  polykey-cli-flake = builtins.getFlake
    "github:MatrixAI/Polykey-CLI/f325edefc2b6f74b049811c8c9d4c36306cd7efd";
in lib.makeExtensible (self: {
  polykey-cli = polykey-cli-flake.packages.${system}.default;
  polykey-cli-docker = polykey-cli-flake.packages.${system}.docker;
})
