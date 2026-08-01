#!/usr/bin/env bash
# user-discovery-proposal-norm gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$HERE/resolve-core.sh"
GATE="$HERE/../user-discovery-proposal-norm/hooks/proposal-norm-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

run() { # want name file_path content extra_env
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/docs/issue-7/proposals"
  payload_file="$td/.payload.json"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    > "$payload_file"
  env CLAUDE_PROJECT_DIR="$td" ${5:-} /bin/bash "$GATE" < "$payload_file" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

run allow proposal-cites-survey \
  docs/issue-7/proposals/plugin-enforcement.md \
  'Per docs/issue-7/reports/user-discovery/survey.md we propose X.'

run deny proposal-no-survey-cited \
  docs/issue-7/proposals/plugin-enforcement.md \
  'We propose X because it seems good.'

run allow non-owning-path \
  docs/issue-7/reports/user-discovery.md \
  'no survey citation here at all'

run allow kill-switch \
  docs/issue-7/proposals/plugin-enforcement.md \
  'no survey citation here at all' \
  'USER_DISCOVERY_PROPOSAL_NORM_GATE_OFF=1'

run deny kill-switch-unrecognized-value-stays-active \
  docs/issue-7/proposals/plugin-enforcement.md \
  'We propose X because it seems good.' \
  'USER_DISCOVERY_PROPOSAL_NORM_GATE_OFF=banana'

# Bash-tool write reaching this gate's owned proposal path is denied
# (previously invisible — the gate only matched Write/Edit/MultiEdit).
PROP=docs/issue-7/proposals/plugin-enforcement.md
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$PROP")"
printf '{"tool_name":"Bash","tool_input":{"command":"printf x > %s"},"cwd":"%s"}' "$PROP" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" bash-tool-write-to-owned-path

# absolute path resolves to the same outcome as the relative-path case
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$PROP")"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$td/$PROP" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' 'We propose X because it seems good.')" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" absolute-path-no-survey-cited

# malformed JSON — truncated, non-object, empty — all deny (exit 2)
for label_payload in \
  'truncated-json:{"tool_name":"Write","tool_input":' \
  'non-object-json:[1,2,3]' \
  'empty-payload:'; do
  label="${label_payload%%:*}"
  bad_payload="${label_payload#*:}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$PROP")"
  printf '%s' "$bad_payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report deny "$got" "malformed-json-$label"
done

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
