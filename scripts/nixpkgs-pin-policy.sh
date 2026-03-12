#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE_FILE="$ROOT_DIR/flake.nix"
LOCK_FILE="$ROOT_DIR/flake.lock"

CACHE_ROOT_DIR="$ROOT_DIR/tmp/nixpkgs-pin-policy"
API_CACHE_DIR="$CACHE_ROOT_DIR/api"
GIT_CACHE_DIR="$CACHE_ROOT_DIR/git"
API_CACHE_TTL_SECONDS=900
HTTP_TIMEOUT_SECONDS=20

DEFAULT_TRACKING_REF="refs/heads/nixos-unstable"

MANAGED_BLOCK_BEGIN="    # BEGIN: nixpkgs-pin (managed by scripts/nixpkgs-pin-policy.sh)"
MANAGED_BLOCK_END="    # END: nixpkgs-pin"

usage() {
  cat <<'EOF'
Usage:
  scripts/nixpkgs-pin-policy.sh info [--tracking-ref <git-ref>]
  scripts/nixpkgs-pin-policy.sh update <commit-sha> [--tracking-ref <git-ref>]

Description:
  info                Show explicit pin policy, lock integrity, and upstream comparison topology.
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

log_info() {
  echo "[nixpkgs-pin-policy] $*" >&2
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

commit_iso_date_from_repo() {
  local repo_dir="$1"
  local sha="$2"
  git -C "$repo_dir" show -s --format=%cI "$sha" 2>/dev/null || true
}

commit_epoch_from_repo() {
  local repo_dir="$1"
  local sha="$2"
  git -C "$repo_dir" show -s --format=%ct "$sha" 2>/dev/null || true
}

urlencode() {
  local input="$1"
  local encoded=""
  local i ch hex

  for ((i = 0; i < ${#input}; i++)); do
    ch="${input:$i:1}"
    case "$ch" in
      [a-zA-Z0-9.~_-]) encoded+="$ch" ;;
      *)
        printf -v hex '%%%02X' "'$ch"
        encoded+="$hex"
        ;;
    esac
  done

  printf '%s' "$encoded"
}

cache_prepare_dirs() {
  mkdir -p "$API_CACHE_DIR" "$GIT_CACHE_DIR" || return 1
}

file_age_seconds() {
  local path="$1"
  local now mtime

  now="$(date +%s 2>/dev/null || true)"
  mtime="$(stat -c %Y "$path" 2>/dev/null || true)"

  if [[ "$now" =~ ^[0-9]+$ ]] && [[ "$mtime" =~ ^[0-9]+$ ]]; then
    printf '%s' "$((now - mtime))"
  else
    printf '%s' "$((API_CACHE_TTL_SECONDS + 1))"
  fi
}

is_cache_fresh() {
  local cache_file="$1"
  local age

  [[ -f "$cache_file" ]] || return 1
  age="$(file_age_seconds "$cache_file")"
  [[ "$age" =~ ^[0-9]+$ ]] || return 1
  (( age <= API_CACHE_TTL_SECONDS ))
}

json_field_string() {
  local json_file="$1"
  local field="$2"

  awk -v field="$field" '
    {
      line = $0;
      pattern = "\"" field "\"[[:space:]]*:[[:space:]]*\"";
      if (match(line, pattern)) {
        sub("^.*\"" field "\"[[:space:]]*:[[:space:]]*\"", "", line);
        sub("\".*$", "", line);
        print line;
        exit 0;
      }
    }
    END { exit 1 }
  ' "$json_file" 2>/dev/null
}

json_first_sha_after_key() {
  local json_file="$1"
  local key="$2"

  awk -v key="$key" '
    BEGIN {
      in_target = 0;
    }
    {
      line = $0;
      if (in_target == 0 && index(line, "\"" key "\"") > 0) {
        in_target = 1;
        next;
      }
      if (in_target == 1 && line ~ /"sha"[[:space:]]*:[[:space:]]*"/) {
        sub("^.*\"sha\"[[:space:]]*:[[:space:]]*\"", "", line);
        sub("\".*$", "", line);
        print line;
        exit 0;
      }
    }
    END { exit 1 }
  ' "$json_file" 2>/dev/null
}

json_first_date_after_key() {
  local json_file="$1"
  local key="$2"

  awk -v key="$key" '
    BEGIN {
      in_target = 0;
    }
    {
      line = $0;
      if (in_target == 0 && index(line, "\"" key "\"") > 0) {
        in_target = 1;
        next;
      }
      if (in_target == 1 && line ~ /"date"[[:space:]]*:[[:space:]]*"/) {
        sub("^.*\"date\"[[:space:]]*:[[:space:]]*\"", "", line);
        sub("\".*$", "", line);
        print line;
        exit 0;
      }
    }
    END { exit 1 }
  ' "$json_file" 2>/dev/null
}

json_field_int() {
  local json_file="$1"
  local field="$2"

  awk -v field="$field" '
    {
      line = $0;
      pattern = "\"" field "\"[[:space:]]*:[[:space:]]*[0-9]+";
      if (match(line, pattern)) {
        sub("^.*\"" field "\"[[:space:]]*:[[:space:]]*", "", line);
        if (match(line, /^[0-9]+/)) {
          print substr(line, RSTART, RLENGTH);
          exit 0;
        }
      }
    }
    END { exit 1 }
  ' "$json_file" 2>/dev/null
}

http_fetch_to_file() {
  local url="$1"
  local out_file="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time "$HTTP_TIMEOUT_SECONDS" \
      -H 'Accept: application/vnd.github+json' \
      -o "$out_file" \
      "$url"
    return $?
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -q -T "$HTTP_TIMEOUT_SECONDS" \
      -O "$out_file" \
      --header='Accept: application/vnd.github+json' \
      "$url"
    return $?
  fi

  return 127
}

github_compare_cache_file() {
  local owner="$1"
  local repo="$2"
  local base_sha="$3"
  local head_sha="$4"
  printf '%s/%s-%s-%s-%s.compare.json' "$API_CACHE_DIR" "$owner" "$repo" "$base_sha" "$head_sha"
}

github_commit_cache_file() {
  local owner="$1"
  local repo="$2"
  local sha="$3"
  printf '%s/%s-%s-%s.commit.json' "$API_CACHE_DIR" "$owner" "$repo" "$sha"
}

fetch_compare_json_cached() {
  local owner="$1"
  local repo="$2"
  local base_sha="$3"
  local head_sha="$4"
  local cache_file tmp_file url

  cache_file="$(github_compare_cache_file "$owner" "$repo" "$base_sha" "$head_sha")"

  if is_cache_fresh "$cache_file"; then
    log_info "using cached compare response: $cache_file"
    printf '%s\n' "$cache_file"
    return 0
  fi

  url="https://api.github.com/repos/${owner}/${repo}/compare/${base_sha}...${head_sha}"
  tmp_file="$(mktemp)" || return 1

  log_info "requesting compare endpoint: $url"
  if ! http_fetch_to_file "$url" "$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$cache_file" || {
    rm -f "$tmp_file"
    return 1
  }

  printf '%s\n' "$cache_file"
}

fetch_commit_json_cached() {
  local owner="$1"
  local repo="$2"
  local sha="$3"
  local cache_file tmp_file url

  cache_file="$(github_commit_cache_file "$owner" "$repo" "$sha")"

  if is_cache_fresh "$cache_file"; then
    log_info "using cached commit response: $cache_file"
    printf '%s\n' "$cache_file"
    return 0
  fi

  url="https://api.github.com/repos/${owner}/${repo}/commits/${sha}"
  tmp_file="$(mktemp)" || return 1

  log_info "requesting commit endpoint: $url"
  if ! http_fetch_to_file "$url" "$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$cache_file" || {
    rm -f "$tmp_file"
    return 1
  }

  printf '%s\n' "$cache_file"
}

collect_upstream_topology_api() {
  local pin_rev="$1"
  local upstream_head="$2"
  local pin_owner="$3"
  local pin_repo="$4"
  local compare_file merge_base base_status ahead behind
  local head_commit_file pin_commit_file head_epoch pin_epoch

  TOPOLOGY_AVAILABLE=0
  TOPOLOGY_SOURCE="api"
  TOPOLOGY_AHEAD_COUNT=""
  TOPOLOGY_BEHIND_COUNT=""
  TOPOLOGY_MERGE_BASE=""
  TOPOLOGY_MERGE_BASE_DATE=""
  TOPOLOGY_PIN_DATE=""
  TOPOLOGY_HEAD_DATE=""
  TOPOLOGY_AGE_DELTA_DAYS=""

  compare_file="$(fetch_compare_json_cached "$pin_owner" "$pin_repo" "$pin_rev" "$upstream_head" 2>/dev/null)" || return 1

  ahead="$(json_field_int "$compare_file" ahead_by || true)"
  behind="$(json_field_int "$compare_file" behind_by || true)"
  base_status="$(json_field_string "$compare_file" status || true)"
  merge_base="$(json_first_sha_after_key "$compare_file" merge_base_commit || true)"

  if [[ -z "$ahead" || -z "$behind" ]]; then
    return 1
  fi

  TOPOLOGY_AHEAD_COUNT="$behind"
  TOPOLOGY_BEHIND_COUNT="$ahead"
  TOPOLOGY_MERGE_BASE="$merge_base"

  TOPOLOGY_PIN_DATE="$(json_first_date_after_key "$compare_file" base_commit || true)"
  TOPOLOGY_MERGE_BASE_DATE="$(json_first_date_after_key "$compare_file" merge_base_commit || true)"

  head_commit_file="$(fetch_commit_json_cached "$pin_owner" "$pin_repo" "$upstream_head" 2>/dev/null)" || true
  if [[ -n "$head_commit_file" ]]; then
    TOPOLOGY_HEAD_DATE="$(json_first_date_after_key "$head_commit_file" commit || true)"
  fi

  if [[ -z "$TOPOLOGY_PIN_DATE" ]]; then
    pin_commit_file="$(fetch_commit_json_cached "$pin_owner" "$pin_repo" "$pin_rev" 2>/dev/null)" || true
    if [[ -n "$pin_commit_file" ]]; then
      TOPOLOGY_PIN_DATE="$(json_first_date_after_key "$pin_commit_file" commit || true)"
    fi
  fi

  if [[ -z "$TOPOLOGY_MERGE_BASE_DATE" && -n "$merge_base" ]]; then
    local merge_commit_file
    merge_commit_file="$(fetch_commit_json_cached "$pin_owner" "$pin_repo" "$merge_base" 2>/dev/null)" || true
    if [[ -n "$merge_commit_file" ]]; then
      TOPOLOGY_MERGE_BASE_DATE="$(json_first_date_after_key "$merge_commit_file" commit || true)"
    fi
  fi

  head_epoch="$(date -u -d "$TOPOLOGY_HEAD_DATE" +%s 2>/dev/null || true)"
  pin_epoch="$(date -u -d "$TOPOLOGY_PIN_DATE" +%s 2>/dev/null || true)"

  if [[ "$pin_epoch" =~ ^[0-9]+$ ]] && [[ "$head_epoch" =~ ^[0-9]+$ ]]; then
    TOPOLOGY_AGE_DELTA_DAYS="$(signed_days_delta "$pin_epoch" "$head_epoch")"
  fi

  TOPOLOGY_STATUS_API="$base_status"
  TOPOLOGY_AVAILABLE=1
  return 0
}

signed_days_delta() {
  local older_epoch="$1"
  local newer_epoch="$2"
  local delta sign

  delta=$((newer_epoch - older_epoch))
  sign="+"

  if (( delta < 0 )); then
    sign="-"
    delta=$((-delta))
  fi

  printf '%s%d' "$sign" "$((delta / 86400))"
}

git_cache_repo_path() {
  local owner="$1"
  local repo="$2"
  printf '%s/%s-%s.repo' "$GIT_CACHE_DIR" "$owner" "$repo"
}

init_or_update_git_cache() {
  local repo_url="$1"
  local pin_owner="$2"
  local pin_repo="$3"
  local cache_repo

  cache_repo="$(git_cache_repo_path "$pin_owner" "$pin_repo")"

  if [[ ! -d "$cache_repo/.git" ]]; then
    log_info "initializing git cache at $cache_repo"
    mkdir -p "$cache_repo" || return 1
    if ! git -C "$cache_repo" init -q >/dev/null 2>&1; then
      return 1
    fi
    if ! git -C "$cache_repo" remote add origin "$repo_url" >/dev/null 2>&1; then
      return 1
    fi
  fi

  printf '%s\n' "$cache_repo"
}

collect_upstream_topology_git() {
  local pin_rev="$1"
  local upstream_head="$2"
  local repo_url="$3"
  local pin_owner="$4"
  local pin_repo="$5"
  local cache_repo counts pin_epoch head_epoch

  TOPOLOGY_AVAILABLE=0
  TOPOLOGY_SOURCE="git"
  TOPOLOGY_AHEAD_COUNT=""
  TOPOLOGY_BEHIND_COUNT=""
  TOPOLOGY_MERGE_BASE=""
  TOPOLOGY_MERGE_BASE_DATE=""
  TOPOLOGY_PIN_DATE=""
  TOPOLOGY_HEAD_DATE=""
  TOPOLOGY_AGE_DELTA_DAYS=""

  cache_repo="$(init_or_update_git_cache "$repo_url" "$pin_owner" "$pin_repo" 2>/dev/null)" || return 1

  log_info "updating git cache refs for topology (this can be slower on first run)"
  if ! git -C "$cache_repo" fetch --filter=blob:none --no-tags origin "$pin_rev" "$upstream_head" >/dev/null 2>&1; then
    return 1
  fi

  counts="$(git -C "$cache_repo" rev-list --left-right --count "${pin_rev}...${upstream_head}" 2>/dev/null || true)"
  if [[ -z "$counts" ]]; then
    return 1
  fi

  TOPOLOGY_AHEAD_COUNT="$(awk '{print $1}' <<< "$counts")"
  TOPOLOGY_BEHIND_COUNT="$(awk '{print $2}' <<< "$counts")"

  TOPOLOGY_MERGE_BASE="$(git -C "$cache_repo" merge-base "$pin_rev" "$upstream_head" 2>/dev/null || true)"
  TOPOLOGY_PIN_DATE="$(commit_iso_date_from_repo "$cache_repo" "$pin_rev")"
  TOPOLOGY_HEAD_DATE="$(commit_iso_date_from_repo "$cache_repo" "$upstream_head")"

  if [[ -n "$TOPOLOGY_MERGE_BASE" ]]; then
    TOPOLOGY_MERGE_BASE_DATE="$(commit_iso_date_from_repo "$cache_repo" "$TOPOLOGY_MERGE_BASE")"
  fi

  pin_epoch="$(commit_epoch_from_repo "$cache_repo" "$pin_rev")"
  head_epoch="$(commit_epoch_from_repo "$cache_repo" "$upstream_head")"

  if [[ "$pin_epoch" =~ ^[0-9]+$ ]] && [[ "$head_epoch" =~ ^[0-9]+$ ]]; then
    TOPOLOGY_AGE_DELTA_DAYS="$(signed_days_delta "$pin_epoch" "$head_epoch")"
  fi

  TOPOLOGY_AVAILABLE=1
  return 0
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
  local lrev lhash upstream_head repo_url

  pin_type="$(extract_nixpkgs_field_from_flake_block type)"
  pin_owner="$(extract_nixpkgs_field_from_flake_block owner)"
  pin_repo="$(extract_nixpkgs_field_from_flake_block repo)"
  pin_rev="$(extract_nixpkgs_field_from_flake_block rev)"

  lrev="$(lock_rev)"
  lhash="$(lock_nar_hash)"
  upstream_head="$(upstream_head_for_tracking_ref || true)"
  repo_url="$(pin_repo_url)"

  if ! cache_prepare_dirs; then
    log_info "warning: failed to prepare cache dirs under $CACHE_ROOT_DIR"
  else
    log_info "cache root: $CACHE_ROOT_DIR"
  fi

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

    log_info "computing topology via GitHub API first"

    if collect_upstream_topology_api "$pin_rev" "$upstream_head" "$pin_owner" "$pin_repo"; then
      log_info "topology source: API"
    else
      log_info "API topology unavailable, falling back to git topology"
      collect_upstream_topology_git "$pin_rev" "$upstream_head" "$repo_url" "$pin_owner" "$pin_repo" || true
    fi

    if [[ "${TOPOLOGY_AVAILABLE:-0}" == "1" ]]; then
      echo "  topology"
      echo "    source: ${TOPOLOGY_SOURCE:-unknown}"
      echo "    ahead count (pin-only): ${TOPOLOGY_AHEAD_COUNT}"
      echo "    behind count (tracking-only): ${TOPOLOGY_BEHIND_COUNT}"
      echo "    merge-base: ${TOPOLOGY_MERGE_BASE:-unavailable}"
      echo "    merge-base date: ${TOPOLOGY_MERGE_BASE_DATE:-unavailable}"
      echo "    pinned commit date: ${TOPOLOGY_PIN_DATE:-unavailable}"
      echo "    tracking-head date: ${TOPOLOGY_HEAD_DATE:-unavailable}"
      echo "    age delta (head - pin): ${TOPOLOGY_AGE_DELTA_DAYS:-unavailable} days"

      if [[ "$TOPOLOGY_AHEAD_COUNT" == "0" && "$TOPOLOGY_BEHIND_COUNT" == "0" ]]; then
        echo "  status: pinned to current tracking head"
      elif [[ "$TOPOLOGY_AHEAD_COUNT" == "0" ]]; then
        echo "  status: pinned behind tracking head"
      elif [[ "$TOPOLOGY_BEHIND_COUNT" == "0" ]]; then
        echo "  status: pinned ahead of tracking head"
      else
        echo "  status: pinned diverged from tracking head"
      fi
    else
      if [[ "$pin_rev" == "$upstream_head" ]]; then
        echo "  status: pinned to current tracking head"
      else
        echo "  status: pinned behind/diverged from tracking head"
      fi
      echo "  topology: unavailable (failed to compute commit graph)"
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

  if ! command -v date >/dev/null 2>&1; then
    die "date command not found"
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
