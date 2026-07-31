# Proposal: mechanize the adopted user-discovery methodology (issue-7)

Phase-1 proposal only — no execution. Approve on issue-7/user-discovery
(per `docs/specs/approvers.md` and contract v3 s19) opens phase 2, where
this plan is carried out on the same branch. See
`docs/issue-7/reports/user-discovery/survey.md` (current-state inventory
of this plugin's and core canon's actual enforcement surface) and
`docs/issue-7/reports/user-discovery/scout-brief.md` (exemplar gates
read, adopt/skip decisions) for the evidence this proposal is built
from. This proposal follows the proposal-norm codified in
`docs/issue-1/proposals/user-discovery-methodology.md` section (a):
opening framing line, preceding survey cited, numbered self-contained
sections, `**Gap:**` flags where exact wording depends on something to
be confirmed at phase-2 start, sourced evidence for methodology claims.

Nothing here proposes vendoring any `core/hooks/*` file into this
rulebook's tree. Per `docs/handbooks/canon-scripts.md` (read directly
from core canon, referenced not copied here): every script this
proposal calls for is role-owned, new content specific to this role's
own `produces`, invoked alongside — never replacing — core's generic
`record-fields-gate.sh` and `role-directive.sh`. Role boundaries and
`write_scope` (report-only; this role writes only its own phase-1/
phase-2 docs) stay exactly as issue-2 and issue-1 phase-2 already landed
them.

## 1. Directive deepening — phase-1 and phase-2, per facet, no one-line summaries

**Current state** (survey §"What issue-1/phase-2 actually landed"):
`directive.sh` calls `core_role_directive` with one flat `PRODUCES`
string covering both phases at once. `core_role_directive`'s signature
is fixed at 4 positional args (survey, confirmed by direct read of
`core/hooks/lib/role-directive.sh`) — this proposal does not ask core to
change that signature (out of scope, role boundaries unchanged); it
proposes making the `PRODUCES` argument itself phase-aware and
facet-explicit, which the existing signature already permits (it is
just a string).

