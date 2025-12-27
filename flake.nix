{
  description = "Matrix AI Public Overlay";

  inputs = {
    nixpkgs.url =
      "github:NixOS/nixpkgs/0d2b38f933f51002f4949a53d52b3eff0026ba0c";
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

