{ system, lib }:

let
  polykey-cli-flake = builtins.getFlake
    "github:MatrixAI/Polykey-CLI/8bee0de0adedb64645a6ea48ddb63330c348b713";
in lib.makeExtensible (self: {
  polykey-cli = polykey-cli-flake.packages.${system}.default;
  polykey-cli-docker = polykey-cli-flake.packages.${system}.docker;
})
