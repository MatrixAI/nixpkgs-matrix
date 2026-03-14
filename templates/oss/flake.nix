{
  description = "Minimal starter consuming nixpkgs-matrixai via lib.mkPkgs";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-matrixai.url = "github:MatrixAI/nixpkgs-matrixai";
  };

  outputs = inputs@{ flake-parts, nixpkgs-matrixai, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      perSystem = { system, ... }:
        let
          pkgs = nixpkgs-matrixai.lib.mkPkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.nix
              pkgs.git
              pkgs."matrixai-public-hello"
            ];
          };
        };
    };
}
