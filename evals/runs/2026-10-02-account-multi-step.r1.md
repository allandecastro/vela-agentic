---
scenario: account-multi-step
date: 2026-10-02
verdict: pass
campaign: 2026-10-02
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **17/17 passed**, no failed checks. These include: build succeeds, no VELA diagnostics, tests re-run green (12/12), Create and Update steps registered PreOperation/Synchronous with filter `name`, exactly 2 authored steps, `HandleUpdate` and `OnExecute` both kept, a `PluginPipeline` "does not fire" test, no write-back, and the package holds the plugin dll.

## Loop outcome
- `vela version` → `vela 0.21.4`, exit 0 (Canvas Run trace #1).
- The Canvas was committed first (29a53bc). It has `reuse: add-step:AccountDefaultDescription`, the Update step and the assumptions.
- `vela add step AccountDefaultDescription --entity Account --message Update --stage PreOperation --mode Sync --filtering-attributes Name --project ...` → "Added step Update (HandleUpdate)", exit 0. In the same commit (8eab17b) the actor added a pre-image `[Name, AccountNumber]`, made the class `partial`, and added a labelled `AccountNumber` model STAND-IN because there was no org.
- RED: the tests were committed alone (ce080de). **The grader reproduced it** on a clone at ce080de: `Total: 12, Errors: 0, Failed: 4`. The 4 failures were AC1 (Execute), AC1 (pipeline), AC2 and AC7, each on the expected value.
- GREEN (cbb940f): 12/12. The evaluator's re-run confirms it (`tests re-run green`, total=12 failed=0).
- Review: an isolated `vela-reviewer` returned PASS with 0 Critical, 0 Required and 3 Nits (`docs/vela-builds/account-uppercase-account-number.review.md`).
- Package: `artifacts/zava.Plugins.1.0.0.nupkg` contains `lib/net462/zava.Plugins.dll`. `vela plan` was skipped (no org) and its exact command is recorded. The actor stopped at the apply gate, did not run `vela apply`, and set `status: awaiting-apply`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reuse via `vela add step`, not a new plugin and not a hand-written step | met | Canvas Run trace #3, which `vela add step ...` reproduces exactly (grader re-ran it on the baseline); check "exactly 2 authored step(s)" |
| Generated handler `HandleUpdate` kept, `OnExecute` kept | met | `AccountDefaultDescription.cs:22,30,33,60`; checks `src contains /HandleUpdate/` and `/OnExecute/` |
| Placeholder replaced with the gating column (`e => e.Name`) | met (by outcome) | `AccountDefaultDescription.cs:27` `.FilterOn(e => e.Name)`. With CLI 0.21.4 and `--filtering-attributes Name`, `add step` emits `FilterOn(e => e.Name)` directly, so no placeholder was produced (grader reproduced this). Check "step registered: Update ... filter=['name']" |
| Stage PreOperation on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:25,35,56`; check "no write-back" |
| Multi-step harness: every test states its trigger, Create tests updated and green | met | Tests `:22` `.OnCreate().Stage(PluginStages.PreOperation)` and `:36` `.OnUpdate().Stage(...)`; pipeline tests trigger through `Service.Update/Create`; the 3 Create tests are green |
| SC1: Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step | met | `account-uppercase-account-number.md:9-10` |
| SC2: gating column in place, build green, no VELA00x in authored code | met | checks "build succeeds" and "no VELA diagnostics"; grader build at ce080de: 0 errors, 0 warnings |
| SC3: RED then GREEN; name changed → uppercased; name unchanged → step not run; Create cases still pass | met | RED reproduced by the grader (4 expected failures). GREEN 12/12. AC1/AC2 cover "uppercased". AC6 (`Name_not_sent_does_not_fire_the_step`, `Assert.Empty(p.ExecutionLog)`) covers "not run". AC5 covers a resent same value as a no-op. AC8 and 3 Create tests pass |
| SC4: `vela-code-review` PASS | met | `account-uppercase-account-number.review.md:3` "Verdict: PASS - no Critical/Required, 3 Nits" |
| Human answer: a null account number stays null | met | AC3 and AC4 (tests `:81-96`), implementation `:47-50` |
| Stop before apply | met | Canvas `apply: pending`, `status: awaiting-apply`; the Gate section hands `vela apply` to a human |

## Planted-violation results
This scenario has no "Planted-violation check" section, so none were applied.

## Findings against the skills
1. minor: the scenario rubric no longer matches CLI 0.21.4.
   - `evals/scenarios/account-multi-step.md:26` says "the generated `FilterOn(e => e.Id /* TODO */)` (which fails the build with **VELA001**)".
   - The grader ran `vela add step` on the baseline with 0.21.4. With `--filtering-attributes Name` it emits `.FilterOn(e => e.Name)`. Without the flag it keeps no placeholder and adds the comment `// TODO: add .FilterOn(e => e.Column) to scope this step to the attribute changes it needs.`
   - The `vela001-placeholder` gotcha therefore can no longer be exercised. The criterion should become "the step is filtered on the gating column (`Name`), via `--filtering-attributes` or by editing the generated TODO".
2. minor: two pack sources still describe the placeholder as live CLI output.
   - `skills/vela-scaffold/SKILL.md:117` lists "a placeholder (`e => e.Id`, VELA001)" as a current red flag.
   - `plugin-authoring-api.md:64` already says "older CLIs emitted `FilterOn(e => e.Id ...)`".
   - They are not wrong, since the red flag still guards older CLIs. But neither names the 0.21.4 no-flag behaviour, where the TODO comment leaves the step unfiltered and firing on every Update. That is the trap an agent can now hit silently, because it builds with no VELA001.
3. minor (evaluator hygiene, not a skill defect): `r1/evidence/` holds files from 2026-09-29. They come from a different earlier run: test class `AccountNumberUppercaseTests`, Total 14, Canvas `account-number-uppercase.md`. Clear the run directory before each campaign run so a grader cannot mistake them for this actor's evidence. This run's evidence is in `r1/review/` and the work repo.

No blocker findings.

## Verdict
**pass**. Checks passed 17/17, and the grader found every criterion met. The grader confirmed RED independently at ce080de. The next run must re-check the placeholder criterion against the updated rubric (finding 1).
