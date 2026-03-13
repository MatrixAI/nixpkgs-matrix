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

    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ nixpkgs, flake-parts, ... }:
    let
      system = "x86_64-linux";

      defaultOverlay = import ./overlays;

      publicLib = import ./lib {
        lib = nixpkgs.lib;
        overlay = defaultOverlay;
        mkPkgsUpstream = { system, overlays ? [ ], config ? { } }:
          import nixpkgs {
            inherit system overlays config;
          };
      };

      pkgsFor = system:
        publicLib.mkPkgs {
          inherit system;
          config.allowUnfree = true;
        };

      pkgs = pkgsFor system;

      topLevelPackages = (import ./pkgs { }).exportTopLevel pkgs;

      nixosModule = import ./modules/nixos/default.nix;
      homeModule = import ./modules/home/default.nix;

      nixosModulesSet = {
        default = nixosModule;
      };

      homeModulesSet = {
        default = homeModule;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ system ];

      flake = rec {
        lib = publicLib;

        overlays.default = defaultOverlay;

        legacyPackages.${system} = pkgs;

        packages.${system} = topLevelPackages;

        checks.${system} = import ./checks/default.nix {
          lib = nixpkgs.lib;
          inherit
            system
            pkgs
            publicLib
            defaultOverlay
            topLevelPackages
            nixosModule
            homeModule
            ;
          legacyPackages = pkgs;
        };

        nixosModules = nixosModulesSet;

        homeModules = homeModulesSet;
      };

      perSystem = { pkgs, ... }: {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.nix
            pkgs.git
            pkgs.gnugrep
            pkgs.gawk
            pkgs.coreutils
            pkgs.gnused
            pkgs.findutils
            pkgs.curl
            pkgs.wget
          ];
        };
      };
    };
}
