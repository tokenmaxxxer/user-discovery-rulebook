#!/usr/bin/env bash
# user-discovery-proposal-norm gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$HERE/resolve-core.sh"
GATE="$HERE/../user-discovery-proposal-norm/hooks/proposal-norm-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }
groups_seen=""
mark() { groups_seen="$groups_seen $1"; }
mark absolute-path
mark bash-write-coverage
mark malformed-json
mark kill-switch
mark replace_all-edit
mark multiedit-replace_all
mark missing-core

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

# Edit with replace_all: true against a doubly-occurring survey citation:
# removing BOTH occurrences leaves the proposal with no survey citation at
# all -> deny. A first-occurrence-only bug would leave the second citation
# intact and wrongly allow.
run_edit() { # want name old new replace_all pre_content
  local want="$1" name="$2" old="$3" new="$4" replace_all="$5" pre="$6"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$PROP")"
  printf '%s' "$pre" > "$td/$PROP"
  payload="$(python3 -c '
import json, sys
old, new, ra, pre = sys.argv[1], sys.argv[2], sys.argv[3] == "true", sys.argv[4]
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[5], "old_string": old, "new_string": new, "replace_all": ra}, "cwd": sys.argv[6]}))
' "$old" "$new" "$replace_all" "$pre" "$PROP" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_edit deny edit-replace-all-both-occurrences \
  'Per docs/issue-7/reports/user-discovery/survey.md' 'Per our judgement' 'true' \
  'Per docs/issue-7/reports/user-discovery/survey.md we propose X.
Per docs/issue-7/reports/user-discovery/survey.md this also holds.'

# MultiEdit with a mix of replace_all:false/true edits in one call. Pre-
# content has two survey citations. Edit 1 (replace_all:false) rewrites an
# unrelated span; edit 2 (replace_all:true) removes the citation phrase
# everywhere, of which two remain -- a correct per-edit-flag reconstruction
# removes both (deny, no citation left); a collapsed-to-count=1 bug would
# leave one behind (wrongly allow).
run_multiedit() { # want name pre edits_json
  local want="$1" name="$2" pre="$3" edits_json="$4"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$PROP")"
  printf '%s' "$pre" > "$td/$PROP"
  payload="$(python3 -c '
import json, sys
edits = json.loads(sys.argv[1])
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": sys.argv[2], "edits": edits}, "cwd": sys.argv[3]}))
' "$edits_json" "$PROP" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_multiedit deny multiedit-mixed-replace-all \
  'Intro. Per docs/issue-7/reports/user-discovery/survey.md we propose X. Per docs/issue-7/reports/user-discovery/survey.md this also holds.' \
  '[{"old_string":"Intro.","new_string":"Introduction.","replace_all":false},{"old_string":"Per docs/issue-7/reports/user-discovery/survey.md","new_string":"Per our judgement","replace_all":true}]'

# missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere must deny (guarded
# source line, issue-75/issue-13 fix), not silently allow.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$PROP")"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$PROP" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' 'x')" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core" /bin/bash "$GATE" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" missing-core-guarded-source-denies

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
for g in replace_all-edit multiedit-replace_all malformed-json kill-switch absolute-path bash-write-coverage missing-core; do
  case " $groups_seen " in
    *" $g "*) ;;
    *) echo "proposal-norm-gate-tests: MANDATORY GROUP MISSING: $g" >&2; fail=$((fail + 1)) ;;
  esac
done
[ "$fail" -eq 0 ]
