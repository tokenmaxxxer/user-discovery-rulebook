# Proposal: gate A+ upgrade (issue-10)

Phase-1 proposal only — research + design, no implementation. Per
role-handoff contract v3, phase-2 (actual `src/`/`test/` changes to the
four gate scripts) opens only on a human APPROVE recorded per
`docs/specs/approvers.md`. This document does not touch any gate script.

Survey: `docs/issue-10/reports/user-discovery/current-state-survey.md`.
Scout brief: `docs/issue-10/reports/user-discovery/scout-brief.md`.

Design stance: **conservative, reference-adopting.** Every defect
gate-lib.sh already solves gets a one-line call into gate-lib, not a
reimplementation. Only the two defects gate-lib does not cover (semantic
matching, state-update timing) get new logic in this repo, and that logic
is scoped to the minimum needed to close the audited gap.

## (a) Fix design per defect, before/after

### 1. State update at PreToolUse time, including denied writes

**Before**: `hypothesis-order-gate.sh` calls `save_state(state)`
unconditionally whenever it does not itself deny (survey §2.1), even
though a sibling gate on the same tool call (evidence-tagging or
saturation) may still deny the actual write.

**After**: `.state.json` is only advanced from state a gate can trust
already landed. Two changes, both scoped to `hypothesis-order-gate.sh`
(the only gate that persists cross-call state):
1. Split "compute what the markers imply" from "persist it." The gate
   still reads `.state.json` and combines it with the current write's own
   markers to make its **allow/deny decision** for *this* call (unchanged
   — that's the correct check-time semantics). But it moves the
   `save_state()` call for `hypotheses_stated`/`evidence_logged` off the
   PreToolUse critical path for writes this gate itself denies (already
   true — deny happens via `sys.exit(2)` before `save_state` — the bug is
   specifically about *sibling* gates denying the same call after this
   gate already wrote state).
2. Because Claude Code's hook model gives no cross-hook "did every gate
   on this call allow" signal at PreToolUse time, the only reliable fix is
   to move persistence to `PostToolUse`, which only fires once the tool
   call actually completed (i.e., every gate on it allowed and the write
   happened). `user-discovery-hypothesis-order` adds a small
   `hooks/hypothesis-order-state-sync.sh` PostToolUse hook, registered
   in that plugin's own `hooks.json`, that re-derives the three markers
   from the file **as written on disk** (not from `tool_input`, so it's
   immune to reconstruction bugs by construction) and persists them.
   `hypothesis-order-gate.sh` itself becomes read-only against
   `.state.json` at PreToolUse — it still combines persisted state with
   the current write's own markers for its allow/deny decision (an
   in-flight write that adds both evidence and verdict in one shot must
   still be allowed, per existing test case (b)), it just never writes.

### 2. `'h1'` matching inside `'<h1>'`; substring semantics generally

Covered together with (c) below — this is the semantic-check redesign,
not a gate-lib concern.

### 3. `'opinion'` alone counts as evidence

Covered together with (c) below.

### 4. Path matching not absolute-path normalized

**Before**: each of the four gates independently implements
`resolve()`/`_under()` (survey §2.4) — four copies, none tested against
absolute or `./`-prefixed fixtures.

**After**: every gate's Python payload calls
`gate_lib.gate_normalize_path(root, path)` in place of its own
`resolve()`. `gate_normalize_path` already returns a root-relative tail
for absolute, relative, and `./`-prefixed input, or `None` when the path
resolves outside root (the `None` case replaces this repo's
`if not r.startswith(root + "/"): sys.exit(0)` early-return — same
allow-and-ignore behavior for an out-of-scope path, now expressed as
"path is `None` → not this plugin's business → exit 0").

### 5. Fail-closed gaps

