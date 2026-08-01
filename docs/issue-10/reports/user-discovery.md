# Record: gate A+ upgrade delivery (issue-10)

loop_state: landed

Phase-2 delivery record for the proposal at
`docs/issue-10/proposals/gate-a-plus-upgrade.md`, sourced from the survey
at `docs/issue-10/reports/user-discovery/current-state-survey.md`. All four
gates (`user-discovery-proposal-norm`, `user-discovery-hypothesis-order`,
`user-discovery-evidence-tagging`, `user-discovery-saturation`) migrated
onto `core/hooks/lib/gate-lib.{sh,py}` (issue-72) per the approved plan;
every audited defect from the issue's "실물 코드 감사 결과 (등급: B+)"
comment is fixed. This is an implementation-audit record, not a
user-discovery interview verdict — no hypothesis/evidence/verdict markers
apply here.

## Why

Rationale, per the issue and its upstream basis
(`docs/issue-10/proposals/gate-a-plus-upgrade.md`, itself sourced from
`docs/issue-10/reports/user-discovery/current-state-survey.md`, and the
core issue-72 gate-house standard the proposal adopts by reference): the
issue's own audit graded this repo's four gates B+ on four repo-wide bug
classes core had already fixed once in its own canon and packaged as
`gate-lib.sh`/`gate-lib.py`, plus two rulebook-local semantic/state gaps.
The proposal committed to a conservative, reference-adopting fix (no
reimplementation of anything `gate-lib` already provides); this record
delivers that plan.

## What was done (summary of work)

1. **State-timing (PreToolUse write, including denied writes).**
   `hypothesis-order-gate.sh` no longer calls `save_state()` at all. A new
   PostToolUse hook, `hypothesis-order-state-sync.sh` (registered in
   `user-discovery-hypothesis-order/hooks/hooks.json`), re-derives the
   three markers from the file **as written on disk** and persists them —
   it only fires once every gate on the same tool call, including sibling
   plugins, allowed the write. Regression-tested by
   `state-unchanged-on-deny` in `tests/run-hypothesis-order-gate-tests.sh`.
2. **Substring semantics (bare hypothesis-heading token inside an HTML
   heading tag; a bare evidence-strength word used only in running prose).**
   `user-discovery/hooks/lib/_semantic.py` replaces every gate's
   `has_any()`/bare-substring check with `structural_marker()`: a marker
   word counts only in a labeled field line (`hypothesis:`/`evidence:`),
   a heading, a list item, or a `[tag]` bracket — never in flowing prose.
   Regression-tested by `h1-in-prose-not-a-marker` /
   `opinion-in-prose-not-evidence` (hypothesis-order) and
   `opinion-bare-word-in-prose` (evidence-tagging).
3. **Path normalization.** All four gates now call
   `gate_lib.gate_normalize_path(root, path)` in place of their own
   `resolve()`/`_under()`. Regression-tested by absolute-path and
   `./`-prefixed-path cases in the hypothesis-order, saturation, and
   proposal-norm suites.
4. **Fail-closed gaps.** `gate_trap_fail_closed` replaces the hand-rolled
   `__fc`/`trap` pair (still the literal first two statements, before
   `set -uo pipefail`); `gate_parse_json_or_deny` replaces the inline
   `json.loads`/`except` block, extended to `gate-lib`'s broader malformed
   set (non-object top level); `gate_kill_switch_active` replaces every
   `case ... *) exit 0 ;; esac`, so an unrecognized value (e.g. a typo) now
   stays active instead of silently disabling the gate. Regression-tested
   by the `malformed-json-*` and `kill-switch-unrecognized-value-*` cases.
5. **Edit/MultiEdit/replace_all/NotebookEdit.** All four gates now call
   `gate_lib.gate_reconstruct_write(tool, ti, current)` instead of their
   own hardcoded `current.replace(o, n, 1)`. Regression-tested by
   `edit-replace-all-both-occurrences` and `multiedit-mixed-replace-all`
   in `tests/run-evidence-tagging-gate-tests.sh`.
6. **Deny reasons to stderr.** Uniform via `gate_lib.gate_deny` /
   bash-level `gate_deny`/`gate_allow` — no behavior change, protocol
   consistency only (this was already correct).
