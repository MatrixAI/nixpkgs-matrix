#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOWLIST_FILE="$ROOT_DIR/checks/policy-pin-allowlist.nix"

DEFAULT_TRACKING_REF="refs/heads/main"

usage() {
  cat <<'EOF'
Usage:
  scripts/external-pin-lifecycle.sh info [--tracking-ref <git-ref>]

Description:
  Show allowlisted external flake pins, commit age, and review-window due status.

Options:
  --tracking-ref <git-ref>
      Upstream branch/ref used for freshness comparison (default: refs/heads/main,
      with fallback to refs/heads/master when unavailable).
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || die "required command not found: $name"
}

parse_args() {
  TRACKING_REF="$DEFAULT_TRACKING_REF"
  POSITIONAL_ARGS=()

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

require_file() {
  [[ -f "$ALLOWLIST_FILE" ]] || die "allowlist file not found: $ALLOWLIST_FILE"
}

nix_eval_raw() {
  local expr="$1"
  nix eval --raw --impure --expr "$expr" 2>/dev/null
}

nix_eval_json() {
  local expr="$1"
  nix eval --json --impure --expr "$expr" 2>/dev/null
}

allowlist_json() {
  nix_eval_json "import ${ALLOWLIST_FILE}"
}

extract_allowlist_keys() {
  local allowlist="$1"
  jq -r 'keys[]' <<< "$allowlist"
}

extract_field_line() {
  local allowlist="$1"
  local key="$2"
  local field="$3"
  jq -r --arg k "$key" --arg f "$field" '.[$k][$f] // empty' <<< "$allowlist"
}

extract_review_days() {
  local allowlist="$1"
  local key="$2"
  jq -r --arg k "$key" '.[$k].reviewCadenceDays // empty' <<< "$allowlist"
}

extract_pinned_ref_from_path() {
  local rel_path="$1"
  local abs_path="$ROOT_DIR/$rel_path"

  [[ -f "$abs_path" ]] || return 1

  grep -Eo 'github:[^"[:space:]]+/[0-9a-f]{40}' "$abs_path" | head -n 1
}

fetch_json() {
  local url="$1"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 20 \
      -H 'Accept: application/vnd.github+json' \
      "$url"
    return $?
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -q -T 20 -O - \
      --header='Accept: application/vnd.github+json' \
      "$url"
    return $?
  fi

  return 127
}

iso_from_commit() {
  local repo_owner="$1"
  local repo="$2"
  local sha="$3"

  fetch_json "https://api.github.com/repos/${repo_owner}/${repo}/commits/${sha}" \
    | jq -r '.commit.committer.date // .commit.author.date // empty'
}

epoch_from_iso() {
  local iso="$1"
  date -u -d "$iso" +%s 2>/dev/null || true
}

head_sha_for_tracking() {
  local repo_owner="$1"
  local repo="$2"
  local tracking_ref="$3"

  git ls-remote "https://github.com/${repo_owner}/${repo}" "$tracking_ref" 2>/dev/null | awk 'NR==1 {print $1}'
}

resolve_tracking_head() {
  local repo_owner="$1"
  local repo="$2"
  local ref="$3"
  local head

  head="$(head_sha_for_tracking "$repo_owner" "$repo" "$ref")"
  if [[ -n "$head" ]]; then
    printf '%s|%s\n' "$ref" "$head"
    return 0
  fi

  if [[ "$ref" != "refs/heads/master" ]]; then
    head="$(head_sha_for_tracking "$repo_owner" "$repo" "refs/heads/master")"
    if [[ -n "$head" ]]; then
      printf '%s|%s\n' "refs/heads/master" "$head"
      return 0
    fi
  fi

  printf 'unavailable|\n'
}

print_info() {
  local allowlist keys key path ref owner rationale cadence sha pin_iso pin_epoch now_epoch
  local age_days due_status repo_owner repo_name tracking_tuple tracking_ref tracking_head

  allowlist="$(allowlist_json)"
  [[ -n "$allowlist" ]] || die "failed to evaluate allowlist from $ALLOWLIST_FILE"

  keys="$(extract_allowlist_keys "$allowlist")"
  [[ -n "$keys" ]] || die "no allowlist entries found in $ALLOWLIST_FILE"

  echo "external pin lifecycle"
  echo "  allowlist file: $ALLOWLIST_FILE"
  echo "  tracking ref:   $TRACKING_REF"
  echo

  now_epoch="$(date +%s)"

  while IFS= read -r key; do
    [[ -n "$key" ]] || continue

    path="$key"
    rationale="$(extract_field_line "$allowlist" "$key" rationale)"
    cadence="$(extract_review_days "$allowlist" "$key")"

    [[ -n "$path" ]] || die "missing path for allowlist key: $key"
    [[ -f "$ROOT_DIR/$path" ]] || die "allowlisted path does not exist in repository: $path"
    ref="$(extract_pinned_ref_from_path "$path" || true)"
    [[ -n "$ref" ]] || die "missing commit-pinned github:<owner>/<repo>/<sha> ref in allowlisted file: $path"
    [[ -n "$ref" ]] || die "missing ref for allowlist key: $key"
    [[ -n "$rationale" ]] || die "missing rationale for allowlist key: $key"
    [[ -n "$cadence" ]] || die "missing reviewCadenceDays for allowlist key: $key"

    if [[ "$ref" =~ ^github:([^/]+)/([^/]+)/([0-9a-f]{40})$ ]]; then
      repo_owner="${BASH_REMATCH[1]}"
      repo_name="${BASH_REMATCH[2]}"
      sha="${BASH_REMATCH[3]}"
      owner="$repo_owner"
    else
      die "ref for $key is not commit pinned in github:<owner>/<repo>/<sha> form: $ref"
    fi

    pin_iso="$(iso_from_commit "$repo_owner" "$repo_name" "$sha" || true)"
    if [[ -n "$pin_iso" ]]; then
      pin_epoch="$(epoch_from_iso "$pin_iso")"
      if [[ "$pin_epoch" =~ ^[0-9]+$ ]]; then
        age_days="$(( (now_epoch - pin_epoch) / 86400 ))"
      else
        age_days="unknown"
      fi
    else
      age_days="unknown"
    fi

    if [[ "$age_days" =~ ^[0-9]+$ ]]; then
      if (( age_days >= cadence )); then
        due_status="DUE"
      else
        due_status="OK"
      fi
    else
      due_status="UNKNOWN"
    fi

    tracking_tuple="$(resolve_tracking_head "$repo_owner" "$repo_name" "$TRACKING_REF")"
    tracking_ref="$(printf '%s' "$tracking_tuple" | awk -F'|' '{print $1}')"
    tracking_head="$(printf '%s' "$tracking_tuple" | awk -F'|' '{print $2}')"

    echo "- $key"
    echo "  owner (derived):      $owner"
    echo "  rationale:            $rationale"
    echo "  path:                 $path"
    echo "  ref:                  $ref"
    echo "  pinned sha:           $sha"
    echo "  pinned commit date:   ${pin_iso:-unknown}"
    echo "  pin age days:         $age_days"
    echo "  review cadence days:  $cadence"
    echo "  review due status:    $due_status"
    echo "  tracking ref used:    ${tracking_ref:-unavailable}"
    echo "  tracking head sha:    ${tracking_head:-unavailable}"
    echo
  done <<< "$keys"
}

main() {
  parse_args "$@"

  local cmd="${POSITIONAL_ARGS[0]:-}"
  [[ -n "$cmd" ]] || {
    usage
    exit 1
  }

  require_cmd nix
  require_cmd git
  require_cmd jq
  require_cmd date

  require_file

  case "$cmd" in
    info)
      if [[ ${#POSITIONAL_ARGS[@]} -ne 1 ]]; then
        usage
        exit 1
      fi
      print_info
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
