# Proposal: mechanize the adopted user-discovery methodology as a plugin set (issue-7)

Phase-1 proposal only — no execution. Approve on issue-7/user-discovery
(per `docs/specs/approvers.md` and contract v3 s19) opens phase 2, where
this plan is carried out on the same branch. See
`docs/issue-7/reports/user-discovery/survey.md` (current-state inventory)
and `docs/issue-7/reports/user-discovery/scout-brief.md` (exemplar gates
read, adopt/skip decisions) for the evidence this proposal is built
from.

**Revision note**: this replaces the prior draft's single
directive-deepening-plus-one-gate design per the approver's structural
correction on issue #7 (`요구 정정` comment): enforcement is organized as
a **plugin set**, not one hardened role stub. Each adopted methodology
facet becomes its own independent, self-contained plugin (own
`.claude-plugin/plugin.json`, own `hooks.json`, own gate script(s), own
tests — the shape `core`'s `freelunch`/`scout` plugins already
establish, read directly from this repo's `.claude-plugin/marketplace.json`
registration pattern). Phase-1 (기획서) norm and phase-2 (산출물) norm are
each *defined as* a specific combination of these plugins, stated
explicitly in §5 — not left implicit in role-stub prose.

## 0. Plugin roster (required)

| Plugin (dir/marketplace name) | Methodology owned | Components | Phase(s) it applies to |
|---|---|---|---|
| `user-discovery-proposal-norm` | Phase-1 proposal quality: survey-first, sourced-or-labeled evidence (from `docs/issue-1/proposals/user-discovery-methodology.md` §a) | `directive.sh` (phase-1 PRODUCES text), `hooks/proposal-norm-gate.sh` (survey-path-cited check on `docs/issue-<n>/proposals/*.md`), `tests/run-proposal-norm-gate-tests.sh` | Phase 1 |
| `user-discovery-hypothesis-order` | Customer Development ordering discipline: hypotheses before interviews, evidence before verdict (Blank/Ries) | `hooks/hypothesis-order-gate.sh` (denies verdict marker while `evidence_logged=false`), `.state` tracking (`hypotheses_stated`/`evidence_logged`/`verdict_written`), `tests/run-hypothesis-order-gate-tests.sh` | Phase 2 |
| `user-discovery-evidence-tagging` | Mom Test discipline: behavioral/recounted/opinion tagging, no pitching before behavioral questions exhausted | `hooks/evidence-tagging-gate.sh` (tag-vocabulary check on the evidence log), `handbooks/user-discovery/per-interview-checklist.md` (steps 2–3), `tests/run-evidence-tagging-gate-tests.sh` | Phase 2 |
| `user-discovery-saturation` | Prevalence + contradicting-evidence + saturation threshold (Guest/Bunce/Johnson 2006, already sourced in `user-discovery-methodology.md` §c) | `hooks/saturation-gate.sh` (prevalence marker + residual/contradiction marker on the verdict), `handbooks/user-discovery/per-interview-checklist.md` (step 4), `tests/run-saturation-gate-tests.sh` | Phase 2 |

Each plugin registers as its own entry in `.claude-plugin/marketplace.json`
alongside the existing `user-discovery` role plugin — mirroring how a
rulebook can carry several independently-loadable plugins (the pattern
`core` already uses for `freelunch`/`scout`, read directly from that
repo, not copied). Each plugin's `plugin.json` states its single owned
methodology in its `description` field, matching the "clear single
methodology per plugin" requirement.

**Gap:** whether these four load as *separate* Claude Code plugins (each
with independently toggleable `hooks.json`) or as one `user-discovery`
plugin directory containing four self-contained subdirectories under a
shared `hooks.json` that dispatches to each gate script in sequence is a
mechanical packaging choice this proposal does not resolve — both satisfy
"self-contained, single-methodology, listed in the roster." Recommend
phase-2 read how `core`'s `freelunch` and `scout` are actually packaged
(separate `.claude-plugin/plugin.json` each, per this repo's own
`marketplace.json` shape already showing one entry per plugin) and match
that, since the issue names that pattern explicitly as the bar.

## 1. `user-discovery-proposal-norm` — phase-1 proposal quality

**Current state** (survey §"What issue-1/phase-2 actually landed"):
`directive.sh` calls `core_role_directive` with one flat `PRODUCES`
string covering both phases. No role-owned `PreToolUse` gate exists
anywhere in this repo (confirmed absent, issue-1 survey and this survey
both).

**Owned methodology**: the evidence-honesty and survey-first norm
`user-discovery-methodology.md` §a already established for this role's
own proposals (rule 4: every adopted technique cites a real source or is
labeled `[assumption]`; a proposal with no survey path cited is not
phase-1-complete).

**Components**:
- *Directive*: phase-1 PRODUCES text states the order (survey → scout →
  proposal) and the sourcing rule inline, so a session sees it before
  writing, not only in doc prose it might not open.
