#!/usr/bin/env bash
# Ghost-file / stale-role-name hard-error guard (issue-13 gate A+ closeout,
# fix 5). Scoped-down analog of core's stub-check.sh / canon-manifest
# mechanism — this repo does not vendor canon files, so it only needs two
# absence-based checks, not stub-check's structural directive.sh check:
#
#   1. every file path referenced from this repo's README.md files and
#      .claude-plugin/*.json manifests must exist on disk.
#   2. no retired role-name string (this plugin set's own history — see
#      RETIRED_NAMES below) may appear in any README.md or manifest file.
#
# A clean run here is the ship-time evidence that "green suite" already
# implies req. 4 (no ghost files / stale role names), per
# docs/issue-13/proposals/gate-a-plus-remediation.md fix 5.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$HERE/.." && pwd -P)"
rc=0

# --- 1. every referenced file path resolves on disk -------------------------
# Scoped to what a README/manifest in THIS repo can actually verify: its own
# plugin's hooks/ scripts (resolved relative to the README's own directory —
# these READMEs describe "hooks/foo.sh" meaning ./hooks/foo.sh from the
# plugin root they live in) and manifest JSON "source" fields (resolved from
# repo root, as `.claude-plugin/marketplace.json` already does). Cross-repo
# canon references (`core/hooks/lib/gate-lib.sh`, `docs/handbooks/*.md`
# living in the shared handbooks/core repos, `docs/issue-160/...` in
# on-the-record) are explicitly out of scope — this repo cannot resolve
# another repo's tree, and treating them as ghosts would be a false
# positive, not a real drift signal.
manifests="$(find "$ROOT" -maxdepth 3 \( -name 'README.md' -o -path '*/.claude-plugin/*.json' \) -type f 2>/dev/null | sort)"

while IFS= read -r mf; do
  [ -n "$mf" ] || continue
  mdir="$(dirname "$mf")"
  case "$mf" in
    *.json)
      while IFS= read -r p; do
        [ -n "$p" ] || continue
        candidate="$ROOT/${p#./}"
        if [ ! -e "$candidate" ]; then
          echo "manifest-check: FAIL — $mf references '$p', which does not exist at $candidate" >&2
          rc=1
        fi
      done < <(grep -oE '"(source|path)": *"\./[^"]+"' "$mf" | sed -E 's/^"(source|path)": *"//; s/"$//')
      ;;
    *)
      # The repo-root README.md documents all 5 plugins at once, so a bare
      # "hooks/foo.sh" mention there is ambiguous about which plugin dir it
      # belongs to — only each plugin's own README.md (one unambiguous
      # hooks/ directory) is checked here.
      [ "$mf" = "$ROOT/README.md" ] && continue
      while IFS= read -r p; do
        [ -n "$p" ] || continue
        candidate="$mdir/$p"
        if [ ! -e "$candidate" ]; then
          echo "manifest-check: FAIL — $mf references '$p' (this plugin's own hooks/), which does not exist at $candidate" >&2
          rc=1
        fi
      done < <(grep -oE '`hooks/[A-Za-z0-9_./-]+\.[A-Za-z0-9]+`' "$mf" | sed -E 's/^`//; s/`$//')
      ;;
  esac
done <<< "$manifests"
[ "$rc" -eq 0 ] && echo "manifest-check: ok — every hooks/ path referenced from a README, and every manifest source/path, resolves on disk"

# --- 2. retired role-name strings are hard errors ---------------------------
# Populated from this repo's own history: names this plugin set used before
# its current 5-plugin (user-discovery + 4 enforcement plugins) structure.
RETIRED_NAMES=(
  "warrant-hunter"
)

for name in "${RETIRED_NAMES[@]}"; do
  hits="$(grep -rl -- "$name" $(printf '%s\n' "$manifests") 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    echo "manifest-check: FAIL — retired role-name '$name' still referenced:" >&2
    printf '%s\n' "$hits" >&2
    rc=1
  else
    echo "manifest-check: ok — retired role-name '$name' absent from README/manifest files"
  fi
done

exit "$rc"
