{
  description = "Minimal starter consuming nixpkgs-matrix via lib.mkPkgs";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-matrix.url = "github:MatrixAI/nixpkgs-matrix";
  };

  outputs = inputs@{ flake-parts, nixpkgs-matrix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      perSystem = { system, ... }:
        let
          pkgs = nixpkgs-matrix.lib.mkPkgs {
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
