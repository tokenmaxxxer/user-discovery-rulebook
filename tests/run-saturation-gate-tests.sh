#!/usr/bin/env bash
# Real-subprocess tests for user-discovery-saturation/hooks/saturation-gate.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../user-discovery-saturation/hooks/saturation-gate.sh"
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

# (a) verdict + prevalence + no contradiction language -> allow
run allow verdict-prevalence-clean "$REC" \
  'Interview log: pain-confirmed. 3 of 8 interviews reported the pain point directly.'

# (b) verdict + prevalence + contradiction language WITH residual note -> allow
run allow verdict-prevalence-contradiction-acked "$REC" \
  'pain-confirmed: 5 of 9 interviews confirmed. However, some interviewees pushed back; residual: contradicting evidence noted from 2 participants who saw no pain.'

# (c) verdict with no prevalence marker at all -> deny, names prevalence missing
run deny verdict-no-prevalence "$REC" \
  'Overall verdict: pain-confirmed. Users clearly want this.'

# (d) verdict + prevalence + contradiction language but no residual ack -> deny, names residual missing
run deny verdict-contradiction-unacked "$REC" \
  'pain-confirmed: 4 of 7 interviews confirmed the pain. However, some said it was not a big deal.'

# (e) non-owning path -> allow, gate exits 0 immediately
run allow non-owning-path "docs/issue-7/reports/coding.md" \
  'pain-confirmed with no prevalence at all and no residual note'

# (f) kill switch set -> allow regardless of content
run allow kill-switch "$REC" \
  'pain-confirmed with no prevalence at all and no residual note' \
  "USER_DISCOVERY_SATURATION_GATE_OFF=1"

# spot-check deny messages name the right missing element
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$REC")"
msg="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' 'Overall verdict: pain-confirmed. Users clearly want this.')" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" 2>&1 1>/dev/null)"
rm -rf "$td"
if printf '%s' "$msg" | grep -qi 'prevalence'; then
  pass=$((pass+1)); printf 'ok     %-34s message-names-prevalence\n' "deny-message-prevalence"
else
  fail=$((fail+1)); printf 'FAIL   %-34s message did not name prevalence: %s\n' "deny-message-prevalence" "$msg"
fi

td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$REC")"
msg="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' 'pain-confirmed: 4 of 7 interviews confirmed the pain. However, some said it was not a big deal.')" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" 2>&1 1>/dev/null)"
rm -rf "$td"
if printf '%s' "$msg" | grep -qi 'residual'; then
  pass=$((pass+1)); printf 'ok     %-34s message-names-residual\n' "deny-message-residual"
else
  fail=$((fail+1)); printf 'FAIL   %-34s message did not name residual: %s\n' "deny-message-residual" "$msg"
fi

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
