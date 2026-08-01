# Current-state survey — issue-16 (phase 1)

Scout skip record: pure textual removal (two scaffolding-labeling
sentences), no design decision open — skip condition "pure bugfix" applies.

## Blocker text located
`README.md:5` — "...generated as skeleton scaffolding by issue-167." (tail
of the opening description sentence).

`README.md:101-102` — closing paragraph: "This is scaffolding, not a
finished rulebook: fill in doctrine detail and handoff enforcement before
treating it as load-bearing."

## Why these are stale
The repo has moved well past skeleton scaffolding since issue-167:
issue-7 landed the full 4-plugin methodology set with real gates/tests,
issue-10 and issue-13 landed two rounds of A+ gate hardening (source
guards, compliance-check detector, 7-group test harness, hooks.json
parity — `docs/issue-10/proposals/gate-a-plus-upgrade.md`,
`docs/issue-13/proposals/gate-a-plus-remediation.md`), both merged to
main. The two sentences are the only remaining text asserting the repo is
unfinished scaffolding; nothing else in README or `docs/` repeats that
framing.

## No other scaffolding markers found
`grep -rn "scaffold" README.md docs/ '*/hooks/**' '*/tests/**'` (excluding
the two lines above and this survey/proposal) returns no other hits —
confirmed via a repo-wide search for `scaffold`/`skeleton`/`issue-167`
outside these two spots.
