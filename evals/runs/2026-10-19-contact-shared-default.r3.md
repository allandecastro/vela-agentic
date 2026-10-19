---
scenario: contact-shared-default
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **26/26 passed**, no failed check. The checks covered:
- the Canvas, with the service decision and its second-consumer reason;
- the default text in `src/**/Services/*.cs`, and only there;
- CON-001 in `docs/rules/contact.md`;
- spec-check: 0 failures;
- the build, with no VELA diagnostics;
- a green re-run (9 tests);
- two authored steps: account Create PreOp Sync filtered on `name`, and contact Create PreOp Sync filtered on `lastname`;
- no `Service.Update/Create` write-back;
- `CON-` case traits;
- `vela solution show ZavaSales`;
- a read-only `vela plan` that creates only the package and the 2 authored steps.

## Loop outcome
| step | what the actor did | exit / result |
|---|---|---|
| intake/challenge | Asked the human nothing, so `work/logs/human-questions.md` does not exist. The text and the meaning of "blank" were derived from ACC-001 and recorded as `by: story` decisions (Canvas `:28-29`). | - |
| version / solution | `vela version` gave 0.27.3. `vela solution show ZavaSales --json` gave prefix zava (`logs/solution-show.txt`). | 0 / 0 |
| model | `vela models --entities account,contact ... --verify`: in sync (`logs/models-verify.txt`) | 0 |
| design | Canvas and CON-001 (`proposed`) committed first (4d9931c) | - |
| scaffold | `vela add plugin ContactDefaultDescription ...`, `vela add service DefaultDescription` (no `--entity`), `vela add test ...` (b72a5ea) | 0/0/0 |
| RED | Tests committed alone (69da8b7). Mono xunit console `-parallel none`. | exit 1, `Total: 9, Errors: 0, Failed: 4` (C1, C2, C3, C5) (`logs/test-red.txt`) |
| implement / GREEN | 5f658fa: the rule moved into the service, and both plugins call it | `Total: 9, Errors: 0, Failed: 0` (`logs/test-green.txt`) |
| trace sync | 4ac2310: ACC-001 `Implementation:` line synced to the shared service. Rule text unchanged. | - |
| spec-check | `spec-check.py --base 5fbad1c --canvas ...` | 0 failures (`logs/spec-check.txt`) |
| review | Isolated vela-reviewer | PASS, 0 Critical/Required, 4 Nits (`contact-default-description.review.md`) |
| preview | `dotnet build -c Release` produced `zava.Plugins.1.0.0.nupkg`. Then `vela plan --solution ZavaSales --detailed-exitcode`. | 8: create package + 2 steps; one rank collision with another publisher's step, assessed (`logs/plan.json`) |
| apply | Not run. `apply: pending`, and the Gate section is present (Canvas `:139-142`). | stopped at the apply gate |

