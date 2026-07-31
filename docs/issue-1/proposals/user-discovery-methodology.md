# Proposal: methodology and required components for user-discovery (issue-1)

Phase-1 proposal only — no execution. Approve on issue-1/user-discovery
opens phase 2, where this plan is carried out on the same branch. See
`docs/issue-1/reports/user-discovery/survey.md` (current-state inventory)
and `docs/issue-1/reports/user-discovery/scout-brief.md` (chosen axes and
gap line) for the evidence this proposal is built from.

## Summary

This role's mandate — "이 문제가 실제 사용자의 고통인가" — is a discovery-
research problem, not a validation-metrics problem. The domain that
studies exactly this (customer/user discovery interviewing) has a well
established, cited core: ask about specific past behavior instead of
opinions or future hypotheticals (Fitzpatrick, *The Mom Test*), test
falsifiable hypotheses rather than gut calls (Blank's Customer
Development / Ries's Lean Startup), and grade every claim by the
strength of its evidence before it's allowed into a verdict (thematic
analysis discipline, Braun & Clarke 2006). This proposal adopts that
core, explicitly skips heavier machinery this role's narrow mandate
doesn't need (JTBD's full four-forces model, Torres's opportunity-
solution tree as a *mandatory* structure), and lays out (a) how this
repo's own phase-1 proposals should be documented, (b) what phase-2's
three deliverables must structurally contain, (c) why each pick is
inevitable given the role's mandate, and (d) exactly which plugin fields
would carry the result — as a plan, not code.

Nothing here proposes reintroducing `agents/warrant-hunter.md` or any of
the three gate copies issue-2 already removed from this repo (commit
d0569d5). warrant-hunter stays a core-canon reference per core issue #63;
this proposal only concerns the role-specific content that was never
core's to own — the discovery methodology itself.

## (a) Proposal-norm: how this repo's own phase-1 proposals should be written

Generalized from what worked in `docs/issue-2/proposals/core-canon-
reference-cutover.md` (numbered sections, gaps named explicitly rather
than glossed over, every claim traceable to a survey file) plus one rule
this domain's own research supplies:

1. **Opening framing line** stating "Phase-1 proposal only — no
   execution" and naming which record/comment triggers phase 2 (per
   approvers.md and contract v3 s19). Every proposal in this repo should
   open this way — it is now this repo's convention, not a one-off.
2. **A preceding survey doc is mandatory**, cited by path in the first
   paragraph — a proposal must be built on an inventory of what already
   exists, not asserted from memory. (Issue-2's proposal did this;
   codifying it here makes it a rule, not a coincidence.)
3. **Numbered, self-contained sections** — each proposed change gets its
   own section naming exactly what changes and why; gaps that block
   exact execution detail are named as `**Gap:**` inline, not hidden.
4. **Evidence-format rule specific to this role**: because this role's
   own subject matter is "don't trust opinions, trust behavior," this
   role's proposals must hold themselves to the same standard when
   justifying methodology picks — every adopted technique must cite a
   real, checkable source (book, paper, article), and any claim that
   cannot be verified must be labeled `[assumption]` rather than stated
   as fact. This proposal follows that rule in section (c) below.
5. **No design decision left un-flagged**: if a design choice depends on
   something unknowable from this repo (e.g., core-canon internals),
   name it as a gap for phase-2 to resolve by reading the real thing —
   never guess silently (same practice issue-2's proposal used for its
   four core-canon unknowns).

## (b) Deliverable-norm: required components of the three phase-2 outputs

### Interview script

