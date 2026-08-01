#!/usr/bin/env bash
# user-discovery-hypothesis-order gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$HERE/resolve-core.sh"
HOOK="$HERE/../user-discovery-hypothesis-order/hooks/hypothesis-order-gate.sh"
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

REC=docs/issue-7/reports/user-discovery.md

run() { # want name path content [extra_env_assignments...]
  local want="$1" name="$2" path="$3" content="$4"; shift 4
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$path")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$path" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    > "$td/.payload.json"
  env CLAUDE_PROJECT_DIR="$td" "$@" /bin/bash "$HOOK" < "$td/.payload.json" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

# (a) verdict marker, no prior state, no evidence tag in same content -> deny
run deny verdict-no-evidence "$REC" 'hypothesis: H1 users struggle
verdict: pain-confirmed'

# (b) evidence tag AND verdict marker in same write -> allow
run allow evidence-and-verdict-same-write "$REC" 'hypothesis: H1 users struggle
evidence: behavioral observation logged
verdict: pain-confirmed'

# (c) prior state file with evidence_logged=true, then write with only a verdict marker -> allow
run_with_prior_state() {
  local want="$1" name="$2" path="$3" content="$4"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/docs/issue-7/reports/user-discovery"
  printf '{"hypotheses_stated": true, "evidence_logged": true, "verdict_written": false}' \
    > "$td/docs/issue-7/reports/user-discovery/.state.json"
  mkdir -p "$td/$(dirname "$path")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$path" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOK" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_with_prior_state allow prior-evidence-state-verdict-only "$REC" 'verdict: not-confirmed'

# (d) non-owning path -> allow, gate exits 0 immediately
run allow non-owning-path "docs/issue-7/proposals/x.md" 'verdict: pain-confirmed'

# (e) kill switch set -> allow regardless of content
run allow kill-switch "$REC" 'verdict: pain-confirmed' USER_DISCOVERY_HYPOTHESIS_ORDER_GATE_OFF=1

# (f) substring-vs-structure: '<h1>' in prose is not a labeled/heading/list
# hypothesis marker; with no evidence and a verdict marker present, deny
# still fires the same as it would with no hypothesis marker at all — this
# just proves the '<h1>' text alone did not accidentally count as anything.
run deny h1-in-prose-not-a-marker "$REC" \
  '<h1>Notes</h1> verdict: pain-confirmed with no evidence logged'

# (g) substring-vs-structure: bare "opinion" in running prose (about the
# rule itself, not a tag) does not satisfy the evidence marker, so a verdict
# right after it still denies for lack of evidence.
run deny opinion-in-prose-not-evidence "$REC" \
  'We must not accept opinion alone as evidence. verdict: pain-confirmed'

# (h) absolute path resolves to the same outcome as the relative-path case
run_abs() { # want name content
  local want="$1" name="$2" content="$3"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$REC")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$td/$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOK" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_abs deny absolute-path-verdict-no-evidence 'verdict: pain-confirmed'

# (i) ./-prefixed path resolves to the same outcome as the unprefixed case
run deny dot-prefixed-path-verdict-no-evidence "./$REC" 'verdict: pain-confirmed'

# (j) state-timing: a write this gate itself denies never advances
# .state.json (this gate is read-only at PreToolUse now — persistence moved
# to the PostToolUse hypothesis-order-state-sync.sh hook, which only fires
# once a write actually lands).
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
mkdir -p "$td/docs/issue-7/reports/user-discovery"
printf '{"hypotheses_stated": false, "evidence_logged": false, "verdict_written": false}' \
  > "$td/docs/issue-7/reports/user-discovery/.state.json"
before="$(cat "$td/docs/issue-7/reports/user-discovery/.state.json")"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' 'verdict: pain-confirmed')" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOK" >/dev/null 2>&1
after="$(cat "$td/docs/issue-7/reports/user-discovery/.state.json")"
rm -rf "$td"
if [ "$before" = "$after" ]; then
  pass=$((pass+1)); printf 'ok     %-34s %s\n' "state-unchanged-on-deny" "unchanged"
else
  fail=$((fail+1)); printf 'FAIL   %-34s state changed on a denied write: before=%s after=%s\n' "state-unchanged-on-deny" "$before" "$after"
fi

# (k) kill-switch unrecognized value (e.g. a typo) must NOT disable the gate
run deny kill-switch-unrecognized-value-stays-active "$REC" 'verdict: pain-confirmed' \
  USER_DISCOVERY_HYPOTHESIS_ORDER_GATE_OFF=banana

# (l) Bash-tool write reaching this gate's owned record path is denied
# (the gate only inspects Write/Edit/MultiEdit/NotebookEdit content).
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$REC")"
printf '{"tool_name":"Bash","tool_input":{"command":"printf x > %s"},"cwd":"%s"}' "$REC" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOK" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" bash-tool-write-to-owned-path

# (m) malformed JSON — truncated, non-object, empty — all deny (exit 2)
for label_payload in \
  'truncated-json:{"tool_name":"Write","tool_input":' \
  'non-object-json:[1,2,3]' \
  'empty-payload:'; do
  label="${label_payload%%:*}"
  bad_payload="${label_payload#*:}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$REC")"
  printf '%s' "$bad_payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOK" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report deny "$got" "malformed-json-$label"
done

# (n) Edit with replace_all: true against a doubly-occurring evidence tag:
# removing BOTH occurrences leaves the verdict with no evidence logged at
# all -> deny. A first-occurrence-only bug would leave the second tag
# intact and wrongly allow.
run_edit() { # want name old new replace_all pre_content
  local want="$1" name="$2" old="$3" new="$4" replace_all="$5" pre="$6"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$REC")"
  printf '%s' "$pre" > "$td/$REC"
  payload="$(python3 -c '
import json, sys
old, new, ra, pre = sys.argv[1], sys.argv[2], sys.argv[3] == "true", sys.argv[4]
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[5], "old_string": old, "new_string": new, "replace_all": ra}, "cwd": sys.argv[6]}))
' "$old" "$new" "$replace_all" "$pre" "$REC" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOK" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_edit deny edit-replace-all-both-occurrences \
  'evidence: behavioral' 'note: nothing' 'true' \
  'evidence: behavioral observation logged.
