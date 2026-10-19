---
scenario: contact-shared-default
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **26/26 passed**, no failed check. The checks covered:
- the Canvas, which records the service decision and the second-consumer reason;
- the default text, which appears only in `src/zava.Plugins/Services/DescriptionDefault.cs`;
- CON-001 written as Given/When/Then;
- spec-check (0 failures);
- the build, with no VELA diagnostics;
- a green re-run (10 tests);
- exactly 2 authored steps:
  - account: Create PreOp Sync, filter `name`;
  - contact: Create PreOp Sync, filter `firstname`, `lastname`;
- no `Service.Update/Create` write-back;
- `CON-` traits;
- `vela solution show ZavaSales`;
- a read-only `vela plan` that creates only the package and the 2 authored steps.

## Loop outcome
| step | what the actor did | exit / result |
|---|---|---|
| intake | `vela version` | 0, vela 0.27.3 |
| challenge | Canvas and CON-001 (`proposed`) committed first (06273b6). There were no questions to the human (no `work/logs/human-questions.md`). Assumptions are flagged in the Canvas `:30-35` | advisory |
| solution | `vela solution show ZavaSales --json --url <org>` | 0, prefix zava |
| model | `vela models --entities account,contact ... --verify` | 0, in sync |
| scaffold | `vela add service DescriptionDefault` (shared, no `--entity`), `vela add plugin ContactDefaultDescription ...`, `vela add test ...` (3ca8d33) | 0/0/0, build 0 errors |
| RED | tests committed alone (05fe28e); Mono xunit `-parallel none` | exit 1, Total 10 / Failed 4 (C1, C2, C3, C5) (`logs/test-red.log`) |
| implement / GREEN | d172240: rule held in the service; both plugins use it; ACC-001 `Implementation:` trace line synced | Total 10 / Failed 0 (`logs/test-green.log`) |
| spec-check | `tools/spec-check.py --base main --canvas ...` | 0 failures (`logs/spec-check.log`) |
| review | isolated vela-reviewer | PASS, 0 Critical/Required, 4 Nits (`docs/vela-builds/contact-default-description.review.md`) |
| preview | `dotnet build -c Release` produced `artifacts/zava.Plugins.1.0.0.nupkg`; `vela plan -p ... --solution ZavaSales --detailed-exitcode` | 8: create package + 2 steps; 1 rank-collision diagnostic with a foreign step (assessed) (`logs/plan.json`) |
| apply | not run; Build Report `status: awaiting-apply`, with a Gate section | stopped at the gate |

## Criteria
| criterion | met? | evidence |
|---|---|---|
| Service trigger: the Canvas names the second-consumer trigger and records `service: new:<Name>` (`vela add service`) | met | Canvas `:13` `service: new:DescriptionDefault   # shared (no --entity) - trigger 1: a second consumer (account + contact)`; S section `:73-76`; run trace row 5 |
| Rule (text + blank check) held once, in the service, used by both plugins | met | `Services/DescriptionDefault.cs:18-23`; `AccountDefaultDescription.cs:22-23,32` and `ContactDefaultDescription.cs:22-23,32` both register and call `IDescriptionDefault`. The check "src contains /Created via Vela plugin/" finds only the service |
| A move, not a behaviour change: ACC-001 tests unchanged and green; spec-check passes | met | `git diff main --stat` does not touch `AccountDefaultDescriptionTests.cs`; GREEN 10/10 includes ACC-001/C1-C3; spec-check 0 failures. Handler semantics are identical (assign only when blank) |
| Contact: a new Create step (Sync PreOperation, set on the Target), not on the account plugin | met | `ContactDefaultDescription.cs:14-19,31-34`; check "step registered: Create 'contact' ..."; Canvas `:66-70` |
| CON-001 in `docs/rules/contact.md`, cross-referenced from ACC-001 if relevant | met | `docs/rules/contact.md:3-25`, which references ACC-001 at `:8,22`. ACC-001 only got its `Implementation:` trace line synced (`account.md:19`). The pack now allows that (`build-report-template.md:23-24`, spec-check `:15`) |
| New tests carry `[Trait("Case","CON-001/Cn")]`, RED first | met | `ContactDefaultDescriptionTests.cs:27-57`. RED commit 05fe28e comes before d172240, and `logs/test-red.log` shows Failed 4 for the right reasons |
| SC1 Default text once in `src/`, in a shared service; the Canvas gives the second-consumer reason | met | as above |
| SC2 ACC-001 tests unchanged and green; contact RED then green; spec-check passes | met | as above |
| SC3 Review PASS; `vela plan --solution ZavaSales` run; no apply | met | review record `:11` PASS; plan exit 8 (Canvas `:119-128`, `logs/plan.json`); `apply: pending` |
| One question at a time | met (n/a) | no questions were asked |
| Ask vs assume | met | The text and blank semantics come from ACC-001 ("the same default text as accounts") and are recorded as a story decision plus assumptions (Canvas `:29-31`). They match the evaluator's answers. Solution and prefix were confirmed read-only via `vela solution show`. Nothing that needed asking was assumed |

## Planted-violation check
Each violation was applied to a copy at `r2/planted-<x>/` and built: 0 warnings, 0 errors, no VELA. Each copy was then reviewed by a fresh subagent acting as vela-reviewer (read-only), given only the diff and the Canvas.

| plant | build | expected | reviewer verdict | result |
|---|---|---|---|---|
| (a) contact plugin drops the service (registration + call) and inlines `IsNullOrWhiteSpace` + `"Created via Vela plugin"` | clean | Required | BLOCK, 3 Required (duplicated rule against the recorded second-consumer service; Canvas/trace drift; stale evidence) + 1 Nit | blocked |
| (b) ACC-001/C2 weakened to `Assert.NotNull(Run("   ").Description)` | clean | Critical | BLOCK, Critical (regression test modified while ACC-001 is not change/retire) + Required (stale evidence) | blocked |

Plant (b) is also caught deterministically. Once committed, `tools/spec-check.py --base main` gives `FAIL ... regression test Whitespace_description_is_defaulted (ACC-001/C2) modified, but ACC-001 is not changed/retired by the story` (exit 1).

## Findings against the skills
1. minor: `AGENTS.md:85-86` (golden rule 7) says `docs/rules/` "changes only in the design phase ... in the build it is read-only". It does not state the trace-line exception that `build-report-template.md:23-24` ("except a rule's trace lines (`Implementation:` / `Tests:`), which are synced to the code") and `tools/spec-check.py:15` now allow. `skills/vela-apply/SKILL.md:63` also says the rules are "read-only in the build" without the exception. The actor followed the template and synced ACC-001's trace line in the build commit d172240. That was correct, but a reader of AGENTS.md alone would believe it was forbidden. This closes r1 finding 1 (the pointer gap) in the template and tooling only. The top-level rule should carry the same exception.

Observations (not pack defects):
- r1's Vela gap (`vela add service` was table-scoped only) is gone in vela 0.27.3. The service was added shared, without `--entity`, under `zava.Plugins.Services`.
- The plan creates the account step too, because the baseline was never applied to this org. The actor flagged this as an open question instead of glossing over its DoD line "no change to the account step" (Canvas Sync log `:133-134`). That is an environment fact, not a defect.

## Fixes
- None yet.

## Verdict
**pass.** Checks passed 26/26 and the grader passed. Every criterion is met, and both planted violations were blocked at or above the expected severity: (a) Required, (b) Critical. Next run: re-check that the shared service stays the single home of the text, and whether AGENTS.md rule 7 has gained the trace-line exception.
