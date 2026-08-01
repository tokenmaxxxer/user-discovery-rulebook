#!/usr/bin/env bash
# user-discovery-hypothesis-order gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$HERE/resolve-core.sh"
HOOK="$HERE/../user-discovery-hypothesis-order/hooks/hypothesis-order-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

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

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
