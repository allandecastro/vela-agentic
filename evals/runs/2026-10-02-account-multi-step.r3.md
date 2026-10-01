---
scenario: account-multi-step
date: 2026-10-02
verdict: pass
campaign: 2026-10-02
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: campaign actor + separate grader
---

## Check summary
`checks.json`: **17/17 passed**, no failed checks (build green, no VELA diagnostics, 15/15 tests re-run green,
Create + Update account PreOperation/Synchronous filter=['name'] registered, exactly 2 authored steps,
`HandleUpdate` and `OnExecute` both present, no `UserService.Update/Create` write-back, `PluginPipeline` used in tests,
package holds the plugin dll).

## Loop outcome
- `vela version` -> 0.21.4 (run trace row 1).
- Canvas `docs/vela-builds/account-uppercase-accountnumber.md` (commit 349e17b), assumptions flagged, continued.
- `vela add step AccountDefaultDescription --entity Account --message Update --stage PreOperation --mode Sync --filtering-attributes Name --project ...` exit 0 (commit c6b743c) -> generated `FilterOn(e => e.Name)` + `HandleUpdate`.
- Pre-image + description added, class made `partial`; `AccountNumber` added as a labelled no-org model stand-in (fb8e6fa).
- RED (c094741): 15 total, 4 failed for the right reason; baseline Create tests restated with `.OnCreate().Stage(PreOperation)`.
- GREEN (225f38c): 15/15, mono xunit.console `-parallel none`; `dotnet build --no-incremental` 0 warnings / 0 errors.
- Isolated vela-reviewer: PASS, 0 Critical / 0 Required / 5 Nits.
- `dotnet build -c Release` -> `artifacts/zava.Plugins.1.0.0.nupkg`; `vela plan` skipped (no org), command recorded; stopped at the apply gate.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reuse: `vela add step AccountDefaultDescription --entity Account --message Update`, not a new plugin / hand-written step | met | commit c6b743c (CLI-generated diff only); Canvas run trace row 3; check "exactly 2 authored step(s)" |
| Generated handler `HandleUpdate` kept, `OnExecute` kept for Create | met | `AccountDefaultDescription.cs:20,28,31,57`; checks "src contains /HandleUpdate/", "/OnExecute/" |
| Placeholder replaced with the gating column (`e => e.Name`) | met | `AccountDefaultDescription.cs:25` `FilterOn(e => e.Name)`; the actor passed `--filtering-attributes Name`, so the CLI emitted the gating column directly (no `e.Id` placeholder ever existed - see c6b743c); no VELA00x (check) |
| Stage: PreOperation on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:23,33,53`; check "step registered: Update account PreOperation/Synchronous"; no-write-back check |
| Harness: every test states its trigger; Create tests updated and green | met | `AccountDefaultDescriptionTests.cs` (`.OnCreate().Stage(PluginStages.PreOperation)`, c094741); `AccountUppercaseAccountNumberTests.cs:18,137`; pipeline tests at 101-128 |
| SC1: Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step | met | Canvas lines 20-21 |
| SC2: placeholder replaced; build green, no VELA00x in authored code | met | checks "build succeeds", "no VELA diagnostics"; Canvas Evidence line 111 |
| SC3: RED then green - name changed -> uppercased; name not changed -> step not run; Create cases pass | met | `review/red-green.txt` (RED 4 failed: AC1/AC2/AC10/AC9 for the right reason; GREEN 15/15); AC1/AC9 (uppercased), AC8 `Name_not_sent_step_does_not_fire` via `PluginPipeline` (`Assert.Empty(p.ExecutionLog)`), AC7 same-value no-op; 3 Create tests + AC11 green; check "tests re-run green" total=15 failed=0 |
| SC4: `vela-code-review` PASS | met | `docs/vela-builds/account-uppercase-accountnumber.review.md` - PASS, 0 Critical / 0 Required |
| Human answers honoured ("Name changes" = sent with a different value; null account number stays null; ZavaSales/zava) | met | `ctx.HasChanged` guard (line 37) + AC7; AC4/AC5 null stays null; Canvas lines 23-24 |
| Stop before apply | met | Canvas `apply: pending`, Gate section; no apply in run trace |

## Planted-violation results
The scenario has no "Planted-violation check" section - none applied.

## Findings against the skills
1. minor - `evals/scenarios/account-multi-step.md` (rubric, not a skill) expects "the generated `FilterOn(e => e.Id /* TODO */)` ... is replaced", but `skills/vela-scaffold/SKILL.md:65` ("pass `--stage`, `--mode` and `--filtering-attributes`") correctly leads the agent to have the CLI emit `FilterOn(e => e.Name)` directly, so the VELA001 placeholder gotcha (`vela001-placeholder`) is never exercised by this scenario. Graded met; the scenario should say "the step's filter is the gating column (via `--filtering-attributes` or by replacing the placeholder)" or drop `vela001-placeholder` from `gotchas_exercised`.
2. minor - the Canvas reached review with `status: proposed` and `decisions: []` (reviewer Nits 2-3), fixed only afterwards. The pack's flow does not prompt the agent to fill `decisions:` when the Canvas is written in `vela-plan-review`, nor to advance `status` before dispatching `vela-code-review`; the reviewer caught it, so not blocking.
3. minor - the package was built on a hand-edited "generated" `Account.cs` (labelled `// STAND-IN for vela-models (no org)`), sanctioned by `skills/vela-plugin-authoring/SKILL.md:37` but in tension with AGENTS.md golden rule 7 ("never hand-edit generated files"). The actor and reviewer both flagged it as a pre-apply blocker for the human, and the Gate says the package "is not the one to apply" - handled correctly; noting the rule tension only.

No blocker findings.

## Verdict
**pass** - checks 17/17 and every scenario criterion met from the artifacts. Next run should re-check that the
Create tests state their trigger and that `--filtering-attributes` (or the placeholder replacement) yields `e => e.Name`.
