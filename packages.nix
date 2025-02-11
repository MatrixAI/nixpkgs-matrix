{ system, lib }:

lib.makeExtensible (self: {
  polykey-cli = (builtins.getFlake
    "github:MatrixAI/Polykey-CLI/022856be82ff26335f366f509b5fdd6fe0edc8a6").packages.${system}.default;
  polykey-cli-docker = (builtins.getFlake
    "github:MatrixAI/Polykey-CLI/022856be82ff26335f366f509b5fdd6fe0edc8a6").packages.${system}.docker;
})
