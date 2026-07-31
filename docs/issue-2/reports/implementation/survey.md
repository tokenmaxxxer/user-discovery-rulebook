# issue-2 phase-1 survey: current-state of role-copied canon surfaces

Subject: issue-2. Scope: the five work items in the issue body — inventory
what exists in this repo today, so the proposal can name exact deletions
and exact stub contents instead of guesses.

## Scout-gate skip record

Scouting (per scout-directive) is skipped for this pass. Reason: the task
is a pointer-cutover to a named upstream artifact (core canon, core issues
#63/#66) that lives in a separate repo not checked out here — there is no
external field of comparable products to sweep; the only "exemplar" is the
core repo itself, and this repo cannot reach it (no network fetch target
was given, no local checkout exists). The design space is fixed by the
issue's five numbered items, not open to product-style discovery. This
satisfies the "spec leaves no [product-style] design decision open" skip
condition for the exemplar-sweep stage specifically; the decisions that
remain (exact stub shape, which fields differ per role) are resolved by
reading this repo's own files below, not by scouting.

## Inventory: files this repo owns today

| Path | Role in current setup | Disposition per issue item |
|---|---|---|
| `user-discovery/agents/warrant-hunter.md` | Local copy of the warrant-hunter agent, adapted (per its own text) from `implementation-rulebook`'s copy. Declares a stance-rotation mandate, scoped to this role's decision boundary. | Item 1: remove; replace with a canon reference (core `warrant/` plugin, core issue #63). |
| `user-discovery/hooks/trailer-gate.sh` | PreToolUse gate on `Bash` matching `git commit`. Self-describes as "role-agnostic" logic adapted from implementation-rulebook, role name substituted only. Registered in `hooks.json`. | Item 2: remove file + its `hooks.json` entry; core-side registration (core issue #66) takes over. |
| `user-discovery/hooks/record-fields-gate.sh` | PreToolUse gate on `Write\|Edit\|MultiEdit\|NotebookEdit`. Role-specific: enforces `REQUIRED_FIELDS = ["interview-script", "per-interview-evidence-log", "pain-verdict"]` against `docs/issue-<n>/reports/user-discovery.md`. Registered in `hooks.json`. | Item 2 removes the copy + registration; item 4 must re-home the role-specific `REQUIRED_FIELDS` list (this role's genuine difference) as `RECORD_FIELDS_TERMINAL_STATES`-style explicit config so core's generic gate can still enforce it. |
| `user-discovery/hooks/handbook-trigger-gate.sh` | PreToolUse gate on `Bash`. Currently an explicit placeholder: `exit 0  # placeholder verdict — TODO before this repo is treated as load-bearing`. Registered in `hooks.json`. | Item 2: remove file + registration; core-side registration takes over. No role-specific logic to preserve — the file never implemented one. |
| `user-discovery/hooks/directive.sh` | SessionStart hook. Emits the full role directive text inline (YOU DECIDE / USE_WHEN / PRODUCES / WRITE_SCOPE / HAND-OFF / BOUNDARY CASE / RECORD), with no shared-boilerplate sourcing — this is the "copy" item 3 targets. | Item 3: replace with a stub that sources `core/hooks/lib/role-directive.sh`'s `core_role_directive` function and calls it, keeping only the role-unique fields inline. |
| `user-discovery/hooks/hooks.json` | Registers all four hooks above (SessionStart → directive.sh; PreToolUse → record-fields-gate.sh, handbook-trigger-gate.sh, trailer-gate.sh). | Items 2–3: once the three gate copies are deleted and core-side registration takes over, this file's PreToolUse block empties out; SessionStart entry stays (directive.sh remains, just stubbed). |
| `user-discovery/.claude-plugin/plugin.json` | Plugin manifest: name, description (embeds YOU DECIDE/USE_WHEN/HAND-OFF text), author. No hook/agent path list — Claude Code auto-discovers `agents/` and `hooks/hooks.json` by convention. | No item targets this directly; unaffected by the cutover except that its description text should stay consistent with whatever directive.sh keeps inline. |
| `docs/specs/approvers.md` | Empty (no logins populated yet). | Not in scope; noted because phase-2 (execution) cannot open in single-account mode until this is populated — separate from issue-2's work. |

## What is NOT available to inspect from this repo

- The actual core `warrant/` plugin (core issue #63) and its invocation
  contract (how a role-scoped rulebook is expected to reference it —
  a plugin dependency line, a doc pointer, or something else).
- `core/hooks/` registration mechanics for the three gates (core issue
  #66) — specifically how `CLAUDE_ROLE` injection is wired and whether
  role-specific config (like this role's `REQUIRED_FIELDS`) is read from
  a file, an env var, or a role manifest key.
- `core/hooks/lib/role-directive.sh`'s `core_role_directive` function
  signature — its exact argument order/names for YOU DECIDE / USE_WHEN /
  PRODUCES / WRITE_SCOPE / HAND-OFF / BOUNDARY CASE / RECORD.
- `core/hooks/tests/stub-check.sh` — its existence is asserted by the
  issue (item 5) but its invocation form (path, expected args, pass/fail
  contract) is unknown from here.

These four gaps are the reason this PR stops at phase 1: the concrete
diff (stub `directive.sh` calling `core_role_directive`, the exact
`RECORD_FIELDS_TERMINAL_STATES`-equivalent config key name, the exact
`hooks.json` shape after core-side registration) cannot be written
correctly without reading the actual core canon files, which this
environment cannot reach (no core repo checkout, no fetch target named
by the user). The proposal below states assumptions explicitly where it
must guess, flagged as such, and defers to core canon's actual shape at
phase-2 time.
