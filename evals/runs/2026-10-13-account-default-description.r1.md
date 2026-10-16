---
scenario: account-default-description
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed**, no failed check. Highlights: build succeeds, no VELA diagnostics, tests
re-run green (total=8 failed=0), step registered Create/account/PreOperation/Synchronous filter=[name],
exactly 1 authored step, no `Service.Update/Create` in src, package holds the dll, `vela solution show`
ZavaSales/zava, read-only `vela plan` runs and creates only the authored package + step.

## Loop outcome
- `vela version` -> 0.25.0 (exit 0); one question to the human (setup conflict: "no org" vs read-only dev org; solution; whitespace) -> answered.
- `vela solution show ZavaSales --json` -> `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0).
- `vela init --name ZavaSales --prefix Zava --publisher-prefix zava -o .` (exit 0, minimal scaffold with `tests/Zava.Plugins.Tests`).
- `vela models --entities account ...` (exit 0, 4 generated files); `vela add plugin ... --filtering-attributes name` (exit 0); `vela add test ... --kind plugin` into the existing test project (exit 0).
- RED commit 43bc9c6 (tests only, handler TODO): mono xunit.console 2.9.2 `-parallel none` -> Total 8, Failed 5 (exit 1).
- GREEN commit b60349f: Total 8, Failed 0. `dotnet build -c Release --no-incremental`: 0 warnings, 0 errors.
- Review: self-review (subagent limit, documented fallback) -> PASS, 0 Critical / 0 Required / 4 Nits (2 fixed).
- `dotnet build -c Release` -> `artifacts/Zava.Plugins.1.0.0.nupkg` (sha256 recorded); unsigned, `signed: unknown` as open question.
- `vela plan ... --detailed-exitcode` -> exit 8 (changes: create package + 1 step). Stopped at the apply gate; no apply.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | `vela init` + `vela add plugin` exit 0 per `vela-scaffold`; tests in the scaffold's `.Tests` project | met | `work/review/evidence.txt` lines 3-6; git e71353b (scaffold with `tests/Zava.Plugins.Tests`), tests at `tests/Zava.Plugins.Tests/Account/Plugins/AccountDefaultDescriptionTests.cs`. `vela add test` added a test *class* to the existing project, as `skills/vela-test-harness/SKILL.md` step 1 instructs (the rubric's "only when none exists" wording predates that step). |
| 2 | Handler per `vela-plugin-authoring` (`EntityPluginBase` / `OnExecute` / `ctx.Request.Target`), no magic strings where a model exists | met | `src/Zava.Plugins/Account/Plugins/AccountDefaultDescription.cs`: `EntityPluginBase<Account>`, `Handle(OnExecute)`, `ICreatePreContext<Account>`, `ctx.Request.Target.Description`, `FilterOn(e => e.Name)`; generated `Account` model. Only the default text literal, held in a constant. |
| 3 | Test-first: RED before implementation, then green, OS-correct runner, real harness API | met | Git history: 43bc9c6 (tests only) precedes b60349f (logic). **Grader re-ran RED independently** on a clone at 43bc9c6: mono xunit.console 2.9.2 `-parallel none` -> `Total: 8, Errors: 0, Failed: 5` (AC1-AC4 + AC6 default). Green: checks.json "tests re-run green" total=8 failed=0. Harness: `PluginContext.For<Account>().WithTarget().WithOrganizationService().Execute(...)` and `PluginPipeline.Empty().Register<>()`. |
| 4 | `dotnet build` green, no VELA00x | met | checks "build succeeds", "no VELA diagnostics"; Build Report line 92. |
| 5 | null / whitespace -> defaulted; non-empty -> untouched | met | Tests AC1 (not sent), AC2 null, AC3 "", AC4 "  \t  ", AC5 "Key customer" untouched; pipeline AC6 both directions; AC7 Update does not fire (`Assert.Empty(ExecutionLog)`). |
| 6 | PreOperation, sets default on `ctx.Request.Target`, no `ctx.Service.Update` | met | Plugin `.PreOperation()`, `target.Description = DefaultDescription`; check "src must not contain Service.(Update\|Create)"; tests assert `Assert.Empty(crm.GetAll("account"))` (no extra write). |
| 7 | Vela Canvas (acceptance cases) + Build Report (harness pass, analyzers clean, cases checklist) per template | met | `docs/vela-builds/account-default-description.md`: front-matter `acceptance_cases` AC1-AC7 (l.17-24), `harness: pass`, `analyzers: clean`, `review: pass` (self-review labelled), REASONS Canvas (l.48-78), cases checklist (l.93-94), run trace, gate with hash + exact apply command. |
| - | Known findings closed (iteration 1/2: harness API, Mono runner, authoring surface, mandatory Create FilterOn, target.Id vs PrimaryEntityId) | met | No rediscovery in the trace; FilterOn(Name) with the VELA020 comment; correct runner first time. |
| - | Stop before apply | met | Build Report `apply: pending`, `status: awaiting-apply`; no apply in evidence. |

## Planted-violation results
The scenario has no "Planted-violation check" section - none applied.

Self-review quality (evaluator note): adequate. It ran both axes, found only Nits, and the two kept Nits
(`"description"` logical-name string in pipeline read-back assertions; unused `using Vela.Constants;` from
the scaffold) are genuinely cosmetic. Grader found nothing Critical/Required that it missed.

## Findings against the skills
None blocking. No defect of the skill pack surfaced in this run.

1. minor (evaluator, not the pack) - `evals/scenarios/account-default-description.md` success criterion 1 says
   "`vela add test` only when none exists", while `skills/vela-test-harness/SKILL.md` step 1 says "Add a test
   class with `vela add test <Name> --kind plugin ...`, run inside the test project". The actor followed the
   skill; the rubric wording should say "tests live in the scaffold's .Tests project (a test class via `vela add test`)".
2. minor (evaluator, already noted as fixed) - the Setup/frontmatter conflict (`org_required: false` vs the read-only
   dev org) cost the actor one human question; the actor resolved it correctly.

## Verdict
pass - 19/19 checks and every criterion met, RED independently reproduced by the grader. Next run must
re-check: RED commit precedes logic, PreOperation Target edit (no write-back), and the whitespace case.
