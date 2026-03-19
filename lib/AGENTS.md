# Library taxonomy

- Use [`default.nix`](default.nix) as the canonical export surface for this
  repo's library helpers.
- Keep reusable helper logic in [`lib/`](./) only when it belongs to the flake's
  library API rather than to a package implementation or module tree.
- Files under [`lib/`](./) should normally be `callPackage`-style Nix functions
  that are instantiated through [`callLib`](default.nix) in
  [`default.nix`](default.nix).
- [`callLib`](default.nix) is intentionally wired with the upstream package set,
  the local library scope, and [`lib`](default.nix). This means library helpers
  may receive standard package dependencies by injection without manually
  threading them through every caller.
- Put logic in [`lib/`](./) when it is a reusable constructor or helper for
  flake surfaces such as [`lib`](../flake.nix), [`checks`](../checks/), or other
  repo-owned composition code.
- Put logic in [`pkgs/`](../pkgs/) when it defines a derivation, package
  registry entry, or package-scoped implementation detail.
- Put logic in [`modules/`](../modules/) when it is evaluated by the NixOS
  module system and depends on module arguments such as `{ config, lib, pkgs,
  ... }`.
- Do not treat module-system files as if they were library helpers, and do not
  move package-building logic into [`lib/`](./) just to avoid explicit wiring.
- When adding a new helper, export it from [`default.nix`](default.nix) and keep
  the naming aligned with the value it exports.
