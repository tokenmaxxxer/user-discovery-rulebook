#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
# PreToolUse gate (Write|Edit|MultiEdit|Bash) — user-discovery-evidence-tagging's
# own write surface: docs/issue-<n>/reports/user-discovery.md.
#
# Enforces Mom Test evidence-strength tagging discipline: the reconstructed
# resulting content of a record write must contain at least one hit of the
# evidence-strength tag vocabulary (behavioral|recounted|opinion), in a
# structural position (a labeled "evidence:" field, a heading, a list item,
# or a "[tag]" bracket) — not a bare substring anywhere in the document
# (issue-10 audit §"'opinion' alone counts as evidence": a sentence like "we
# must not accept opinion alone" no longer counts). The no-pitch-before-
# behavioral-exhausted rule is explicitly OUT of scope here (content-
# judgment, not substring-checkable) — it lives only in
# docs/handbooks/user-discovery/per-interview-checklist.md.
#
# Sources core/hooks/lib/gate-lib.sh (issue-72 gate-house standard) for the
# fail-closed trap, kill switch, deny protocol, JSON parsing, path
# normalization, and Edit/MultiEdit/NotebookEdit reconstruction — reference
# only, never vendored, per docs/handbooks/canon-scripts.md.
#
# Kill switch: export USER_DISCOVERY_EVIDENCE_TAGGING_GATE_OFF=1
role="${CLAUDE_ROLE:-user-discovery}"

gate_kill_switch_active "${USER_DISCOVERY_EVIDENCE_TAGGING_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "$role" "evidence-tagging-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || gate_deny "$role" "evidence-tagging-gate: empty tool-use payload on stdin; cannot evaluate the evidence-tagging gate."

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
if [ -z "$root" ]; then
  d="$_target"; [ -n "$d" ] || d="$(pwd -P)"; [ -d "$d" ] || d="$(dirname "$d")"
  root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && gate_deny "$role" "no project root could be determined; failing closed (evidence-tagging check cannot run)."

_bash_cmd="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
if not isinstance(e,dict): sys.exit(0)
ti=e.get("tool_input")
cmd=ti.get("command") if isinstance(ti,dict) else None
if e.get("tool_name")=="Bash" and isinstance(cmd,str): print(cmd)
' 2>/dev/null || true)"
BASH_TOKENS=""
[ -n "$_bash_cmd" ] && BASH_TOKENS="$(gate_bash_write_targets "$_bash_cmd")"

SEMANTIC_PY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../user-discovery/hooks/lib" && pwd -P)/_semantic.py"

PG_PAYLOAD="$payload" PG_ROOT="$root" PG_BASH_TOKENS="$BASH_TOKENS" SEMANTIC_PY="$SEMANTIC_PY" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("user-discovery: refused — %s\n" % m); sys.exit(2)

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)
    _sspec = importlib.util.spec_from_file_location("semantic", os.environ["SEMANTIC_PY"])
    semantic = importlib.util.module_from_spec(_sspec); _sspec.loader.exec_module(semantic)

    raw = os.environ.get("PG_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (evidence tagging).")

    root = posixpath.normpath(os.environ["PG_ROOT"].replace("\\", "/"))
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/user-discovery\.md$')

    if tool == "Bash":
        for tok in os.environ.get("PG_BASH_TOKENS", "").splitlines():
            if not tok:
                continue
            rel = gate_lib.gate_normalize_path(root, tok)
            if rel is not None and RECORD_RE.match(rel):
                deny(
                    "a Bash-tool command appears to write to %s (matches this plugin's owned "
                    "record path) but the gate cannot determine the resulting content from a "
                    "Bash command; use Write/Edit/MultiEdit instead so evidence-strength tags "
                    "can be checked." % rel
                )
        sys.exit(0)

    path = None
    if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        p = ti.get("file_path") or ti.get("notebook_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        sys.exit(0)  # outside project root — not this plugin's business
    if not RECORD_RE.match(rel):
        sys.exit(0)  # not this plugin's business

    r = posixpath.join(root, rel)
    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on evidence tagging." % rel)

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so evidence-strength tags can be "
            "checked." % (rel, tool)
        )

    if not semantic.structural_marker(new_text, "behavioral", "recounted", "opinion", fields=("evidence",)):
        deny(
            "no evidence-strength tag (behavioral|recounted|opinion) found in this record "
            "write, in a structural position (a labeled \"evidence:\" field, a heading, a "
            "list item, or a \"[tag]\" bracket). Per the Mom Test discipline, every claim in "
            "docs/issue-<n>/reports/user-discovery.md must be tagged behavioral, "
            "recounted, or opinion."
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("evidence-tagging-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "user-discovery: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
