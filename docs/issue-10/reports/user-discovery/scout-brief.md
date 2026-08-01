# Scout brief — gate-lib.sh adoption pattern (issue-10)

Scope kept tight per handoff: this is an internal engineering fix (adopt
an already-landed shared library), not a product feature. Scouting done
by direct file reads/grep against the local checkout of `core` and this
repo — no external web research, since the standard is already landed
internally (core issue #72, confirmed merged to `main` at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`).

## Other adopters found

None. `core/hooks/lib/gate-lib.sh` itself documents that core's own seven
`core/hooks/*.sh` gates were migrated onto it as part of issue #72, and
the standard doc's "Per-repo migration checklist" describes 43 downstream
rulebook repos as the intended future adopters — but issue-72 explicitly
states "no retroactive fix to any of the 43 rulebooks' already-merged
gates happens in this repo — each rulebook's own A+ issue does that work."
No sibling rulebook repo's gates were available to compare against on
this machine at scouting time. **Falling back to the standard doc's own
prescriptions as the bar**, per the handoff's explicit fallback
instruction.

## Must-bes, read directly from `gate-house-standard.md`

1. Source `gate-lib.sh` from each gate script using the documented
   resolution idiom (`docs/handbooks/gate-house-standard.md` doesn't
   spell out the bash one-liner itself; `gate-lib.sh`'s own header
   comment, lines 11-19, is the canon usage snippet):
   ```bash
   . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh"
   gate_trap_fail_closed
   set -uo pipefail
   gate_kill_switch_active "${SOME_OFF:-}" || { trap - EXIT; exit 0; }
   ```
2. Load `gate-lib.py` from the gate's own Python heredoc payload via the
   `importlib.util.spec_from_file_location` pattern in `gate-lib.sh`'s
   header comment (lines 21-26), reading the path from the
   `GATE_LIB_PY` env var that `gate-lib.sh` exports (line 29) — not a
   hardcoded relative path, since the Python payload runs as a detached
   heredoc subprocess, not as a sourced file.
3. Reference only, never vendor a copy — `docs/handbooks/canon-scripts.md`
   is the reference-not-copy rule, and `stub-check.sh` (via
   `canon-manifest.txt`) is stated to catch a vendored copy of
   `gate-lib.sh`/`gate-lib.py`/`compliance-check.sh`.
4. Run `compliance-check.sh` before and after migration, per the "Per-repo
   migration checklist" (gate-house-standard.md §"Per-repo migration
   checklist", 5 steps): (1) run compliance-check.sh, record violations;
   (2) migrate flagged gates; (3) re-run own gate tests plus a
   repo-adapted copy of the six-case `run-gate-lib-tests.sh`; (4) re-run
   compliance-check.sh clean; (5) file the A+ issue citing the clean
   output. Step 5 is already done (this is that issue). Steps 1-4 are
   phase-2 execution, out of scope for this phase-1 proposal, but the
   proposal must commit to running them and must show what "clean" means
   for this repo's four gates.
5. Mandatory six-case test harness (`gate-house-standard.md`
   "Standard test harness"): `Edit`+`replace_all:true` against a
   multiply-occurring `old_string`; `MultiEdit` mixing `replace_all`
   true/false in one call; malformed JSON (truncated / non-object /
   empty); kill-switch set to an unrecognized value (must assert the gate
   **stays active**); absolute `file_path` matching the same scope as an
   existing relative fixture, plus a `./`-prefixed variant; a `Bash`-tool
   write reaching the same target a `Write` call would hit. The handoff's
   own mandatory-test list matches five of these six verbatim
   (Edit/MultiEdit/replace_all, malformed-JSON, kill-switch,
   absolute-path); the sixth (Bash-tool write detection) is not named in
   the issue text but is part of the standard's own harness, so the
   proposal includes it as a should-adopt rather than treating the
   issue's list as exhaustive.

## Adopt / skip decisions

**Adopt as-is (no redesign):**
- `gate_trap_fail_closed`, `gate_kill_switch_active`, `gate_deny`,
  `gate_allow` (bash) — replace this repo's four duplicated hand-rolled
  copies of each.
- `gate_parse_json_or_deny`, `gate_normalize_path`,
  `gate_reconstruct_write` (Python, via `GATE_LIB_PY`) — replace this
  repo's four duplicated copies of JSON-parse-or-deny, path resolution,
  and `Write`/`Edit`/`MultiEdit` reconstruction.
- `gate_bash_write_targets` — not currently used by any gate in this
  repo; adopt it as a new capability (see proposal) so a `Bash`-tool
  write to a gated path is no longer invisible, matching the standard's
  sixth mandatory test case.

**Skip / do not reimplement:**
- No new shared-library code for this repo. The four gates become thin
  callers of `gate-lib.sh`/`gate-lib.py`, not a reimplementation of any
  function gate-lib already provides.

**Not covered by gate-lib — this repo's own design work required:**
- Semantic-check upgrade (substring → section/adjacency/structure), since
  gate-house-standard.md's six classes are mechanical/structural
  (trap, kill-switch, JSON, path, reconstruction, deny-protocol), not
  content-judgment. Confirmed by reading gate-lib.sh's function list in
  full — no semantic/NLP-shaped function exists there.
- The state-update-timing fix for `.state.json` (§2.1 of the survey) —
  gate-lib has no PostToolUse or cross-gate coordination primitive; this
  is `user-discovery-hypothesis-order`'s own plugin-specific bug.

## Gap line: standard requirements already met vs. missed, per gate

All four gates currently:
- MEET: trap-at-top (hand-rolled but present), malformed-JSON deny
  (hand-rolled but present), deny-to-stderr (already correct).
- MISS: kill-switch fail-closed-on-unrecognized-value (all four have the
  pre-issue-72 inverted idiom), `replace_all` honoring on `Edit`/
  `MultiEdit` (all four hardcode `count=1`), sourcing any shared library
  at all (all four are fully duplicated, zero-adoption today),
  `Bash`-tool write-target detection (not implemented by any gate),
  the standard's own six-case test harness (none of the four
  `tests/run-*-gate-tests.sh` files test `replace_all`, malformed JSON as
  a distinct case, kill-switch-unrecognized-value, or absolute/`./`-path
  fixtures today — confirmed by reading `run-hypothesis-order-gate-tests.sh`
  in full, five cases total, none matching the standard's six).

Net: adoption is a subtraction (delete ~40 duplicated lines ×4 gates,
replace with `gate-lib.sh`/`gate-lib.py` calls), not an addition, for
every defect class gate-lib covers. The two defects gate-lib doesn't
cover (semantic checks, state-timing) are this repo's own scoped design
work, detailed in the proposal.
