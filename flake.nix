{
  description = "Matrix AI Public Overlay";

  inputs = {
    nixpkgs.url =
      "github:NixOS/nixpkgs/a82ccc39b39b621151d6732718e3e250109076fa";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      nixpkgs_ = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      packages = final: prev: (nixpkgs_.callPackage ./packages.nix { });
      pkgs = nixpkgs_.extend packages;
    in {
      legacyPackages.${system} = pkgs;
      nixpkgs = nixpkgs_;
      lib = nixpkgs_.lib;

      templates = {
        internal = {
          path = ./templates/internal;
          description = "Matrix internal template using flake registry flake:nixpkgs-matrix";
        };

        external = {
          path = ./templates/external;
          description = "External template using github:MatrixAI/nixpkgs-matrix";
        };
      };
    };
}
