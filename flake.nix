{
  description = "Matrix AI Public Overlay";

  inputs = {
    # BEGIN: nixpkgs-pin (managed by scripts/nixpkgs-pin-policy.sh)
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      rev = "a82ccc39b39b621151d6732718e3e250109076fa";
    };
    # END: nixpkgs-pin
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      defaultOverlay = import ./overlays;
      publicLib = (import ./lib { 
        lib = nixpkgs.lib;
        overlay = defaultOverlay;
        mkPkgsUpstream = { system, overlays ? [ ], config ? { } }:
          import nixpkgs {
            inherit system overlays config;
          };
      });
      pkgsFor = system: 
        publicLib.mkPkgs {
          inherit system;
          config.allowUnfree = true;
        };
      pkgs = pkgsFor system;
    in rec {
      lib = publicLib;

      overlays.default = defaultOverlay;

      legacyPackages.${system} = pkgs;

      packages.${system} = (import ./pkgs { }).exportTopLevel pkgs;

      nixosModules = {
        default = import ./modules/nixos/default.nix;
      };

      # Home-Manager modules
      homeModules = {
        default = import ./modules/home/default.nix;
      };
      homeManagerModules = homeModules;
    };
}
