# user-discovery-proposal-norm

Enforces the phase-1 proposal survey-first/sourced-evidence norm owned by the
user-discovery role, per `docs/issue-7/proposals/plugin-enforcement-hardening.md`
§1: a proposal must cite a real survey path it was built on, not just assert
findings.

**What the gate checks**: a `PreToolUse` gate on `Write|Edit|MultiEdit`,
scoped only to `docs/issue-<n>/proposals/*.md`. It reconstructs the resulting
content of the write and denies (exit 2) if that content contains no
`docs/issue-<n>/reports/user-discovery/` path substring — i.e., the proposal
cites no survey it is based on. Any other path is not this gate's business
and it exits 0 immediately.

**What it deliberately does NOT check**: the `[assumption]`-labeling rule
from the same proposal is explicitly out of scope for this gate. That is a
separate, already-decided methodology concern this plugin does not enforce —
not an oversight.

**Kill switch**: `USER_DISCOVERY_PROPOSAL_NORM_GATE_OFF=1` disables the gate
(unset, `0`, `false`, `no`, `off` all leave it on; any other value turns it
off).
