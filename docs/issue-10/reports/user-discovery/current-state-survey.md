# Current-state survey — gate A+ upgrade (issue-10)

Phase-1 research only. Scope: this repo's four PreToolUse gates
(`user-discovery-hypothesis-order`, `user-discovery-evidence-tagging`,
`user-discovery-saturation`, `user-discovery-proposal-norm`) plus
`README.md`. No `src/`, no `test/`, no implementation here.

## 1. What exists today

Four independently-toggleable plugins, each with one `hooks/*-gate.sh`
PreToolUse gate on `Write|Edit|MultiEdit`, all four **hand-rolled from the
same template** (no shared library sourced):

- `user-discovery-hypothesis-order/hooks/hypothesis-order-gate.sh`
- `user-discovery-evidence-tagging/hooks/evidence-tagging-gate.sh`
- `user-discovery-saturation/hooks/saturation-gate.sh`
- `user-discovery-proposal-norm/hooks/proposal-norm-gate.sh`

Each script independently re-derives: the fail-closed `trap`, the
kill-switch `case`, JSON parsing, project-root resolution, path
normalization, and `Write`/`Edit`/`MultiEdit` content reconstruction. This
is exactly the shape core issue #72's survey found repo-wide (six
structural defect classes, not isolated bugs) — this repo has its own
instance of each class, times four (once per gate).

Also present: `tests/run-*-gate-tests.sh` (one per gate, subprocess-driven
against a temp git repo — good pattern, reused going forward) and
`user-discovery/hooks/{hooks.json,directive.sh}` (SessionStart directive
only, no PreToolUse gate of its own — unaffected by this issue).

## 2. Where each audited defect lives (file:line)

### 2.1 State update at PreToolUse time, including on writes later denied

`user-discovery-hypothesis-order/hooks/hypothesis-order-gate.sh:206-209`

```python
state["hypotheses_stated"] = state["hypotheses_stated"] or hyp_marker
state["evidence_logged"] = evidence_logged_effective
state["verdict_written"] = state["verdict_written"] or verdict_marker
save_state(state)
```

This runs whenever *this* gate itself doesn't deny. But Claude Code fires
all matching `PreToolUse` hooks for one tool call — the same `Write` to
`docs/issue-<n>/reports/user-discovery.md` is also gated independently by
`evidence-tagging-gate.sh` and `saturation-gate.sh`. If hypothesis-order
allows (persisting `evidence_logged=true` for content it just read) but a
sibling gate then denies the same tool call, the actual file write never
happens — yet `.state.json` now claims evidence was logged. The state file
drifts from repo reality after the first denied-by-a-different-gate write.
No PostToolUse confirmation step exists anywhere in this repo.

### 2.2 Substring bug: `'h1'` matches inside `'<h1>'`

`user-discovery-hypothesis-order/hooks/hypothesis-order-gate.sh:188-191`

```python
def has_any(*needles):
    return any(nd in low for nd in needles)

hyp_marker = has_any("hypothesis:", "falsifiable hypothesis", "h1", "h2")
```

`low` is the whole lower-cased reconstructed document. `"h1" in low` is a
bare substring test — any Markdown heading `<h1>`, `# H1 notes`, an HTML
tag, or an unrelated word containing `h1` trips `hyp_marker = True` with no
hypotheses ever having been stated.

### 2.3 `'opinion'` alone counts as evidence

Two independent occurrences, identical shape:

- `user-discovery-hypothesis-order/hooks/hypothesis-order-gate.sh:192`
  (`evidence_marker = has_any("behavioral", "recounted", "opinion")`)
- `user-discovery-evidence-tagging/hooks/evidence-tagging-gate.sh:155-156`
  (`if not any(tag in low for tag in ("behavioral", "recounted", "opinion")):`)

