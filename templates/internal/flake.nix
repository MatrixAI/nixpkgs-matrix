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
      # Canonical constructor path
      pkgs = nixpkgs-matrix.lib.mkPkgs {
        inherit system;
        config.allowUnfree = true;
      };
      # Compatibility fallback (major v1 contract window only):
      # pkgs = nixpkgs-matrix.legacyPackages.${system};
    in {
      nixosConfigurations.example = nixpkgs-matrix.lib.nixosSystem {
        specialArgs = { inherit inputs system; };
        modules = [
          nixpkgs-matrix.nixosModules.default
          ./configuration.nix
        ];
      };

      homeConfigurations.example =
        nixpkgs-matrix.homeModules.default;
      # Compatibility alias (equivalent surface):
      # homeConfigurations.example = nixpkgs-matrix.homeManagerModules.default;

      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.hello ];
      };
    };
}
