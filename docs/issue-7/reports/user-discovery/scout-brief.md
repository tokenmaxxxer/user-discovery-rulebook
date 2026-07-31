# issue-7 scout brief

Deliverable class: a phase-1 design proposal for a plugin enforcement
mechanism (directive + gate + tests + agents/checklist), not a
product/market decision — so the comparables are same-class artifacts
already living in sibling rulebooks in this same tokenmaxxxer ecosystem,
not external web products. Per the scout directive, "best of own
deliverable's kind" for a non-product role means the strongest existing
examples of this exact artifact class.

Mode: batched-sequential (single session, no parallel subagent/tool
fan-out) — reading known local repo paths directly is a targeted lookup,
not a breadth search; there was no ambiguity about where to look (the
issue names implementation-rulebook and pricing-rulebook's
methodology-gate.sh explicitly), so a fan-out sweep across search angles
would not have surfaced anything a direct read didn't. 2 stages used:
(1) locate and read the named exemplars + core canon signatures, (2)
one deepening pass reading the actual gate/test code bodies referenced
by stage 1's file listing. Wall-clock well under budget.

## Must-bes (what the strongest existing gate implementations assume)

- A role-specific gate is **layered on top of**, never instead of,
  core's generic `record-fields-gate.sh` — it only fires on this role's
  own write surfaces and only checks this role's own domain elements.
  Source: `pricing-rulebook/pricing/hooks/methodology-gate.sh` (header
  comment, lines 3-5).
- Fail-closed on internal error (trap + explicit exit 2 on any
  unexpected exception), never fail-open. Source: same file, `__fc`
  trap + `except Exception` wrapper; also `core/hooks/record-fields-gate.sh`
  identical pattern.
- A kill switch env var per gate (`<NAME>_GATE_OFF=1`), checked first.
  Source: both gate files above.
- Canon scripts referenced by resolved path, never vendored — mechanically
  enforced by `core/hooks/tests/stub-check.sh` against
  `canon-manifest.txt`. Source: `docs/handbooks/canon-scripts.md`.

## Performance axes the strongest examples compete on

1. **Content-reconstruction correctness** — Write/Edit/MultiEdit all
   produce different `tool_input` shapes; a gate that only handles
   `Write`'s `content` field misses `Edit`'s old/new-string diff. Both
   exemplar gates reconstruct the resulting text for all three tool
   types before checking it.
2. **Message diagnosability** — deny messages name exactly which
   required element(s) are missing (a list, not a single generic
   "invalid"), so a session can fix the write in one pass.

## Adopt / skip

- **Adopt**: role-owned methodology gate targeting this role's own
  proposal+record write surfaces, substring/regex-checking required
  elements, fail-closed, kill-switched, layered on core's generic gate.
  (pricing-rulebook's shape.)
- **Adopt**: state-tracking for the one genuine ordering constraint this
  role's methodology has (hypothesis stated → interviews logged →
  verdict written) — small persisted marker file + gate check, shaped
  like `implementation-rulebook`'s `hunt-state.sh`/`hunt-guard.sh` pair,
  but role-owned content (not copied).
- **Skip**: a full JSON-schema validator for record structure — none of
  the exemplars use one; substring/regex-on-reconstructed-text is the
  established, cheap pattern across every reference gate read, and this
  role's required elements (hypothesis line, evidence-strength tag,
  prevalence count, residual/contradiction note) are exactly as
  grep-checkable as pricing's six elements were.
- **Skip**: proposing a change to `core/hooks/lib/role-directive.sh`'s
  4-arg signature — out of this issue's scope (issue says "역할 경계
  불변"); directive deepening works within the existing 4-string-arg
  call by making the PRODUCES string itself carry more structure, per
  facet, not by changing core's function.

## Segment fit

This role's methodology (Mom Test / falsifiable hypotheses / evidence-
strength tagging / saturation) already has a phase-1-adopted, sourced
rationale in `docs/issue-1/proposals/user-discovery-methodology.md`
section (c). This issue does not re-derive methodology; it mechanizes
what issue-1 already adopted. The gap line below is scoped to that.

## Gap line (what the field's must-bes the current state already meets vs. misses)

- **Already meets**: kill-switch convention exists at the `directive.sh`
  level (`USER_DISCOVERY_CYCLE_OFF`); phase-gated PR/record discipline
  exists at the contract level (core, not this role, enforces it via
  `approval-gate.sh`/`board-gate.sh`).
- **Missing**: no role-owned PreToolUse gate at all (core's generic gate
  only checks §20 generic fields, not this role's domain elements); no
  phase-aware directive text (one flat PRODUCES string for both
  phases); no state tracking for the hypothesis→evidence→verdict order;
  no gate tests in this repo's `tests/`; no per-interview checklist
  artifact for the evidence-tagging discipline issue-1 already adopted.

## Sources

- `pricing-rulebook/pricing/hooks/methodology-gate.sh` (local repo path:
  `/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh`)
- `implementation-rulebook/coding/hooks/hunt-state.sh`,
  `implementation-rulebook/coding/hooks/hunt-guard.sh` (local repo path:
  `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/`)
- `core/hooks/record-fields-gate.sh`, `core/hooks/lib/role-directive.sh`,
  `docs/handbooks/canon-scripts.md` (local repo path:
  `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/`)
- `core/hooks/tests/run-role-gates-tests.sh` (same repo, test-harness
  shape reference)
- This repo's own `docs/issue-1/proposals/user-discovery-methodology.md`
  (the already-adopted methodology this issue mechanizes)
