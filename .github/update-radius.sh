#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ci=false
only_check=false
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
sources_file="nix/sources.json"

for arg in "$@"; do
  case "$arg" in
    --ci)
      ci=true
      ;;
    --only-check)
      only_check=true
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

set_output() {
  if $ci && [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "$1" "$2" >>"$GITHUB_OUTPUT"
  fi
}

current_rev() {
  local channel="$1"
  jq -r --arg channel "$channel" '.[$channel].rev' "$sources_file"
}

update_source_field() {
  local channel="$1"
  local field="$2"
  local value="$3"
  local tmp
  tmp="$(mktemp)"
  jq --arg channel "$channel" --arg field "$field" --arg value "$value" '.[$channel][$field] = $value' "$sources_file" >"$tmp"
  mv "$tmp" "$sources_file"
}

prepare_channel_update() {
  local channel="$1"
  local rev="$2"
  local version="${rev#v}"
  local tmp
  tmp="$(mktemp)"
  jq \
    --arg channel "$channel" \
    --arg version "$version" \
    --arg rev "$rev" \
    --arg fake "$fake_hash" \
    '.[$channel].version = $version | .[$channel].rev = $rev | .[$channel].srcHash = $fake | .[$channel].vendorHash = $fake' \
    "$sources_file" >"$tmp"
  mv "$tmp" "$sources_file"
}

extract_got_hash() {
  local log_file="$1"
  sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' "$log_file" | tail -n 1
}

resolve_hash() {
  local channel="$1"
  local package_attr="$2"
  local field="$3"
  local log_file
  log_file="$(mktemp)"

  if nix build "$package_attr" --no-link -L >"$log_file" 2>&1; then
    rm -f "$log_file"
    return 0
  fi

  local hash
  hash="$(extract_got_hash "$log_file")"

  if [ -z "$hash" ]; then
    cat "$log_file" >&2
    rm -f "$log_file"
    printf 'Failed to resolve %s for %s\n' "$field" "$channel" >&2
    exit 1
  fi

  update_source_field "$channel" "$field" "$hash"
  rm -f "$log_file"
}

update_channel() {
  local channel="$1"
  local rev="$2"
  local package_attr="$3"

  prepare_channel_update "$channel" "$rev"
  resolve_hash "$channel" "$package_attr" srcHash
  resolve_hash "$channel" "$package_attr" vendorHash
  nix build "$package_attr" --no-link >/dev/null
}

stable_rev="$(gh api repos/radius-project/radius/releases --jq 'map(select(.draft == false and .prerelease == false)) | first.tag_name')"
rc_rev="$(gh api repos/radius-project/radius/releases --jq 'map(select(.draft == false and .prerelease == true)) | first.tag_name')"

stable_changed=false
rc_changed=false

if [ "$(current_rev stable)" != "$stable_rev" ]; then
  stable_changed=true
fi

if [ "$(current_rev rc)" != "$rc_rev" ]; then
  rc_changed=true
fi

if ! $stable_changed && ! $rc_changed; then
  set_output should_update false
  set_output should_sync_rc false
  exit 0
fi

if $only_check; then
  set_output should_update true
  set_output should_sync_rc true
  exit 0
fi

if $stable_changed; then
  update_channel stable "$stable_rev" .#rad-unwrapped
fi

if $rc_changed; then
  update_channel rc "$rc_rev" .#rad-rc-unwrapped
fi

nix build .#rad --no-link >/dev/null
nix build .#rad-rc --no-link >/dev/null

commit_message="chore(update):"

if $stable_changed; then
  commit_message="${commit_message} stable to ${stable_rev}"
fi

if $rc_changed; then
  if $stable_changed; then
    commit_message="${commit_message} and"
  fi
  commit_message="${commit_message} rc to ${rc_rev}"
fi

set_output should_update true
set_output should_sync_rc true
set_output commit_message "$commit_message"