evidence: behavioral confirmed again.
verdict: pain-confirmed'

# (o) MultiEdit with a mix of replace_all:false/true edits in one call.
# Pre-content has two evidence tags. Edit 1 (replace_all:false) rewrites an
# unrelated span; edit 2 (replace_all:true) removes the evidence-tag phrase
# everywhere, of which two remain -- a correct per-edit-flag reconstruction
# removes both (deny, no evidence left); a collapsed-to-count=1 bug would
# leave one behind (wrongly allow).
run_multiedit() { # want name pre edits_json
  local want="$1" name="$2" pre="$3" edits_json="$4"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  mkdir -p "$td/$(dirname "$REC")"
  printf '%s' "$pre" > "$td/$REC"
  payload="$(python3 -c '
import json, sys
edits = json.loads(sys.argv[1])
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": sys.argv[2], "edits": edits}, "cwd": sys.argv[3]}))
' "$edits_json" "$REC" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOK" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_multiedit deny multiedit-mixed-replace-all \
  'Intro. evidence: behavioral observation logged. evidence: behavioral confirmed again. verdict: pain-confirmed' \
  '[{"old_string":"Intro.","new_string":"Introduction.","replace_all":false},{"old_string":"evidence: behavioral","new_string":"note: nothing","replace_all":true}]'

# (p) missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere must deny
# (guarded source line, issue-75/issue-13 fix), not silently allow.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$REC")"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' 'x')" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core" /bin/bash "$HOOK" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" missing-core-guarded-source-denies

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
for g in replace_all-edit multiedit-replace_all malformed-json kill-switch absolute-path bash-write-coverage missing-core; do
  case " $groups_seen " in
    *" $g "*) ;;
    *) echo "hypothesis-order-gate-tests: MANDATORY GROUP MISSING: $g" >&2; fail=$((fail + 1)) ;;
  esac
done
[ "$fail" -eq 0 ]