7. **Bash-tool write visibility.** All four gates gained a `Bash` branch
   (`gate_bash_write_targets`, matched against each gate's owned path
   pattern via `gate_normalize_path`): a `Bash`-tool write reaching a
   gated path is now denied with an explicit "cannot determine resulting
   content from a Bash command" message instead of being invisible.
   Regression-tested by `bash-tool-write-to-owned-path` in the
   proposal-norm, evidence-tagging, and saturation suites.
8. **Saturation prevalence/residual same-block adjacency.** Extended per
   proposal (c) item 5, consistent with the structural-scoping approach:
   the prevalence figure must sit in the same paragraph block as the
   verdict marker, and a residual/contradiction acknowledgment must sit in
   the same block as the contradiction-indicating language it acknowledges.

## Scope decisions (deviating from the literal proposal text)

- **The two verdict marker words (a positive-pain compound token and a
  negative-pain compound token, plus "insufficient-evidence") use
  word-boundary matching only, not full structural scoping**, even though
  proposal (c) item 3 phrases the rule as applying uniformly to
  "hypothesis/verdict/evidence" markers. These are distinctive hyphenated
  compound tokens — the audit found no substring-collision bug for them
  (unlike the short bare hypothesis-heading tokens or the bare evidence
  word) — and full structural scoping would have broken a real, intended
  case: a verdict sentence phrased as "Overall verdict: ..." does not
  start a line with the bare label `verdict:`, but is unambiguously a
  verdict; scoping it out would have silently defeated the saturation
  gate's prevalence/residual requirement on realistic phrasing. Kept as
  `semantic.word_present()`.
- **Bracket tags (e.g. `[behavioral]`) count as a structural position**,
  in addition to proposal (c) item 3's labeled-field and heading/list-item
  positions. The pre-existing evidence-tagging test fixtures already used
  bracket-tag content as this plugin's established usage convention;
  recognizing brackets as structural (a deliberate tag, not incidental
  prose) closes the same false-positive class the audit named without
  discarding that convention.
- **Item 4 (evidence-to-claim paragraph adjacency) not implemented.** The
  proposal itself marks this "beyond what's strictly required to close the
  audited bugs," and it is not in the mandatory test-case table (d). Left
  out to keep the change scoped to the audited defects plus the items the
  standard's own harness requires.

## Test suite

`tests/run-all-gate-tests.sh` — all green (46 cases across four gate
suites, 0 failed):

- `run-proposal-norm-gate-tests.sh`: 10 passed, 0 failed
- `run-hypothesis-order-gate-tests.sh`: 10 passed, 0 failed
- `run-evidence-tagging-gate-tests.sh`: 15 passed, 0 failed
- `run-saturation-gate-tests.sh`: 11 passed, 0 failed

Each suite covers the mandatory case set (issue text + proposal (d)) at
least once across the four files: Edit+replace_all, MultiEdit mixed
replace_all, malformed JSON (truncated/non-object/empty), kill-switch
unrecognized value, absolute path, `./`-prefixed path, Bash-tool write to
a gated path, and both substring-vs-structure regressions (bare hypothesis
token inside an HTML heading tag; bare evidence word in running prose).

## `compliance-check.sh` (core/hooks/tests, issue-72)

Run via `tests/run-gate-lib-compliance-tests.sh`, part of
`run-all-gate-tests.sh`. Clean against all four plugin `hooks/`
directories:

```
compliance-check: ok — user-discovery-proposal-norm/hooks/proposal-norm-gate.sh
compliance-check: ok — user-discovery-hypothesis-order/hooks/hypothesis-order-gate.sh
compliance-check: ok — user-discovery-evidence-tagging/hooks/evidence-tagging-gate.sh
compliance-check: ok — user-discovery-saturation/hooks/saturation-gate.sh
```

No `FAIL` lines — no gate reads a kill-switch env var without calling
`gate_kill_switch_active`, and no gate reconstructs Edit/MultiEdit content
via its own `.replace(...)` call outside `gate_reconstruct_write`.

## README

Realigned to on-disk reality: ghost-file bullets (`record-fields-gate.sh`,
`trailer-gate.sh`, `handbook-trigger-gate.sh`, `agents/warrant-hunter.md`)
removed from "Layout"; a "Gate implementation" section added pointing at
`gate-house-standard.md` and this issue's proposal; kill-switch env var
names consolidated into a table.

## Open findings

None outstanding. `loop_state: landed` — this delivery is complete: all
mandatory test cases pass, `compliance-check.sh` is clean, and the README
is realigned to the on-disk layout.
