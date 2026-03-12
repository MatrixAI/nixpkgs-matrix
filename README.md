# nixpkgs-matrix

Matrix AI public Nix package and module distribution flake.

## Contents

- [What this flake exports](#what-this-flake-exports)
- [Architecture model](#architecture-model)
  - [Constructor path (`lib.mkPkgs`)](#constructor-path-libmkpkgs)
  - [Package registry and projection (`pkgs/default.nix`)](#package-registry-and-projection-pkgsdefaultnix)
  - [Overlay adapter (`overlays/default.nix`)](#overlay-adapter-overlaysdefaultnix)
- [Consumer usage examples (replaces flake templates)](#consumer-usage-examples-replaces-flake-templates)
  - [Internal (Matrix registry)](#internal-matrix-registry)
  - [External / OSS (GitHub input)](#external--oss-github-input)
- [Why templates are not exported](#why-templates-are-not-exported)
- [Development](#development)
  - [Adding packages](#adding-packages)
  - [Module placeholders](#module-placeholders)
  - [Cross-repo consumption checks](#cross-repo-consumption-checks)

## What this flake exports

`nixpkgs-matrix` is the public producer flake. The contract surface is defined by `outputs` in `flake.nix`.

| Output | Purpose |
| --- | --- |
| `lib` | Public helper scope from `lib/default.nix`; includes upstream `nixpkgs.lib` under `lib.lib` and constructor helpers such as `lib.mkPkgs`. |
| `overlays.default` | Canonical project overlay from `overlays/default.nix`. |
| `legacyPackages.${system}` | Compatibility package set produced via `lib.mkPkgs`. |
| `packages.${system}` | Curated flat top-level installables projection from `pkgs/default.nix` (`exportTopLevel` path). |
| `nixosModules.default` | Public NixOS module entrypoint. |
| `homeModules.default` | Public Home Manager module entrypoint. |
| `homeManagerModules` | Compatibility alias to `homeModules`. |

Notes:

- `packages` and `legacyPackages` are currently materialized for `x86_64-linux` in `flake.nix`.
- Flake templates are intentionally not exported.

## Architecture model

### Constructor path (`lib.mkPkgs`)

`lib.mkPkgs` is the canonical constructor for downstream composition.

Defined in `lib/mkPkgs.nix`, it applies overlay ordering as:

1. upstream nixpkgs constructor,
2. project default overlay,
3. caller-provided overlays.

Implementation shape:

```nix
mkPkgsUpstream {
  inherit system config;
  overlays = [ overlay ] ++ overlays;
}
```

This ordering is the intended composition contract for consumers.

### Package registry and projection (`pkgs/default.nix`)

`pkgs/default.nix` is the package registry and projection hub.

- `registry.topLevel` maps top-level package names to package files.
- `registry.scopes` maps scoped package sets (currently `python3Packages`) to package files.
- `exportTopLevel` projects only top-level installables into `packages.${system}`.
- `overlay` applies top-level and scoped registrations into the overlay path (`overlays.default`), which is reflected in `legacyPackages.${system}`.

The file intentionally uses an empty dependency set (`{ }:`).

### Overlay adapter (`overlays/default.nix`)

`overlays/default.nix` imports `pkgs/default.nix` and delegates to its `overlay` function:

```nix
final: prev:
let
  packageDefs = import ../pkgs { };
in
packageDefs.overlay final prev
```

This keeps the source of package truth in one place (`pkgs/default.nix`) while exposing one canonical overlay.

## Consumer usage examples (replaces flake templates)

Examples are provided directly in this README instead of exported templates.

### Internal (Matrix registry)

```nix
{
  description = "Internal consumer using Matrix registry";

  nixConfig = {
    flake-registry = "https://nix.matrix.ai/registry/flake-registry.json";
    experimental-features = [ "nix-command" "flakes" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nixpkgs-matrix.url = "flake:nixpkgs-matrix";
  };

  outputs = { nixpkgs, nixpkgs-matrix, ... }:
    let
      system = builtins.currentSystem or "x86_64-linux";
      pkgs = nixpkgs-matrix.lib.mkPkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs."matrixai-public-hello" ];
      };

      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixpkgs-matrix.nixosModules.default
          ./configuration.nix
        ];
      };

      # Home Manager module consumption:
      # imports = [ nixpkgs-matrix.homeModules.default ];
      # Compatibility alias:
      # imports = [ nixpkgs-matrix.homeManagerModules.default ];
    };
}
```

### External / OSS (GitHub input)

```nix
{
  description = "External consumer using GitHub";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nixpkgs-matrix.url = "github:MatrixAI/nixpkgs-matrix";
  };

  outputs = { nixpkgs, nixpkgs-matrix, ... }:
    let
      system = builtins.currentSystem or "x86_64-linux";
      pkgs = nixpkgs-matrix.lib.mkPkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs."polykey-cli" ];
      };

      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixpkgs-matrix.nixosModules.default
          ./configuration.nix
        ];
      };
    };
}
```

Direct convenience output usage:

```sh
nix build 'github:MatrixAI/nixpkgs-matrix#packages.x86_64-linux.matrixai-public-hello'
```

Compatibility package-set usage:

```sh
nix build 'github:MatrixAI/nixpkgs-matrix#legacyPackages.x86_64-linux.matrixai-public-hello'
```

## Development

### Nixpkgs pin policy

Updating nixpkgs is treated as a policy-level change because it effectively repins the package universe.

Policy model:

- Explicit pin intent lives in a managed block in `flake.nix` (`inputs.nixpkgs`, between `# BEGIN: nixpkgs-pin` and `# END: nixpkgs-pin`).
- `scripts/nixpkgs-pin-policy.sh` is the sole policy mutation path and preflights the managed block before rewriting.
- Content integrity is enforced by `flake.lock` (`nodes.nixpkgs.locked.rev` + `nodes.nixpkgs.locked.narHash`).

Use one control script:

```sh
./scripts/nixpkgs-pin-policy.sh info
./scripts/nixpkgs-pin-policy.sh info --tracking-ref refs/heads/nixos-unstable
./scripts/nixpkgs-pin-policy.sh update <commit-sha>
```

Behavior:

- `info` shows explicit pin policy, lock integrity, and full upstream topology for the selected tracking ref:
  - retrieval mode is API-first (GitHub compare + commit endpoints),
  - fallback mode uses git graph analysis when API retrieval is unavailable,
  - cache location is `tmp/nixpkgs-pin-policy/` (API + git cache),
  - ahead count (pin-only commits),
  - behind count (tracking-only commits),
  - merge-base commit + merge-base date,
  - pinned commit date,
  - tracking-head date,
  - age delta in days (`tracking-head date - pinned commit date`).
- `update <commit-sha>` requires an explicit commit choice, refuses if that SHA cannot be found in upstream nixpkgs, rewrites the managed nixpkgs block in `flake.nix`, refreshes `flake.lock`, and verifies lock rev equality.

After policy update in this repo, downstream consumers (for example private repo) should update their input lock:

```sh
nix flake update nixpkgs-matrix
nix flake check
```

### Adding packages

1. Add or update package definitions under `pkgs/top-level` or `pkgs/development/python-modules`.
2. Register package paths in `pkgs/default.nix` under either:
   - `registry.topLevel`, or
   - `registry.scopes.<scopeName>`.
3. Validate both surfaces:
   - `packages.${system}` via `exportTopLevel` (flat top-level installables only),
   - `overlays.default` / `legacyPackages.${system}` via overlay composition (including scopes such as `python3Packages`).

Useful checks:

```sh
nix flake show
nix build '.#packages.x86_64-linux.matrixai-public-hello'
nix build '.#legacyPackages.x86_64-linux.matrixai-public-hello'
```

### Module placeholders

Current module files are intentionally minimal placeholders:

- `modules/nixos/default.nix`
- `modules/home/default.nix`

The contract is on the exported entrypoints and aliasing behavior:

- `nixosModules.default`
- `homeModules.default`
- `homeManagerModules = homeModules`

### Cross-repo consumption checks

When iterating against `nixpkgs-matrix-private`, run from the private checkout:

```sh
nix flake check --override-input nixpkgs-matrix ../nixpkgs-matrix
```

For lock-based validation in private:

```sh
nix flake update nixpkgs-matrix
nix flake check
```
