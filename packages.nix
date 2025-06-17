{ system, lib }:

let
  polykey-cli-flake = builtins.getFlake
    "github:MatrixAI/Polykey-CLI/094c48fee10211fbae9ca7dd1eca5cfec7f2b928";
in lib.makeExtensible (self: {
  polykey-cli = polykey-cli-flake.packages.${system}.default;
  polykey-cli-docker = polykey-cli-flake.packages.${system}.docker;
})
