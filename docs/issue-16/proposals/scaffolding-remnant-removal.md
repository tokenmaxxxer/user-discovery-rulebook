# Proposal — issue-16 A+ 인증 마감: scaffolding 잔재 제거 (phase 1)

Status: PROPOSED. Awaiting approvers.md APPROVE per contract v3 s19. No
execution work in this document or commit.

## Basis
Survey: docs/issue-16/reports/user-discovery/current-state-survey.md.

## Fix — README.md L5, L101-102
Remove the two remaining "this is unfinished scaffolding" assertions,
since the repo has since landed a full plugin set (issue-7) and two A+
gate-hardening rounds (issue-10, issue-13):

1. `README.md:5` — drop the trailing "and generated as skeleton
   scaffolding by issue-167" clause from the opening sentence; keep the
   role-taxonomy split-off attribution (`docs/issue-160/...
   role-taxonomy.md`'s round-4 promotion), which is still accurate
   provenance, not a scaffolding claim.
2. `README.md:101-102` — drop the closing "This is scaffolding, not a
   finished rulebook: fill in doctrine detail and handoff enforcement
   before treating it as load-bearing." paragraph entirely (no
   replacement text needed — the preceding "Gate implementation" section
   already stands as the closing section).

No other file carries a scaffolding/skeleton/issue-167 marker (survey
grep confirmed).

## Verification plan
No code paths touched — text-only doc edit. Confirm via:
- `grep -rn "scaffold\|skeleton\|issue-167" README.md` returns no hits
  post-edit.
- `tests/run-all-gate-tests.sh` (full suite) still green — proves the
  edit didn't disturb gate/test wiring, satisfying the issue's "관련
  테스트 green 유지" requirement even though this fix touches no test
  surface.
- Clean-clone check: re-clone the branch tip and re-run the same grep +
  test suite, per issue's "clean clone 기준".

Execution and the green-run log land in phase 2
(`docs/issue-16/reports/user-discovery.md`) after APPROVE.
