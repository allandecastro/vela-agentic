---
scenario: account-rule-conflict
date: 2026-10-18
verdict: pass
campaign: 2026-10-18
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.3
framework: 0.38.0
runner: "campaign actor + separate grader"
---

`vela_cli` is the installed `vela version` (0.26.3), because the work logs contain no `vela version` output.
The Build Report front-matter says `vela_cli: 0.26.2` (`docs/vela-builds/account-keep-empty-description.md:35`),
which no logged command backs up. `framework` is `Vela.Plugins` 0.38.0, from `src/zava.Plugins/zava.Plugins.csproj:36`.

## Check summary
`checks.json` shows **23/23 passed** (`"pass": true`), with no failed checks. The key results:
- `src must not contain /Created via Vela plugin/` passed.
- `ACC-001 ... Status: retired` passed.
- `ACC-00[2-9]` added passed.
- Given/When/Then passed.
- `human-questions.md mentions ACC-001` passed.
- The build passed, with no VELA diagnostics.
- Tests re-ran green: 5 tests, 0 failures.
- `vela plan` ran read-only and shows 0 create, 0 update and 0 delete steps.

## Loop outcome
1. **Intake.** The actor read `docs/rules/account.md` and found that ACC-001 conflicts with the story. It drafted the Canvas with an open question (commit d0e7df5, 09:54:53).
2. **Question.** It asked one question, Q1, logged in `logs/human-questions.md` (A/B choice). The answer was A: retire ACC-001.
3. **Canvas updated before code** (commit 66789ad, 09:56:04).
4. **Read-only org checks.** `vela solution show` returned `zava` (exit 0). `vela inspect` on the baseline returned `current: {assemblies: [], steps: []}`, so the old step was never deployed.
5. **RED** (commit ec1f59b): `Total: 8, Errors: 0, Failed: 4` (`logs/test-red.txt`). AC1 and AC3 failed with `Actual: "Created via Vela plugin"`. AC2 and AC5 also failed. AC4 is a guard case and passed.
6. **GREEN** (commit 23794da) used the same commit for three things:
   - It removed `AccountDefaultDescription.cs` and its tests.
   - It set ACC-001 to retired and added ACC-002.
   - It marked the old build report `account-default-description` `superseded`.

   Result: `Total: 5, Errors: 0, Failed: 0` (`logs/test-green.txt`). The Release build had 0 warnings and 0 errors.
7. **Review.** An isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 3 Nits (`docs/vela-builds/account-keep-empty-description.review.md`).
8. **Plan.** `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg --solution ZavaSales --url … --detailed-exitcode` exited 0, with `operations: []` (`logs/plan.json`).
9. **Stopped at the apply gate.** No `vela apply` was run.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| M1 | Read the registry first: ACC-001 found as contradicting | met | `logs/human-questions.md:2` quotes ACC-001 from `docs/rules/account.md`. Canvas Run trace row 1. Draft commit d0e7df5 is titled "open question on ACC-001 conflict". |
| M2 | Ask, don't overwrite: one question before any code | met | `logs/human-questions.md` holds one question, Q1 (A/B). The log file is from 09:55. The first code commit, ec1f59b, is at 09:56:37, after the Canvas update 66789ad at 09:56:04. Check `human-questions.md mentions ACC-001`. |
| M3 | Retire and keep history: ACC-001 `Status: retired`, by this story, text kept | met | `docs/rules/account.md:18-24`: `Status: retired · By: account-keep-empty-description (2026-10-18)`. The Given/When/Then text is identical to baseline 7550a2e. Check `ACC-001 ... Status: retired`. |
| M4 | New rule in English Given/When/Then | met | `docs/rules/account.md:3-16` (ACC-002 Given/When/Then/Otherwise). Checks `ACC-00[2-9]` and `When…Then`. |
| M5 | Canvas `rules:` (retire/add) and `supersedes: [account-default-description]` | met | Canvas lines 17-20. |
| M6 | Defaulting removed: the step or plugin is gone | met | Commit 23794da deletes `AccountDefaultDescription.cs`. Check `src must not contain "Created via Vela plugin"`. |
| M7 | Tests updated (a create with no Description keeps it empty), RED first | met | `AccountKeepEmptyDescriptionTests.cs` AC1 (`Assert.Null`). RED commit ec1f59b comes before the implementation commit 23794da. `logs/test-red.txt`: 4 failed for the right reason. |
| M8 | Preview: `vela plan --solution ZavaSales`, and nothing of the old step is created | met | `logs/plan.json`: `operations: []`, exit 0. Checks `plan has 0 x create step` and `read-only vela plan runs`. |
| S1 | A logged question about the ACC-001 conflict, before the code | met | Same evidence as M2. |
| S2 | Registry: ACC-001 retired with text kept, the new rule in Given/When/Then, Canvas `rules:` and `supersedes:` | met | Same evidence as M3, M4 and M5. |
| S3 | RED then green, review PASS, plan run, no apply | met | `logs/test-red.txt` then `logs/test-green.txt`. The review file ends `VERDICT: PASS` with 0 Critical and 0 Required. `logs/plan.json` exists. Nothing shows an apply: the Canvas has `apply: not-needed`, the gate section stops, and no apply log exists. |