- *Gate* (`hooks/proposal-norm-gate.sh`, new `PreToolUse` on
  `Write|Edit|MultiEdit`, path-scoped to `docs/issue-<n>/proposals/*.md`
  only — exits 0 immediately on any other path, "not this plugin's
  business," same convention pricing's gate uses): denies a proposal
  write whose reconstructed content contains no
  `docs/issue-<n>/reports/user-discovery/` path substring (the
  survey-path-cited rule, hard-enforced). The `[assumption]`-labeling
  rule stays directive-text-only, **not** gate-enforced — scout-brief's
  skip list already rejected a full-parser heuristic for this as likely
  to misfire on ordinary prose; a substring check for citation-shaped
  claims with no way to distinguish false positives is not worth
  building. This is this plugin's one deliberate skip, stated rather
  than silently dropped.
- *Tests*: pass (proposal citing survey path), deny (proposal with none),
  allow (non-owning-role write in the same batch, gate exits 0).

## 2. `user-discovery-hypothesis-order` — ordering discipline

**Current state**: no ordering enforcement exists anywhere in this
plugin today.

**Owned methodology**: the one genuine sequential constraint the adopted
methodology carries (issue-1): falsifiable hypotheses stated *before*
interviews are logged against them (a hypothesis discovered after the
fact by pattern-matching the log is a post-hoc story, not a validated
one), and the verdict must cite log entries that exist *before* the
verdict is written.

**Components**:
- *State*: `docs/issue-<n>/reports/user-discovery/.state.json` (branch-
  durable — recommended over `.claude/`-session-local so a single
  interview round spanning multiple sessions on the same branch does not
  lose state; mirrors `implementation-rulebook`'s `hunt-state.sh` shape,
  read directly, not copied), three booleans: `hypotheses_stated`,
  `evidence_logged`, `verdict_written`.
- *Gate* (`hooks/hypothesis-order-gate.sh`, `PreToolUse` on
  `Write|Edit|MultiEdit`, path-scoped to
  `docs/issue-<n>/reports/user-discovery.md`): sets
  `hypotheses_stated=true` on first recognized hypothesis marker, sets
  `evidence_logged=true` on first evidence-strength tag, **denies** any
  write whose content contains a verdict marker
  (`pain-confirmed`|`not-confirmed`|`insufficient-evidence`) while
  `evidence_logged` is still false — the one hard sequential denial in
  this whole plugin set, because a verdict with zero preceding logged
  evidence is exactly the "gut call reported as validated" failure mode
  issue-1's proposal named as the reason Customer Development discipline
  was adopted at all. Content reconstruction handles all three tool
  types (`Write` content, `Edit` old/new-string, `MultiEdit` fold),
  denying with a specific "cannot determine resulting content" message
  otherwise — scout-brief's flagged performance axis #1.
- *Tests*: verdict marker with `evidence_logged=false` → deny, ordering-
  specific message (not a generic "missing element" message); verdict
  after evidence logged → allow; kill switch
  `USER_DISCOVERY_HYPOTHESIS_ORDER_GATE_OFF=1` → allow regardless.
- Fail-closed, kill-switched: `trap` + exception-wrapper pattern read
  directly from `core/hooks/record-fields-gate.sh` and pricing's gate,
  applied as this plugin's own new script.

## 3. `user-discovery-evidence-tagging` — Mom Test discipline

**Current state**: no evidence-tag enforcement or checklist exists.

**Owned methodology**: evidence-strength tagging
(`behavioral`|`recounted`|`opinion`) and the no-pitch-before-behavioral-
exhausted rule already adopted in `user-discovery-methodology.md`.

**Components**:
- *Gate* (`hooks/evidence-tagging-gate.sh`, same path scope and tool
  handling as §2's gate, independently registered and independently
  toggleable): denies a record write with no evidence-strength tag
  vocabulary hit anywhere in the log content.
- *Checklist* (`docs/handbooks/user-discovery/per-interview-checklist.md`
  steps 2–3, handbooks bucket per contract's standing-buckets layout —
  reusable procedure, not per-issue): ask past-behavior questions only
  until exhausted, no pitch; tag each claim, flag prompted/unprompted.
  Procedural reminder — the gate is the actual enforcement for the tag
  presence; the no-pitch rule itself is not mechanically gate-checkable
  (content-judgment, not substring-checkable) and stays checklist-only,
  stated as such rather than claimed as gated.
- *Tests*: record with tag vocabulary present → allow; record with none
  → deny, message names the missing tag axis; kill switch
  `USER_DISCOVERY_EVIDENCE_TAGGING_GATE_OFF=1`.

## 4. `user-discovery-saturation` — prevalence, contradiction, saturation

**Current state**: no prevalence/residual/saturation enforcement exists.

**Owned methodology**: stated prevalence (N of M), contradicting
evidence named rather than dropped, and the Guest/Bunce/Johnson 2006
saturation heuristic (~6 interviews in a homogeneous sample, already
sourced in `user-discovery-methodology.md` §c).

**Components**:
- *Gate* (`hooks/saturation-gate.sh`, same path scope): when the record
  content states `pain-confirmed` or `not-confirmed`, denies absence of
  (a) a prevalence marker (regex for "N of M" / "of N interviews" or
  equivalent) and (b) a residual/contradiction marker when contradicting
  evidence exists in the log (this role's own residual concept per
  `user-discovery-methodology.md` §b's "must note contradicting
  evidence" rule — role-adapted, not lifted from pricing's "what this
  cannot answer" wording). **Gap:** the exact substring heuristic for
  "a hypothesis/contradiction is stated" needs calibration against a
  real first-draft record, same caveat pricing's own gate accepted for
  its six elements — phase-2 should draft against that first real
  instance, not guess it here.
- *Checklist* (`per-interview-checklist.md` step 4): update running
  saturation count each round, note if the round crossed the ~6-
  interview heuristic threshold — stated as a checklist trigger, not a
  hard stop (saturation is a judgment call about diminishing new
  themes, not a countable gate condition).
- *Tests*: verdict with prevalence + residual note → allow; verdict
  missing either → deny, message names which is missing; kill switch
  `USER_DISCOVERY_SATURATION_GATE_OFF=1`.

## 5. Phase norms as plugin composition (the required framing)

- **Phase-1 (기획서) norm** = `user-discovery-proposal-norm` alone. No
  other plugin's gate is active on phase-1 paths — §2–§4's gates are all
  scoped to `docs/issue-<n>/reports/user-discovery.md`, which does not
  exist yet in phase 1 (contract v3 s19: the record "is phase-2 output
  like code," its absence is itself the phase-1 signal). This is why
  phase detection (see Gap below) matters: it is what makes phase-1's
  norm *only* the proposal-norm plugin's business, not an accidental
  side effect of file-not-existing-yet.
- **Phase-2 (산출물) norm** = the composition of
  `user-discovery-hypothesis-order` + `user-discovery-evidence-tagging`
  + `user-discovery-saturation`, all three independently gating the same
  target file (`docs/issue-<n>/reports/user-discovery.md`) on
  `Write|Edit|MultiEdit`, each checking its own owned element and
  denying independently — a phase-2 record must satisfy all three to be
  written at all. `core`'s generic `record-fields-gate.sh` continues to
  check contract §20's five generic fields separately; none of these
  three plugins re-checks those fields, only the domain elements core's
  generic gate structurally cannot know.

**Gap (phase detection, carried from the prior draft, unresolved by the
plugin-set restructuring):** the concrete signal for "is this session
phase-1 or phase-2" — used by `directive.sh` to select which plugins'
PRODUCES text applies, and implicitly by each gate's own path-scoping —
is not yet confirmed from this proposal's vantage point. Candidates, in
order: (a) whether `docs/issue-<n>/reports/user-discovery.md` exists yet
on this branch; (b) an env var core's own approval-gate machinery may
already set per session state. Resolve by reading
`core/hooks/approval-gate.sh` and `core/hooks/board-gate.sh` at phase-2
start before committing to one. Nothing in this proposal's plugin split
depends on which way this resolves — every plugin's gate is path-scoped
by file existence already, which is itself candidate (a).

## 6. Tests — repo-root `tests/`, one runner per plugin

**Current state**: no `tests/` directory exists in this repo at all
(confirmed absent). `core/hooks/tests/run-role-gates-tests.sh` and
`implementation-rulebook/tests/run-gate-tests.sh` (both read directly)
establish the pattern: pure-bash runner, no test framework, invoke the
gate script as a real subprocess with a crafted JSON payload on stdin,
assert exit code (0=allow, 2=deny) and a plugin-labeled deny-message
prefix.

**Proposed change**: one runner per plugin (`tests/run-proposal-norm-
gate-tests.sh`, `tests/run-hypothesis-order-gate-tests.sh`,
`tests/run-evidence-tagging-gate-tests.sh`,
`tests/run-saturation-gate-tests.sh`), each following that exact
invocation shape and each independently runnable — mirroring the
plugins' independence (a broken evidence-tagging gate should not block
running the hypothesis-order gate's own tests). Each includes, at
minimum: one pass case, one deny case with a plugin-specific message,
one non-owning-path allow case (gate exits 0 immediately), and one
kill-switch allow case.

## Open decision for phase-2/human review (not decided here)

- Whether the verdict enum gains a third `insufficient-evidence` state
  (raised, unresolved, in issue-1's own proposal §d) — §2 and §4's
  verdict-marker lists already assume yes, since a gate recognizing only
  a binary enum cannot flag an `opinion`-tier-only verdict as anything
  but a forced binary choice. If phase-2/human review decides no, §2 and
  §4 drop the third marker; nothing else in this proposal depends on
  which way this resolves.
- Packaging mechanics (§0's Gap): four separate plugin directories vs.
  one plugin directory with four self-contained gate scripts under a
  shared `hooks.json`. Recommend matching however `core`'s
  `freelunch`/`scout` are actually packaged, read directly at phase-2
  start.
