---
scenario: account-default-description
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **15/15 passed**, `pass: true`. No failed checks. Highlights: build succeeds, no VELA
diagnostics, tests re-run green (total=19 failed=0), exactly 1 authored step
`Create account PreOperation/Synchronous filter=['name']`, no scaffold demo registered, no
`UserService.(Update|Create)(` in src, no `ColumnSet(true)`, package holds the plugin dll.

## Loop outcome
- `vela version` -> 0.21.0 (Build Report run trace row 1; no raw log in `work/`).
- Grill: human answers recorded ("empty" = null/""/whitespace; ZavaSales/zava) - Canvas `decisions`.
- `vela init` unpinned resolved Vela.Plugins 0.29.4 + NU1603 (Vela.Testing 1.0.0 from local cache); discarded,
  re-scaffolded with `--core-version 0.29.3` (commit 8a8a5d9). Demos removed (d5a3d3f).
- `vela add plugin ... --message Create --filtering-attributes Name` (c683bec), stage switched to PreOperation.
- No-org stand-in `Account.Description`, labelled (456e608).
- RED tests committed alone (88e5b28), handler still the TODO stub. **Grader re-ran RED independently**
  (clone at 88e5b28, `dotnet build -c Release` 0 errors/0 warnings, mono xunit `-parallel none`):
  `Total: 19, Errors: 0, Failed: 12` - exactly the 12 behaviour cases; guards passed.
- Implement (973809d, a7f4795) -> GREEN 19/19 (confirmed by checks.json re-run).
- Review: two isolated vela-reviewer passes, PASS, Nits only. Package built, unsigned; `vela plan` skipped (no org)
  with the exact command recorded; no `apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | `vela init` + `vela add plugin` + `vela add test` exit 0, per `vela-scaffold` | met | Build Report run trace rows 4,5,7 (exit 0); git commits 8a8a5d9 (init output), c683bec (add plugin output); check "solution found" |
| 2 | Handler per `vela-plugin-authoring` (`EntityPluginBase`/`OnExecute`/`ctx.Request.Target`), no magic strings | met | `src/zava.Plugins/Account/Plugins/AccountDefaultDescriptionPlugin.cs:8` (`EntityPluginBase<Account>`), `:23` (`OnExecute(ICreatePreContext<Account>)`), `:25` (`ctx.Request.Target`), `:28,34` typed `Description`; default in a named const `:11` |
| 3 | Test-first: RED before handler, then green, OS-correct runner, real harness API | met | git: 88e5b28 tests-only with stub handler, 973809d implementation; grader-reproduced RED 12/19 fail with mono xunit `-parallel none`; GREEN via checks "tests re-run green"; harness API `PluginContext.For<Account>().WithTarget().WithOrganizationService().Execute(...)`, `PluginPipeline.Empty().Register<>()` (tests `:101,153`) |
| 4 | `dotnet build` green + no VELA00x | met | checks "build succeeds", "no VELA diagnostics"; grader RED-commit build 0 warnings |
| 5 | null / whitespace -> defaulted; non-empty -> untouched | met | tests AC1-AC4 (`:19-75`), AC5 (`:78-91`, incl. padded text not trimmed), pipeline AC6 (`:95-131`); all green |
| 6 | PreOperation, sets on `ctx.Request.Target`, no `UserService.Update` | met | plugin `:16` `.PreOperation()`, `:34`; check "step registered: Create account PreOperation/Synchronous"; check "src must not contain UserService.(Update|Create)" |
| 7 | Canvas with acceptance cases + Build Report (harness pass, analyzers clean, cases checklist) per template | met | `docs/vela-builds/account-default-description.md:16-23` (AC1-AC7), `:45-47` (harness/analyzers/review), `:113-114` cases checklist, R-E-A-S-O-N-S sections `:56-95`, Gate `:153-164` |
| - | No-org note: labelled stand-in, `FilterOn(e => e.Name)` kept | met | `src/zava.Shared/Models/Generated/Account.cs:32-39` STAND-IN comment; plugin `:18` |
| - | Iteration 1/2 findings do not recur (harness API, Mono runner, authoring surface, mandatory FilterOn, no-org path, Id vs PrimaryEntityId) | met | tests set `Id = Guid.NewGuid()` on targets; pipeline tests use `Service.Create` returned id; no rediscovery visible in trace |
| - | Stop before apply | met | Build Report `apply: pending`, `plan_preview: skipped(no-org)`; no apply in trace |

## Planted-violation results
The scenario has no "Planted-violation check" section - none applied.

## Findings against the skills
1. minor - `skills/vela-scaffold/SKILL.md:126-128` red flag: "The **baseline scaffold build fails right after
   `vela init`** (an incompatible auto-resolved framework version): pin a known-good core with
   `vela init --core-version <v>`". Here the unpinned init resolved Vela.Plugins 0.29.4 with no published
   Vela.Testing 0.29.4, and NuGet silently substituted Vela.Testing 1.0.0 from the local cache (NU1603) - a
   version mismatch that is not necessarily a build *failure*. The actor caught it on its own; the skill
   should also flag NU1603 / a Vela.Plugins vs Vela.Testing version mismatch as a trigger for
   `--core-version`.
2. minor - evidence gap: `vela version` and the `vela init/add` exit codes exist only as rows in the Build
   Report run trace; `work/` holds no raw CLI logs. The "Evidence over claims" rule in `AGENTS.md` asks for
   output, and the Build Report template does not require the raw lines for scaffold commands. Not blocking
   (git history corroborates the scaffold), but the template could ask for the pasted exit/summary line.

## Verdict
**pass** - checks 15/15 and every success criterion met from artifacts; RED independently reproduced by
the grader. Next run must re-check the framework version resolution (0.29.4 / Vela.Testing gap) and
whether the actor again needs `--core-version`.
