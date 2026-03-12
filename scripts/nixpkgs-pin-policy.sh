#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE_FILE="$ROOT_DIR/flake.nix"
LOCK_FILE="$ROOT_DIR/flake.lock"

DEFAULT_TRACKING_REF="refs/heads/nixos-unstable"

MANAGED_BLOCK_BEGIN="    # BEGIN: nixpkgs-pin (managed by scripts/nixpkgs-pin-policy.sh)"
MANAGED_BLOCK_END="    # END: nixpkgs-pin"

usage() {
  cat <<'EOF'
Usage:
  scripts/nixpkgs-pin-policy.sh info [--tracking-ref <git-ref>]
  scripts/nixpkgs-pin-policy.sh update <commit-sha> [--tracking-ref <git-ref>]

Description:
  info                Show explicit pin policy, lock integrity, and upstream comparison.
  update <commit-sha> Update nixpkgs policy rev in flake.nix, refresh flake lock, and verify lock match.

Options:
  --tracking-ref <git-ref>
      Reference used for upstream comparison in `info` (default: refs/heads/nixos-unstable).
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

parse_global_args() {
  TRACKING_REF="$DEFAULT_TRACKING_REF"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tracking-ref)
        [[ $# -ge 2 ]] || die "--tracking-ref requires a value"
        TRACKING_REF="$2"
        shift 2
        ;;
      *)
        POSITIONAL_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

preflight_validate_flake_managed_block() {
  if [[ ! -f "$FLAKE_FILE" ]]; then
    die "flake file not found: ${FLAKE_FILE}"
  fi

  if ! grep -Fq "$MANAGED_BLOCK_BEGIN" "$FLAKE_FILE"; then
    die "managed nixpkgs block begin marker not found in ${FLAKE_FILE}"
  fi

  if ! grep -Fq "$MANAGED_BLOCK_END" "$FLAKE_FILE"; then
    die "managed nixpkgs block end marker not found in ${FLAKE_FILE}"
  fi
}

extract_nixpkgs_field_from_flake_block() {
  local field="$1"
  local value

  value="$({
    awk -v begin="$MANAGED_BLOCK_BEGIN" -v end="$MANAGED_BLOCK_END" -v field="$field" '
      BEGIN {
        in_block = 0;
      }
      {
        if (index($0, begin) > 0) {
          in_block = 1;
          next;
        }

        if (in_block == 1 && index($0, end) > 0) {
          in_block = 0;
          next;
        }

        if (in_block == 1) {
          line = $0;
          gsub(/^[[:space:]]+/, "", line);
          if (line ~ "^" field "[[:space:]]*=[[:space:]]*\"") {
            sub("^" field "[[:space:]]*=[[:space:]]*\"", "", line);
            sub("\";[[:space:]]*$", "", line);
            print line;
            exit 0;
          }
        }
      }
      END {
        exit 1;
      }
    ' "$FLAKE_FILE"
  } 2>/dev/null)"

  [[ -n "$value" ]] || die "failed to read '${field}' from managed nixpkgs block in ${FLAKE_FILE}"
  printf '%s\n' "$value"
}

render_flake_nixpkgs_block() {
  local type owner repo rev
  type="$(extract_nixpkgs_field_from_flake_block type)"
  owner="$(extract_nixpkgs_field_from_flake_block owner)"
  repo="$(extract_nixpkgs_field_from_flake_block repo)"
  rev="${1:-$(extract_nixpkgs_field_from_flake_block rev)}"

  cat <<EOF
${MANAGED_BLOCK_BEGIN}
    nixpkgs = {
      type = "${type}";
      owner = "${owner}";
      repo = "${repo}";
      rev = "${rev}";
    };
${MANAGED_BLOCK_END}
EOF
}

replace_managed_block() {
  local replacement="$1"
  local tmp
  tmp="$(mktemp)" || die "failed to create temp file"

  awk -v begin="$MANAGED_BLOCK_BEGIN" -v end="$MANAGED_BLOCK_END" -v replacement="$replacement" '
    BEGIN {
      in_block = 0;
      replaced = 0;
    }
    {
      if (index($0, begin) > 0) {
        if (in_block == 1) {
          print "error: nested managed block detected" > "/dev/stderr";
          exit 2;
        }
        in_block = 1;
        if (replaced == 1) {
          print "error: multiple managed blocks detected" > "/dev/stderr";
          exit 3;
        }
        print replacement;
        replaced = 1;
        next;
      }

      if (in_block == 1) {
        if (index($0, end) > 0) {
          in_block = 0;
        }
        next;
      }

      print;
    }
    END {
      if (in_block == 1) {
        print "error: unterminated managed block" > "/dev/stderr";
        exit 4;
      }
      if (replaced == 0) {
        print "error: managed block not replaced" > "/dev/stderr";
        exit 5;
      }
    }
  ' "$FLAKE_FILE" > "$tmp" || {
    rm -f "$tmp"
    die "failed to rewrite managed nixpkgs block in ${FLAKE_FILE}"
  }

  mv "$tmp" "$FLAKE_FILE" || {
    rm -f "$tmp"
    die "failed to update ${FLAKE_FILE}"
  }
}

lock_rev() {
  local value
  value="$(nix eval --impure --raw --expr "let l = builtins.fromJSON (builtins.readFile ${LOCK_FILE}); in l.nodes.nixpkgs.locked.rev" 2>/dev/null)" \
    || die "failed to read locked.rev from ${LOCK_FILE}"
  printf '%s\n' "$value"
}