- **trap-at-top**: every gate script's line 2-3 hand-rolled
  `__fc(){...}; trap __fc EXIT` is replaced by sourcing `gate-lib.sh` and
  calling `gate_trap_fail_closed` as the literal first statement, before
  `set -uo pipefail` (per gate-lib.sh's own usage comment). Behavior is
  unchanged (same remap-any-nonzero/non-2-exit-to-2 semantics); the
  change is de-duplication, not new coverage.
- **malformed JSON**: the four inline `try: json.loads / except ValueError:
  deny(...)` blocks are replaced by one call to
  `gate_lib.gate_parse_json_or_deny(raw, deny)` each, imported via
  `GATE_LIB_PY` (scout-brief §"must-bes" item 2). Behavior unchanged for
  the cases already handled (empty payload, non-JSON), extended to match
  gate-lib's own broader malformed-input set (e.g. non-object top level,
  which this repo's gates already separately check via
  `isinstance(ev, dict)` — that check becomes redundant with gate-lib's
  own and is removed, not duplicated).
- **kill-switch unrecognized-value bug**: every gate's
  `case ... ""|0|false|no|off) ;; *) exit 0 ;; esac` (survey §2.5,
  present identically in all four) is replaced by
  `gate_kill_switch_active "${SOME_OFF:-}" || { trap - EXIT; exit 0; }`.
  **Before**: `SOME_OFF=typo` → falls into `*) exit 0` → gate silently
  disabled. **After**: `SOME_OFF=typo` → `gate_kill_switch_active` returns
  0 (true, "stay active", since `typo` is not a recognized on-spelling) →
  gate proceeds normally. Only `1`/`true`/`yes`/`on` (case-insensitive)
  now disable a gate.

### 6. Edit/MultiEdit/replace_all not handled correctly

**Before**: `current.replace(o, n, 1)` hardcoded in all four gates for
both `Edit` and each `MultiEdit` sub-edit (survey §2.6); `replace_all` is
read from `tool_input` nowhere; `NotebookEdit` falls through to
`new_text is None` → deny by accident.

**After**: all four gates' `new_text` derivation block (currently ~20
lines per gate) is replaced by one call:
`new_text = gate_lib.gate_reconstruct_write(tool, ti, current)`.
**Before/after on the audited case**: `Edit` with
`old_string="opinion"` occurring 3 times and `"replace_all": true` —
before, only the first occurrence is replaced, so a semantic check reading
`new_text` may still see 2 stale occurrences of the pre-edit string;
after, `gate_reconstruct_write` honors `replace_all` and all 3 are
replaced. `MultiEdit` with edit 1 `replace_all:false` and edit 2
`replace_all:true` — before, both collapse to `count=1`; after, each
edit's own flag is honored independently, matching gate-lib's documented
behavior. `NotebookEdit` — before, always denied with a misleading "cannot
determine resulting content" message; after, `gate_reconstruct_write`
returns the edited cell source, so a `NotebookEdit` gets judged instead of
reflexively denied (this repo's gates don't currently target
`NotebookEdit` paths, so in practice this mostly means the deny message a
user would see if they ever hit this path stops being wrong).

### 7. Deny reasons to stderr