Both accept the bare word `opinion` anywhere in the document — including
inside a sentence explicitly describing the Mom Test rule itself (e.g. "we
must not accept opinion alone") — as satisfying the evidence-tag
requirement. No adjacency to an actual claim, no tag syntax, no per-claim
association is checked.

### 2.4 Path matching not absolute-path normalized (as a design property, not resourced)

All four gates' `resolve()`/`_under()` (e.g.
`evidence-tagging-gate.sh:42-53,91-98`) do call `posixpath.normpath` +
`os.path.realpath` and do branch on `posixpath.isabs`, so a literal
absolute path is not silently mishandled in the common case. The defect
the audit flags is structural, not a single wrong output: each gate
reimplements this normalization independently (four near-identical
copies), it is never tested against the standard's own mandatory case set
(absolute path matching the same scope as a relative fixture, plus a
`./`-prefixed variant — none of `tests/run-*-gate-tests.sh` exercise this
today), and it does not delegate to any canon function, so a future fix to
one copy silently leaves the other three (and any new gate) with the old
behavior. This is precisely the "same shape, re-derived N times, one
confirmed live bug eventually" pattern gate-lib.sh exists to end.

### 2.5 Fail-closed gaps

- **Trap-at-top**: already present in all four gates
  (`__fc(){...}; trap __fc EXIT` as line 2-3, before `set -uo pipefail`) —
  functionally close to `gate_trap_fail_closed`, but hand-rolled and
  duplicated four times rather than sourced once.
- **Malformed JSON**: already denied in the Python payload
  (`json.loads(raw)` wrapped in `try/except ValueError: deny(...)`, e.g.
  `evidence-tagging-gate.sh:76-79`) — this specific sub-case is not
  currently broken, but it is (again) four independent copies of logic
  `gate_parse_json_or_deny` already provides canonically.
- **Kill-switch, unrecognized value = disabled (the actual live bug)**: all
  four gates use the exact pre-issue-72 idiom
  (`evidence-tagging-gate.sh:20-23`, `hypothesis-order-gate.sh:25-28`,
  `saturation-gate.sh:27-30`, `proposal-norm-gate.sh:21-24`):

  ```bash
  case "${USER_DISCOVERY_..._GATE_OFF:-}" in
    ""|0|false|no|off) ;;
    *) exit 0 ;;
  esac
  ```

  Any unrecognized value — a typo like `USER_DISCOVERY_SATURATION_GATE_OFF=of` — falls into `*) exit 0`, silently disabling the gate. This is the same bug class core's own audit found and fixed with `gate_kill_switch_active`; this repo has it in all four gates.

### 2.6 Edit/MultiEdit/replace_all not handled correctly

All four gates, identically:

```python
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
            ...
            text = text.replace(o, n, 1)
        if ok:
            new_text = text
```

(`evidence-tagging-gate.sh:128-145`, and the same block verbatim in the
other three gates.) `replace_all` is never read from `tool_input` — every
`Edit`/`MultiEdit` replacement is hardcoded to `count=1`. An `Edit` call
with `"replace_all": true` against a multiply-occurring `old_string`
reconstructs a document that still has un-replaced occurrences, so the
gate judges stale content. `MultiEdit`'s per-edit `replace_all` flag is
dropped entirely. `NotebookEdit` is not handled at all (falls through to
`new_text is None` → deny — fail-closed by accident, not by design, and
undocumented).

### 2.7 Deny reasons to stderr

Already correct in all four gates: every `deny()` writes to `sys.stderr`
(`evidence-tagging-gate.sh:72-73` and the bash-level `deny()` at line 18),
and the outer bash wrapper's own `deny()` (line 18) also writes to `>&2`.
No change needed here beyond preserving this when migrating to
`gate_deny`.

## 3. What `gate-lib.sh` / `gate-lib.py` already offer that this repo can reuse directly

