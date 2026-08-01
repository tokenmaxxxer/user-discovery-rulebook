# Per-Interview Checklist

Checklist run after each user-discovery interview round.

2. Keep asking about the interviewee's past behavior until it is exhausted
   before pitching anything (Mom Test). Do not introduce the
   idea/product/solution until you have run out of concrete past-behavior
   questions to ask — pitching early anchors the interviewee's answers and
   contaminates the rest of the interview. This is a content-judgment call
   for the interviewer to make; it is not enforced by any automated gate.

3. Tag every claim recorded from the interview with its evidence strength:
   `behavioral` (what the person actually did), `recounted` (what the person
   says they did), or `opinion` (what the person thinks/feels/would do). For
   each claim, also flag whether it was volunteered unprompted or surfaced
   only after a prompt from the interviewer — prompted claims carry weaker
   evidentiary weight than unprompted ones. The `user-discovery-evidence-tagging`
   plugin gates `docs/issue-<n>/reports/user-discovery.md` writes to require
   at least one of these three tags be present in the record; it does not
   and cannot verify that individual claims are tagged correctly or that the
   prompted/unprompted flag is present — that judgment remains the
   interviewer's. A tag counts only in a structural position — a labeled
   `evidence:` field, a heading, a list item, or a `[tag]` bracket — not a
   bare word anywhere in flowing prose (issue-10 gate A+ upgrade); see
   `docs/handbooks/gate-house-standard.md` for the shared gate machinery all
   four of this rulebook's gates now source, and
   `tests/run-all-gate-tests.sh` for the maintained regression suite that
   must stay green whenever a gate script changes. All four enforcement
   gates now source `gate-lib.sh` with a guarded fallback (fail-closed —
   hard-denies rather than fail-open — if core cannot be resolved) and
   every gate's suite carries the mandatory `missing-core` regression case
   for it (issue-13 gate A+ closeout); `tests/manifest-check.sh`, run as
   part of the same suite, hard-fails on any README/manifest reference to
   a file that no longer exists or to a retired role name.

4. Update the running saturation count for this study (interviews
   completed so far out of the sample). Note in the round's log whether
   this round crossed the ~12-interview heuristic threshold (Guest, Bunce &
   Johnson 2006, for a reasonably homogeneous sample) — this is a trigger
   to review whether new themes are still emerging, not a hard stop on
   further interviews.
