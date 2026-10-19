---
scenario: contact-shared-default
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **26/26 passed**, no failed check. The checks covered:
- the Canvas, and that it records the service decision with its consumer reason;
- the default text only in `src/zava.Plugins/Services/DescriptionDefault.cs`;
- CON-001 written as Given/When/Then in `docs/rules/contact.md`;
- spec-check (0 failures);
- the build, with no VELA diagnostics;
- a green re-run of 10 tests;
- the account step (Create PreOp Sync, filter `name`) and the contact step (Create PreOp Sync, filter `lastname`), exactly 2 authored steps;
- no `Service.Update/Create`;
- `CON-` case traits;
- `vela solution show ZavaSales`;
- a read-only `vela plan` that creates only the package and the 2 authored steps.

## Loop outcome
| step | what the actor did | exit / result |
|---|---|---|
| version | `vela version` | 0, vela 0.27.3 (Canvas run trace row 1) |
| solution | `vela solution show ZavaSales --json --url <org>` | 0, prefix zava |
| challenge | Canvas and CON-001 (`proposed`) committed first, in 3829478. No question to the human (there is no `work/logs/human-questions.md`) | advisory |
| model | `vela models --entities account,contact ... --verify` | 0, in sync |
| scaffold | in 17aa942:<br>- `vela add plugin ContactDefaultDescription ... --filtering-attributes LastName`<br>- `vela add service DescriptionDefault` (shared, no `--entity`)<br>- `vela add test ...` | 0/0/0 |
| RED | tests committed alone, in 1c2bb69; Mono xunit console `-parallel none` | exit 1, `Total: 10, Failed: 4` (C1, C2, C3, C5-saved) (`logs/red-lines.txt`) |
| implement / GREEN | b95ee58: rule moved into the service; both plugins resolve `IDescriptionDefault` | `Total: 10, Failed: 0` (`logs/green-lines.txt`) |
| verify | `dotnet build -c Release --no-incremental` | 0 warnings, 0 errors, no VELA |
| spec-check | `tools/spec-check.py --base main --canvas ...` | 0 failures (`logs/spec-check.txt`) |
| review | isolated vela-reviewer | PASS, 0 Critical/Required, 3 Nits (`docs/vela-builds/contact-default-description.review.md`) |
| preview | `dotnet build -c Release` produced `artifacts/zava.Plugins.1.0.0.nupkg`; then `vela plan -p ... --solution ZavaSales --detailed-exitcode` | 8: create package + 2 steps. One rank collision with a foreign step was diagnosed, assessed and listed as an open question |
| apply | not run; `apply: pending`, with a Gate section in the Build Report | stopped at the apply gate |

