{
  description = "Template: External OSS consumption via GitHub URL";

  # Optional: pointing at the Matrix registry keeps the indirect ID stable; safe to remove if undesired.
  nixConfig.flake-registry = "https://nix.matrix.ai/registry/flake-registry.json";

  inputs = {
    nixpkgs-matrix.url = "github:MatrixAI/nixpkgs-matrix";
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
