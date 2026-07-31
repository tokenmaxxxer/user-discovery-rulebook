#!/usr/bin/env bash
# Real-subprocess tests for user-discovery-evidence-tagging/hooks/evidence-tagging-gate.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../user-discovery-evidence-tagging/hooks/evidence-tagging-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/user-discovery.md

run() { # want name path content [extra_env]
  local want="$1" name="$2" path="$3" content="$4" extra_env="${5:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"
  git init -q "$td"
  mkdir -p "$td/$(dirname "$path")"
  set +o pipefail
  out="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$path" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$content")" "$td" \
    | env $extra_env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" 2>&1)"
  rc=$?
  set -o pipefail
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"
  report "$want" "$got" "$name"
  LAST_OUT="$out"
}

# (a) record content with a behavioral/recounted/opinion tag hit -> allow
run allow tag-behavioral-present "$REC" \
  'Claim: user checks email daily. [behavioral] observed via screen-share.'
run allow tag-recounted-present "$REC" \
  'Claim: user says they file expenses weekly. [recounted]'
run allow tag-opinion-present "$REC" \
  'Claim: user thinks the feature would help. [opinion]'

# (b) record content with none of the three words -> deny, names missing tag axis
run deny no-tag-at-all "$REC" \
  'Interview notes: the user seemed happy with the current process.'

# (c) non-owning path -> allow, gate exits 0 immediately
run allow non-owning-path "docs/issue-7/proposals/x.md" \
  'no tag words here at all'

# (d) kill switch set -> allow regardless of content
run allow kill-switch "$REC" \
  'no tag words here at all' \
  "USER_DISCOVERY_EVIDENCE_TAGGING_GATE_OFF=1"

# spot-check deny message names the missing tag axis
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$REC")"
msg="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' 'Interview notes: the user seemed happy.')" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" 2>&1 1>/dev/null)"
rm -rf "$td"
if printf '%s' "$msg" | grep -qi 'evidence-strength tag'; then
  pass=$((pass+1)); printf 'ok     %-34s message-names-tag-axis\n' "deny-message-tag-axis"
else
  fail=$((fail+1)); printf 'FAIL   %-34s message did not name tag axis: %s\n' "deny-message-tag-axis" "$msg"
fi

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
