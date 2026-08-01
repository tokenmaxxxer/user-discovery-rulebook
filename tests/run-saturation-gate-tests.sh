#!/usr/bin/env bash
# Real-subprocess tests for user-discovery-saturation/hooks/saturation-gate.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$HERE/resolve-core.sh"
GATE="$HERE/../user-discovery-saturation/hooks/saturation-gate.sh"
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

# (g) kill-switch unrecognized value (e.g. a typo) must NOT disable the gate
run deny kill-switch-unrecognized-value-stays-active "$REC" \
  'Overall verdict: pain-confirmed. Users clearly want this.' \
  "USER_DISCOVERY_SATURATION_GATE_OFF=banana"

# (h) Bash-tool write reaching this gate's owned record path is denied
# (previously invisible — the gate only matched Write/Edit/MultiEdit).
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$REC")"
printf '{"tool_name":"Bash","tool_input":{"command":"printf x > %s"},"cwd":"%s"}' "$REC" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" bash-tool-write-to-owned-path

# (i) absolute path resolves to the same outcome as the relative-path case
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$REC")"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$td/$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' 'Overall verdict: pain-confirmed. Users clearly want this.')" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" absolute-path-verdict-no-prevalence

# malformed JSON — truncated, non-object, empty — all deny (exit 2)
for label_payload in \
  'truncated-json:{"tool_name":"Write","tool_input":' \
  'non-object-json:[1,2,3]' \
  'empty-payload:'; do
  label="${label_payload%%:*}"
  bad_payload="${label_payload#*:}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$REC")"
  printf '%s' "$bad_payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report deny "$got" "malformed-json-$label"
done

# Edit with replace_all: true against a doubly-occurring prevalence marker:
# removing BOTH occurrences leaves the verdict with no prevalence marker at
# all -> deny. A first-occurrence-only bug would leave the second marker
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
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_edit deny edit-replace-all-both-occurrences \
  '3 of 8 interviews' 'no count here' 'true' \
  'pain-confirmed: 3 of 8 interviews reported the pain.
Restated: 3 of 8 interviews confirmed again.'

# MultiEdit with a mix of replace_all:false/true edits in one call. Pre-
# content has two prevalence markers. Edit 1 (replace_all:false) rewrites
# an unrelated span; edit 2 (replace_all:true) removes the marker phrase
# everywhere, of which two remain -- a correct per-edit-flag reconstruction
# removes both (deny, no prevalence left); a collapsed-to-count=1 bug would
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
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}
run_multiedit deny multiedit-mixed-replace-all \
  'Intro. pain-confirmed: 3 of 8 interviews reported the pain. Restated: 3 of 8 interviews confirmed again.' \
  '[{"old_string":"Intro.","new_string":"Introduction.","replace_all":false},{"old_string":"3 of 8 interviews","new_string":"no count here","replace_all":true}]'

# missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere must deny (guarded
# source line, issue-75/issue-13 fix), not silently allow.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$REC")"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
  "$REC" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' 'x')" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core" /bin/bash "$GATE" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" missing-core-guarded-source-denies

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
for g in replace_all-edit multiedit-replace_all malformed-json kill-switch absolute-path bash-write-coverage missing-core; do
  case " $groups_seen " in
    *" $g "*) ;;
    *) echo "saturation-gate-tests: MANDATORY GROUP MISSING: $g" >&2; fail=$((fail + 1)) ;;
  esac
done
[ "$fail" -eq 0 ]