lock_nar_hash() {
  local value
  value="$(nix eval --impure --raw --expr "let l = builtins.fromJSON (builtins.readFile ${LOCK_FILE}); in l.nodes.nixpkgs.locked.narHash" 2>/dev/null)" \
    || die "failed to read locked.narHash from ${LOCK_FILE}"
  printf '%s\n' "$value"
}

pin_repo_url() {
  local owner repo
  owner="$(extract_nixpkgs_field_from_flake_block owner)"
  repo="$(extract_nixpkgs_field_from_flake_block repo)"
  printf 'https://github.com/%s/%s' "$owner" "$repo"
}

upstream_head_for_tracking_ref() {
  local repo_url
  repo_url="$(pin_repo_url)"
  git ls-remote "$repo_url" "$TRACKING_REF" 2>/dev/null | awk '{ print $1 }'
}

validate_sha_format() {
  local sha="$1"
  if ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
    die "commit sha must be 40 lowercase hex characters"
  fi
}

ensure_sha_exists_upstream() {
  local sha="$1"
  local repo_url tmpdir fetched
  repo_url="$(pin_repo_url)"
  tmpdir="$(mktemp -d)" || die "failed to create temp directory"

  if ! git -C "$tmpdir" init -q >/dev/null 2>&1; then
    rm -rf "$tmpdir"
    die "failed to initialize temporary git repository"
  fi

  if ! git -C "$tmpdir" remote add origin "$repo_url" >/dev/null 2>&1; then
    rm -rf "$tmpdir"
    die "failed to configure upstream remote"
  fi

  if ! git -C "$tmpdir" fetch --depth 1 origin "$sha" >/dev/null 2>&1; then
    rm -rf "$tmpdir"
    die "requested sha not found in upstream repository: $sha"
  fi

  fetched="$(git -C "$tmpdir" rev-parse FETCH_HEAD 2>/dev/null || true)"
  rm -rf "$tmpdir"

  if [[ "$fetched" != "$sha" ]]; then
    die "fetched upstream commit does not match requested sha: $sha"
  fi
}

print_info() {
  local pin_type pin_owner pin_repo pin_rev
  local lrev lhash upstream_head

  pin_type="$(extract_nixpkgs_field_from_flake_block type)"
  pin_owner="$(extract_nixpkgs_field_from_flake_block owner)"
  pin_repo="$(extract_nixpkgs_field_from_flake_block repo)"
  pin_rev="$(extract_nixpkgs_field_from_flake_block rev)"

  lrev="$(lock_rev)"
  lhash="$(lock_nar_hash)"
  upstream_head="$(upstream_head_for_tracking_ref || true)"

  echo "nixpkgs policy pin"
  echo "  type:         $pin_type"
  echo "  owner/repo:   $pin_owner/$pin_repo"
  echo "  rev:          $pin_rev"
  echo "  trackingRef:  $TRACKING_REF"
  echo
  echo "flake lock integrity"
  echo "  locked.rev:     $lrev"
  echo "  locked.narHash: $lhash"
  echo
  if [[ -n "$upstream_head" ]]; then
    echo "upstream comparison"
    echo "  upstream head ($TRACKING_REF): $upstream_head"
    if [[ "$pin_rev" == "$upstream_head" ]]; then
      echo "  status: pinned to current tracking head"
    else
      echo "  status: pinned behind/diverged from tracking head"
    fi
  else
    echo "upstream comparison"
    echo "  status: unable to resolve tracking ref upstream"
  fi

  echo
  if [[ "$pin_rev" == "$lrev" ]]; then
    echo "pin-lock consistency: OK"
  else
    echo "pin-lock consistency: MISMATCH"
    echo "  pin rev differs from lock rev"
  fi
}

update_pin_rev() {
  local new_sha="$1"
  validate_sha_format "$new_sha"
  ensure_sha_exists_upstream "$new_sha"

  local before_rev after_rev after_hash
  before_rev="$(extract_nixpkgs_field_from_flake_block rev)"

  replace_managed_block "$(render_flake_nixpkgs_block "$new_sha")"

  if ! nix flake lock --update-input nixpkgs --flake "$ROOT_DIR"; then
    die "failed to refresh lock for nixpkgs input"
  fi

  after_rev="$(lock_rev)"
  after_hash="$(lock_nar_hash)"

  if [[ "$after_rev" != "$new_sha" ]]; then
    die "lock rev does not match requested sha (requested=$new_sha locked=$after_rev)"
  fi

  echo "updated nixpkgs pin"
  echo "  previous rev: $before_rev"
  echo "  requested rev: $new_sha"
  echo "  locked.rev: $after_rev"
  echo "  locked.narHash: $after_hash"
}

main() {
  POSITIONAL_ARGS=()
  parse_global_args "$@"

  local cmd="${POSITIONAL_ARGS[0]:-}"

  if ! command -v nix >/dev/null 2>&1; then
    die "nix command not found"
  fi

  if ! command -v git >/dev/null 2>&1; then
    die "git command not found"
  fi

  if [[ ! -f "$LOCK_FILE" ]]; then
    die "lock file not found: ${LOCK_FILE}"
  fi

  preflight_validate_flake_managed_block

  case "$cmd" in
    info)
      if [[ ${#POSITIONAL_ARGS[@]} -ne 1 ]]; then
        usage
        exit 1
      fi
      print_info
      ;;
    update)
      if [[ ${#POSITIONAL_ARGS[@]} -ne 2 ]]; then
        usage
        exit 1
      fi
      update_pin_rev "${POSITIONAL_ARGS[1]}"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"

