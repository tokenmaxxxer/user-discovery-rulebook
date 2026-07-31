# user-discovery-saturation

Enforces the evidence-discipline half of user-discovery verdicts: a
prevalence claim cannot be written without saying how many interviews it's
based on, and contradicting evidence cannot be silently dropped.

**Methodology owned:**

- **Stated prevalence** — every verdict ("pain-confirmed" / "not-confirmed")
  must be stated as N of M interviews (e.g. "3 of 8 interviews"), not as a
  bare impression.
- **Contradicting evidence named, not dropped** — if the write-up itself
  contains contradiction-indicating language, it must also carry an
  acknowledgment of the residual/contradicting evidence, not just the
  majority read.
- **Guest, Bunce & Johnson (2006) saturation heuristic** — in a reasonably
  homogeneous sample, thematic saturation is commonly reached by around the
  12th interview. This plugin does not mechanically enforce a count; it is
  carried as a checklist trigger in
  `docs/handbooks/user-discovery/per-interview-checklist.md` step 4 (update
  the running interview count each round; note if the round crossed the
  ~12-interview threshold) — a prompt to check, not a hard stop.

## Enforcement

A `PreToolUse` gate (`hooks/saturation-gate.sh`) on `Write|Edit|MultiEdit`,
scoped only to `docs/issue-<n>/reports/user-discovery.md`. On any other path
it exits 0 immediately — not this plugin's business.

When the reconstructed resulting content contains a verdict marker
(`pain-confirmed` or `not-confirmed`), the gate denies (exit 2) unless:

- a **prevalence marker** is present — detected via `\d+\s*(of|/)\s*\d+` or
  the phrase "of N interviews"; always required when a verdict is present.
- a **residual/contradiction-acknowledgment marker** is present — but only
  required when the content itself contains contradiction-indicating
  language.

### Exact substring heuristics chosen (named gap — needs calibration)

- Contradiction-indicating language that triggers the residual requirement:
  `"contradict"`, `"residual"`, `"disconfirm"`, `"however"`, `"some said"`.
- Residual/acknowledgment markers that satisfy the requirement:
  `"residual"`, `"contradicting evidence noted"`, `"contradiction:"`.

This is a simple substring heuristic, not NLP-grade contradiction detection.
The proposal (`docs/issue-7/proposals/plugin-enforcement-hardening.md` §4)
explicitly flags this list as needing calibration against a real first
draft of `docs/issue-<n>/reports/user-discovery.md` — words like "however"
will over-trigger on prose that isn't actually reporting disconfirming
evidence. Treat the current list as a starting point, not a settled spec.

Content reconstruction handles `Write` (content), `Edit`
(old_string/new_string replace), and `MultiEdit` (folded edit list)
identically; when it cannot determine the resulting content, the gate
denies with a specific "cannot determine resulting content" message rather
than guessing.

## Kill switch

`export USER_DISCOVERY_SATURATION_GATE_OFF=1` disables the gate entirely
(any non-empty, non-"0"/"false"/"no"/"off" value works, mirroring the rest
of this stack's kill switches).