**Before/after**: no behavior change — already correct in all four gates.
The bash-level `deny()` helper and the Python-level `deny()` are both
replaced by calling `gate_lib.gate_deny` (Python, via `GATE_LIB_PY`) and
`gate_deny`/`gate_allow` (bash, for the wrapper-level early exits like "no
project root," "python3 missing," "empty payload"), for uniformity with
the shared library's protocol — not because the current stderr behavior
is wrong.

## (b) Exact gate-lib.sh / gate-lib.py adoption plan

Per gate script (`hooks/*-gate.sh`), the migration is mechanical:

1. Add, as the literal first two lines after the shebang:
   ```bash
   #!/usr/bin/env bash
   . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh"
   gate_trap_fail_closed
   set -uo pipefail
   ```
   replacing the current lines 2-3 (`__fc(){...}; trap __fc EXIT`) and the
   existing `set -uo pipefail`.
2. Replace the kill-switch `case` block with:
   ```bash
   gate_kill_switch_active "${USER_DISCOVERY_<PLUGIN>_GATE_OFF:-}" || { trap - EXIT; exit 0; }
   ```
3. Replace the bash-level `deny()` helper's call sites (`command -v
   python3`, empty-payload, no-project-root checks) with `gate_deny
   "$role" "..."` / fall through to `gate_allow` — no behavior change,
   protocol uniformity only.
4. In the Python heredoc payload, load gate-lib.py via `GATE_LIB_PY`
   (exported by `gate-lib.sh`, so no path duplication needed):
   ```python
   import importlib.util, os
   _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
   gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)
   ```
5. Replace `raw = ...; try: ev = json.loads(raw) ...` with
   `ev = gate_lib.gate_parse_json_or_deny(raw, deny)`.
6. Replace `resolve()`/`_under()`/the `r.startswith(root + "/")` check
   with `rel = gate_lib.gate_normalize_path(root, path)` — `rel is None`
   replaces the current out-of-scope early `sys.exit(0)`.
7. Replace the `Write`/`Edit`/`MultiEdit` `new_text` derivation block with
   `new_text = gate_lib.gate_reconstruct_write(tool, ti, current)`.
8. `proposal-norm-gate.sh` and the semantic checks in the other three
   (see (c)) additionally gain a `Bash`-tool branch: when `tool ==
   "Bash"`, run `gate_bash_write_targets(command)` (bash-side, before
   handing off to the Python payload) against each candidate token with
   this plugin's existing path regex (`RECORD_RE`/`PROPOSAL_RE`), so a
   `Bash`-tool write to the same gated path is no longer invisible.
   Scoped narrowly: if any candidate token matches the gate's owned path
   pattern, treat it exactly like a `Write` whose `content` is unknown —
   i.e. `new_text` cannot be determined from a `Bash` command, so this
   falls into the existing "cannot determine resulting content, deny"
   branch (same message family as an unreconstructable `Edit` today).
   This is deliberately conservative: it makes an invisible bypass into a
   safe deny, not into a new content-inspection capability gate-lib
   doesn't provide.
9. No gate reimplements anything `gate-lib.sh`/`gate-lib.py` provide.
   Compliance is checked by running
   `"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/compliance-check.sh" <plugin-hooks-dir>`
   against each of the four `hooks/` directories at phase-2 ship time,
   per the standard's own migration checklist (scout-brief §"must-bes"
   item 4); this proposal commits to that check running clean before
   ship, not to running it now.

## (c) Semantic check redesign: substring → section/adjacency/structure

Algorithm sketch, applied uniformly to the three marker classes each gate
currently detects with `has_any(*needles)`: hypothesis markers
(`hypothesis:`, `h1`, `h2`), evidence-strength tags (`behavioral`,
`recounted`, `opinion`), verdict markers (`pain-confirmed`,
`not-confirmed`, `insufficient-evidence`), and saturation markers
(prevalence, residual/contradiction).

1. **Tokenize into lines, then into Markdown-aware blocks.** Split
   `new_text` on blank lines into paragraphs, and separately identify
   heading lines (`^#{1,6}\s`) and list-item lines
   (`^\s*[-*]\s`/`^\s*\d+\.\s`) via regex anchored to line start — not a
   substring scan of the whole document.
2. **Word-boundary match, not substring match**, for every marker: compile
   each needle as `re.compile(r'(?<![\w-])' + re.escape(needle) +
   r'(?![\w-])', re.I)` (or, for multi-word needles like `"hypothesis:"`,
   the trailing `:` already anchors it — the boundary guard is added for
   the short bare-word needles `h1`/`h2`/`opinion` specifically, since
   those are exactly the ones the audit caught matching inside `<h1>` or
   inside unrelated prose). This alone kills defect §2.2/§2.3's literal
   failure mode (`<h1>` no longer matches `h1` — the boundary regex
   requires a non-word/non-hyphen character or string edge on both
   sides, and `<`/`>` don't satisfy "word start"; but `# H1` at a line
   start followed by space does, correctly).
