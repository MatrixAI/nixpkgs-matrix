# nixpkgs-matrix

Matrix AI public Nix package and module distribution flake.

## Usage

### What this flake exports

The public contract is the `outputs` shape in `flake.nix`.

| Output | Purpose |
| --- | --- |
| `lib` | Public helper scope from `lib/default.nix`; includes upstream `nixpkgs.lib` under `lib.lib` and constructor helpers such as `lib.mkPkgs`. |
| `overlays.default` | Canonical project overlay from `overlays/default.nix`. |
| `legacyPackages.${system}` | Compatibility package set produced via `lib.mkPkgs`. |
| `packages.${system}` | Curated flat top-level installables projection from `pkgs/default.nix` (`exportTopLevel`). |
| `templates.default` | Minimal OSS starter template (alias of `templates.oss`). |
| `templates.oss` | Minimal OSS starter template using flake-parts and `nixpkgs-matrix.lib.mkPkgs`. |
| `nixosModules.default` | Public NixOS module entrypoint. |
| `homeModules.default` | Public Home Manager module entrypoint. |
| `checks.${system}` | Local contract/policy/smoke gates consumed by `nix flake check`. |
| `devShells.${system}.default` | Developer shell for local repository maintenance workflows. |

Current policy is explicit single-system materialization (`x86_64-linux`).

### Start from the OSS template

Initialize a new project using the exported starter:

```sh
nix flake init -t github:MatrixAI/nixpkgs-matrix#oss
```

Equivalent alias:

```sh
nix flake init -t github:MatrixAI/nixpkgs-matrix#default
```

The template emits one minimal `flake.nix` that:

1. uses flake-parts,
2. imports `nixpkgs-matrix` from GitHub,
3. constructs `pkgs` through `nixpkgs-matrix.lib.mkPkgs`,
4. defines a small `devShell` consuming `nixpkgs-matrix` packages.

### Constructor path (`lib.mkPkgs`)

`lib.mkPkgs` is the canonical constructor for downstream composition.

Overlay ordering in `lib/mkPkgs.nix` is:

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

### Package registry and overlay model

`pkgs/default.nix` is the package registry and projection hub:

- `registry.topLevel` maps top-level package names to package files,
- `registry.scopes` maps scoped package sets (currently `python3Packages`),
- `exportTopLevel` projects flat installables to `packages.${system}`,
- `overlay` wires top-level + scoped entries into `overlays.default` / `legacyPackages.${system}`.

### Direct output usage

```sh
nix build 'github:MatrixAI/nixpkgs-matrix#packages.x86_64-linux.matrixai-public-hello'
nix build 'github:MatrixAI/nixpkgs-matrix#legacyPackages.x86_64-linux.matrixai-public-hello'
```

## Development

### Local developer shell

Enter the repository maintenance shell:

```sh
nix develop
```

The shell is intentionally curated for this repository’s maintenance workflows and includes tools like `nix`, `git`, `jq`, GNU text/core utilities, `curl`, and `wget`.

### Canonical local test workflow

Use these as the standard local gates:

```sh
nix flake show path:. --no-write-lock-file
nix flake check path:. --no-write-lock-file
```

Current checks:

- `checks.${system}.contract-outputs`
- `checks.${system}.contract-packages`
- `checks.${system}.contract-modules`
- `checks.${system}.policy-pin`
- `checks.${system}.smoke-hello`

### Pin governance workflows

#### Upstream nixpkgs pin workflow

Use:

```sh
./scripts/nixpkgs-pin-policy.sh info
./scripts/nixpkgs-pin-policy.sh info --tracking-ref refs/heads/nixos-unstable
./scripts/nixpkgs-pin-policy.sh update <commit-sha>
```

`update` rewrites the managed nixpkgs block in `flake.nix`, refreshes `flake.lock`, and verifies rev consistency.

#### External flake pin baseline

External `builtins.getFlake` usage is allowlisted and enforced by `checks.${system}.policy-pin`.

Allowlist metadata lives in:

- `plans/pin-sources-policy.nix`

### Helper scripts for maintainers

These scripts improve maintainer decision-making inside this repository. They are ergonomics helpers, not the contract authority (the contract authority remains flake outputs and checks).

1. External pin lifecycle visibility:

```sh
./scripts/external-pin-lifecycle.sh info
./scripts/external-pin-lifecycle.sh info --tracking-ref refs/heads/main
```

Reports include:

- allowlisted entry metadata,
- pinned commit date,
- pin age in days,
- review cadence and due state,
- tracking branch head SHA visibility.

2. Package version intelligence for policy decisions:

```sh
./scripts/package-version-intel.sh current vscodium
./scripts/package-version-intel.sh compare vscodium --candidate-ref refs/heads/nixos-unstable
./scripts/package-version-intel.sh compare matrixai-public-hello --system x86_64-linux --candidate-ref <commit-sha>
```

Reports include current pinned metadata and candidate metadata (`version`, `pname`, `name`) plus a simple changed/unchanged status.

### Adding packages

1. Add or update package definitions under `pkgs/top-level` or `pkgs/development/python-modules`.
2. Register package paths in `pkgs/default.nix` under:
   - `registry.topLevel`, or
   - `registry.scopes.<scopeName>`.
3. Validate both surfaces:
   - `packages.${system}` via `exportTopLevel`,
   - `legacyPackages.${system}` via overlay composition.

Useful checks:

```sh
nix flake show path:. --no-write-lock-file
nix build '.#packages.x86_64-linux.matrixai-public-hello'
nix build '.#legacyPackages.x86_64-linux.matrixai-public-hello'
```

### Module placeholders

Current module files are intentionally minimal placeholders:

- `modules/nixos/default.nix`
- `modules/home/default.nix`

Stable exported entrypoints:

- `nixosModules.default`
- `homeModules.default`

### Cross-repo consumption checks

When iterating with `nixpkgs-matrix-private`, run from the private checkout:

```sh
nix flake check --override-input nixpkgs-matrix ../nixpkgs-matrix
```

For lock-based validation in private:

```sh
nix flake update nixpkgs-matrix
nix flake check
```
