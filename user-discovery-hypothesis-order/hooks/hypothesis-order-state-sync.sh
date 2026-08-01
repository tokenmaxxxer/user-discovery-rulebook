#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
set -uo pipefail 2>/dev/null || true
# PostToolUse hook (Write|Edit|MultiEdit) — user-discovery-hypothesis-order's
# state-sync half (issue-10 audit §"state update at PreToolUse time,
# including denied writes").
#
# PreToolUse fires before a write is known to actually land: at that point
# a sibling gate on the same tool call (evidence-tagging/saturation) may
# still deny it. PostToolUse only fires once the tool call actually
# completed, so persisting hypothesis-order's three state booleans here
# instead means .state.json only ever advances from a write that really
# happened.
#
# Re-derives the three markers from the file AS WRITTEN ON DISK (never from
# tool_input) — immune by construction to any reconstruction bug, since it
# reads the same bytes the file now actually contains.
#
# This hook never denies (PostToolUse cannot block a completed write); it
# fails open on any internal error rather than fail-closed, since there is
# nothing left to protect by that point — a state-sync miss just means the
# next PreToolUse call re-derives from a slightly stale state.json, which
# self-heals on the following successful write to the same file.
#
# Kill switch: shares USER_DISCOVERY_HYPOTHESIS_ORDER_GATE_OFF with the
# PreToolUse gate — when hypothesis-order is off, state tracking is also
# off (there's no ordering rule left to track state for).
role="${CLAUDE_ROLE:-user-discovery}"

gate_kill_switch_active "${USER_DISCOVERY_HYPOTHESIS_ORDER_GATE_OFF:-}" || exit 0

command -v python3 >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

_target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    for k in ("file_path","notebook_path"):
        v=ti.get(k)
        if isinstance(v,str) and v: print(v); break
' 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
_under() {
  [ -z "$2" ] && return 0
  python3 -c '
import os,posixpath,sys
r,t=sys.argv[1],sys.argv[2]
try: rr=posixpath.normpath(os.path.realpath(r).replace("\\","/"))
except Exception: sys.exit(1)
n=t.replace("\\","/"); a=n if posixpath.isabs(n) else posixpath.join(rr,n)
a=posixpath.normpath(a); real=posixpath.normpath(os.path.realpath(a).replace("\\","/"))
sys.exit(0 if (real==rr or real.startswith(rr+"/")) else 1)
' "$1" "$2"
}

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR" && _under "$CLAUDE_PROJECT_DIR" "$_target"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && exit 0

SEMANTIC_PY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../user-discovery/hooks/lib" && pwd -P)/_semantic.py"

PG_PAYLOAD="$payload" PG_ROOT="$root" SEMANTIC_PY="$SEMANTIC_PY" \
python3 <<'PY' || true
import importlib.util, json, os, posixpath, re, sys

_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)
_sspec = importlib.util.spec_from_file_location("semantic", os.environ["SEMANTIC_PY"])
semantic = importlib.util.module_from_spec(_sspec); _sspec.loader.exec_module(semantic)

raw = os.environ.get("PG_PAYLOAD", "")
try:
    ev = json.loads(raw) if raw else {}
except ValueError:
    sys.exit(0)
if not isinstance(ev, dict):
    sys.exit(0)

ti = ev.get("tool_input")
if not isinstance(ti, dict):
    sys.exit(0)

root = posixpath.normpath(os.environ["PG_ROOT"].replace("\\", "/"))
RECORD_RE = re.compile(r'^docs/issue-([0-9]+)/reports/user-discovery\.md$')

path = ti.get("file_path") or ti.get("notebook_path")
if not isinstance(path, str) or not path:
    sys.exit(0)

rel = gate_lib.gate_normalize_path(root, path)
if rel is None:
    sys.exit(0)
m = RECORD_RE.match(rel)
if not m:
    sys.exit(0)

issue_n = m.group(1)
state_path = os.path.join(root, "docs", "issue-%s" % issue_n, "reports", "user-discovery", ".state.json")

r = posixpath.join(root, rel)
try:
    with open(r, encoding="utf-8-sig") as fh:
        on_disk = fh.read(1 << 20)
except OSError:
    sys.exit(0)

hyp_marker = semantic.structural_marker(on_disk, "hypothesis", "h1", "h2", fields=("hypothesis",))
evidence_marker = semantic.structural_marker(on_disk, "behavioral", "recounted", "opinion", fields=("evidence",))
verdict_marker = semantic.word_present(on_disk, "pain-confirmed", "not-confirmed", "insufficient-evidence")

state = {"hypotheses_stated": False, "evidence_logged": False, "verdict_written": False}
if os.path.isfile(state_path):
    try:
        with open(state_path, encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict):
            for k in state:
                state[k] = bool(data.get(k, state[k]))
    except (OSError, ValueError):
        pass

state["hypotheses_stated"] = state["hypotheses_stated"] or hyp_marker
state["evidence_logged"] = state["evidence_logged"] or evidence_marker
state["verdict_written"] = state["verdict_written"] or verdict_marker

try:
    os.makedirs(os.path.dirname(state_path), exist_ok=True)
    with open(state_path, "w", encoding="utf-8") as fh:
        json.dump(state, fh)
except OSError:
    pass

sys.exit(0)
PY
exit 0
