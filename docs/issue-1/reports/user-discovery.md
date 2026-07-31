---
subject: issue-1
role: user-discovery
loop_state: landed
---

# Phase-2 record — rulebook maturation (user-discovery methodology)

Approved via issue comment `APPROVE issue-1/user-discovery` (single-account
mode, `docs/specs/approvers.md`), opening phase 2 on
`docs/issue-1/proposals/user-discovery-methodology.md`.

## What was done

Reflected the approved methodology norm into this rulebook's plugin
surfaces, per proposal section (d):

1. **`user-discovery/.claude-plugin/plugin.json`**: added a structured
   `produces` array — `["interview-script", "per-interview-evidence-log",
   "pain-verdict"]` — alongside the existing prose `description`, so the
   three phase-2 deliverables are machine-readable rather than only
   embedded in free text.
2. **`user-discovery/hooks/directive.sh`**: kept the existing
   `core_role_directive` call with its 4 positional args (unchanged
   call signature — verified against
   `core/hooks/lib/role-directive.sh` in a local core checkout, see
   upstream basis below). Rewrote the `PRODUCES` argument from a flat
   one-line sentence to an itemized string spelling out each
   deliverable's required sub-structure from the approved proposal:
   interview script (past-behavior questions only, follow-up ladder per
   hypothesis, stated falsifiable hypothesis + disconfirming answer per
   question, no pitching before behavioral questions are exhausted),
   evidence log (evidence-strength tag per claim, prompted/unprompted
   flag per theme, running saturation count), and verdict (cites log
   entries, states prevalence as N of M, notes contradicting evidence).
   This is now the text a session sees at `SessionStart`.
3. **`REQUIRED_FIELDS`-equivalent gate config: explicitly NOT added** —
   see "What was deliberately not built" below; this was proposal open
   item 2, now resolved by reading core canon directly.
4. **No local `warrant-hunter.md`, no local gate-script
   reintroduction** — confirmed still true; no files added under
   `user-discovery/agents/` or duplicate `hooks/*-gate.sh` copies.
   `warrant-hunter` stays a core-canon reference (core issue #63),
   consistent with this issue's own constraint and issue-2's already-
   landed cutover (commit d0569d5).

## Why

The proposal's rationale (section (c)) is the "why" for the methodology
content itself (past-behavior-only questions, falsifiable hypotheses,
evidence-strength tagging, timeline/follow-up-ladder structure,
saturation as heuristic not hard gate) and is not repeated here. This
record's own "why" is narrower: which of the proposal's plan items were
actually reflected into plugin fields, and which were correctly left
unbuilt because core canon does not support them — both traceable to
reading the real core implementation rather than guessing, per this
role's own evidence-honesty norm (proposal section (a) rule 4).

## Upstream basis

Phase-2 execution read core canon directly at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core` (local checkout of
`tokenmaxxxer-core`, `main`) to resolve the proposal's open items before
editing this rulebook, specifically:

- `core/hooks/lib/role-directive.sh` — confirms `core_role_directive`
  takes exactly 4 positional args (`you_decide`, `use_when`, `produces`,
  `hand_off`), no fifth slot. The `PRODUCES` string can be arbitrarily
  long/structured prose; the function does no parsing of it beyond
  emitting it verbatim. This resolves proposal open item 2 in the
  negative for structure-at-the-directive-layer: `directive.sh` can
  *say* more, but the function gives it no machine-checkable structure.
- `core/hooks/record-fields-gate.sh` — confirms core's generic
  record-fields gate enforces a **fixed §20 field set** (what-was-done,
  why, upstream-basis, `loop_state`, open-findings, plus
  next-steps/resolution-path when `loop_state` is non-terminal) against
  a role's own record file (`docs/issue-<n>/reports/<role>.md`). It does
  **not** read a per-role `produces` list or any nested sub-structure
  (interview-script's required sub-fields, evidence-log's tag
  vocabulary, verdict's citation requirement) from anywhere — the
  proposal's `REQUIRED_FIELDS`-equivalent plan item (section (d), third
  bullet) is therefore **not expressible in current core canon**. Adding
  it would require a core canon change, which is out of this rulebook's
  scope per this issue's own constraint. This resolves proposal open
  item 2 definitively (previously flagged as needing this exact read).
  Deferred per that finding — see Open findings.

## What was deliberately not built

- **No `REQUIRED_FIELDS`-equivalent config file or env block** in
  `user-discovery/hooks/hooks.json`. Core's generic gate has no config
  surface to receive one (see upstream basis above); inventing a config
  key core never reads would be dead weight, and writing a new local
  gate script to enforce it would violate this issue's explicit
  constraint against reintroducing local gate copies (issue-2's already-
  landed direction). The deliverable-level requirements (evidence-
  strength tags, follow-up ladders, prevalence counts, etc.) stay
  enforced as the **directive text + human review checklist** the
  proposal itself recommended for exactly this reason (section (d),
  "Gate honesty note") — most of them are not reliably machine-
  checkable by pattern match in the first place.
- **No `RECORD_FIELDS_TERMINAL_STATES` override** — nothing in this
  role's files defines a non-`landed` terminal state; matches issue-2's
  same finding for this same role.
- **No resolution of the third `insufficient-evidence` verdict state**
  (proposal open item 1) — this is a mandate/scope question for human
  review, not a plugin-reflection task; left open, not decided
  unilaterally, per the proposal's own instruction.

## Open findings

1. **Third verdict state (`insufficient-evidence`)** — proposal open
   item 1. The mandate's binary `pain-confirmed|not-confirmed` enum may
   need a third state for verdicts resting only on `opinion`-tier
   evidence. Not decided here; needs explicit human/approver direction
   on a future issue before either `plugin.json`'s prose or any future
   gate config encodes a third state.
2. **Deliverable sub-structure has no machine gate** — confirmed (see
   upstream basis) that core's record-fields gate cannot enforce
   interview-script/evidence-log/verdict sub-requirements. If future
   maturation wants these machine-checked rather than human-reviewed,
   that requires a core-canon change (a new gate or an extension to
   `record-fields-gate.sh`'s config surface) filed as a core issue, not
   as work inside this rulebook.
3. **Braun & Clarke 2006 primary-source citation** — proposal open item
   3, still sourced via the user-discovery skill's evidence grading
   (`[secondary-citation]`), not independently re-verified by URL in
   this pass. Precision only matters if a future gate's error-message
   wording needs to quote the paper directly; not blocking for this
   issue's scope.

None of the three block this issue's own delivery: items 1 and 3 are
explicitly scoped to human/future-issue decisions by the approved
proposal itself, and item 2 is a negative finding (confirmed
not-buildable within this rulebook's own files), not an unresolved gap
in this repo.
