# AGENTS.md

- Read the repo profile selector at [`.matrixai/repo-profile.yml`](.matrixai/repo-profile.yml).
- Standards are expected at `./.matrixai/matrixai-standards/` from private submodule sync; if access is unavailable, standards and skill updates cannot be refreshed.
- Enforce the universal hotset [`.matrixai/matrixai-standards/standards/HOTSET.md`](.matrixai/matrixai-standards/standards/HOTSET.md).
- When editing Markdown/prose artifacts, enforce [`.matrixai/matrixai-standards/standards/prose-markdown.md`](.matrixai/matrixai-standards/standards/prose-markdown.md).
- Enforce the profile doc under [`.matrixai/matrixai-standards/standards/profiles/`](.matrixai/matrixai-standards/standards/profiles) matching `profile:` in [`.matrixai/repo-profile.yml`](.matrixai/repo-profile.yml) (for this repo: `flake-nix`).
- Profile index (for discovery): [`.matrixai/matrixai-standards/standards/profiles/README.md`](.matrixai/matrixai-standards/standards/profiles/README.md)
- Tooling contract reference (primarily JS-profile specific): [`.matrixai/matrixai-standards/standards/coding/tooling/tooling-contract.md`](.matrixai/matrixai-standards/standards/coding/tooling/tooling-contract.md).
- Materialize skills from canonical `./.matrixai/matrixai-standards/skills/**` using profile and ecosystem collection defaults from `./.matrixai/matrixai-standards/skills-collections/**` into `./.agents/skills/**` for runtime discovery, and rematerialize after standards submodule updates.
- For this repo profile, ensure both Nix skills are materialized: `nix-flake-local-dev` and `nix-flake-architecture`.
- When using `nix run` with a flake ref, quote the full flake ref argument (for example, `'./.matrixai/matrixai-standards#skills-materializer'`).
- Profile-driven materialization is the default fast path: run `nix run './.matrixai/matrixai-standards#skills-materializer' -- --standards-root ./.matrixai/matrixai-standards` and it resolves profile+ecosystem collection defaults into `./.agents/skills/**`.
- Explicit selectors remain optional additive overrides: use `--collection ...` and/or `--root-skill ...` only when narrowing or extending selection behavior.
- Content under `./.matrixai/matrixai-standards/standards/**` and `./.matrixai/matrixai-standards/skills/**` MUST NOT reference raw `exhibits/...` intake paths; use stable standards paths (for example `./.matrixai/matrixai-standards/standards/exhibits/...`) or source-repo identifiers instead.
- Prefer ASCII punctuation/symbols when an equivalent exists (see [`.matrixai/matrixai-standards/standards/HOTSET.md`](.matrixai/matrixai-standards/standards/HOTSET.md) [MXS-GEN-006]).
- Ensure edits comply with [`.editorconfig`](.editorconfig).
- Line-reference policy (applies to all agent-generated repository content: Markdown, docs, templates, and code comments):
  - Never emit `path:line` (e.g. `foo.ts:1`, `README.md:126`) into repository files.
  - Do NOT put `:number` inside Markdown link destinations: `[x](path:123)` is banned.
  - If a line reference is needed, use either:
    - `[x](path#heading-anchor)` (if possible), or
    - `[x](path) (line 123)` (preferred, portable), or
    - `[x](path#L123)` only when explicitly targeting a renderer that supports `#L` anchors.
  - If you would have emitted `:1`, drop it entirely: use `path` with no line info.

## Project Local Configuration

### Purpose

This section defines repository-specific guidance for this public Nix flake producer while keeping standards-owned rules in the vendored profile and skills docs.

### Scope boundaries

- This repository is the public producer flake.
- Changes here must preserve a coherent public consumption model.
- Edit only files in this repository unless explicitly asked to work elsewhere.

### Golden commands

- Apply repo-local golden commands and overrides here:
  - build: `nix build '.#packages.x86_64-linux.matrixai-public-hello'`
  - test: `nix flake check path:. --no-write-lock-file`
  - lintfix: not defined for this repo; use targeted edits then rerun `nix flake check path:. --no-write-lock-file`
  - lint: `nix flake check path:. --no-write-lock-file`
  - docs: `nix flake show path:. --no-write-lock-file`
  - bench: not defined for this repo

### Architecture invariants (high level)

- Treat `flake.nix` output surfaces as the public contract.
- Preserve canonical constructor layering through `lib.mkPkgs`.
- Keep package registration/projection coherent across exported package surfaces.
- Keep module and template entrypoints stable unless a deliberate contract change is made.
- Keep checks and consumer docs aligned with output-surface changes.

### Canonical registration and export seams

- Keep each major subtree's canonical registry/export seam close to that subtree,
  then have `flake.nix` consume that seam rather than re-declaring deep entries.
- For library helpers, `lib/default.nix` is the canonical library export surface.
- For packages, `pkgs/default.nix` is the canonical package registry/projection
  surface.
- For modules, `modules/default.nix` is the flake-facing family export surface,
  while subtree-specific registries such as `modules/nixos/module-list.nix` are
  the canonical internal source of truth for that family.
- For the NixOS family specifically, keep these roles distinct:
  `modules/nixos/module-list.nix` is the canonical leaf-module registry,
  `modules/nixos/default.nix` is the aggregate default module composed from that
  registry, and `modules/default.nix` is the flake-facing projection that
  derives named module exports from the same registry.
- Avoid maintaining the same package, module, or helper registration in multiple
  places when one subtree-local registry can feed the higher-level export surface.
- Prefer adding or removing entries at the subtree seam first, then let
  `flake.nix` project the resulting attrsets outward.

### Working order for architecture changes

Review architecture edits in this order:

1. `flake.nix` output contract and checks wiring.
2. Constructor and overlay composition (`lib/`, `overlays/`).
3. Package registry/projection wiring (`pkgs/`).
4. Module/template entrypoints (`modules/`, `templates/`).
5. Consumer docs (`README.md`).

### Contribution checklist

When changing architecture-sensitive files, verify all of:

1. `nix flake show path:. --no-write-lock-file` reflects intended output shape.
2. `nix flake check path:. --no-write-lock-file` passes.
3. Representative package outputs still resolve.
4. Consumer-facing docs remain accurate.

### Anti-patterns

- Duplicating volatile profile/skills detail here when it is already maintained in vendored standards.
- Splitting package truth across competing registries or constructor paths.
- Introducing output-contract drift without matching checks/docs updates.