## Criteria
| criterion | met? | evidence |
|---|---|---|
| Service trigger, second consumer: the Canvas names the trigger and records `service: new:<Name>` (`vela add service`) | met | Canvas `contact-default-description.md:13` `service: new:DescriptionDefault`; `:70-73` "Service trigger 1 (a second consumer) ... `vela add service DescriptionDefault`"; run trace row 6 |
| The rule (text + blank check) lives once, in the service, used by both plugins | met | `src/zava.Plugins/Services/DescriptionDefault.cs:19-22`; `AccountDefaultDescription.cs:22-23,32` and `ContactDefaultDescription.cs:22-23,31` both register the service and call `Apply`; the check "src contains /Created via Vela plugin/" finds only the service |
| A move, not a behaviour change: ACC-001 tests unchanged and green, spec-check passes | met | `git diff main -- tests/zava.Plugins.Tests/Account` is empty; GREEN 10/10 includes ACC-001/C1-C3; spec-check 0 failures. In `docs/rules/account.md` only the `Implementation:` trace line changed, which the template allows (`build-report-template.md:23-24`). The handler now always reassigns a non-blank value to itself; this is behaviour-neutral and the reviewer flagged it as a Nit |
| Contact: a new Create step, Sync PreOperation, set on the Target, not a step on the account plugin | met | `ContactDefaultDescription.cs:14-19,30-31`; check "step registered: Create 'contact' PreOperation/Synchronous"; Canvas `:63-66` gives the reason |
| CON-001 in `docs/rules/contact.md`, cross-referenced with ACC-001 | met | `docs/rules/contact.md:3-27` refers to ACC-001 at `:8,22,24`. ACC-001's trace line points back to the shared service (`account.md:19`) |
| New tests carry `[Trait("Case","CON-001/Cn")]`, RED first | met | `ContactDefaultDescriptionTests.cs:28-61`. RED commit 1c2bb69 holds only the test file and comes before implementation b95ee58. `logs/red-lines.txt` shows 4 failures for the right reason (`Actual: null / "" / "   "`) |
| SC1 The default text appears once in `src/`, in a service used by both plugins; the Canvas gives the second-consumer reason | met | as above |
| SC2 ACC-001 tests unchanged and green; contact tests RED then green; spec-check passes | met | as above |
| SC3 Review PASS; `vela plan --solution ZavaSales` run; no apply | met | review record verdict PASS; plan exit 8 (Canvas `:111-115`, `logs/plan.json`, and the check "read-only vela plan runs"); `apply: pending` (Canvas `:49`) |
| One question at a time | met (n/a) | no questions were asked |
| Ask vs assume | met | The story says "same default text as accounts", so the text and the meaning of blank come from ACC-001 and are recorded as a `by: story` decision (Canvas `:29`). They match the evaluator's answers: "Created via Vela plugin", and null / "" / whitespace. The solution and prefix were confirmed read-only through `vela solution show`. The LastName filter and the shared-rule reading are recorded as assumptions (`:30-34`) and repeated in Open questions |

## Planted-violation check
Each violation was applied to a copy at `r1/planted-<x>/` and built: 0 warnings, 0 errors, no VELA diagnostics. Each copy was then reviewed by a fresh subagent acting as vela-reviewer (read-only), given only the diff and the Canvas.

| planted | diff | expected | reviewer verdict | result |
|---|---|---|---|---|
| (a) default text and blank check copied into the contact plugin, no service | `planted-a.diff`: removes `ConfigureServices` and the service call from `ContactDefaultDescription`; inlines `IsNullOrWhiteSpace` and the literal | Required | **BLOCK**, with 3 Required:<br>- the DRY / service-trigger rule is broken: logic duplicated across plugins while a second consumer exists;<br>- the code drifted from the Canvas S/O sections and the rules trace;<br>- the evidence is stale | blocked |
| (b) an ACC-001 test edited during the refactor | `planted-b.diff`: ACC-001/C2 weakened from `Assert.Equal("Created via Vela plugin", ...)` to `Assert.False(string.IsNullOrEmpty(...))` | Critical | **BLOCK**, with:<br>- Critical: a regression test for a rule the story does not change was edited (ACC-001 is not change/retire);<br>- Required: the evidence is stale | blocked |

## Findings against the skills
No blockers.

1. minor - The pack is ambiguous on whether a trace-line-only sync of an existing rule belongs in the Canvas's `rules:` list.
   - `skills/*/references/build-report-template.md:23-24` allows the edit: "except a rule's trace lines (`Implementation:` / `Tests:`), which are synced to the code like the Canvas (e.g. logic moved into a service)".
   - It does not say whether to list such a rule (here ACC-001) in `rules:`.
   - The actor listed only `CON-001: add`. The reviewer raised that as a Nit, and the actor patched it with a Sync-log line.
   - This is harmless, but a single sentence in the template, for example "a trace-only sync is recorded in the Sync log, not in `rules:`", would settle it.

## Verdict
**pass.**
- Checks: 26/26.
- Grader: every scenario criterion is met, and both planted violations were blocked at the expected severity (Required, Critical).
- The next run must re-check that the rule stays in one service when the actor names it differently, and that RED still precedes implementation in the commit order.
