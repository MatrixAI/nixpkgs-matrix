# nixpkgs-matrix

Matrix AI's public Nix Packages collection.

## Contents

- [Installation](#installation)
  - [Internal (Matrix)](#internal-matrix)
  - [External / OSS](#external--oss)
  - [Why not `type = "indirect"`?](#why-not-type--"indirect")
- [Development](#development)
  - [Project structure](#project-structure)
- [License](#license)

## Installation

This repository is configured to support Flakes. Ensure flakes are enabled (e.g. via `nix.settings.experimental-features = [ "nix-command" "flakes" ];`).

### Internal (Matrix)

Prefer the Matrix registry so internal consumers resolve via `flake:nixpkgs-matrix` (stable IDs with Nix ≥ 2.26):

```nix
{
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
```

Registry can also be set globally: `nix.settings.flake-registry = "https://nix.matrix.ai/registry/flake-registry.json";`.

### External / OSS

External consumers should pin directly to the GitHub URL (optionally set the registry above to keep the indirect ID stable):

```nix
{
  inputs = {
    nixpkgs-matrix.url = "github:MatrixAI/nixpkgs-matrix";
  };

  outputs = inputs@{ nixpkgs-matrix, ... }:
    let
      system = "x86_64-linux";
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
```

### Why not `type = "indirect"`?

`type = "indirect"` inputs are rewritten during lockfile writes (notably with Nix 2.26), which can produce unstable IDs across environments. Matrix's approach is to use the global registry entry (`flake:nixpkgs-matrix`) for internal stability, while external users continue to consume the explicit GitHub URL.

## Development

This repository contains a few important files to look at when contributing to the project.

- `flake.nix` - Contains the base definition for the flake package. Re-exports our modified package set as an output.
- `packages.nix` - Custom packages are placed here. These entries use `builtins.getFlake` with explicit revisions for reproducibility; prefer wiring new dependencies through flake inputs unless a fixed-rev fetch is required.

### Project structure

```
/nixpkgs-matrix
├── flake.nix - The primary flake file.
└── packages.nix - This is where in-tree packages exist.
```

## License

The source code for this project is licensed under the Apache 2.0 License. You may find the conditions of the license [here](LICENSE).
