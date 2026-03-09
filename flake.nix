{
  description = "Matrix AI Public Overlay";

  inputs = {
    nixpkgs.url =
      "github:NixOS/nixpkgs/a82ccc39b39b621151d6732718e3e250109076fa";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      defaultOverlay = import ./overlays/default.nix;
      mkPkgs = import ./lib/mkPkgs.nix {
        inherit nixpkgs;
        inherit defaultOverlay;
      };
      nixpkgs_ = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      publicLib = nixpkgs_.lib // (import ./lib/default.nix { inherit mkPkgs; });
    in {
      overlays.default = defaultOverlay;

      legacyPackages.${system} = publicLib.mkPkgs {
        inherit system;
        config.allowUnfree = true;
      };

      nixpkgs = nixpkgs_;
      lib = publicLib;

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
