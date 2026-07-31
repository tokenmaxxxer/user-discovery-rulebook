# user-discovery-hypothesis-order

Enforces the Customer Development ordering discipline for user-discovery
records: falsifiable hypotheses stated before interviews, evidence logged
before a verdict is written.

A `PreToolUse` gate (`Write|Edit|MultiEdit`) is path-scoped to exactly one
write surface — `docs/issue-<n>/reports/user-discovery.md` — and exits 0
immediately on any other path.

## State

A branch-durable JSON state file at
`docs/issue-<n>/reports/user-discovery/.state.json` (not `.claude/`-session-
local) tracks three booleans, derived from the reconstructed content of each
write to the record file:

- `hypotheses_stated`
- `evidence_logged`
- `verdict_written`

## Marker vocabulary

- **Hypothesis markers**: `hypothesis:`, `falsifiable hypothesis`, `H1`, `H2`
- **Evidence-strength tags** (shared with the sibling evidence-tagging
  plugin): `behavioral`, `recounted`, `opinion`
- **Verdict markers**: `pain-confirmed`, `not-confirmed`,
  `insufficient-evidence`

## The one hard denial

A write whose reconstructed content contains a verdict marker is **denied**
if `evidence_logged` is still false — checked against the persisted state
file OR fresh detection of an evidence tag in that same write's content
(so a single write introducing both the first evidence tag and a verdict
marker is allowed). On an allowed write, the state file is updated with the
newly detected booleans for subsequent writes to see.

Content reconstruction handles `Write` (`content`), `Edit`
(`old_string`/`new_string` replace), and `MultiEdit` (folded edit list)
identically; if reconstruction fails, the gate denies with a specific
"cannot determine resulting content" message rather than guessing.

## Kill switch

`USER_DISCOVERY_HYPOTHESIS_ORDER_GATE_OFF=1` disables the gate (exits 0
regardless of content).