**Proposed change**: `directive.sh` computes which phase the session is
in — **Gap (blocks exact detection mechanism):** the concrete signal for
"is this session phase-1 or phase-2" is not yet confirmed from this
proposal's vantage point. Candidates to check at phase-2 start, in
order: (a) whether `docs/issue-<n>/reports/user-discovery.md` exists yet
on this branch (its absence = phase-1, per contract v3 s19's own
statement that the record "is phase-2 output like code" and "waits for
the Approve too"); (b) an env var core's own directive/approval-gate
machinery may already set per session state. Resolve by reading
`core/hooks/approval-gate.sh` and `core/hooks/board-gate.sh` at phase-2
start before committing to one. — then passes one of two PRODUCES
strings:

- **Phase-1 PRODUCES text** (this session may only write
  `docs/issue-<n>/reports/user-discovery/{survey,scout-brief}.md` and
  `docs/issue-<n>/proposals/*.md`): spells out, per facet —
  - *Steps*: current-state survey → scout sweep (per the scout
    directive already active session-wide) → proposal, in that order —
    a proposal with no survey path cited is not phase-1-complete.
  - *Judgment criteria*: every adopted technique in the proposal must
    cite a real, checkable source or be labeled `[assumption]` (the
    evidence-honesty norm `user-discovery-methodology.md` section (a)
    rule 4 already established for this role's own proposals — this
    directive text now states it inline instead of only in a doc a
    session might not open).
  - *Prohibitions*: no phase-2 artifact write (`reports/user-discovery.md`)
    before Approve; no pitching-style interview questions proposed as
    primary script content (Mom Test discipline, already adopted,
    restated here as a directive-level prohibition, not just doc prose).
- **Phase-2 PRODUCES text** (session may now also write
  `docs/issue-<n>/reports/user-discovery.md` and, per this role's
  `produces` array, the three deliverables): spells out, per facet —
  - *Interview script*: every question line carries a stated falsifiable
    hypothesis + disconfirming answer; a follow-up ladder per
    hypothesis (when did this last happen → what did you do → did you
    spend money/time → what happened next); no pitch before behavioral
    questions are exhausted.
  - *Evidence log*: one entry per interview; evidence-strength tag per
    claim (`behavioral`|`recounted`|`opinion`); prompted/unprompted flag
    per theme; running saturation count.
  - *Verdict*: `pain-confirmed`|`not-confirmed`|`insufficient-evidence`
    (see item 4's decision on the third state) with cited log-entry
    references, stated prevalence (N of M), and any contradicting
    evidence named rather than dropped.
  - *Judgment criteria*: a verdict resting only on `opinion`-tier
    evidence must not read `pain-confirmed` (this is the exact rule the
    methodology gate in item 2 also mechanizes — the directive states
    it in prose so a session sees it before writing, the gate catches it
    if the prose was missed).
  - *Prohibitions*: no verdict with zero cited log entries; no evidence
    log entry with no evidence-strength tag.

This keeps `core_role_directive`'s call signature exactly as-is (4
positional strings) — only the *content* of the 3rd argument changes,
and it changes per phase via a shell conditional in this role's own
`directive.sh`, which already has role-specific plumbing (the
`USER_DISCOVERY_CYCLE_OFF` check) living in the stub per issue-2's
already-landed cutover.

## 2. Methodology gate — mechanically verify required `produces` elements

**Current state** (survey): core's generic `record-fields-gate.sh`
checks contract §20's five generic fields on any role's own record; it
has no knowledge of this role's three-item `produces` array's internal
sub-structure. No role-owned `PreToolUse` gate exists in this repo at
all (confirmed absent, issue-1 survey and this survey both).

**Proposed change**: add `user-discovery/hooks/methodology-gate.sh`, a
new role-owned PreToolUse gate (registered in `hooks.json` alongside
`directive.sh`'s existing `SessionStart` entry, as a new `PreToolUse`
block matching `Write|Edit|MultiEdit`), modeled on
`pricing-rulebook/pricing/hooks/methodology-gate.sh`'s shape (read
directly, referenced not copied — every line of actual content below is
this role's own, not lifted text):

- **Targets**: `docs/issue-<n>/reports/user-discovery.md` (phase-2
  record) and `docs/issue-<n>/proposals/*.md` whose content, once
  resolved, is this role's own proposal — same path-ownership check
  pricing's gate uses (resolve target, confirm under project root,
  regex-match this role's write surface, exit 0 immediately if it isn't
  — "not this gate's business").
