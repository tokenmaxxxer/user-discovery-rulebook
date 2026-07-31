---
subject: issue-2
role: implementation
loop_state: landed
---

# Implementation record — core canon reference cutover

Approved (see issue #2 comment thread) after the phase-1 proposal
(`docs/issue-2/proposals/core-canon-reference-cutover.md`), which left
four gaps open pending access to core canon (core issues #63/#66).

## What was done (upstream basis)

Phase-2 execution started by reading the actual core canon files at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core` (a local checkout of the
`tokenmaxxxer-core` repo on `main`, containing the landed core issue-63
and issue-66 deliveries) to resolve the proposal's four open gaps before
touching this rulebook:

1. **`agents/warrant-hunter.md` removed, no replacement pointer file.**
   Core's `warrant/` plugin (core issue #63) is a marketplace plugin
   (`.claude-plugin/marketplace.json` entry), the same install
   mechanism this rulebook already relies on for `core`/`scout`/
   `terse`/`freelunch` — none of which this rulebook declares via a
   local pointer file either. Deleting the vendored copy with no
   replacement matches that existing precedent exactly; no dependency
   syntax needed inventing.

2. **Three gate copies removed, all `hooks.json` `PreToolUse` entries
   removed.** `trailer-gate.sh`, `record-fields-gate.sh`,
   `handbook-trigger-gate.sh` deleted from `user-discovery/hooks/`.
   Confirmed from `core/hooks/hooks.json` (core issue-66 delivery) that
   the approver chose core-side registration: all three gates now fire
   from `core/hooks/hooks.json`'s own `PreToolUse` block for every
   plugin install, so no per-rulebook registration remains at all —
   `user-discovery/hooks/hooks.json` now carries only the
   `SessionStart` → `directive.sh` entry.

3. **`directive.sh` stubbed.** Replaced the standalone heredoc with:
   ```
   #!/usr/bin/env bash
   . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
   core_role_directive "YOU DECIDE: ..." "USE WHEN: ..." "PRODUCES: ..." "HAND-OFF: ..."
   ```
   `core_role_directive`'s actual signature (read from
   `core/hooks/lib/role-directive.sh`) takes exactly four positional
   values — no fifth slot for `WRITE_SCOPE` or `BOUNDARY CASE`, both of
   which the old local directive carried. These are not lost: they are
   now covered generically by core's own protocol layer, not by this
   role's directive text. The `USER_DISCOVERY_CYCLE_OFF` kill switch the
   proposal expected to keep local is also already reproduced generically
   inside `core_role_directive` itself (it derives `<ROLE>_CYCLE_OFF`
   from `CLAUDE_ROLE`), so no local kill-switch code was added — kept
   the stub to exactly the `stub-check.sh`-required shape (source line +
   one single-line `core_role_directive` call, no trap/set preamble),
   confirmed against `stub-check.sh`'s own passing-fixture test case in
   `core/hooks/tests/run-role-gates-tests.sh` — stricter than a prose
   description in the core issue-66 record that mentioned keeping a
   trap/set pair; the actual script and its own test fixture were
   trusted over the prose.

4. **Role-specific difference: none needed.** The proposal's item 4
   assumed `record-fields-gate.sh`'s local `REQUIRED_FIELDS =
   [interview-script, per-interview-evidence-log, pain-verdict]` would
   need a `RECORD_FIELDS_TERMINAL_STATES`-style config override.
   Reading `core/hooks/record-fields-gate.sh` shows this assumption was
   wrong: core's generic gate does not read a per-role `produces` list
   at all — it enforces a fixed §20 field set (what-was-done, why,
   upstream-basis, `loop_state`, open-findings) for every role, with
   only `RECORD_FIELDS_TERMINAL_STATES` (default `landed`) as a
   per-role override knob. This role has no evidence anywhere in its
   current files of a non-`landed` terminal state, so no override was
   added — `hooks.json` needed no new `env` block, matching the
   proposal's own noted optimistic branch ("no additional config file
   is needed at all").

## `core/hooks/tests/stub-check.sh` result

Run against `user-discovery/` (this rulebook's plugin root) from the
core checkout above:

```
stub-check: ok — no vendored 'trailer-gate.sh' under .../user-discovery
stub-check: ok — no vendored 'record-fields-gate.sh' under .../user-discovery
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under .../user-discovery
stub-check: ok — no vendored 'parse-check.sh' under .../user-discovery
stub-check: ok — .../user-discovery/hooks/directive.sh is a role-directive stub
```

All five checks pass. Also functionally verified `directive.sh` end to
end (not just parsed): with `CLAUDE_ROLE=user-discovery` and
`CLAUDE_PLUGIN_ROOT_CORE` pointed at the core checkout, it emits the
same four role-unique lines plus the `RECORD:` line core generates; with
`USER_DISCOVERY_CYCLE_OFF=1` set it exits 0 silently — matching the
kill-switch behavior the old local heredoc had.

## What was deliberately not built

- A replacement pointer doc for `agents/warrant-hunter.md` — the
  proposal floated one as a possibility, but no other core-plugin
  reference in this rulebook (core/scout/terse/freelunch) has one
  either; adding one here would be new, unprecedented ceremony this
  role does not need.
- Any `RECORD_FIELDS_TERMINAL_STATES` override — confirmed unnecessary,
  see item 4 above.

## Open findings

None outstanding — all four proposal gaps were resolved by reading core
canon directly (see above), `stub-check.sh` passes cleanly, and the
stub was functionally exercised, not just parsed.

## Ordering constraint

Per the issue, this cutover was required to land before this repo's own
rulebook-maturation issue reaches phase 2. Recorded here for that
issue's phase-2 execution to check against.
