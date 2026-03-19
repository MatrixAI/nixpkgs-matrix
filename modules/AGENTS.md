# Module taxonomy

- Use [`default.nix`](default.nix) as the flake-facing export surface for module
  families under [`modules/`](./).
- Keep family-specific aggregation close to each family subtree:
  [`nixos/default.nix`](nixos/default.nix) is the aggregate default NixOS module
  implementation and [`home/default.nix`](home/default.nix) is the aggregate
  Home module implementation.
- Keep canonical internal registration for NixOS leaf modules in
  [`nixos/module-list.nix`](nixos/module-list.nix). This file is the single
  source of truth for exported non-default NixOS module entries and for the
  aggregate import list used by [`nixos/default.nix`](nixos/default.nix).
- Do not inline that leaf-module list into [`nixos/default.nix`](nixos/default.nix)
  while both the aggregate default module and the named
  [`nixosModules`](default.nix) exports exist. Both surfaces consume the same
  registry, so the list should remain explicit and subtree-local.
- Follow the nixpkgs-style shape for [`nixos/module-list.nix`](nixos/module-list.nix):
  use a plain list of module paths rather than an ad hoc record structure.
- Avoid maintaining the same NixOS leaf-module list independently in
  [`default.nix`](default.nix), [`nixos/default.nix`](nixos/default.nix), and
  [`../flake.nix`](../flake.nix). Prefer one subtree-local registry feeding the
  higher-level export surfaces.
- Do not blindly export the filesystem. Module export names are part of the
  public flake contract and should stay curated.
- Put reusable module-system files under family subtrees such as [`nixos/`](nixos/)
  and [`home/`](home/), but keep the exported family attrsets intentional.
- When adding a new NixOS leaf module, register it in
  [`nixos/module-list.nix`](nixos/module-list.nix), let
  [`nixos/default.nix`](nixos/default.nix) aggregate it, and let
  [`default.nix`](default.nix) derive the curated family export names from those
  paths.
- Treat [`nixos/module-list.nix`](nixos/module-list.nix) as an internal registry
  seam rather than a consumer-facing API surface. Consumers should rely on the
  exported flake module surfaces instead.
- Keep module checks durable and shape-oriented: validate exported family sets
  and module evaluability rather than pinning the repo to transient module names
  unless a name is deliberately part of the public contract.
