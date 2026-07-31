# issue-7 phase-1 survey: current-state of the user-discovery plugin's enforcement surface

Subject: issue-7. Scope: what this role's plugin enforces mechanically
today (not what it says in prose), so the proposal can name exact gaps
against the implementation-rulebook bar the issue cites, instead of
guessing. Builds on `docs/issue-1/reports/user-discovery/survey.md`
(issue-1's inventory) — this survey only covers what changed or is newly
relevant since then.

## What issue-1/phase-2 actually landed (commit 46ee001)

| Path | Contents today |
|---|---|
| `user-discovery/.claude-plugin/plugin.json` | `produces: ["interview-script", "per-interview-evidence-log", "pain-verdict"]` — a flat array of three strings, no sub-structure. |
| `user-discovery/hooks/directive.sh` | Sources `core/hooks/lib/role-directive.sh`, calls `core_role_directive` with 4 flat string args (YOU DECIDE / USE WHEN / PRODUCES / HAND-OFF). The `PRODUCES` string is one sentence listing sub-requirements as prose ("a stated falsifiable hypothesis + disconfirming answer per question line", "an evidence-strength tag per claim", etc.) — readable to a human, unenforceable by a machine. |
| `user-discovery/hooks/hooks.json` | `SessionStart` → `directive.sh` only. No `PreToolUse` entries at all. |
| (no local gates, no `agents/`, no `tests/`) | Confirmed absent by direct listing. |

## What core canon provides today (read directly from `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`, per this issue's own constraint — reference only, nothing here is copied into this rulebook)

- `core/hooks/record-fields-gate.sh` — a generic PreToolUse gate, registered per `CLAUDE_ROLE`, that checks any role's own record
  (`docs/issue-<n>/reports/<role>.md`) for contract §20's five generic
  fields (what-was-done, why, upstream-basis, `loop_state`, open-findings)
  plus next-steps/resolution-path when `loop_state` is non-terminal. It
  has **no knowledge of this role's `produces` sub-structure** — it
  cannot check for a falsifiable-hypothesis line, an evidence-strength
  tag, or a prevalence count, because those are role-specific, not
  contract-generic. This confirms issue-1's own survey's open question:
  core's generic gate reads §20 fields only; it does not read a role's
  `produces` array for domain-specific required elements.
- `core/hooks/lib/role-directive.sh` — `core_role_directive` takes
  exactly 4 positional string args and prints them verbatim under a
  fixed banner. It has **no phase parameter** (phase-1 vs phase-2) and
  **no facet/sub-structure parameter** — a rulebook cannot ask it to
  print "phase-1 stops after the script+ladder; phase-2 requires the
  evidence log" differently from a single flat PRODUCES string.
  Confirmed by direct read; this is a hard constraint on what
  `directive.sh` alone can express — deepening the *directive text* is
  possible (a longer PRODUCES string with more of the norm spelled out),
  but it cannot become phase-aware through this function signature
  without either (a) still packing everything into one string per phase
  the caller manually swaps, or (b) core landing a new signature (out of
  this issue's scope — this issue works within core's current shape).
- `docs/handbooks/canon-scripts.md` — the binding constraint this issue
  names explicitly: canon scripts (`core/hooks/*.sh`,
  `core/hooks/tests/*.sh`) are referenced by path, never vendored into a
  rulebook's own tree. `core/hooks/tests/stub-check.sh` mechanically
  fails any rulebook whose tree contains a copy of a manifest-listed
  core file (`core/hooks/tests/canon-manifest.txt`).

## Sibling rulebooks already at the bar this issue asks for (read directly, referenced not copied)

- `pricing-rulebook/pricing/hooks/methodology-gate.sh` (~200 lines) — a
  **role-owned** PreToolUse gate, layered *on top of* (never instead of)
  core's generic `record-fields-gate.sh`, that targets this role's own
  write surfaces (`docs/issue-<n>/proposals/*pricing*.md` and
  `docs/issue-<n>/reports/pricing.md`) and greps the proposed resulting
  content for that domain's own required elements (method named, family
  named, inputs stated, gate-check result present, labeled numbers,
  residual list). Structurally: resolve target path → confirm it's this
  role's write surface → reconstruct new content from Write/Edit/
  MultiEdit tool_input → substring-check required elements → fail closed
  on internal error. This is the exact shape issue-7 item 2 asks for,
  generalized from prose-array `produces` to grep-checkable elements.
- `implementation-rulebook/coding/hooks/hunt-state.sh` +
  `hunt-guard.sh` — a small persisted-state file (JSON under
  `.claude/state` or similar, read via env-resolved root) that tracks a
  sequence of named stages and denies a later-stage action until an
  earlier-stage marker is present. This is the concrete mechanism
  available for issue-7's "방법론상 순서 제약이 있으면 상태 추적으로
  강제" clause — not something to copy (it is coding-role-specific
  wording), but the state-file-plus-gate-check *shape* transfers.
- `core/hooks/tests/run-role-gates-tests.sh` — the test-harness shape:
  a pure-bash test runner, no framework dependency, invokes the gate as a
  real subprocess with a crafted JSON payload on stdin and asserts exit
  code (0 = allow, 2 = deny) plus a role-labeled message prefix. This is
  the pattern issue-7 item 3 (게이트 테스트) should follow, placed under
  this repo's own `tests/` per contract's root-tests convention (already
  used by `implementation-rulebook/tests/run-gate-tests.sh`).

## Gaps this survey leaves for the proposal to resolve explicitly

- Exactly which sub-elements of each of the three `produces` entries are
  mechanically checkable via substring/regex grep on proposed file
  content (cheap, mirrors pricing's approach) vs. which require actual
  state tracking across multiple writes (the ordering constraint:
  hypothesis-before-interview, interview-before-evidence-log,
  evidence-log-before-verdict) — named in the proposal, not resolved
  here.
- Whether this role needs a `RECORD_FIELDS_TERMINAL_STATES` override
  (issue-1's survey flagged this as likely "no" — this role has no
  distinct terminal `loop_state` beyond core's default `landed`); this
  survey does not find any reason to revisit that conclusion.
- Whether an `insufficient-evidence` third verdict state (raised as an
  open question in issue-1's proposal section (d), never resolved) should
  be decided in this issue or deferred again — named as a decision point
  in the proposal, not decided in this survey.
