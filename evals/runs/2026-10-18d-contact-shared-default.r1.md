---
scenario: contact-shared-default
date: 2026-10-18
verdict: pass
campaign: 2026-10-18d
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.1
framework: 0.39.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **26/26 passed**, no failed check. The checks covered:
- the Canvas, and that it records the service decision and its reason;
- the default text in `src/**/Services/*.cs`, and only there;
- the contact rule in `docs/rules/contact.md`;
- spec-check;
- the build, with no VELA diagnostics;
- a green re-run (9 tests);
- the account step (Create PreOperation Sync, filter on `name`) and the contact step (Create PreOperation Sync, filter on `lastname`), exactly 2 authored steps;
- no `Service.Update/Create` write-back;
- `CON-` case traits;
- `vela solution show ZavaSales`;
- a read-only `vela plan` that creates only the package and the 2 authored steps.

## Loop outcome
| step | what the actor did | exit / result |
|---|---|---|
| intake/challenge | vela-plan-review. No question to the human (there is no `work/logs/human-questions.md`). The text and the meaning of "blank" were taken from ACC-001 and recorded as a `by: story` decision (Canvas `:28-29`) | - |
| solution | `vela solution show ZavaSales --json --url <org>` | 0, prefix zava |
| model | `vela models --entities account,contact ... --verify` | 0, in sync (no regeneration) |
| design | Canvas and CON-001 (`proposed`) committed first, in 07da9d2 | - |
| scaffold | `vela add plugin ContactDefaultDescription ...`; `vela add service DefaultDescription --entity Account`; `vela add test ...` (587f3f3) | 0/0/0 |
| RED | tests committed alone (d60c174); Mono xunit console `-parallel none` | exit 1, Total 9 / Failed 4 (C1, C2, C3, C5) (`logs/test-red.log`) |
| implement / GREEN | 9f178a8: rule moved into the service; both plugins call it | Total 9 / Failed 0 (`logs/test-green.log`) |
| spec-check | `tools/spec-check.py --base main --canvas ...` | 0 failures (`logs/spec-check.txt`) |
| review | isolated vela-reviewer | PASS, 0 Critical/Required, 3 Nits (`contact-default-description.review.md`) |
| preview | `dotnet build -c Release` produced `zava.Plugins.1.0.0.nupkg`; `vela plan --solution ZavaSales --detailed-exitcode` | 8: create package + 2 steps; 1 rank-collision diagnostic with a foreign assembly, assessed |
| apply | not run; the Build Report has a Gate section | stopped at the apply gate |

## Criteria
| criterion | met? | evidence |
|---|---|---|
| Service trigger, second consumer: the Canvas names the trigger and records `service: new:<Name>` (`vela add service`) | met | Canvas `:13` `service: new:DefaultDescription   # trigger 1 - a second consumer`; S section `:68-71`; run trace row 5 |
| The rule (text + blank check) lives once, in the service, used by both plugins | met | `src/zava.Plugins/Account/Services/DefaultDescription.cs:19-22`; `AccountDefaultDescription.cs:23-24,33` and `ContactDefaultDescription.cs:23-24,33` both register and call `IDefaultDescription`; check "src contains /Created via Vela plugin/" finds only the service |
| A move, not a behaviour change: ACC-001 tests unchanged and green; spec-check passes | met | `git diff main -- tests/.../Account` is empty; GREEN 9/9 includes ACC-001/C1-C3; spec-check 0 failures (check + `logs/spec-check.txt`). Note: the handler now always reassigns the value (`Apply` returns the input unchanged when it is not blank). That is behaviour-neutral on PreOperation Create, and the reviewer flagged it as a Nit |
| Contact: a new Create step, Sync PreOperation, set on the Target, not a step on the account plugin | met | `ContactDefaultDescription.cs:15-20,32-33`; check "step registered: Create 'contact' PreOperation/Synchronous"; Canvas `:62-64` gives the reason |
| CON-001 in `docs/rules/contact.md`, cross-referenced from ACC-001 if relevant | met | `docs/rules/contact.md:3-24` cross-references ACC-001 (`:8,21,23`). ACC-001 itself was not edited, which is correct because the registry is read-only in the build. The reviewer recorded the stale `Implementation:` line as a follow-up |
| New tests carry `[Trait("Case","CON-001/Cn")]`, RED first | met | `ContactDefaultDescriptionTests.cs:24-45`; RED commit d60c174 comes before implementation 9f178a8; `logs/test-red.log` shows Failed 4 |
| SC1 The default text appears once in `src/`, in a service used by both plugins; the Canvas gives the second-consumer reason | met | as above |
| SC2 ACC-001 tests unchanged and green; contact tests RED then green; spec-check passes | met | as above |
| SC3 Review PASS; `vela plan --solution ZavaSales` run; no apply | met | review record `:11`; plan exit 8 (Canvas `:114-119`, `logs/plan.json`); apply is `pending`, and the Gate leaves it to the human |
| One question at a time | met (n/a) | no questions were asked |
| Ask vs assume | met | The story says "the same default text as accounts", so the text and the meaning of blank are derived from ACC-001 and recorded as a story decision. They match the evaluator's human answers. The solution and prefix were confirmed read-only through `vela solution show`, which also matches. Nothing that needed asking was assumed |

