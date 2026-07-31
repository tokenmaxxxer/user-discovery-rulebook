# Proposal: cut this rulebook over to core canon (issue-2)

Phase-1 proposal only — no execution. Approve on issue-2/implementation
opens phase 2, where this plan is carried out on the same branch.

## Summary

This role's rulebook currently carries three local copies of surfaces
that core has since landed as canon (core issues #63, #66): the
warrant-hunter agent, the three role-agnostic PreToolUse gates, and the
directive boilerplate. Each copy admits, in its own comments, that it was
adapted from `implementation-rulebook` rather than authored for this
role. Item by item, keyed to the issue's five work items; see
`docs/issue-2/reports/implementation/survey.md` for the file-level
inventory this plan is built from.

## 1. Remove `agents/warrant-hunter.md`, reference core canon

Delete `user-discovery/agents/warrant-hunter.md`. It has no role-specific
logic beyond the mandate line (이 문제가 실제 사용자의 고통인가) and the
hand-off pointer, both of which already live in `directive.sh` /
`plugin.json` — nothing here is lost by deletion.

Replace it with a short pointer doc (or a `README.md` note in
`user-discovery/agents/`, whichever core's own rollout convention
expects — **unresolved, see gap below**) stating: hunt agent duties are
served by the core `warrant/` plugin; this role supplies only its stance
input (the mandate line) via `directive.sh`.

**Gap (blocks exact wording):** how a role-scoped rulebook is expected to
declare a dependency on a core plugin — a `plugin.json` `dependencies`
key, a doc-only pointer, or an actual `agents/` symlink/stub — is not
knowable without reading core issue #63's landed shape. Recommend phase-2
starts by reading that shape before writing the replacement file.

## 2. Remove the three gate copies + their registration

Delete:
- `user-discovery/hooks/trailer-gate.sh`
- `user-discovery/hooks/handbook-trigger-gate.sh`
- `user-discovery/hooks/record-fields-gate.sh`

And remove the corresponding `PreToolUse` block entries from
`user-discovery/hooks/hooks.json`, leaving only the `SessionStart` entry
for `directive.sh`.

`trailer-gate.sh` and `handbook-trigger-gate.sh` have no role-specific
logic today (the former is explicitly role-agnostic by its own comment;
the latter is a bare placeholder that always exits 0) — deleting them
loses nothing. `record-fields-gate.sh` DOES carry role-specific state
(the `REQUIRED_FIELDS` list and the `docs/issue-<n>/reports/user-discovery.md`
target path) — that state must be preserved, which is item 4 below, not
lost as part of this deletion.

**Gap (blocks exact hooks.json diff):** whether core's own hook
registration (core issue #66) is injected automatically per `CLAUDE_ROLE`
with zero rulebook-side config, or whether this rulebook must still
declare something (e.g., a role manifest key naming its record path) for
core's generic gate to find `docs/issue-<n>/reports/user-discovery.md`
and this role's required fields. This determines whether `hooks.json`
ends up empty of `PreToolUse` entries entirely, or gets one new entry
pointing at a role-config file. Resolve by reading core issue #66's
landed hook registration before editing `hooks.json`.

## 3. Stub `directive.sh`

Replace the current standalone heredoc in `user-discovery/hooks/directive.sh`
with a stub that sources `core/hooks/lib/role-directive.sh` and calls its
`core_role_directive` function, passing only this role's unique content:

- YOU DECIDE: 이 문제가 실제 사용자의 고통인가
- USE_WHEN: 가설 검증을 위해 사용자 인터뷰가 필요할 때
- PRODUCES: interview script, per-interview evidence log, pain-confirmed|not-confirmed verdict
- WRITE_SCOPE: [] (report-only role)
- HAND-OFF: 검증된 가설을 스펙화하면 → requirements-engineering
- RECORD: `docs/issue-<n>/reports/user-discovery.md`

The `USER_DISCOVERY_CYCLE_OFF` kill-switch check (lines 4–8 of the
current file) is role-specific plumbing, not boilerplate — it stays in
the stub.

**Gap (blocks exact call syntax):** `core_role_directive`'s argument
order, names, and whether it takes the BOUNDARY CASE paragraph as a
fixed shared string or a per-role override, is unknown without reading
`core/hooks/lib/role-directive.sh`. The proposal preserves every field
this role's current directive emits; phase-2 execution maps them onto
whatever the actual function signature turns out to be.

## 4. Preserve this role's genuine differences explicitly

Two role-specific facts must survive the gate-copy deletion (item 2) as
explicit config rather than silently vanishing:

- `record-fields-gate.sh`'s `REQUIRED_FIELDS = ["interview-script",
  "per-interview-evidence-log", "pain-verdict"]` — this is this role's
  actual `produces` set and has no equivalent elsewhere once the local
  copy is gone.
- This role has no distinct terminal `loop_state` set beyond core's
  default (nothing in the current files defines one) — so unlike the
  issue's example (`RECORD_FIELDS_TERMINAL_STATES` for closing-state
  differences), this role likely needs only a required-fields override,
  not a terminal-states override. Confirm this reading against core
  canon's actual config surface in phase 2; if core's generic gate reads
  required fields from `roles/user-discovery.json`'s `produces` key
  directly (as `record-fields-gate.sh`'s own comment implies it already
  should), no additional config file is needed at all — the local gate
  copy was doing redundant work.

## 5. `core/hooks/tests/stub-check.sh`

Cannot be run from this environment (path does not exist in this repo;
core is not checked out here). Phase-2 execution must locate and run it
against the post-cutover state, then record the pass/fail result in
`docs/issue-2/reports/implementation.md` per the issue's item 5.

## Ordering constraint carried forward

Per the issue: this cutover must complete before this repo's own
"rulebook maturation" issue reaches phase 2. Noting this so phase-2
execution (once approved) sequences ahead of any other in-flight issue
on this repo touching the same files.

## Open gaps requiring core canon access (repeated for visibility)

1. Dependency-declaration convention for `agents/warrant-hunter.md`'s replacement.
2. `core/hooks/` registration shape for the three gates (auto vs. role-config-driven).
3. `core_role_directive` function signature.
4. Whether core's generic record-fields gate already reads `produces` from a role manifest, making a `REQUIRED_FIELDS`-equivalent override unnecessary.

None of these block phase-1 (this proposal); all four must be resolved by
reading actual core canon files at the start of phase-2 execution, before
any deletion or stub-write happens.
