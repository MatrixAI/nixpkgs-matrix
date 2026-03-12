{ stdenv }:

let
  system = stdenv.hostPlatform.system;
  polykey-cli-flake = builtins.getFlake
    "github:MatrixAI/Polykey-CLI/b72e05b3709dcc862fac428022c4b8bbe3e35f6e";
in
polykey-cli-flake.packages.${system}.default