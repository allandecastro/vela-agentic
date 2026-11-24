---
scenario: account-default-description
date: 2026-11-24
verdict: pass
campaign: 2026-11-24
run: 2/2
checks: pass
grader: pass
model: claude-sonnet-5.5
vela_cli: 0.33.0
framework: 0.44.0
runner: "copilot-cli actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), `--agent vela-builder`, pack installed as its Copilot surface.
Two turns: `copilot-turn1.md` (one numbered question message: solution + "empty"), `copilot-turn2.md` (after the
evaluator's answers, `work/logs/human-questions.md`). Re-run after r1 failed by scaffolding `tbd`; validates PR #131
(+ #132/#133). Not counted: repo hooks skipped, folder untrusted (`copilot-turn*.err`); eval shim blocks org writes.
`skill` loads: using-vela (l.57), vela-plan-review (l.81), vela-scaffold (l.308), vela-models (l.796),
vela-plugin-testing (l.866), vela-plugin-authoring (l.1158), vela-code-review (l.1263; l.1467 inside the reviewer task),
vela-apply (l.1583). Not loaded: vela-grill.

## Checks
19/19 passed (`checks.json`). Step: Create `account` PreOperation/Synchronous, filter `[name, description]`; plan creates
only package + `AccountPlugin`.

## Loop outcome
- `vela version` → 0.33.0 (l.111). No PROJECT.md. Q1 asked **before any scaffold** (l.255): solution unique name +
  "empty" meaning, with a proposed default. Answer logged (l.283).
- `vela solution show ZavaSales --json --url ...` → `{"solution":"ZavaSales","publisherPrefix":"zava"}`, exit 0 (l.285-290).
- `vela init ZavaSales --prefix Zava --publisher-prefix zava --solution ZavaSales -o .` (l.555), exit 0.
- `vela models --entities account --project src/Zava.Shared/Zava.Shared.csproj --url ...` exit 0 (l.815-819).
- `vela add plugin AccountPlugin ... --stage PreOperation --mode Sync --filtering-attributes Name,Description --handler OnDescriptionDefault`
  + `vela add test AccountPlugin --kind plugin --project tests/Zava.Plugins.Tests/...` (l.832). Canvas + ACC-001 committed first (1dc088a).
- RED: Mono xunit console `-parallel none` `Total: 7, Errors: 0, Failed: 5` (l.1104), committed 787c95f before the handler (f0af652).
- GREEN `Total: 7, Errors: 0, Failed: 0` (l.1217); Release build 0 warnings / 0 errors.
- spec-check 0 failures; `vela-reviewer` dispatched as a task (l.1460): PASS, 2 Nits.
- `dotnet build -c Release` → `artifacts/zava_Zava.Plugins.1.0.0.nupkg` (sha256 recorded, unsigned);
  `vela plan -p ... --solution ZavaSales --url ... --detailed-exitcode --out .vela-runs/.../plan.json` → exit 8,
  create package + step, diagnostics `[]` (l.1630-1645). Stopped before apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| SC1 `vela init` + `vela add plugin` exit 0; tests in the scaffold `.Tests` project | met | l.555, l.832; `tests/Zava.Plugins.Tests/Account/Plugins/AccountPluginTests.cs` (test class via `vela add test` into the existing project, per `vela-plugin-testing` step 1) |
| SC2 real surface, no magic strings where a model exists | met | `AccountPlugin.cs:9` `EntityPluginBase<Account>`, `:17` `FilterOn(e => e.Name, e => e.Description)`, `:28` `ctx.Request.Target`, `:29-31` typed `Description` |
| SC3 test-first RED→GREEN, OS-correct runner, real harness | met | RED l.1104 (5 failed: C1, C2, C3, C5, C6) committed 787c95f before f0af652; Mono `-parallel none`; `PluginPipeline` |
| SC4 build green, no VELA00x | met | checks "build succeeds", "no VELA diagnostics" |
| SC5 null / ""/ whitespace defaulted; non-empty untouched | met | tests C1, C2, C3, C5 / C4; check "tests re-run green" 7/7; mutation 2/2 killed |
| SC6 PreOperation, sets Target, no `Service.Update` | met | check "step registered ... PreOperation"; "src must not contain Service.Update"; `AccountPlugin.cs:31` |
| SC7 Canvas with cases + Build Report (harness, analyzers, cases) per template | met (minor gaps) | `docs/features/account-default-description/README.md` l.19-26 cases C1-C7; Build Report l.57-63 harness pass, analyzers clean, "Cases C1-C7 all covered", plan exit 8; Gate l.65-66. Gaps: no build front-matter keys (`harness:`, `plan_preview:`, `package_sha256:`...), no per-case [x] list, no RED failing test names (finding 3) |
| Ask vs assume: solution / publisher prefix | met | Asked before `vela init` (l.255), prefix then read with `vela solution show` exit 0 - not guessed; Canvas `decisions: by: human` l.28-29 |
| Ask vs assume: "empty" | met | Asked with a proposed default; answer matches the key (null, "", whitespace) |
| One question per decision | met | One message, two numbered load-bearing decisions, one-line answers each (`vela-grill` l.29, l.64) |
| Preview on the final package | met | `vela plan` on `zava_Zava.Plugins.1.0.0.nupkg` after review, exit 8, diagnostics `[]` |
| Stop before apply | met | no `vela apply`; human command in the Gate section |

No planted-violation section in the scenario.

## Mutation
2/2 killed (`AccountPlugin.cs:29` negate if, `:31` drop assignment). No survivors.

## Did #131 hold?
Yes. `skills/vela-scaffold/SKILL.md` l.36-38 ("With a human reachable, an unknown name or exit `4` ... is **asked** (one
question) before `vela init`. Only with **no human reachable** ... `tbd`") was read at l.196-199 and followed: the actor
asked at l.255, never probed `tbd`, and scaffolded with the answered `ZavaSales` / `zava`. The review-checklist Required
rule was not exercised (the question was asked).

## Findings
1. minor - `skills/vela-code-review/SKILL.md` l.43 "append its verbatim output" / `agents/vela-builder.agent.md` l.44
   "save its verbatim output": `.vela-runs/.../review.md` is headed "verbatim summary" and is a 6-line paraphrase of the
   reviewer's long output (l.1470-1520). Fourth Copilot run in a row; the rule is clear, so this needs an enforceable form
   (e.g. "redirect the reviewer's reply to review.md unchanged; a summary is not the review") or a spec-check probe.
2. minor - `agents/vela-reviewer.agent.md` l.11 "Follow `vela-code-review` and `references/review-checklist.md`": the
   reviewer said "I did not open the source files or the checklist references" (l.1468) and still passed. The checklist
   is where #131's Required rule lives; a reviewer that skips it would miss it. Make reading the checklist a stated first
   step of the reviewer (or require naming the checklist items checked).
3. minor - `agents/vela-reviewer.agent.md` l.45-46 ("Missing ... RED/GREEN lines (failing test names verbatim) ... or Run
   trace: **BLOCK**"): no `.vela-runs/<slug>/trace.md` exists and the Build Report gives only "RED seen first: 5 failed",
   yet the reviewer wrote "RED and GREEN lines are present ... Run trace present". The builder's task prompt is not in the
   transcript, so it may have been passed inline; unverifiable. The builder skipped `agents/vela-builder.agent.md` l.65
   ("Keep the **Run trace** current in `.vela-runs/<slug>/trace.md`").
4. minor - `skills/vela-plan-review/references/build-report-template.md` l.114-133, l.142: the Build Report kept the
   Canvas front matter but added none of the build keys and collapsed the cases checklist to one line. Same as r1 finding 4;
   low impact.
5. note (not counted) - repo hooks skipped (untrusted folder); two shell calls denied for lack of an interactive approver
   (l.607, l.668) - the actor retried in smaller commands, no harm. No AI trailer in the commits (`grep -ci co-author` = 0).

## Verdict
pass - checks 19/19, every criterion met, mutation 2/2. The r1 blocker (scaffolding `tbd` without asking) is closed by
#131: the actor asked the solution before `vela init` and previewed on the real solution. Remaining items are minor
evidence-hygiene gaps (review.md paraphrased, no trace.md, reviewer skipped the checklist).
