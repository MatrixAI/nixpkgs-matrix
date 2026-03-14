{ pkgs }:

let
  pinPolicyAllowlist = import ./policy-pin-allowlist.nix;

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

  allowlistMetadataInvariant =
    builtins.all
      (relPath:
        let
          entry = pinPolicyAllowlist.${relPath};
        in
        builtins.isAttrs entry
        && builtins.hasAttr "rationale" entry
        && builtins.isString entry.rationale
        && builtins.hasAttr "reviewCadenceDays" entry
        && builtins.isInt entry.reviewCadenceDays
        && entry.reviewCadenceDays > 0)
      allowlistPaths;

  allowlistCount = builtins.length allowlistPaths;
in
pkgs.runCommand "policy-pin" { src = repoSrc; } ''
  cd "$src"

  ${if allowlistInvariant && allowlistMetadataInvariant then "true" else "false"}

  count="$(grep -R --include='*.nix' -n 'builtins.getFlake' ./pkgs | wc -l)"
  test "$count" -eq "${toString allowlistCount}"

  for rel_path in ${allowlistPathsText}; do
    grep -q 'builtins.getFlake' "$rel_path"
    grep -q 'github:[^"[:space:]]\+/[a-f0-9]\{40\}' "$rel_path"
  done

  tmp_hits="$(mktemp)"
  trap 'rm -f "$tmp_hits"' EXIT

  grep -R --include='*.nix' -n 'builtins.getFlake' ./pkgs > "$tmp_hits"

  allowlist_count="${toString allowlistCount}"
  usage_count="$(wc -l < "$tmp_hits")"
  test "$usage_count" -eq "$allowlist_count"

  touch "$out"
''
