{
  description = "Matrix AI Public Overlay";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?rev=a1ff35c63891ec9e4df75189427a5d81b5882bb9"; # Pinned to revision
    flake-utils.url = "github:numtide/flake-utils"; # No pinning needed (doesn't use nixpkgs)

    # Custom packages
    polykey-cli.url = "github:MatrixAI/Polykey-CLI?rev=2bcebd05046bbae86a7b9da67e22613720952627";
    polykey-cli.inputs.nixpkgs.follows = "nixpkgs"; # Inheriting the nixpkgs input above; pinned
  };

  outputs = inputs@{ nixpkgs, flake-utils, ... }:
    let
      overlay = import ./overlays/overlay.nix {
        inherit inputs; # Import the inputs into the overlay.nix
      };

      modules = import ./modules/module-list.nix {
        inherit inputs; # Same here
      };
    in
    {
      overlays.default = overlay; # Overlay exposed to external flakes

      nixosModules.default = modules; # Modules exposed to external flakes
    } //

    # The rest of this code is for testing purposes
    flake-utils.lib.eachSystem flake-utils.lib.allSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        devShells.default = with pkgs; mkShell {
          inputsFrom = [
            polykey-cli
          ];
        };
      }
    );
}
