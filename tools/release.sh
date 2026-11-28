#!/usr/bin/env bash
set -euo pipefail

fork=Starlightbotanist/pureRGB-caught-indicator
upstream=Vortyne/pureRGB
upstream_url="https://github.com/$upstream.git"
push_url="git@github.com:$fork.git"
branch=caught-indicator
feature_ref="refs/remotes/origin/$branch"
author='Starlightbotanist'
email='starlightbotanist@gmail.com'

fail() {
  echo "::error::$*" >&2
  exit 1
}

[[ "${GITHUB_REPOSITORY:?}" == "$fork" ]] || fail "Unexpected repository"
origin=$(git remote get-url --push origin)
[[ "${origin%.git}" == "https://github.com/$fork" ]] || fail "Unexpected origin"

export GIT_AUTHOR_NAME="$author" GIT_AUTHOR_EMAIL="$email"
export GIT_COMMITTER_NAME="$author" GIT_COMMITTER_EMAIL="$email"

fetch_upstream_tag() {
  [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Unexpected stable upstream tag: $1"
  git fetch --quiet --no-tags "$upstream_url" "refs/tags/$1" || fail "Could not fetch upstream tag $1"
  git rev-parse 'FETCH_HEAD^{commit}'
}

fetch_feature_refs() {
  git fetch --quiet --no-tags origin "refs/heads/$branch:$feature_ref"
  local remote_tag
  remote_tag=$(git ls-remote origin "refs/tags/$1")
  if [[ -n "$remote_tag" ]]; then
    git fetch --quiet --no-tags origin "refs/tags/$1:refs/tags/$1"
  fi
}

start_authenticated_push() {
  [[ -n "${DEPLOY_KEY:-}" ]] || fail 'Missing release deploy key'
  release_ssh_dir=$(mktemp -d "$RUNNER_TEMP/release-ssh.XXXXXX")
  trap 'rm -f -- "$release_ssh_dir/key" "$release_ssh_dir/known_hosts"; rmdir -- "$release_ssh_dir"' EXIT
  printf '%s\n' "$DEPLOY_KEY" > "$release_ssh_dir/key"
  chmod 600 "$release_ssh_dir/key"
  unset DEPLOY_KEY
  # GitHub's published Ed25519 SSH host key.
  printf '%s\n' 'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl' \
    > "$release_ssh_dir/known_hosts"
  local ssh_options=(-i "$release_ssh_dir/key" -o IdentitiesOnly=yes -o BatchMode=yes
                     -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$release_ssh_dir/known_hosts")
  local greeting status=0
  greeting=$(ssh "${ssh_options[@]}" -T git@github.com 2>&1) || status=$?
  [[ "$status" == 1 && "$greeting" == "Hi $fork!"* ]] || fail 'Deploy key did not authenticate to the expected repository'
  printf -v GIT_SSH_COMMAND '%q ' ssh "${ssh_options[@]}"
  export GIT_SSH_COMMAND
}

mirror() {
  local fork_tip upstream_tip
  fork_tip=$(git ls-remote --exit-code origin refs/heads/master | cut -f 1)
  upstream_tip=$(git ls-remote --exit-code "$upstream_url" refs/heads/master | cut -f 1)
  if [[ "$fork_tip" == "$upstream_tip" ]]; then
    echo "master already matches upstream ($upstream_tip)."
    return
  fi
  git fetch --quiet --no-tags "$upstream_url" refs/heads/master
  upstream_tip=$(git rev-parse FETCH_HEAD)
  git merge-base --is-ancestor "$fork_tip" "$upstream_tip" \
    || fail 'master has diverged from upstream. Restore the mirror before publishing.'
  git log --format='%H %an <%ae> | %cn <%ce>' "$fork_tip..$upstream_tip"
  start_authenticated_push
  git push --force-with-lease="refs/heads/master:$fork_tip" "$push_url" "$upstream_tip:refs/heads/master"
  fork_tip=$(git ls-remote --exit-code origin refs/heads/master | cut -f 1)
  [[ "$fork_tip" == "$upstream_tip" ]] || fail 'master did not reach the fetched upstream tip'
}

merge_commit() {
  if git merge-base --is-ancestor "$2" "$1"; then
    # Reuse a manually resolved merge of this release, or a commit pinned for retry.
    echo "$1"
    return
  fi
  local tree
  if ! tree=$(git merge-tree --write-tree "$1" "$2"); then
    printf '%s\n' "$tree" >&2
    fail "Could not merge $3 into $branch. Resolve the merge on $branch and rerun."
  fi
  git commit-tree "$tree" -p "$1" -p "$2" -m "Merge pureRGB $3"
}

release_list() {
  gh api --paginate "repos/$1/releases?per_page=100" | jq -s '[.[][]]'
}

prepare() {
  local tag version stock base caught tree color revision
  release_list "$fork" > "$RUNNER_TEMP/fork-releases.json"
  # Begin with releases published after the fork's last manual release, v2.7.4.
  tag=$(release_list "$upstream" | jq -r --slurpfile fork "$RUNNER_TEMP/fork-releases.json" '
    [ $fork[0][] | select(.draft | not) | .tag_name ] as $published
    | map(select((.draft or .prerelease) | not)
          | select(.published_at > "2026-05-27T14:25:48Z")
          | select(.tag_name as $tag | $published | index($tag) | not))
    | sort_by(.published_at, .id) | first | .tag_name // empty
  ')
  if [[ -z "$tag" ]]; then
    echo 'All eligible upstream releases are published.'
    return
  fi
  stock=$(fetch_upstream_tag "$tag")
  fetch_feature_refs "$tag"
  base=$(git rev-parse "$feature_ref")
  if git show-ref --verify --quiet "refs/tags/$tag"; then
    caught=$(git rev-parse "refs/tags/$tag^{commit}")
    git merge-base --is-ancestor "$caught" "$base" || fail "$tag is outside $branch"
    git merge-base --is-ancestor "$stock" "$caught" || fail "$tag does not contain its upstream release"
  else
    caught=$(merge_commit "$base" "$stock" "$tag")
  fi
  tree=$(git rev-parse "$caught^{tree}")
  version=${tag#v}
  for revision in "$stock" "$caught"; do
    git show "$revision:version_number.asm" | grep -Fx "db \"$version\"" \
      || fail "$tag does not match the source version at $revision"
  done
  git worktree add --detach "$RUNNER_TEMP/stock" "$stock"
  git worktree add --detach "$RUNNER_TEMP/caught" "$caught"
  local patterns=()
  for color in Blue Green Red; do
    patterns+=(--pattern "Pokemon_Pure${color}_$tag.bps")
  done
  gh release download "$tag" --repo "$upstream" --dir "$RUNNER_TEMP/upstream-assets" "${patterns[@]}"
  {
    echo "tag=$tag"
    echo "upstream=$stock"
    echo "base=$base"
    echo "tree=$tree"
    echo "archive=Caught_indicator_${version//./_}.zip"
  } >> "$GITHUB_OUTPUT"
}

publish() {
  local caught title draft notes digest archive
  [[ "$(fetch_upstream_tag "$TAG")" == "$UPSTREAM_SHA" ]] || fail "$TAG moved upstream during the build"
  archive="$RUNNER_TEMP/package/$ARCHIVE"
  [[ "$ARCHIVE" == "Caught_indicator_$(echo "${TAG#v}" | tr . _).zip" && -s "$archive" ]] \
    || fail "Missing patch ZIP for $TAG"
  fetch_feature_refs "$TAG"

  if git show-ref --verify --quiet "refs/tags/$TAG"; then
    caught=$(git rev-parse "refs/tags/$TAG^{commit}")
    git merge-base --is-ancestor "$caught" "$feature_ref" || fail "$TAG is outside $branch"
    [[ "$(git rev-parse "$caught^{tree}")" == "$BUILT_TREE" ]] || fail "$TAG changed during the build"
  else
    [[ "$(git rev-parse "$feature_ref")" == "$BASE_SHA" ]] || fail "$branch changed during the build"
    caught=$(merge_commit "$BASE_SHA" "$UPSTREAM_SHA" "$TAG")
    [[ "$(git rev-parse "$caught^{tree}")" == "$BUILT_TREE" ]] || fail "Release tree changed during the build"
    if [[ "$caught" != "$BASE_SHA" ]]; then
      [[ "$(git show -s --format='%an <%ae>%n%cn <%ce>' "$caught")" == "$author <$email>"$'\n'"$author <$email>" ]] \
        || fail 'Unexpected merge identity'
    fi
    start_authenticated_push
    # Publish the exact built tree and pin it for safe retries if the asset upload fails.
    git push --atomic --force-with-lease="refs/heads/$branch:$BASE_SHA" \
      --force-with-lease="refs/tags/$TAG:" "$push_url" "$caught:refs/heads/$branch" "$caught:refs/tags/$TAG"
  fi

  title="pureRGB-caught-indicator - $TAG"
  notes="$RUNNER_TEMP/release-notes.md"
  # Preserve the line endings and terminal byte of the previous release notes.
  python3 - "$notes" <<'PY'
from pathlib import Path
import sys

text = Path('tools/release-notes.md').read_text(encoding='utf-8').rstrip('\n')
Path(sys.argv[1]).write_bytes(text.replace('\n', '\r\n').encode('utf-8'))
PY
  draft=$(release_list "$fork" | jq -c --arg tag "$TAG" '.[] | select(.tag_name == $tag)')
  if [[ -z "$draft" ]]; then
    gh release create "$TAG" --repo "$fork" --verify-tag --title "$title" --notes-file "$notes" --draft
  else
    jq -e --arg title "$title" --arg asset "$ARCHIVE" --rawfile notes "$notes" \
      '.draft and .name == $title and .body == $notes and all(.assets[]; .name == $asset)' \
      <<< "$draft" >/dev/null || fail "A release for $TAG already exists and differs from the expected draft"
  fi

  gh release upload "$TAG" "$archive" --repo "$fork" --clobber
  digest=$(sha256sum "$archive" | cut -d ' ' -f 1)
  release_list "$fork" | jq -e --arg tag "$TAG" --arg name "$ARCHIVE" --arg digest "sha256:$digest" \
    'any(.[]; .tag_name == $tag and .draft and (.assets | length) == 1
              and any(.assets[]; .name == $name and .state == "uploaded" and .digest == $digest))' >/dev/null \
    || fail "Uploaded ZIP could not be verified"
  gh release edit "$TAG" --repo "$fork" --draft=false --latest
}

case "${1:-}" in
  mirror) mirror ;;
  prepare) prepare ;;
  publish) publish ;;
  *) fail "Use $0 mirror, prepare, or publish" ;;
esac
