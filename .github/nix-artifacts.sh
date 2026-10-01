#!/usr/bin/env bash
set -euo pipefail

roots() {
  local system checks packages
  system="$(nix eval --impure --raw --expr builtins.currentSystem)"
  checks="$(nix eval --json ".#checks.$system" --apply 'checks: builtins.map (check: check.outPath) (builtins.attrValues checks)')"
  packages="$(nix eval --json ".#packages.$system" --apply 'packages: builtins.map (name: (builtins.getAttr name packages).outPath) [ "rad" "rad-rc" "bicep" ]')"
  printf '%s\n' "$checks" "$packages" | jq -sr 'add | unique | .[]'
}

resolve() {
  local repository head tree runs run attempt artifacts commits tested_commit commit
  repository="repos/$GITHUB_REPOSITORY"
  tree="$(git rev-parse 'HEAD^{tree}')"
  head="$(gh api "$repository/commits/$GITHUB_SHA/pulls" --jq '[.[] | select(.merged_at != null and .merge_commit_sha == env.GITHUB_SHA) | .head.sha][0] // empty')"
  if [[ -z "$head" ]]; then
    echo 'No merged PR for this commit; building normally.'
    return
  fi

  runs="$(gh api --paginate "$repository/actions/workflows/check.yml/runs?event=pull_request&head_sha=$head&status=success&per_page=100" --jq ".workflow_runs[] | select(.head_sha == \"$head\" and .event == \"pull_request\" and .conclusion == \"success\" and .path == \".github/workflows/check.yml\") | [.id, .run_attempt] | @tsv")"
  while IFS=$'\t' read -r run attempt; do
    [[ -n "$run" ]] || continue
    artifacts="$(gh api --paginate "$repository/actions/runs/$run/artifacts?per_page=100" --jq '.artifacts[] | select(.expired == false) | .name' | jq -Rn '[inputs]')"
    commits="$(jq -r --arg attempt "$attempt" '[.[] | select(test("^nix-(x86_64-linux|aarch64-linux|aarch64-darwin)-[0-9a-f]{40}-" + $attempt + "$")) | split("-")[-2]] | unique | .[]' <<< "$artifacts")"
    while IFS= read -r tested_commit; do
      [[ -n "$tested_commit" ]] || continue
      if ! jq -e --arg suffix "$tested_commit-$attempt" --argjson artifacts "$artifacts" 'all(["x86_64-linux", "aarch64-linux", "aarch64-darwin"][]; . as $system | $artifacts | index("nix-\($system)-\($suffix)") != null)' <<< '{}' >/dev/null; then
        continue
      fi

      # Resolve the tested commit through GitHub, rather than trusting an artifact's tree claim.
      commit="$(gh api "$repository/git/commits/$tested_commit")"
      if ! jq -e --arg tree "$tree" --arg head "$head" '.tree.sha == $tree and (.parents | length) == 2 and .parents[1].sha == $head' <<< "$commit" >/dev/null; then
        continue
      fi

      printf 'run-id=%s\nartifact-suffix=%s-%s\n' "$run" "$tested_commit" "$attempt" >> "$GITHUB_OUTPUT"
      echo "Reusing tested outputs from PR run $run (commit $tested_commit)."
      return
    done <<< "$commits"
  done <<< "$runs"
  echo 'No complete set of matching PR artifacts; building normally.'
}

export_outputs() {
  local system closure path
  local paths=() closure_paths=()
  system="$(nix eval --impure --raw --expr builtins.currentSystem)"
  mkdir -p "$RUNNER_TEMP/nix-artifact"
  roots > "$RUNNER_TEMP/nix-artifact-roots"
  while IFS= read -r path; do paths+=("$path"); done < "$RUNNER_TEMP/nix-artifact-roots"
  closure="$(nix-store --query --requisites "${paths[@]}")"
  while IFS= read -r path; do closure_paths+=("$path"); done <<< "$closure"
  nix-store --export "${closure_paths[@]}" | gzip -1 > "$RUNNER_TEMP/nix-artifact/store.nar.gz"
  printf 'artifact-name=nix-%s-%s-%s\n' "$system" "$(git rev-parse HEAD)" "$GITHUB_RUN_ATTEMPT" >> "$GITHUB_OUTPUT"
}

import_outputs() {
  local path
  local paths=()
  gzip --decompress --stdout "$RUNNER_TEMP/nix-artifact/store.nar.gz" | nix-store --import
  roots > "$RUNNER_TEMP/nix-artifact-roots"
  while IFS= read -r path; do paths+=("$path"); done < "$RUNNER_TEMP/nix-artifact-roots"
  nix-store --check-validity "${paths[@]}"
}

case "${1:-}" in
  resolve) resolve ;;
  export) export_outputs ;;
  import) import_outputs ;;
  roots) roots ;;
  *) echo 'Usage: nix-artifacts.sh {resolve|export|import|roots}' >&2; exit 1 ;;
esac