3. **Section-scoping for hypothesis/verdict/evidence markers**: rather
   than searching the whole document, require the marker to appear either
   (i) as a labeled field at the start of a line —
   `^\s*(hypothesis|evidence|verdict)\s*:` — or (ii) inside a heading or
   list item whose own text contains the marker word at a word boundary.
   A marker word appearing only in flowing prose outside any such
   structural position (e.g. inside a sentence *about* the Mom Test rule)
   no longer counts. This directly closes defect §2.3: "we must not
   accept opinion alone" as a sentence in running prose is not a labeled
   `evidence:` field and not a heading/list item, so it stops satisfying
   `evidence_marker`.
4. **Adjacency check for evidence-to-claim association** (upgrade beyond
   what's strictly required to close the audited bugs, but implied by
   "a methodology's judgment can't pass by a bare keyword mention"): an
   evidence-strength tag must appear within the same paragraph/list-item
   block as a claim-shaped sentence (heuristically: a block containing a
   quote, "said"/"told me"/first-person-reported language, or an explicit
   `interview:`/`participant:` label), not merely anywhere in the
   document. A document with one `evidence: behavioral` line up top and
   an unrelated verdict far below no longer counts as "evidence logged
   for this verdict" — the tag must sit in the same structural block as
   the thing it's tagging.
5. **Prevalence/residual (saturation gate)**: already closer to
   structure-aware than the others (`PREVALENCE_RE` requires a `\d+\s*(of|/)\s*\d+`
   numeric pattern, not a bare word) — extend it only to also require the
   prevalence figure and the verdict marker to appear in the same
   paragraph block, closing the same "keyword anywhere in the document"
   gap as item 4, for consistency across all four gates.
