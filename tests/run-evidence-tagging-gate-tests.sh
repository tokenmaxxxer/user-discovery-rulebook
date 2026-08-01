#!/usr/bin/env bash
# Real-subprocess tests for user-discovery-evidence-tagging/hooks/evidence-tagging-gate.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$HERE/resolve-core.sh"
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

# (e) substring-vs-structure: bare "opinion" in running prose (about the
# rule itself, not a bracket tag) is NOT an evidence-strength marker
# (regression test for survey §2.3).
run deny opinion-bare-word-in-prose "$REC" \
  'We must not accept opinion alone as evidence for a claim like this one.'

# (f) Edit + replace_all: old_string occurs twice; only the reconstructed
# (fully replaced) content is judged.
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
# old_string "[behavioral]" occurs twice; replace_all:true removes BOTH,
# leaving no tag anywhere -> deny. A first-occurrence-only bug would instead
# leave the second "[behavioral]" intact and wrongly allow.
run_edit deny edit-replace-all-both-occurrences '[behavioral]' '' 'true' \
  'Claim one. [behavioral]
Claim two. [behavioral]'

# (g) MultiEdit with a mix of replace_all:false / replace_all:true edits in
# one call. Pre-content has three "[behavioral]" tags. Edit 1
# (replace_all:false) removes the tag from the first sentence by matching
# the unique three-word span "[behavioral] a." (count=1 either way — not
# itself distinguishing). Edit 2 (replace_all:true) then targets the bare
# "[behavioral]" string, of which TWO now remain: a correct
# per-edit-flag reconstruction removes both (deny, no tag left anywhere); a
# collapsed-to-count=1 bug (the pre-fix shape) removes only one, leaving a
# tag behind (wrongly allow). Only the fixed behavior denies here.
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
  '[behavioral] a. [behavioral] b. [behavioral] c.' \
  '[{"old_string":"[behavioral] a.","new_string":"a.","replace_all":false},{"old_string":"[behavioral]","new_string":"","replace_all":true}]'

# (h) Bash-tool write reaching this gate's owned record path is denied
# (previously invisible — the gate only matched Write/Edit/MultiEdit).
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$REC")"
printf '{"tool_name":"Bash","tool_input":{"command":"printf x > %s"},"cwd":"%s"}' "$REC" "$td" \
  | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" >/dev/null 2>&1
rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
rm -rf "$td"; report deny "$got" bash-tool-write-to-owned-path

# (i) malformed JSON — truncated, non-object, empty — all deny (exit 2)
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

# (j) kill-switch unrecognized value (e.g. a typo) must NOT disable the gate
run deny kill-switch-unrecognized-value-stays-active "$REC" \
  'Interview notes: the user seemed happy with the current process.' \
  "USER_DISCOVERY_EVIDENCE_TAGGING_GATE_OFF=banana"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
