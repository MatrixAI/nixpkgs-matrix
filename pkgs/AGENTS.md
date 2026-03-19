# Package taxonomy

- Use [`default.nix`](default.nix) as the canonical package registry and export
  seam for [`pkgs/`](./).
- Keep top-level package registration in the `registry.topLevel` section of
  [`default.nix`](default.nix).
- Keep scoped package registration in the `registry.scopes` section of
  [`default.nix`](default.nix).
- Treat [`default.nix`](default.nix) as the single source of truth that feeds
  both the exported top-level package projection and the overlay/package-set
  wiring.
- Put derivation implementations under subtree folders such as
  [`top-level/`](top-level/) or [`development/`](development/), but do not treat
  the filesystem alone as the exported package surface.
- When adding a new package, register it in [`default.nix`](default.nix) rather
  than wiring it directly into [`flake.nix`](../flake.nix) or other top-level
  output code.
- Keep package truth single-sourced: avoid parallel manual declarations for the
  same package across `flake.nix`, overlay code, and ad hoc registries.
- Use [`../checks/`](../checks/) to validate package-surface shape and coherence,
  but keep those checks durable rather than tied to short-lived package names.