- Each question must be phrased to elicit a specific past event, not an
  opinion or hypothetical — the Mom Test's "talk about their life, ask
  about the past, talk less" discipline. Any question a polite stranger
  could answer with a compliment ("would you use this?", "do you think
  this is useful?") is disallowed as a primary question; it may only
  appear, if at all, as a discarded draft noted in review.
- Must include a **follow-up ladder** for each hypothesis under test:
  "when did this last happen → what did you do about it → did you
  spend money/time on it → what happened next" — this is the concrete,
  reusable structure the Mom Test discipline and JTBD's timeline
  technique both converge on for surfacing real behavior.
- Must **not pitch the idea** until after the behavioral questions are
  exhausted, if at all.
- Must state, alongside the script, the **falsifiable hypothesis** each
  question line is meant to test, and what answer would disconfirm it —
  a hypothesis with no stated disconfirming observation is not
  interview-ready (Blank/Ries discipline).

### Per-interview evidence log

- One entry per interview, minimum fields: participant/context,
  the hypothesis(es) addressed, verbatim or closely-paraphrased quotes,
  and an **evidence-strength tag** per quote/claim:
  - `behavioral` — observed or reported concrete past action/spend
    (strongest).
  - `recounted` — a specific past event described in detail but not
    independently observed (medium).
  - `opinion` — prediction, compliment, or stated future intent
    (weakest — flagged explicitly, never silently promoted).
- Must record whether each theme was **unprompted or elicited by a
  leading question** — unprompted mentions carry more weight.
- Must track a running **saturation count**: new themes surfaced per
  interview, so the stopping decision is visible in the log itself
  (Guest, Bunce & Johnson 2006 — expect diminishing new themes after
  roughly 6 interviews in a homogeneous sample, plateauing further by
  ~12; heterogeneous samples may need more — this role should treat the
  numbers as a planning heuristic, not a hard gate, since this role's
  interview samples are not guaranteed homogeneous).

### Pain-confirmed | not-confirmed verdict

- Must be traceable: the verdict must cite which log entries (by
  evidence-strength tier) it rests on. A verdict resting only on
  `opinion`-tier evidence must not be reported as `pain-confirmed` —
  at most it is `insufficient-evidence`, which this role's plugin should
  treat as a distinct honest state alongside the two named in the
  mandate (see gap noted in section (d) below — the mandate's own enum
  is binary and may need a third state; flagged as an open question for
  human review, not resolved unilaterally here).
- Must state prevalence explicitly ("N of M interviews showed this
  unprompted") rather than a bare confirmed/not-confirmed with no count
  — this repo's domain research found no validated numeric threshold
  for "how many is a real pattern," so the deliverable norm is to report
  the count honestly rather than assert a threshold that doesn't exist.
- Must note contradicting evidence, if any was logged, rather than
  silently drop it — this is the check-back step (Braun & Clarke 2006)
  applied to a verdict instead of a full thematic write-up.

## (c) Rationale — why each pick is inevitable, not just popular

- **Past-behavior-only questions (Mom Test)**: the role's decides-line is
  "이 문제가 실제 사용자의 고통인가" — a claim about *actual* pain, not
  imagined pain. Stated willingness/opinion questions are known to
  inflate relative to actual behavior (meta-analytic calibration factor
  ≈1.35, i.e. ~21% overstatement on average — List & Gallet 2001; Murphy
  et al. 2005, *Environmental & Resource Economics*). A role whose whole
  job is separating real pain from polite enthusiasm cannot adopt a
  questioning style whose own literature says it systematically
  overstates the thing being measured. This is not a style preference;
  it's the only question design consistent with the mandate.
  Source: https://blog.uxtweak.com/the-mom-test/ ,
  https://medium.com/@poloniothais/book-summary-the-mom-test-by-rob-fitzpatrick-8440986cd92c
- **Falsifiable hypotheses before interviewing (Blank/Ries)**: the
  hand-off line is "검증된 가설을 스펙화하면 → requirements-engineering" —
  the role's entire output is meant to be a *validated* hypothesis. A
  hypothesis that was never stated in disconfirmable form cannot later
  be described as validated or invalidated; it can only be described as
  "a vibe changed." Customer Development's discipline of testing
  hypotheses systematically outside the building is the direct ancestor
  of "validated hypothesis" as a deliverable category.
  Source: https://www.entrepreneurship.org/learning-paths/the-lean-approach/getting-out-of-the-building-customer-development ,
  https://inversion.agency/articles/four-steps-to-epiphany
- **Evidence-strength tagging + check-back (thematic analysis)**: the
  role produces a binary verdict (pain-confirmed|not-confirmed) that
  another role (requirements-engineering) will treat as ground truth
  for spec work. A verdict is only as trustworthy as its weakest
  supporting evidence; without a tagging discipline, an `opinion`-tier
  quote could silently carry the same weight as a `behavioral`-tier one.
  Braun & Clarke's check-back step is the specific mechanism that
  catches a theme built only on quotes that happened to confirm the
  hypothesis.
  Source: (Braun & Clarke 2006, *Qualitative Research in Psychology* —
  cited via the user-discovery skill's evidence grading; not
  independently re-verified by URL in this pass — labeled
  `[secondary-citation]`, verify primary source in phase 2 if precision
  matters for the gate wording).
- **Timeline/follow-up-ladder structure (JTBD-adjacent, partial adopt)**:
  the "when did this last happen → what did you do → did you spend
  anything → then what" ladder mirrors JTBD's timeline capture
  (first thought → passive looking → active looking → decision), which
  independently converges with the Mom Test's past-event rule on the
  same structural shape. Two independently-developed methodologies
  landing on the same interview shape is stronger grounds for adoption
  than either alone; the FULL four-forces model is skipped (see
  scout-brief.md) because this role only needs the timeline backbone,
  not the complete push/pull/anxiety/habit categorization JTBD uses for
  product positioning decisions this role does not make.
  Source: https://therewiredgroup.com/news/blog-jtbd-interview-live-demonstration/ ,
  https://www.omniconvert.com/blog/jobs-to-be-done-interviews/
- **Saturation-based stopping rule, held as a heuristic not a hard
  number**: Guest, Bunce & Johnson (2006) is a real, specific,
  peer-reviewed measurement (~80% of codes within 6 interviews,
  saturation by ~12, in a homogeneous 60-interview two-country sample).
  It is honestly reported here as a planning heuristic rather than a
  hard rule, because this role's interviewee samples are not guaranteed
  to be homogeneous the way that study's were, and heterogeneous/
  meaning-level questions are reported elsewhere in the literature as
  needing 16-24 interviews. Overstating this as a hard number would
  violate this proposal's own evidence-honesty norm from section (a).

## (d) Plugin reflection plan (PLAN ONLY — no code changes here)

This section names concrete fields to change in phase 2, once approved.
Nothing in this section is executed by this document.

- **`user-discovery/.claude-plugin/plugin.json`**: add a structured
  `produces` array (not just prose in `description`), itemizing the
  three deliverables as machine-readable strings:
  `["interview-script", "per-interview-evidence-log", "pain-verdict"]`.
  This gives phase-2's gate something concrete to check against instead
  of parsing free text.
- **`user-discovery/hooks/directive.sh`**: keep calling
  `core_role_directive` with its existing 4 args (YOU DECIDE, USE WHEN,
  PRODUCES, HAND-OFF) — issue-2 already resolved the call signature by
  reading core canon directly; this proposal does not touch that
  contract. The `PRODUCES` string itself should be updated (phase 2) to
  spell out the same three itemized components rather than a single
  flat sentence, so the directive text a session sees at SessionStart
  matches the structured list in `plugin.json`.
- **Future `REQUIRED_FIELDS`-equivalent config** (whatever core's
  generic record-fields gate reads role-specific requirements from,
  post issue-2 cutover — see the open gap in survey.md): should enumerate
  sub-structure, not just the three top-level names, e.g.:
  - `interview-script`: requires a stated falsifiable hypothesis per
    question line, and a follow-up ladder.
  - `per-interview-evidence-log`: requires an evidence-strength tag
    (`behavioral`|`recounted`|`opinion`) per logged claim, and a
    prompted/unprompted flag per theme.
  - `pain-verdict`: requires cited log-entry references and a stated
    prevalence count, plus (open question for phase-2 human review, not
    decided here) whether a third `insufficient-evidence` state should
    be added alongside `pain-confirmed`/`not-confirmed`.
  Phase 2 must first read core's generic gate implementation (per the
  gap already flagged in survey.md) to know whether this sub-structure
  is even expressible in current config, or whether it requires a core
  canon change out of this rulebook's own scope — that determination is
  explicitly deferred, not guessed here.
- **Gate honesty note**: some of the above (e.g. "is this question
  phrased as past-behavior") is not reliably machine-checkable by a
  simple pattern match — a keyword gate could false-positive on
  "would you" phrasing that's actually fine in context, or miss a
  disguised opinion question. Where machine-checking would be
  unreliable, this plan recommends the requirement be enforced as an
  explicit **human review checklist item** referenced by the gate's
  error message (i.e., the gate can check that the required *sections*
  and *tags* are present structurally, but should not attempt to
  semantically judge question quality) — mislabeling a soft norm as a
  hard gate would itself violate this role's own evidence-honesty
  standard.
- **No local warrant-hunter.md, no local gate-script reintroduction**:
  explicitly out of scope. warrant-hunter remains a core-canon reference
  (core issue #63); the three gate copies issue-2 removed
  (`trailer-gate.sh`, `handbook-trigger-gate.sh`, `record-fields-gate.sh`)
  stay removed — any required-fields enforcement this proposal calls for
  must be expressed as config for core's generic gate, not a new local
  script, consistent with issue-2's already-landed direction and this
  issue's own constraint not to weaken or duplicate that work.

## Open items for phase 2 (explicitly not resolved here)

1. Whether a third `insufficient-evidence` verdict state should be added
   — a mandate/scope question for human review, not a methodology
   question this proposal can answer unilaterally.
2. Whether core's generic record-fields gate can express nested
   sub-structure (per-field requirements, not just top-level field
   names) — must be checked against the actual core canon implementation
   before writing the config.
3. Precise primary-source verification for the Braun & Clarke check-back
   citation (currently sourced via the user-discovery skill's evidence
   grade, not independently re-fetched in this pass) — cite the
   original 2006 paper directly if the gate's documentation needs to
   quote it precisely.