6. Each gate's existing `has_any()` helper is replaced by a shared
   in-repo helper (not part of gate-lib, since this is content-judgment
   logic scoped to this rulebook — see scout-brief "not covered by
   gate-lib") — a small `_semantic.py` module under
   `user-discovery/hooks/lib/` (or equivalent shared location decided at
   phase-2; this proposal fixes the algorithm, not the exact file
   layout) providing `find_labeled_marker(text, label)`,
   `find_structural_marker(text, *words)`, and
   `same_block(text, pos_a, pos_b)`, imported by all four gates' Python
   payloads the same way `GATE_LIB_PY` is loaded. This is new code this
   repo owns, not a reimplementation of anything gate-lib provides.

## (d) Mandatory test cases

Per the standard's six-case harness (scout-brief §5) plus the issue's own
explicit list, applied to each of the four gates where relevant (some
cases only apply to gates with owned write surfaces — all four qualify):

| Case | Setup | Expected behavior |
|---|---|---|
| Edit + replace_all | `Edit` on an existing record with `old_string` occurring 2+ times, `"replace_all": true` | Gate judges content with **all** occurrences replaced (reconstructed via `gate_reconstruct_write`), not just the first |
| MultiEdit mixed replace_all | `MultiEdit` with edit 1 `replace_all:false`, edit 2 `replace_all:true`, targeting distinct multiply-occurring strings | Each edit's own flag honored independently; final reconstructed content reflects both correctly |
| Malformed JSON — truncated | Payload cut mid-object | `exit 2`, stderr names the parse failure — via `gate_parse_json_or_deny` |
| Malformed JSON — non-object | Payload is a JSON array or scalar | `exit 2` |
| Malformed JSON — empty | Empty stdin | `exit 2` (existing empty-payload check, now consistent with gate-lib's own empty handling) |
| Kill-switch unrecognized value | `USER_DISCOVERY_<PLUGIN>_GATE_OFF=banana` with content that would otherwise deny | Gate **stays active** and denies — asserts the fixed default, this is the regression test for the exact bug in survey §2.5 |
| Kill-switch recognized on-spelling | `..._GATE_OFF=1` / `=true` / `=yes` / `=on` (case-insensitive) with denying content | Gate disabled, `exit 0` |
| Absolute path | `file_path` given as an absolute path resolving to the same gated target a relative-path fixture already covers | Same allow/deny outcome as the relative-path case |
| `./`-prefixed path | `file_path` given as `./docs/issue-N/...` | Same allow/deny outcome as the unprefixed case |
| Bash-tool write reaching a gated target | `tool_name: "Bash"`, `command` containing a path token matching the gate's owned pattern | Denied with an explicit "cannot determine resulting content from a Bash command" message (per (b) item 8) — was previously invisible to the gate entirely |
| Substring-vs-structure: `<h1>` false positive | Content containing `<h1>Notes</h1>` and no labeled `hypothesis:`/heading hypothesis marker elsewhere | Hypothesis marker NOT detected (regression test for survey §2.2) |
| Substring-vs-structure: bare "opinion" in prose | Content containing "we must not accept opinion alone" in running prose, no labeled `evidence:` field | Evidence marker NOT detected (regression test for survey §2.3) |
| State-timing: sibling-gate denial doesn't poison state | Write that would satisfy hypothesis-order but is denied by evidence-tagging (no tag present); assert `.state.json` unchanged afterward, since the write never landed and PostToolUse never fired | `.state.json` remains at its pre-call values |

Ship-time requirement (unchanged from the issue): full suite green,
meaning all four gates' existing `tests/run-*-gate-tests.sh` plus the
above cases (added to those same files, or a new
`tests/run-gate-lib-compliance-tests.sh` mirroring
`core/hooks/tests/run-gate-lib-tests.sh`'s six-group structure) pass, and
`compliance-check.sh` runs clean against all four `hooks/` directories.

## (e) README realignment plan

- **Remove**: the four ghost-file bullets under "Layout" (lines 59-62 in
  current `README.md`) — `record-fields-gate.sh`, `trailer-gate.sh`,
  `handbook-trigger-gate.sh` — and the `agents/warrant-hunter.md` bullet
  (line 62); none exist on disk (survey §4).
- **Replace** the "Layout" section with an accurate structure listing:
  `user-discovery/hooks/{hooks.json,directive.sh}` (SessionStart only),
  and each of the four plugin's `hooks/*-gate.sh` + kill switch, one line
  each, cross-referencing the existing "Methodology plugin set" section
  rather than duplicating a stale parallel description.
- **Add**: a short "Gate implementation" subsection stating that all four
  gates source `core/hooks/lib/gate-lib.sh` (reference, not vendored copy)
  per `docs/handbooks/gate-house-standard.md`, with a pointer to this
  issue's proposal for the adoption rationale — so a future reader isn't
  left to rediscover the shared-library relationship from the code alone.
- **Add**: the actual kill-switch env var names as a table (currently
  scattered one-per-plugin-section, all correct individually — consolidate
  for scan-ability): `USER_DISCOVERY_PROPOSAL_NORM_GATE_OFF`,
  `USER_DISCOVERY_HYPOTHESIS_ORDER_GATE_OFF`,
  `USER_DISCOVERY_EVIDENCE_TAGGING_GATE_OFF`,
  `USER_DISCOVERY_SATURATION_GATE_OFF`.
- **Keep unchanged**: "Install" section and the "Methodology plugin set"
  section's plugin descriptions — both already match
  `.claude-plugin/marketplace.json` and the on-disk gates (survey §4).

## Non-goals for this issue

- No change to the Guest/Bunce/Johnson saturation heuristic's own content
  (`docs/handbooks/user-discovery/per-interview-checklist.md`) — out of
  scope per the existing gates' own doc comments, unaffected by this
  audit.
- No new gate-lib.sh/gate-lib.py functions proposed — every mechanical
  defect this issue lists is already covered by what's landed.
- No phase-2 code in this document; the exact file layout for the shared
  `_semantic.py` helper module and the PostToolUse state-sync hook's
  precise contents are phase-2 decisions, constrained but not fully
  specified here.
