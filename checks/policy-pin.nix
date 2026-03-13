{ pkgs }:

let
  pinPolicyAllowlist = {
    "pkgs/top-level/polykey-cli.nix" = {
      rationale = "curated downstream package universe includes external flake pin for polykey-cli";
      reviewCadenceDays = 30;
    };
  };

  repoSrc = builtins.path {
    path = ../.;
    name = "nixpkgs-matrix-source";
  };

  allowlistPaths = builtins.attrNames pinPolicyAllowlist;
  allowlistPathsText = builtins.concatStringsSep " " allowlistPaths;

  # ensure allowlist references real files in this repository
  allowlistInvariant =
    builtins.all
      (relPath: builtins.pathExists (../. + "/${relPath}"))
      allowlistPaths;
in
pkgs.runCommand "policy-pin" { src = repoSrc; } ''
  cd "$src"

  ${if allowlistInvariant then "true" else "false"}

  count="$(grep -R --include='*.nix' -n 'builtins.getFlake' ./pkgs | wc -l)"
  test "$count" -eq 1

  for rel_path in ${allowlistPathsText}; do
    grep -q 'builtins.getFlake' "$rel_path"
    grep -q 'github:[^"[:space:]]\+/[a-f0-9]\{40\}' "$rel_path"
  done

  tmp_hits="$(mktemp)"
  trap 'rm -f "$tmp_hits"' EXIT

  grep -R --include='*.nix' -n 'builtins.getFlake' ./pkgs > "$tmp_hits"

  allowlist_count="$(printf '%s\n' ${allowlistPathsText} | wc -l)"
  usage_count="$(wc -l < "$tmp_hits")"
  test "$usage_count" -eq "$allowlist_count"

  touch "$out"
''
