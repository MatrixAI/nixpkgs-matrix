{ system, lib }:

let
  polykey-cli-flake = builtins.getFlake
    "github:MatrixAI/Polykey-CLI/b102fdc7b456d1140817691a8623046aff6d8f70";
in lib.makeExtensible (self: {
  polykey-cli = polykey-cli-flake.packages.${system}.default;
  polykey-cli-docker = polykey-cli-flake.packages.${system}.docker;
})
