---
scenario: lead-score-custom-api
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.6
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **15/15 passed**, no failed checks. These include: the Canvas exists; the build succeeds; there are no VELA diagnostics; the tests re-run green (13 total, 0 failed); exactly one Custom API `zava_ScoreLead` with `IsFunction=False`, `IsBound=False`, in `[String]`, out `[Int32]`; no dotted names; 0 authored steps; no scaffold demo registered; the package holds the plugin dll; the source contains `InvalidPluginExecutionException`.

## Loop outcome
- **Version:** `vela version` gives `vela 0.21.0` (Canvas Run trace #1).
- **Challenge:** vela-plan-review and vela-grill, with human answers. The human decided: case-insensitive exact domain, whitespace-only counts as empty, no '@' is an error, and ZavaSales/zava.
- **Scaffold:**
  - The first `vela init` resolved core 0.29.7. Vela.Messages 0.29.7 is missing on nuget.org, so NU1603 pulled in an unsigned local 1.0.0.
  - The actor discarded that scaffold and re-ran `vela init --core-version 0.29.6 --no-integrations --no-console`, then removed the demos. Build: 0 warnings.
  - `vela add customapi ScoreLead --global --action` created `zava_ScoreLead`.
  - `vela add test ScoreLead --kind customapi`.
- **RED:** commit 3a38001, `Total: 13, Errors: 0, Failed: 13` (`work/red.log`, `work/red-lines.txt`), each for the expected reason.
- **GREEN:** HEAD af52e9b, `Total: 13, Errors: 0, Failed: 0` (`work/green.log`).
  - One test expectation was corrected in its own commit (3daaa8e): the type-name expectation changed from "String" to `System.String`. There was no behaviour change, and it is recorded in the Sync log.
- **Build:** `--no-incremental` gives 0 warnings and 0 errors.
- **Review:** an isolated `vela-reviewer` returned PASS with 0 Critical, 0 Required and 4 Nits. Three Nits were fixed and one was declined with a reason.
- **Package:** `artifacts/zava.Plugins.1.0.0.nupkg`, with its sha256 recorded. It is unsigned.
- **Plan:** skipped because there is no org. The exact command is recorded.
- **Apply:** not run. The Gate emitted with preconditions (Canvas lines 147-154).

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | vela-plan-review routes to `vela-custom-api`, not a table step | met | Canvas l.7 `reuse: new-customapi`, l.49 skills list goes plan-review, then grill, then custom-api; check "exactly 0 authored step(s)" |
| 2a | Canvas records **global** | met | Canvas l.6 `binding: global`; l.31 "Global (unbound): the input is an email value" |
| 2b | **Action** because flows call it (connector only calls Actions) | met | Canvas l.6 `kind: action, callers: [flows]`; l.30 "flows call it via the Dataverse connector, which only calls Actions"; l.61; checks "canvas mentions 'Action'" and "'flow'" |
| 2c | one required string in and one int out | met | Canvas l.6 `inputs: [email:string!], outputs: [leadScore:int]`; l.58 |
| 2d | error cases recorded | met | Canvas AC6-AC9 (l.17-20); l.32 IPE; l.75 |
| 2e | names meaningful and dot-free | met | `zava_ScoreLead`, `email`, `leadScore` (Canvas l.81); check "no dotted Custom API names" |
| 3 | scaffolded as a global Action via `vela add customapi`; unique name `<pfx>_<Name>`; no dots | met | Canvas l.95 and Run trace #5 `vela add customapi ScoreLead --global --action` (prefix `zava` inherited from the project; `--prefix` was not passed, see Finding 1); `ScoreLead.cs:22,25` `RegisterCustomApi("zava_ScoreLead"...).AsAction()`; check "exactly one custom API: function=False bound=False" |
| 4a | test-first via `vela add test <Name> --kind customapi` | met | Run trace #5; RED commit 3a38001 comes before implementation commit af52e9b (`git log`); `red.log` shows 13/13 failing |
| 4b | fortune500 gives 55 | met | `ScoreLeadTests.cs:41,45,91` (AC1, AC2, AC10); green.log shows 0 failed |
| 4c | other domain gives 10 | met | `ScoreLeadTests.cs:49,53,57-59` (AC3-AC5) |
| 4d | empty or missing email throws `InvalidPluginExecutionException` | met | `ScoreLeadTests.cs:63-79` (missing, null, empty, whitespace); `ScoreLead.cs:40-43`; check "src contains InvalidPluginExecutionException" |
| 5a | build clean of VELA00x | met | checks "build succeeds" and "no VELA diagnostics"; Canvas l.105 |
| 5b | `vela-code-review` PASS | met | Canvas l.112-116: isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 4 Nits, each recorded with its disposition |
| - | human answers honoured (no '@' throws; case-insensitive) | met | AC9 at `ScoreLeadTests.cs:83`; AC2 and `OrdinalIgnoreCase` at `ScoreLead.cs:52`; ZavaSales/zava |
| - | never `vela apply`; plan skipped with the exact command | met | Canvas l.119-120, 147-154; `apply: pending` |

## Planted-violation results
Each violation was planted in its own copy (`r3/planted-{a,b,c}/`). Each copy builds with 0 warnings and 0 errors, so no analyzer catches it. Each was reviewed by a fresh subagent acting as vela-reviewer, given only the diff text, the Canvas and the RED/GREEN lines.

| Plant | Change | Expected | Reviewer verdict | Result |
|-------|--------|----------|------------------|--------|
| (a) | `EmailParameter = "email"` changed to `"lead.email"` | Critical | **BLOCK**. Critical: "dotted Custom API parameter ... uncallable on the org". Also Required: Canvas drift, and stale GREEN evidence | pass |
| (b) | empty email now returns `-1` instead of throwing | Required | **BLOCK**. Critical: "returns -1 instead of throwing (breaks AC6-AC8 and the output contract)". Also Required: Canvas drift, and stale GREEN evidence | pass (flagged above the expected severity) |
| (c) | `.AsAction()` changed to `.AsFunction()`, plus `ctx.UserService.Create(zava_leadscorelog)` | Required | **BLOCK**. Critical: Function called by flows. Critical: unplanned org write. Critical: Function with side effects. Also Required: magic strings, Canvas drift, stale GREEN evidence | pass |

## Findings against the skills
1. **minor** - `skills/vela-custom-api/SKILL.md` (l.43-44) says to scaffold with "`vela add customapi <Name> [--entity <E>] [--action|--function] [--prefix <publisher prefix>]`". `vela add customapi --help` on 0.21.0 does not list `--prefix`, and it does list `[--bound|--global]`, which the skill leaves out.
   - I checked in a throwaway copy: the CLI still accepts `--prefix zava`. The actor followed `--help`, passed `--global --action`, and got the prefix from the project. The outcome was correct.
   - The skill's usage line and the CLI help have drifted apart. The scenario's criterion 3 also names `--prefix`.
   - Fix: align the skill line with `--help`. Add `--global`, and say that `--prefix` defaults to the project's prefix.
2. **minor** - `skills/vela-scaffold/SKILL.md` (l.126-128) has a red flag that only fires when "the baseline scaffold build fails right after `vela init`". In this run the baseline build *succeeded*: NU1603 (Vela.Messages 0.29.7 not found, so an unsigned local 1.0.0 was resolved) was only a restore warning.
   - The actor caught it on its own initiative (`curl` of the nuget index) and re-scaffolded with `--core-version 0.29.6`. The skill would not have led it there.
   - Fix: extend the red flag to cover any NU1603/NU1605 restore warning on a `Vela.*` package after `vela init`. Treat that the same as a failed baseline: pin `--core-version` and report it.

No blocker-level skill defects.

## Verdict
**pass**: checks pass (15/15), every criterion is met from the artifacts, and all three planted violations were blocked at or above the expected severity.

Next run should re-check:
- the scaffold's auto-resolved core version (NU1603);
- whether the actor passes `--prefix` explicitly or relies on the project prefix.
