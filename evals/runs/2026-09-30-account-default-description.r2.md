---
scenario: account-default-description
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **15/15 passed**, no failed checks (canvas exists + mentions PreOperation, build succeeds,
no VELA diagnostics, tests re-run green total=11 failed=0, step registered Create/account/PreOperation/
Synchronous filter=[name], exactly 1 authored step, no demo registered, package holds plugin dll, no
`UserService.Update/Create`, no `ColumnSet(true)`).

## Loop outcome
- `vela version` -> 0.21.0 (Build Report run trace #1).
- `vela init --name ZavaSales --prefix zava --output . --no-integrations --no-console` -> 0, discarded: default
  core 0.29.4 made the test project resolve Vela.Testing 1.0.0 (NU1603). Re-init with `--core-version 0.29.3` -> 0.
- Demo components removed (commit 21ac051); Canvas committed (7de3e0c) before code.
- `vela models` skipped (no org); `account.description` added as labelled `STAND-IN for vela-models (no org)`
  (`src/zava.Shared/Models/Generated/Account.cs:32-39`).
- `vela add plugin AccountDefaultDescriptionPlugin --entity Account --message Create --filtering-attributes Name` -> 0;
  PostOperation -> PreOperation, `ICreatePostContext` -> `ICreatePreContext` (commit 5fc4068).
- `vela add test ... --kind plugin --entity Account` -> 0; RED commit afb645b; GREEN commit 872f4b9.
- Review #1 BLOCK (Required: solution existence as assumption) -> Canvas fix -> fresh review #2 PASS (Nits only).
- `dotnet build -c Release` -> package `artifacts/zava.Plugins.1.0.0.nupkg`, sha256 recorded, unsigned.
- `vela plan` skipped (no org), exact command recorded. No `vela apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | `vela init` + `vela add plugin` + `vela add test` exit 0, per `vela-scaffold` | met | Build Report run trace rows 4, 5, 7 (`docs/vela-builds/account-default-description.md:106-109`); untouched scaffold commit 4d84ba7; scaffolded test file present. No raw CLI logs were kept in `work/` - the trace is the only record of exit codes. |
| 2 | Handler per `vela-plugin-authoring` (`EntityPluginBase` / `OnExecute` / `ctx.Request.Target`), no magic strings where a model exists | met | `AccountDefaultDescriptionPlugin.cs`: `EntityPluginBase<Account>`, `RegisterStep().OnCreate().PreOperation().Sync().FilterOn(e => e.Name)...Handle(OnExecute)`, `ctx.Request.Target.Description` via typed property; stand-in labelled per no-org exception. |
| 3 | Test-first: RED before implementation, then green, OS-correct runner, real harness API | met | Commit order afb645b (tests, handler still TODO) -> 872f4b9 (impl). **Grader re-ran RED independently** (clone at afb645b, `mono xunit.console.exe ... -parallel none`): `Total: 11, Errors: 0, Failed: 7` - the 7 default-expected cases, matching Build Report line 88. GREEN: checks `tests re-run green` total=11 failed=0. Harness: `PluginContext.For<Account>().WithTarget(...).Execute(...)`, `PluginPipeline.Empty().Register<>()`, `InMemoryOrganizationService`. |
| 4 | `dotnet build` green, no VELA00x | met | checks `build succeeds`, `no VELA diagnostics`; Build Report line 86 `0 Warning(s) 0 Error(s)`. |
| 5 | null / "" / whitespace -> default; non-empty -> untouched | met | Tests `Create_DescriptionNotSent/SentAsNull/EmptyString/WhitespaceOnly(x3)` and `Create_DescriptionHasText_LeftUntouched(x2)`, pipeline cases; all green. |
| 6 | PreOperation, default on `ctx.Request.Target`, no `UserService.Update` | met | checks `step registered ... PreOperation/Synchronous` and `src must not contain UserService.(Update|Create)`; tests assert `crm.GetAll(account)` empty (no write). |
| 7 | Canvas (acceptance cases) + Build Report (harness pass + analyzers clean + cases checklist) per template | met | `docs/vela-builds/account-default-description.md`: front-matter `acceptance_cases` (8), `harness: pass`, `analyzers: clean`, `review: pass`; REASONS sections; Evidence with RED/GREEN counts and `[x]` checklist (line 90); apply gate + exact `vela plan`/`vela apply` commands. |
| - | Known findings closed (harness API, Mono runner, authoring surface; F1 FilterOn, F2 no-org stand-in, F3 target.Id) | met | No rediscovery: runner and harness API correct on first RED; `FilterOn(e => e.Name)` kept; stand-in labelled; harness sets `target.Id`. |
| - | Human answers honoured (empty = null/""/whitespace; ZavaSales/zava) | met | Canvas `decisions` lines 36-38. |

## Planted-violation results
The scenario has no "Planted-violation check" section - none applied.

## Findings against the skills
1. minor - `skills/vela-scaffold/SKILL.md:126-128` says "The **baseline scaffold build fails right after
   `vela init`** (an incompatible auto-resolved framework version): pin a known-good core with
   `vela init --core-version <v>`". In this run the default 0.29.4 scaffold did **not** fail - it built with a
   NU1603 warning while the test project silently resolved Vela.Testing/Vela.Plugins 1.0.0 against a shipped
   0.29.4 plugin. The actor caught it only by reading the restore warning. The red flag should also cover
   "restore warns NU1603 / the test project resolves a different Vela.* version than the plugin project",
   not only a failed build.
2. minor - the scaffold's generated handler TODO (commit afb645b, `AccountDefaultDescriptionPlugin.cs`) tells the
   author to "read the typed record with `ctx.GetTarget<Account>()`", while `vela-plugin-authoring` teaches
   `ctx.Request.Target`. The actor followed the skill, but `vela-scaffold` does not warn that the scaffold
   comment points at a different accessor (a CLI-template/skill mismatch worth a one-line note or a CLI fix).
3. minor (evidence retention, not behaviour) - the pack does not ask the actor to keep raw CLI/test logs in the
   work tree; exit codes for `vela init` / `vela add` exist only as the self-reported run-trace table. The grader
   had to re-run RED to verify it. `references/build-report-template.md` could require the raw runner summary
   lines to be saved (e.g. `docs/vela-builds/<slug>.log`).

## Fixes
- none yet.

## Verdict
**pass** - checks 15/15 and every criterion met from the artifacts; RED independently reproduced (7/11 failing
at afb645b), GREEN confirmed by checks. Next run must re-check: NU1603 / core-version pinning path and that the
actor still switches the scaffolded PostOperation to PreOperation.
