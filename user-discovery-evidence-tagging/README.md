# user-discovery-evidence-tagging

Enforces the Mom Test evidence-strength tagging discipline on the
user-discovery record: `docs/issue-<n>/reports/user-discovery.md`.

A `PreToolUse` gate on `Write|Edit|MultiEdit`, scoped only to that path,
denies a write whose reconstructed resulting content carries none of the
three evidence-strength tags:

- **behavioral** — what the person actually did
- **recounted** — what the person says they did
- **opinion** — what the person thinks/feels/would do

Match is a case-insensitive substring check anywhere in the record content.
On any other path the gate exits 0 immediately — not this plugin's business.

**Deliberately not gated**: the no-pitch-before-behavioral-exhausted rule
(keep asking about past behavior until exhausted before pitching anything)
is a content-judgment call, not substring-checkable, so it is out of scope
for this gate. It is enforced only as guidance in
`docs/handbooks/user-discovery/per-interview-checklist.md`.

## Escape hatch

`USER_DISCOVERY_EVIDENCE_TAGGING_GATE_OFF=1` disables the gate.
