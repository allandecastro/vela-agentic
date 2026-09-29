---
superseded_by: 2026-09-30-account-multi-step.r1.md   # rubric corrected mid-campaign; kept for transparency
scenario: account-multi-step
date: 2026-09-30
verdict: fail
run: 1/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **17/17 passed** (`"pass": true`). There were no failed checks. The checks confirm:
- The build succeeds with no VELA diagnostics.
- Tests re-run green: total=13, failed=0.
- Two authored steps are registered: Create and Update, both PreOperation/Sync with `filter=['name']`.
- `HandleUpdate` and `OnExecute` are both present.
- `src` has no `UserService.Update/Create` write-back.
- A `PluginPipeline` test is present.

## Loop outcome (from `work/ZavaSales`, git log and the Build Report)
- 767a66d: Canvas committed to `docs/vela-builds/account-number-uppercase.md`.
- Scaffold: `vela add step AccountDefaultDescription --entity Account --message Update` exited 0 (Run trace #2). The actor then aligned the step before any build: PostOperation became PreOperation, the `FilterOn(e => e.Id /* TODO */)` placeholder became `e => e.Name`, a pre-image was added, and the class was made `partial`.
- Build (Run trace #4): `dotnet build --no-incremental` gave 0 warn / 0 err. This was the first build, and it ran after the placeholder had already been replaced.
- f07820a: `AccountNumber` no-org STAND-IN (sanctioned by `vela-models` step 3).
- RED 1: `Total: 12, Failed: 4`. GREEN: 12/12.
- RED 2 (a new case-only-rename case, added to the Canvas first): `Total: 13, Failed: 1`. GREEN: `Total: 13, Errors: 0, Failed: 0, Skipped: 0`.
- Isolated vela-reviewer: PASS, 0 Critical / 0 Required / 5 Nits.
- Package: nupkg holds `lib/net462/zava.Plugins.dll`.
- `vela plan`: skipped (no org, command recorded). `vela apply` was not run.

## Criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| M1 | Reuse via `vela add step AccountDefaultDescription --entity Account --message Update` | met | Canvas `account-number-uppercase.md:101-104` and Run trace #2 (exit 0). Check "exactly 2 authored step(s)". Only one plugin class exists: `AccountDefaultDescription.cs:11`. |
| M2 | Generated handler `HandleUpdate` kept, `OnExecute` kept | met | `AccountDefaultDescription.cs:20,28,31,55`. Checks "src contains /HandleUpdate/" and "/OnExecute/". |
| M3 | The placeholder `FilterOn(e => e.Id /* TODO */)` fails the build with VELA001, then is replaced by `e => e.Name` | **partly met** | Replaced: yes (`AccountDefaultDescription.cs:25`; check "step registered: Update ... filter=['name']"). **Build failing on VELA001: never observed.** The placeholder was edited before the first build: Canvas lines 102-104 list it in the alignment after `add step`, and Run trace #4 shows the first build at 0 warn / 0 err. No VELA001 line appears anywhere in the artifacts. |
| M4 | Stage PreOperation on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:23,31,35,51` (`IUpdatePreContext`, `target.AccountNumber = upper`). Check "no UserService write-back". The tests assert `Assert.Empty(crm.GetAll(...))` (`Tests.cs:38`). |
| M5 | Harness states the trigger in every test; the Create tests are updated and green | met | `Tests.cs:19` `.OnCreate().Stage(PluginStages.PreOperation)` and `Tests.cs:35` `.OnUpdate().Stage(...)`. The pipeline tests derive the trigger from a real Update. Check "tests re-run green" (13/0). |
| SC1 | Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step | met | Canvas `account-number-uppercase.md:22` and `:20-21`. |
| SC2 | Build fails first on VELA001 (seen and fixed), then green with no VELA00x in authored code | **not met** | The "green with no VELA00x" half is met (check "no VELA diagnostics", Build Report line 112). The "fails first on VELA001 (seen)" half has no evidence. The first recorded build was already clean (Run trace #4), and the actor's report does not claim to have seen VELA001. |
| SC3 | RED then green: name changed means uppercased; name unchanged means step not run; Create cases still pass | met | RED 1 `Failed: 4` → GREEN (Build Report lines 114-119). Uppercased: `Tests.cs:46,54,121`. Name unchanged or not sent: `Tests.cs:87` (same value) and `Tests.cs:111` (`PluginPipeline`, `Assert.Empty(p.ExecutionLog)`). Create: `Tests.cs:25-27`, green in the check re-run. A null account number stays null (human answer): `Tests.cs:70,78`. |
| SC4 | `vela-code-review` PASS | met | Build Report lines 124-129: an isolated reviewer returned PASS, 0 Critical / 0 Required, with the 5 Nits listed. The reviewed diff is `r1/review-diff.txt`. The reviewer's raw output is not saved separately. |

## Planted-violation results
The scenario has no "Planted-violation check" section, so this does not apply.

## Findings against the skills
1. **blocker** (for this criterion): `skills/vela-scaffold/SKILL.md` step 5 says "`vela add step` emits a `FilterOn(e => e.Id /* TODO */)` placeholder that **fails the build with VELA001** ... - replace it with the column that gates the step". It puts this inside "Align the scaffolded registration with the Canvas", before any build step.
   - What happened: the actor followed that instruction literally. It replaced the placeholder pre-emptively, together with the stage and context edits, and its first build was already clean.
   - Result: the VELA001 failure the scenario requires as evidence ("seen and fixed") was never produced.
   - Correct path, either of:
     - The skill tells the agent to build immediately after `vela add step` and record the VELA001 line as evidence, before aligning. That follows "Evidence over claims" in `AGENTS.md`.
     - Or the scenario accepts a pre-emptive replacement plus a recorded clean build.
   - As written, the skill and the success criterion contradict each other.
2. minor: `ctx.HasChanged` semantics are undocumented in the pack. `references/plugin-authoring-api.md`, `references/dataverse-gotchas.md` and `skills/vela-plugin-authoring/SKILL.md` never mention it (grep: 0 hits).
   - The actor found through a failing test (RED 2, `Name_changed_only_in_case_counts_as_a_change`) that `ctx.HasChanged` treats a case-only difference as unchanged.
   - It replaced the call with an ordinal pre-image comparison (`AccountDefaultDescription.cs:34-36`).
   - "When the column changes" is a common story shape, so the pack should state what `HasChanged` compares: case, null vs `""`, and whether it needs a pre-image.
3. minor: the review evidence is only a summary. `vela-code-review` and the Build Report template do not require the reviewer's verbatim output to be persisted. Here the only record of the PASS is the builder's transcription in the Build Report (lines 124-129), so a grader cannot distinguish a real isolated review from a claimed one. Suggest saving the reviewer's raw verdict, for example under `docs/vela-builds/<slug>.review.md`, or embedding it verbatim.

## Verdict
**fail**. The checks pass (17/17). The grader fails on SC2 (and the matching must-get-right item M3): the VELA001 build failure after `vela add step` was never observed. Every other criterion is met with artifact evidence.

The next run must re-check whether the agent builds after `vela add step` and records the VELA001 line. That depends on resolving finding 1: either change the skill order, or relax the criterion.