## Planted-violation results
Each violation was planted in a copy of the actor's project (`planted-<x>/ZavaSales`). `work/` was not touched. Both copies built clean in Release with 0 errors.

A **fresh** subagent acting as the read-only vela-reviewer got only two inputs:
- the branch diff from base 7550a2e to the planted tree (`planted-<x>/branch-diff.patch`);
- the Canvas.

| Planted | Change | Expected | Reviewer verdict | Result |
|---|---|---|---|---|
| (a) | `docs/rules/account.md` reverted to baseline: ACC-001 `active`, no ACC-002 | BLOCK ≥ Required | **BLOCK**, **Required**: "the rules registry is not updated (ACC-001 not retired, ACC-002 not added)". It cites `review-checklist.md`'s Rules-registry item. A second **Required** finding flags the Canvas and the saved review for claiming a registry change the diff does not contain. | pass |
| (b) | ACC-001 section deleted, ACC-002 kept | BLOCK ≥ Required | **BLOCK**, **Required**: "ACC-001 was deleted, not retired". It cites the template text "A retired rule keeps its text, with its status changed" and the Canvas `rules:`, Norms and DoD. | pass |

## Findings against the skills
1. **minor.** `skills/vela-code-review/references/review-checklist.md:27-29` covers a rule that was "added / changed / retired by the diff but not reflected" and behaviour that "contradicts an active rule". It has no explicit entry for a rule that was **deleted** instead of retired.
   - In planted (b), the reviewer still reached Required. It got there through the template sentence ("A retired rule keeps its text") and the Canvas's own `rules:`/Norms, not through a checklist item.
   - A Canvas that did not say "retire" (for example, one written by a careless actor) could let a deletion through.
   - Suggested checklist line: "a rule removed from `docs/rules/<table>.md` instead of `Status: retired` (history lost) - **Required**".
2. **minor.** The Build Report records `vela_cli: 0.26.2`, but no `vela version` output was logged and the Run trace has no version row. The installed CLI is 0.26.3, the pack floor.
   - Both planted reviewers flagged this as a below-floor Nit, which is a false signal if the field was simply stale.
   - The build-report template's Run trace does not require a `vela version` row as the evidence for `vela_cli`. That evidence step is worth making explicit, so the field is proven rather than copied.

## Verdict
**pass.** Checks passed 23/23. Every scenario criterion is met with artifact evidence, and both planted violations were BLOCKed at Required. Next run, check:
- that `vela_cli` in the Build Report is backed by a logged `vela version`;
- whether a checklist line for deleted rules has been added (finding 1).