Read in full at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/lib/gate-lib.sh`
and `docs/handbooks/gate-house-standard.md` (same repo). Summary mapped to
the defects above:

| Defect (§2.x) | This repo's current hand-rolled logic | Canon replacement |
|---|---|---|
| 2.1 state-at-PreToolUse | n/a — gate-lib does not solve this; it's a plugin-specific design bug, not a shared-shape bug | (own fix, see proposal) |
| 2.2 / 2.3 substring semantics | `has_any()` bare `in` test | n/a — gate-lib does not provide semantic matching; this repo's own upgrade (see proposal §c) |
| 2.4 path normalization | `resolve()`/`_under()`, duplicated ×4 | `gate_normalize_path(root, path)` (Python) |
| 2.5a trap-at-top | `__fc(){...}; trap __fc EXIT`, duplicated ×4 | `gate_trap_fail_closed` (bash) |
| 2.5b malformed-JSON deny | inline `try/except` in each Python payload | `gate_parse_json_or_deny(raw, deny)` (Python) |
| 2.5c kill-switch unrecognized-value bug | `case ... *) exit 0 ;; esac`, duplicated ×4 | `gate_kill_switch_active <value>` (bash) |
| 2.6 Edit/MultiEdit/replace_all | `current.replace(o, n, 1)` hardcoded, duplicated ×4 | `gate_reconstruct_write(tool, tool_input, current_content)` (Python) |
| 2.7 deny-to-stderr | already correct | `gate_deny <name> <msg>` / `gate_allow` (bash) — adopt for uniformity, not because current behavior is wrong |
| (bonus) Bash-tool write detection | not implemented anywhere in this repo — gates only match `Write`/`Edit`/`MultiEdit`/`NotebookEdit` tool names, a `Bash` command that writes the same file is invisible to all four gates today | `gate_bash_write_targets <command>` (bash) |

`gate-lib.sh`/`gate-lib.py` do **not** provide: the state-file
persistence-timing fix (§2.1) or the semantic-check upgrade (§2.3/§2.2) —
both are this rulebook's own judgment logic, out of gate-lib's scope by
design (gate-house-standard.md's six classes are structural/mechanical,
not content-judgment). The proposal must design fixes for those
separately, without inventing a competing shared-library shape for the
parts gate-lib *does* cover.

## 4. README ghost-file check

`README.md`'s "Layout" section (lines 54-67) lists files that do not exist
in this repo:

- `user-discovery/hooks/record-fields-gate.sh` — does not exist
- `user-discovery/hooks/trailer-gate.sh` — does not exist
- `user-discovery/hooks/handbook-trigger-gate.sh` — does not exist
- `user-discovery/agents/warrant-hunter.md` — does not exist (`agents/`
  directory itself does not exist under `user-discovery/`)

`user-discovery/hooks/` in fact contains only `hooks.json` and
`directive.sh` (SessionStart wiring, confirmed via direct listing). The
real gate surface — the four plugins' `hooks/*-gate.sh` files and their
kill switches — is documented correctly in the "Methodology plugin set"
section (lines 24-52) but not cross-referenced from "Layout", and "Layout"
still describes an earlier (pre-issue-7) single-role-stub design that this
repo moved away from when it split into the plugin set (issue-7). The
`.claude-plugin/marketplace.json` plugin list (5 entries: `user-discovery`,
`user-discovery-proposal-norm`, `user-discovery-hypothesis-order`,
`user-discovery-evidence-tagging`, `user-discovery-saturation`) matches
what's actually on disk and matches the "Install" section — those two
parts of the README are accurate and should stay.

## 5. Sources

- `gh issue view 10` (2026-08-01 audit findings, grade B+, quoted in the
  handoff prompt).
- `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/lib/gate-lib.sh`
  (read in full).
- `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/docs/handbooks/gate-house-standard.md`
  (read in full).
- This repo's four gate scripts and four test scripts (read in full).
- This repo's `README.md`, `.claude-plugin/marketplace.json`, `docs/`
  tree (listed and cross-checked against README claims).