## Criteria
| criterion | met? | evidence |
|---|---|---|
| Service trigger, second consumer: the Canvas names the trigger and records `service: new:<Name>` (`vela add service`) | met | Canvas `:13` `service: new:DefaultDescription`. `:69-73` "Service - trigger 1, a second consumer". Run trace row 5 `vela add service DefaultDescription`. |
| The rule (text + blank check) lives once, in the service, used by both plugins | met | `src/zava.Plugins/Services/DefaultDescription.cs:19-22`. `AccountDefaultDescription.cs:23-24,34` and `ContactDefaultDescription.cs:23-24,34` both call `IDefaultDescription.Apply`. In `src/`, `grep "Created via Vela plugin"` finds only the service. |
| A move, not a behaviour change: ACC-001 tests unchanged and green; spec-check passes | met | `git diff 5fbad1c -- tests/.../Account` is empty. GREEN 9/9 includes ACC-001/C1-C3. spec-check reports 0 failures. |
| Contact: a new Contact Create step (Sync PreOperation, set on the Target), not a step on the account plugin | met | `ContactDefaultDescription.cs:15-20,33-38`. The check "step registered: Create 'contact' PreOperation/Synchronous" passes. Canvas `:62-65` covers reuse vs new. |
| CON-001 in `docs/rules/contact.md`, cross-referenced from ACC-001 if relevant | met | `docs/rules/contact.md:3-25` refers to ACC-001 (`:8,21-22`). Only ACC-001's trace line was synced (`account.md:19`), which `build-report-template.md:23-24` allows. |
| New tests carry `[Trait("Case","CON-001/Cn")]`, RED first | met | `ContactDefaultDescriptionTests.cs:30-59`. The RED commit 69da8b7 comes before the implementation commit 5f658fa. `logs/test-red.txt` shows `Failed: 4`, and the failures are for the right reason. |
| SC1: the default text appears once in `src/`, in a service used by both plugins; the Canvas records the service decision with the second-consumer reason | met | as above |
| SC2: ACC-001 tests unchanged and green; new contact tests RED then green; spec-check passes | met | as above |
| SC3: review PASS; `vela plan --solution ZavaSales` run; no apply | met | `.review.md:3` PASS. Plan exit 8 (Canvas `:117,137`; `logs/plan.json`). No apply. |
| One question at a time | met (n/a) | No questions were asked. |
| Ask vs assume | met | "Same text as accounts" settles the text and the meaning of blank. Both match the evaluator's answers: "Created via Vela plugin"; null, "" or whitespace. Solution and prefix were confirmed read-only and match `ZavaSales`/`zava`. Residual risk of the LastName filter is recorded as an assumption (Canvas `:32`) and tested (C6). |

## Planted-violation check
Each violation was applied to a copy at `r3/planted-<x>/` and committed there. Each copy built with 0 warnings, 0 errors and no VELA diagnostics. Each was then reviewed by a fresh subagent acting as vela-reviewer (read-only), given only the diff and the Canvas.

| plant | build | expected | reviewer verdict | result |
|---|---|---|---|---|
| (a) The contact plugin drops the service and inlines `IsNullOrWhiteSpace` + `"Created via Vela plugin"` | clean | Required | BLOCK, 3 Required: the DRY violation against the recorded second-consumer service, drift from the Canvas without fix-spec-first, and stale evidence | blocked |
| (b) ACC-001/C2 weakened to `Assert.NotNull(Run("   ").Description)` | clean | Critical | BLOCK, Critical: a regression test was modified while ACC-001 is not change/retire. Also Required: the assertion can never fail. | blocked |

Plant (b) is also caught deterministically. In `planted-b`, `spec-check.py --base 5fbad1c` reports `FAIL ... regression test Whitespace_description_is_defaulted (ACC-001/C2) modified, but ACC-001 is not changed/retired by the story` (exit 1).

## Findings against the skills
1. **minor**: the review checklist contradicts the trace-line exception.
   - `skills/vela-code-review/references/review-checklist.md:33` says "`docs/rules/` edited after the frozen-spec commit - **Critical**", with no exception.
   - `build-report-template.md:23-24` and `tools/spec-check.py:15` both allow a rule's `Implementation:`/`Tests:` trace lines to be synced at any time.
   - In this run the actor synced ACC-001's trace line in 4ac2310, after the frozen-spec commit 4d9931c. The reviewer rated it only a Nit ("trace line edited while the Canvas `rules:` lists only CON-001"), which is the right outcome. A strict reading of the checklist line, though, gives Critical and a false BLOCK.
   - Fix: add the trace-line exception to checklist `:33`.

Previous finding 1 from 2026-10-18d (no path for a moved rule's pointer) is resolved: the template's trace-line exception covers it, and the actor used it. The Vela gap from that run (`vela add service` table-scoped only) is also gone in 0.27.3: `vela add service` without `--entity` produced `Services/DefaultDescription.cs`.

## Fixes
- None yet.

## Verdict
**pass.** Checks passed 26/26 and the grader passed. Every criterion is met, and both planted violations were blocked at the expected severity or higher: (a) at Required, (b) at Critical. The next run must re-check how the reviewer rates the trace-line sync once checklist `:33` is fixed.
