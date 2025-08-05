{
  description = "Matrix AI Public Overlay";

  inputs = {
    nixpkgs.url =
      "github:NixOS/nixpkgs/5b09dc45f24cf32316283e62aec81ffee3c3e376";
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
    };
}