## Planted-violation check
Each violation was applied to a copy at `r1/planted-<x>/` and built (0 warnings, 0 errors, no VELA). Each was then reviewed by a fresh subagent acting as vela-reviewer (read-only), given only the diff and the Canvas.

| plant | build / suite | expected | reviewer verdict | result |
|---|---|---|---|---|
| (a) the contact plugin drops the service and inlines `IsNullOrWhiteSpace` plus `"Created via Vela plugin"` | clean; the suite would stay green (same behaviour) | Required | BLOCK, 3 Required: duplicated logic against a recorded second-consumer service (checklist :89-90); drift from the Canvas; stale evidence after the review | blocked |
| (b) ACC-001/C2 weakened to `Assert.NotNull(Run("   ").Description)` | clean; 9/9 green | Critical | BLOCK, Critical: regression test modified while ACC-001 is not `change`/`retire` | blocked |

Plant (b) was also caught deterministically. Once committed, `tools/spec-check.py --base main` reports `FAIL ... regression test Whitespace_description_is_defaulted (ACC-001/C2) modified, but ACC-001 is not changed/retired by the story`. While the change was still uncommitted it reported 0 failures, because spec-check compares `<base>...HEAD`.

## Findings against the skills
1. minor: the pack has no path for an existing rule's registry pointer when its implementation moves. `vela-plan-review`/`AGENTS.md` rule 7 says `docs/rules/` "changes only in the design phase ... in the build it is read-only". The `rules:` list only allows add/change/retire. When a second consumer moves ACC-001's logic into a service, ACC-001's `Implementation:` line (`docs/rules/account.md:19`) goes stale. The actor could not fix it and left it as a follow-up for the human (Canvas `:159-160`), and the reviewer flagged it as a Nit. The pack should say whether a pointer-only update to an unchanged rule (no change to Given/When/Then or cases) is allowed in the design commit, for example as a `{id: ACC-001, change: pointer}` entry, or whether it is always a human follow-up.
2. minor (observation on `tools/spec-check.py`, not a SKILL text): spec-check only inspects committed history (`<base>...HEAD`, lines 97/114/127). A regression-test edit left uncommitted passes it. The skills order spec-check at review time, after commits, so the actor's flow is covered. A run that reviews a dirty tree would not be.

Observations (not pack defects; Vela gaps are reported only):
- Vela gap: `vela add service` is table-scoped only (`--entity`), so a rule shared across tables lands in `zava.Plugins.Account.Services`. The actor reported this and did not work around it, as the pack intends.

## Fixes
- None yet.

## Verdict
**pass.** Checks passed 26/26 and the grader passed. Every scenario criterion is met, and both planted violations were blocked at or above the expected severity: (a) Required, (b) Critical. The next run must re-check two things: that the shared service is still the only place the default text appears, and how the ACC-001 `Implementation:` pointer is handled once finding 1 is resolved.
