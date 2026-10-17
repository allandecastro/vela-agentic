---
scenario: account-update-recursion
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
`checks.json`: **19/19 passed**, `pass: true`. No failed checks. Highlights: step registered
`Update account PreOperation/Synchronous filter=['description']`, exactly 1 authored step, no
`Service.Update/Create` in src, no `ctx.Depth >` in src, tests use `PluginPipeline`, re-run tests
16/16 green, no VELA diagnostics, read-only `vela plan` runs and creates only the authored package + step.

## Loop outcome
- `vela version` -> 0.25.0; `vela solution show ZavaSales` -> prefix zava (exit 0).
- Canvas committed first (cd63ad7), then `vela init` (f736fad), `vela models` + `vela add plugin/test` (ea07ad7).
- RED commit 0866c6e (tests only; handler still the scaffold TODO): mono xunit `Total: 16, Failed: 10`, failing names listed in `work/review/evidence.txt`.
- GREEN commit 203df67: `Total: 16, Errors: 0, Failed: 0`; `dotnet build -c Release --no-incremental` 0 warnings / 0 errors.
- Review: self-review (subagent dispatch refused: concurrency limit, the documented fallback), PASS 0/0/2 Nits.
- `dotnet build -c Release` -> `artifacts/Zava.Plugins.1.0.0.nupkg`; `vela plan` exit 8 (changes: create package + 1 step). Stopped at the apply gate; no `apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | Canvas Approach records Sync PreOperation with the reason; recursion risk as a Safeguard | met | `docs/vela-builds/account-description-normalise.md:61-64` ("Sync PreOperation on Update ... one write, no extra Update event, nothing re-triggered ... no SkipWhenDepthAbove/Depth check"); `:80-81` Safeguards "recursion avoided by design (Target edit, no write-back)" |
| 2 | `OnUpdate().PreOperation().Sync().FilterOn(e => e.Description)`, value set on `ctx.Request.Target`, no `ctx.Service.Update`, no Depth return | met | `src/Zava.Plugins/Account/Plugins/NormaliseAccountDescription.cs:23-28` (step), `:33-39` (Target edit); checks "src must not contain Service.Update", "no ctx.Depth >", step-registered check |
| 3a | Test-first, RED then green | met | commit 0866c6e (tests only, handler TODO) RED 10/16 with failing names; 203df67 GREEN 16/16 (`work/review/evidence.txt`, Canvas `:95-99`) |
| 3b | `"  Hello   world  "` -> `"Hello world"` on the target | met | tests `:20` (PluginContext) and `:86-100` (pipeline) |
| 3c | Already-normal left as is | met | tests `:21`, `:146-157` |
| 3d | null / empty -> left as is, no exception | met | null: `:55-67`, `:132-143`. `""` -> null (`:41`) follows the human answer "whitespace-only is stored as null"; `""` and null are the same stored value in Dataverse, so "left as is" holds |
| 3e | No extra write reached the service | met (stronger form) | not the literal `Assert.Empty(crm.GetAll("account"))`, but `PluginPipeline` `Assert.Single(p.ExecutionLog)` at `Depth == 1` (`:94-98`): a write-back would show as a second run. `Pipeline_Does_Not_Fire_When_Description_Not_Sent` `Assert.Empty(ExecutionLog)` (`:125`) |
| 4 | Build green, no VELA00x in authored code, `vela-code-review` PASS | met | checks "build succeeds", "no VELA diagnostics"; `work/review/self-review.txt` VERDICT PASS (labelled self-review, the fallback is allowed by the evaluator note). The self-review is substantive: it checks each acceptance case, the filter-on-edited-column recursion question, and `static readonly Regex` against VELA011 |

## Planted-violation results
Each one: a copy of the actor's project in `r1/planted-<x>/`, the violation applied, built, and the diff (`planted-<x>/planted.diff`) plus the Canvas given to a fresh subagent acting as `vela-reviewer` (read-only).

| Planted | Build | Expected | Reviewer verdict | Result |
|---|---|---|---|---|
| (a) PostOperation + `ctx.Service.Update` of the same account | 0 warnings, 0 errors | Critical | **BLOCK**, Critical (self-trigger: the written Description is in `FilterOn`, loops to the depth cap); plus Required (Canvas drift, tests not re-run, anti-pattern in `registration-rules.md`) | pass |
| (b) (a) + `if (ctx.Depth > 1) return;` | 0 warnings, 0 errors | Critical | **BLOCK**, Critical (still writes twice and fires twice; Depth check skips legitimate nested callers); plus Required (Canvas drift, evidence missing) | pass |
| (c) mutable `lastDescription` field on the plugin | 1 warning VELA011 | Required | **BLOCK**, Required (VELA011 mutable state shared across executions); plus Required (Canvas drift / scope creep, evidence stale) | pass |

Note: the reviewer for (b) ran one `ls`/`grep` over the skill's references although told it was read-only. That came from the general-purpose subagent the grader used, not the pack's `vela-reviewer` (which has no shell tool). It changed nothing.

## Findings against the skills
None blocking, none minor attributable to the pack. Observations (not pack defects):
1. Observation (Vela, not the pack): planted (a) and (b) build with **0 analyzer diagnostics**. No VELA analyzer flags a PostOperation self-update of a column that is in the step's own `FilterOn`. Today only the review catches it, and it did. Flag this to the Vela repo as a possible analyzer gap; no change to the skills.
2. Actor-side nit, not a pack defect: Canvas Operations (`account-description-normalise.md:72`) writes the chain without `.Sync()`, but the code and frontmatter (`mode: Synchronous`) have it.

## Verdict
**pass.** checks 19/19 and every grader criterion is met. All three planted violations were blocked at the expected severity or higher. The next run should re-check that the step is still PreOperation with a Target edit, and that the no-re-trigger proof (pipeline single run, or an empty in-memory write) is still there.
