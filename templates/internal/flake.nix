{
  description = "Template: Matrix internal consumption via flake registry";

  nixConfig = {
    flake-registry = "https://nix.matrix.ai/registry/flake-registry.json";
    experimental-features = [ "nix-command" "flakes" ];
  };

  inputs = {
    nixpkgs-matrix.url = "flake:nixpkgs-matrix";
  };

  outputs = inputs@{ nixpkgs-matrix, ... }:
    let
      system = builtins.currentSystem or "x86_64-linux";
      pkgs = nixpkgs-matrix.legacyPackages.${system};
    in {
      nixosConfigurations.example = nixpkgs-matrix.lib.nixosSystem {
        specialArgs = { inherit inputs system; };
        modules = [ ./configuration.nix ];
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.hello ];
      };
    };
}
