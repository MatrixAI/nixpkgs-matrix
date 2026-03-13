# AGENTS.md

## Purpose

This file is the architecture runbook for agents working in `nixpkgs-matrix`.

It defines:

- the public flake API surface,
- the package and module topology,
- composition/layering rules,
- and contribution invariants.

This document is intentionally architecture-focused. It does not define sync-gate process policy.

## Scope boundaries

- This repository is the public producer flake.
- Changes here must preserve a coherent public consumption model.
- Edit only files in this repository unless explicitly asked to work elsewhere.

## Canonical read order for architecture work

Read these files in order before editing:

1. `flake.nix`
2. `lib/default.nix`
3. `lib/mkPkgs.nix`
4. `pkgs/default.nix`
5. `overlays/default.nix`
6. `modules/nixos/default.nix`
7. `modules/home/default.nix`
8. `README.md`

## Public API contract surface

The contract is the `outputs` shape in `flake.nix`:

- `lib`
- `overlays.default`
- `legacyPackages.<system>`
- `packages.<system>`
- `nixosModules.default`
- `homeModules.default`
- `checks.<system>` (local contract/build/smoke/module/pin policy checks)
- `devShells.<system>.default` (developer ergonomics)

### `lib` expectations

`lib` is constructed in `lib/default.nix` via `lib.makeScope` and exposes:

- `lib.lib` (upstream `nixpkgs.lib`),
- `lib.callLib`,
- `lib.mkPkgs`.

Downstream consumers should treat `lib.mkPkgs` as the canonical package-set constructor.

### Constructor layering rule

`lib/mkPkgs.nix` is the architecture-critical layering point.

Required overlay application order:

1. upstream nixpkgs base,
2. project default overlay,
3. caller overlays.

The ordering is implemented as:

```nix
overlays = [ overlay ] ++ overlays;
```

Do not change this ordering unless intentionally changing contract semantics.

## Package topology model

`pkgs/default.nix` is the single registry/projection hub:

- `registry.topLevel`: top-level package names and paths,
- `registry.scopes`: scoped sets (for example `python3Packages`),
- `exportTopLevel`: flat top-level projection used for `packages.<system>`,
- `overlay`: overlay path used by `overlays.default`.

Invariants:

- Keep package registration centralized in `pkgs/default.nix`.
- Ensure additions are wired in both projection paths (`exportTopLevel` for top-level installables and `overlay` for recursive package universes).
- Preserve the empty dependency set (`{ }:`) unless there is a strong architecture reason to change it.

## Overlay adapter model

`overlays/default.nix` is a thin adapter:

- imports `pkgs/default.nix`,
- delegates to `packageDefs.overlay`.

Goal: one source of package truth with one canonical exported overlay.

## Module topology model

Module entrypoints are exported from `flake.nix`:

- `nixosModules.default` -> `modules/nixos/default.nix`
- `homeModules.default` -> `modules/home/default.nix`

Current module files are placeholders. Keep exported names stable even when payloads evolve.

## Consumer pattern policy

Consumer usage examples live in `README.md`.

- This repo does not rely on exported flake templates.
- Internal and external usage patterns must be documented inline in `README.md`.
- If consumer patterns change, update `README.md` in the same change set.

## Contribution checklist (architecture changes)

When changing architecture-sensitive files, verify all of:

1. `nix flake show` reflects intended output shape.
2. `lib.mkPkgs` still produces a package set with expected overlay ordering.
3. `packages.<system>` and `legacyPackages.<system>` still resolve expected packages.
4. Module exports remain present (`nixosModules.default`, `homeModules.default`) and continue to evaluate.
5. `README.md` remains accurate for consumers.

## Framework and systems policy

- Flake composition uses flake-parts for structured output assembly.
- Current systems policy is explicitly single-system (`x86_64-linux`).
- Multi-system expansion is a separate policy decision and must not be bundled into structural migrations.

## Anti-patterns

- Splitting package truth across multiple competing registries.
- Bypassing `lib.mkPkgs` as the primary constructor path in documentation.
- Introducing public API drift without updating `README.md` and this runbook.
- Re-introducing template-export assumptions into the public output contract.
