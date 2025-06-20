{ system, lib }:

let
  polykey-cli-flake = builtins.getFlake
    "github:MatrixAI/Polykey-CLI/006ff6378f7abe7de16c609c333e7e5c10526d69";
in lib.makeExtensible (self: {
  polykey-cli = polykey-cli-flake.packages.${system}.default;
  polykey-cli-docker = polykey-cli-flake.packages.${system}.docker;
})
