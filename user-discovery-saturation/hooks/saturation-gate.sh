#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — user-discovery-saturation plugin.
#
# Target: docs/issue-<n>/reports/user-discovery.md — the phase-2 record for
# this role, per docs/issue-7/proposals/plugin-enforcement-hardening.md §4.
#
# When the reconstructed resulting content carries a verdict marker
# (pain-confirmed / not-confirmed), requires:
#   (a) a stated-prevalence marker ("N of M" / "of N interviews"), always;
#   (b) a residual/contradiction-acknowledgment marker, but ONLY when the
#       content itself contains contradiction-indicating language.
#
# This does not police the Guest/Bunce/Johnson 2006 ~12-interview saturation
# heuristic mechanically (that lives as a checklist trigger in
# docs/handbooks/user-discovery/per-interview-checklist.md step 4) — this
# gate only enforces that a verdict is not written without naming its
# evidence base.
#
# Kill switch: export USER_DISCOVERY_SATURATION_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-user-discovery}"
deny() { echo "${role}: refused — $1" >&2; exit 2; }

case "${USER_DISCOVERY_SATURATION_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "saturation-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "saturation-gate: empty tool-use payload on stdin; cannot evaluate the saturation gate."

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
[ -z "$root" ] && deny "no project root could be determined; failing closed (saturation check cannot run)."

PG_PAYLOAD="$payload" PG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("user-discovery: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("PG_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge saturation fields on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on saturation.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse (saturation).")

    root = posixpath.normpath(os.environ["PG_ROOT"].replace("\\", "/"))
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/user-discovery\.md$')

    def resolve(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    r = resolve(path)
    if not r.startswith(root + "/"):
        sys.exit(0)
    rel = r[len(root):].lstrip("/")
    if not RECORD_RE.match(rel):
        sys.exit(0)  # not this plugin's business

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on saturation." % rel)

    new_text = None
    if tool == "Write":
        c = ti.get("content")
        if isinstance(c, str):
            new_text = c
    elif tool == "Edit":
        o, n = ti.get("old_string"), ti.get("new_string")
        if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
            new_text = current.replace(o, n, 1)
    elif tool == "MultiEdit":
        edits = ti.get("edits")
        text = current
        if isinstance(edits, list) and text is not None:
            ok = True
            for e in edits:
                if not isinstance(e, dict):
                    ok = False; break
                o, n = e.get("old_string"), e.get("new_string")
                if not isinstance(o, str) or not isinstance(n, str) or o not in text:
                    ok = False; break
                text = text.replace(o, n, 1)
            if ok:
                new_text = text

    if new_text is None:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so the saturation fields can be "
            "checked." % (rel, tool)
        )

    low = new_text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    VERDICT_MARKERS = ("pain-confirmed", "not-confirmed")
    if not has_any(*VERDICT_MARKERS):
        sys.exit(0)  # no verdict written yet — nothing to check

    missing = []

    # (a) prevalence marker: "N of M" / "N/M" / "of N interviews"
    PREVALENCE_RE = re.compile(r'\d+\s*(of|/)\s*\d+', re.I)
    has_prevalence = bool(PREVALENCE_RE.search(low)) or bool(
        re.search(r'of\s+\d+\s+interviews', low)
    )
    if not has_prevalence:
        missing.append("prevalence")

    # (b) contradiction language present? then require a residual/ack marker.
    CONTRADICTION_NEEDLES = ("contradict", "residual", "disconfirm", "however", "some said")
    has_contradiction_language = has_any(*CONTRADICTION_NEEDLES)
    RESIDUAL_NEEDLES = ("residual", "contradicting evidence noted", "contradiction:")
    has_residual_ack = has_any(*RESIDUAL_NEEDLES)
    if has_contradiction_language and not has_residual_ack:
        missing.append("residual")

    if missing:
        parts = []
        if "prevalence" in missing:
            parts.append(
                "a stated-prevalence marker (e.g. \"3 of 8 interviews\" or \"of N interviews\")"
            )
        if "residual" in missing:
            parts.append(
                "a residual/contradiction-acknowledgment marker (e.g. \"residual\", "
                "\"contradicting evidence noted\", or \"contradiction:\") — contradiction-"
                "indicating language was found in the content but not acknowledged"
            )
        deny(
            "this verdict (pain-confirmed / not-confirmed) is missing required "
            "element(s): %s. Every user-discovery verdict must state its prevalence "
            "(N of M interviews) and, when contradicting evidence exists, name it "
            "rather than drop it." % "; and ".join(parts)
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("saturation-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "user-discovery: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