- **Content reconstruction**: same three-tool-type handling
  (`Write`'s `content`, `Edit`'s old/new-string substitution,
  `MultiEdit`'s edit-list fold) as both exemplar gates, denying with a
  specific "cannot determine resulting content" message when none of
  the three apply cleanly — this axis was scout-brief's flagged
  performance axis #1 (content-reconstruction correctness).
- **Required elements checked** (substring/regex on the reconstructed
  text, mirroring pricing's has_any()-per-element pattern), scoped to
  which of the three `produces` entries the target file is expected to
  contain:
  - On `docs/issue-<n>/reports/user-discovery.md` (phase-2 record,
    expected to reference or embed all three deliverables per this
    role's `produces`):
    1. a falsifiable-hypothesis marker per question line, or an explicit
       statement that the interview script is attached/referenced
       elsewhere with hypotheses stated there — **Gap:** exact phrasing
       heuristic (what substring counts as "a hypothesis is stated")
       needs the actual first real record instance to calibrate against
       false negatives, same caveat pricing's own gate accepted for its
       six elements; phase-2 execution should draft the heuristic
       against a real first-draft record, not guess it here.
    2. an evidence-strength tag vocabulary hit
       (`behavioral`|`recounted`|`opinion`) somewhere in the log content.
    3. a prevalence marker (regex for "N of M" or "of N interviews" or
       equivalent digit-plus-interview-count pattern) when the verdict
       states `pain-confirmed` or `not-confirmed`.
    4. a residual/contradiction marker when contradicting evidence
       exists in the log (mirrors pricing's "residual" element,
       role-adapted: "what does not confirm" rather than "what this
       cannot answer" — this role's own residual concept per
       `user-discovery-methodology.md` section (b)'s "must note
       contradicting evidence" rule).
    5. a stated `loop_state` (already covered by core's generic gate —
       this gate does **not** re-check §20 fields; it only adds the
       domain elements core's generic gate structurally cannot know).
  - On `docs/issue-<n>/proposals/*.md` (phase-1 proposal): the
    survey-path-cited rule (item 1's phase-1 judgment criterion) —
    checked as "does this text contain a `docs/issue-<n>/reports/
    user-discovery/` path substring" — plus the `[assumption]`-labeling
    rule for unsourced methodology claims (checked as: if a "Source:" or
    URL-looking substring is absent from a paragraph making a citation-
    shaped claim, this is a **soft** check — **Gap:** whether this is
    grep-enforceable at all without false-positiving on ordinary prose
    is genuinely uncertain; scout-brief's skip list already rejected a
    full parser for this reason. Recommend phase-2 implement only the
    survey-path-cited check as a hard gate element, and treat the
    `[assumption]`-labeling rule as directive-text-only (item 1), not
    gate-enforced, rather than build a heuristic likely to misfire.
- **Fail-closed, kill-switched**: `USER_DISCOVERY_METHODOLOGY_GATE_OFF=1`
  env var kill switch; `trap` + `except Exception` fail-closed wrapper —
  both patterns read directly from
  `core/hooks/record-fields-gate.sh` and pricing's gate, applied here as
  this role's own new script, not copied text.

## 3. State tracking for the methodology's one real ordering constraint

**Current state**: no ordering enforcement exists anywhere in this
plugin today. The methodology this role adopted (issue-1) does have one
genuine sequential constraint: falsifiable hypotheses must be stated
*before* interviews are logged against them (Blank/Ries discipline — a
hypothesis discovered after the fact by pattern-matching the log is not
a validated hypothesis, it is a post-hoc story), and the verdict must
cite log entries that exist *before* the verdict is written (a verdict
cannot cite evidence it precedes). This is the "조사→근거→채택" shape the
issue names, applied to this role's own methodology rather than a
literal copy of another role's stage names.

**Proposed change**: a small persisted marker,
`.claude/user-discovery-state.json` (path pattern mirrors
`implementation-rulebook`'s `hunt-state.sh` persisted-state shape, read
directly and referenced not copied — the actual keys and values below
are this role's own), tracking three booleans:
`hypotheses_stated`, `evidence_logged`, `verdict_written`. The
methodology gate (item 2) sets `hypotheses_stated=true` the first time a
Write/Edit to the record content contains a recognized hypothesis
marker, sets `evidence_logged=true` the first time an evidence-strength
tag appears, and **denies** any write whose content contains a verdict
marker (`pain-confirmed`|`not-confirmed`|`insufficient-evidence`) while
`evidence_logged` is still false — the one place a hard sequential
denial is warranted, because a verdict with zero preceding logged
evidence is exactly the "gut call reported as validated" failure mode
issue-1's proposal named as the reason Customer Development's discipline
was adopted in the first place. **Gap:** whether this state file should
live under `.claude/` (session-local, matches `hunt-state.sh`'s
convention) or under `docs/issue-<n>/` (branch-durable, survives across
sessions on the same branch, which a single interview round spanning
multiple sessions would need) is unresolved here — recommend
`docs/issue-<n>/reports/user-discovery/.state.json` (branch-durable,
same tree the record itself lives in) unless phase-2's read of
`hunt-state.sh` shows a specific reason session-locality is required.

## 4. Gate tests — repo-root `tests/`, pass and deny cases

**Current state**: no `tests/` directory exists in this repo at all
(confirmed absent). `core/hooks/tests/run-role-gates-tests.sh` and
`implementation-rulebook/tests/run-gate-tests.sh` (both read directly)
establish the pattern: pure-bash runner, no test framework, invoke the
gate script as a real subprocess with a crafted JSON payload on stdin,
assert exit code (0=allow, 2=deny) and a role-labeled deny-message
prefix.

**Proposed change**: `tests/run-methodology-gate-tests.sh` at this
repo's root, following that exact invocation shape, covering at minimum:

- Record write missing all three domain elements → deny, message names
  the missing elements.
- Record write with hypothesis + evidence-strength tags + prevalence +
  residual-note, `loop_state: landed` → allow.
- Verdict marker present with `evidence_logged` still false in the
  persisted state (item 3) → deny, message states the ordering
  violation specifically (not a generic "missing element" message).
- Proposal write with no survey-path substring → deny.
- Proposal write citing the survey path → allow (assuming other §20-
  independent elements also present).
- Non-owning-role write (e.g. a `docs/issue-<n>/reports/pricing.md`
  write happening to be in the same tool-call batch) → allowed
  (gate exits 0 immediately, "not this gate's business" — mirrors the
  existing test case in `run-role-gates-tests.sh` for
  `record-fields-gate.sh`).
- `USER_DISCOVERY_METHODOLOGY_GATE_OFF=1` → allow regardless of content
  (kill-switch test, same shape as `TRAILER_GATE_OFF` test in core's
  suite).

## 5. Agents / checklist — the per-interview repeated procedure

**Current state**: no `agents/` directory, no checklist artifact exists.
issue-1's proposal explicitly ruled out reintroducing a local
`warrant-hunter.md` (core canon owns that). This issue's own scope is
narrower: not a hunt agent, but the **repeated per-interview procedure**
the methodology requires (tag each claim, flag prompted/unprompted,
update the saturation count) — a checklist, not an agent, since there is
no adversarial-verification role here to delegate to.

**Proposed change**: `docs/handbooks/user-discovery/per-interview-checklist.md`
(handbooks bucket, per contract's standing-buckets layout — this is
reusable procedure, not a per-issue artifact), a short numbered
checklist a session runs once per logged interview:

1. Before the interview: which hypothesis/hypotheses does this session
   address? (must already be stated per item 3's ordering constraint.)
2. During: ask past-behavior questions only until exhausted; no pitch.
3. After, per claim logged: tag `behavioral`|`recounted`|`opinion`;
   flag prompted/unprompted.
4. After: update the running saturation count (new-themes-this-round);
   note if this round crossed a heuristic threshold (~6 interviews in a
   homogeneous sample per Guest/Bunce/Johnson 2006, already sourced in
   `user-discovery-methodology.md` section (c) — restated here as a
   checklist trigger, not a hard stop).
5. Only once evidence is logged: consider whether a verdict can be
   drafted (gate-enforced per item 3 — the checklist states the same
   rule as a procedural reminder, gate is the actual enforcement).

This is a checklist a human/session follows, not a machine gate — it
composes with, but does not duplicate, item 2's mechanical checks.

## Open decision for phase-2/human review (not decided here)

- Whether the verdict enum gains a third `insufficient-evidence` state
  (raised, unresolved, in issue-1's own proposal section (d)) — this
  proposal's item 1 phase-2 PRODUCES text and item 2's verdict-marker
  list already assume the answer is yes, since a gate that only
  recognizes a binary enum cannot flag a verdict resting on
  `opinion`-tier evidence as anything but a forced binary choice. If
  phase-2/human review decides no, item 1 and item 2's verdict-marker
  lists drop the third state; nothing else in this proposal depends on
  which way this resolves.
