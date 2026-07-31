# issue-1 phase-1 survey: current-state of the user-discovery plugin

Subject: issue-1. Scope: what this role's plugin carries today, so the
methodology proposal can name exact gaps instead of guesses. This is a
snapshot as of the issue-2 cutover (commit d0569d5), which already
replaced the local warrant-hunter/gate copies with core-canon references.

## Inventory: files this repo owns today

| Path | Contents today | Relevant to this issue |
|---|---|---|
| `user-discovery/.claude-plugin/plugin.json` | `description` embeds the mandate/use_when/hand-off text; no `produces` field, no methodology reference. | The `produces` line ("interview script, per-interview evidence log, pain-confirmed\|not-confirmed verdict") lives only in prose, not as a structured, checkable list. |
| `user-discovery/hooks/directive.sh` | Stub sourcing `core/hooks/lib/role-directive.sh`, calling `core_role_directive` with 4 string args: YOU DECIDE, USE WHEN, PRODUCES, HAND-OFF. `PRODUCES` is one free-text string, not itemized sub-fields. | This is the field the phase-2 plan (section d of the proposal) will refine — it currently cannot express "each interview-script question must be past-behavior phrased" or similar sub-norms; it can only carry the flat produces line it already has. |
| `user-discovery/hooks/hooks.json` | `SessionStart` → `directive.sh` only. No `PreToolUse` entries (issue-2 removed the three role-local gates; core now registers generic gates by `CLAUDE_ROLE`). | No local record-fields-gate.sh exists in this repo — confirmed by direct listing (`find user-discovery -type f`). Any REQUIRED_FIELDS enforcement today, if it exists at all, must be happening core-side, keyed off some role-manifest `produces`/config value this repo does not yet author explicitly. |
| `docs/specs/approvers.md` | One login (`JiwonJung94`). | Unaffected by this issue; noted for completeness. |
| `docs/issue-2/*` | Already-landed phase-1 survey + proposal + phase-2 delivery for the core-canon cutover. | Establishes the doc conventions this issue's own docs should follow (see scout-brief and proposal). Also establishes that `record-fields-gate.sh` is GONE from this repo (deleted by issue-2) — issue-1's phase-2 plan must not propose re-adding a local copy of it; if a REQUIRED_FIELDS gate is wanted, it has to be expressed as config core's generic gate reads, not a new local script. |

## What this role's plugin does NOT have today (relative to the domain)

- **No interview script template or required-question structure.** Nothing in this repo defines what a "good" interview script looks like structurally (question phrasing rules, ladder of follow-ups, screener). The `produces` line names the deliverable but not its shape.
- **No per-interview evidence log template.** No file defines what fields an evidence log entry must have (date, participant, verbatim quotes, evidence-strength tag, theme tags).
- **No pain-verdict rubric.** "pain-confirmed\|not-confirmed" is named as an enum outcome but nothing defines the evidence threshold that justifies flipping it (e.g., how many corroborating past-behavior accounts, whether prevalence must be stated, whether contradicting interviews must be logged).
- **No REQUIRED_FIELDS-equivalent config in this repo.** issue-2 removed the local `record-fields-gate.sh`; whatever replaces role-specific required-fields enforcement (core-side generic gate + some role config value) is not yet declared anywhere in this repo. This is the concrete hook point section (d) of the proposal targets.
- **No stopping-rule or saturation-tracking convention.** Nothing addresses when discovery is "done" (how many interviews, on what basis).
- **No local warrant-hunter.md** — confirmed absent by direct file listing. Per this issue's own constraint and issue-2's already-landed cutover, this is correct: it should stay a core-canon reference (core issue #63), not be reintroduced locally.

## What is NOT available/known from this repo alone

- The exact shape of core's generic record-fields gate (what config key it reads role-specific required-fields from, post issue-2 cutover) — not visible from this repo; phase-2 execution for issue-1 will need to read `core/hooks/lib/` directly, same caveat issue-2's survey flagged.
- Whether `core_role_directive`'s `PRODUCES` argument supports structured sub-fields or only a flat string — unknown without reading `core/hooks/lib/role-directive.sh`'s current signature (issue-2 already resolved this once for its own purposes; issue-1 phase 2 should re-check rather than assume it hasn't changed).

This inventory is the basis for the gap line in `scout-brief.md` and for
section (d) of `docs/issue-1/proposals/user-discovery-methodology.md`.
