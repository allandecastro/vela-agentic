---
scenario: feature-multi-rule
date: 2026-11-15
verdict: pass
campaign: 2026-11-15
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.29.0
framework: 0.42.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **22/22 passed**, no failed check (canvas exists, ACC-0xx + CON-0xx website rules in `docs/rules/`,
https asked in `logs/human-questions.md`, spec-check 0 failures, build clean, 0 VELA diagnostics, tests 39/0,
package holds the dll, solution ZavaSales/zava, read-only plan runs, plan creates only authored steps).

## Loop outcome
- intake: `vela version` -> vela 0.29.0 (trace.md:5); `vela solution show ZavaSales --json` exit 0 (trace.md:6)
- challenge: Q1 (account website values) and Q2 (contact copy) to the human, one at a time; Canvas + rules committed 7f9b856 before any scaffold (trace.md:7)
- model: `vela models --verify` account, contact in sync, exit 0 (trace.md:8)
- scaffold: 2x `vela add step` on AccountDefaultDescription, `vela add plugin ContactPlugin`, `vela add service ContactWebsiteDefault` (cceb106); existing ACC-001 `PluginContext` tests broke on the 2nd Create PreOp step -> Q3 -> moved to PluginPipeline (7577065)
- RED: 36 total / 16 failed, "Strings differ" (996f56c, logs/red.txt); GREEN 36/0 (1251b92)
- review round 1: BLOCK, 2 Required (embedded `://`; no-account-Read user gets a fault); fixed test-first (RED 38/3 -> GREEN 38/0, 96404d2); Q4 to the human -> CON-001 amendment C11 + WithSecurity test (b08c48a, 39/0)
- review round 2 (scoped): PASS, 4 Nits (2 fixed, 2 test Nits not taken)
- package: `dotnet build -c Release` -> artifacts/zava_zava.Plugins.1.0.0.nupkg; `vela plan --solution ZavaSales --detailed-exitcode` exit 8 (create package + 4 steps); stopped at gate, no `vela apply`

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| One story, two rules: one Canvas, one branch, new ACC- and CON- rules in `rules:`, each with its own cases, not split | met | `docs/features/website-https-default/README.md:25-28` (ACC-002 add, CON-001 add); cases :33-54; single branch `feat/website-https-default`; ACC-002 / CON-001 in `docs/rules/account.md`, `docs/rules/contact.md` (`git diff main -- docs/rules`) |
| Distinct ids not already used | met | main holds only ACC-001 (`git ls-tree main docs` has no contact.md); checks "new account website rule (ACC-001 is taken)" and "new contact website rule" pass |
| Dependency stated (contact rule relies on the account's stored website, its Given says so) | met | `docs/rules/contact.md` Then: "as the account stores it (https, per ACC-002)"; CON-001/C9 Given: "an account created with Website 'http://zava.com' (ACC-002 stores 'https://zava.com')"; account.md "See also CON-001"; Canvas R :83 "CON-001 ... relies on ACC-002". Weakness: the rule's main Given does not name ACC-002, only C9's Given and the Then do |
| Grilled up front: questions for both rules before any code | met | human-questions.md Q1 (ACC) + Q2 (CON) before scaffold (trace.md:3 -> 7f9b856 precedes cceb106). Q3 (harness, before RED) and Q4 (review-driven, security) came later - see findings 1-2 |
| One question at a time; ask vs assume | met | each Q is one decision, multiple-choice; deferred branches recorded as assumptions + open questions (Canvas :61-77) |
| No layer split: RED then implementation, no separate "tests" task | met | 996f56c RED (both rules) -> 1251b92 implementation; no tests-only task in the plan. RED/GREEN batched across the two rules rather than one cycle per rule |
| Existing rules untouched; spec-check clean | met | `git diff main -- docs/rules/account.md` only appends ACC-002; ACC-001 tests moved to PluginPipeline with same data/assertions, declared `change` (Canvas :28); check "spec-check passes" (0 failures) |
| RED then green | met | logs/red.txt (16 fail, right reason), green 39/0 (checks "tests re-run green" total=39 failed=0) |
| One review PASS | met | `.vela-runs/website-https-default/review.md` round 1 BLOCK, round 2 PASS, no open Critical/Required |
| Plan run | met | `.vela-runs/website-https-default/plan.json` (mode plan, 4 adds), trace.md:26 exit 8; check "read-only vela plan runs" |
| No apply | met | "vela apply" appears only as text in the Build Report / trace / br.py; evaluator's check-plan still shows package + steps as `create` |

## Planted-violation results
None: the scenario has no "Planted-violation check" section.

## Findings against the skills
1. minor - `skills/vela-plan-review/SKILL.md:90-93` says "a step that writes another table as the user gets read-denied and write-denied acceptance cases". CON-001 only **reads** another table (account). The actor wrote one read-denied case (C10: no row returned, so nothing is copied). It missed that a user with **no** account Read privilege gets a fault instead. The review caught this (round 1, R2), and the behaviour question (Q4) reached the human only after the code was written. The bullet should also cover a cross-table read as the user, and separate "the row is out of reach" (no row) from "no Read privilege at all" (privilege fault). That way the case is grilled up front.
2. minor - `skills/vela-scaffold/SKILL.md:64-65` says "After `vela add step` the plugin is **multi-step**: the new handler is `Handle<Message>` and its tests must state the trigger (`.OnCreate()` / `.OnUpdate()`)". This has two problems:
   - It contradicts line 58 ("`--handler` named after the behaviour").
   - It is incomplete when the new step shares a trigger with an existing one. Here `.OnCreate()` still threw, because `harness-api.md:43-46` says "several ... throw".

   The actor hit the failure (trace.md:11). It spent a human question (Q3) on what `harness-api.md:13` already answers ("a class with several steps on one trigger is tested [through PluginPipeline]"). The scaffold step should say: a step on the same trigger as an existing one moves that class's `PluginContext` tests to `PluginPipeline`.
3. minor (not the pack, noted for the Vela repo) - Vela.Testing `PluginContext` cannot pick one step out of several on the same message/stage. The error is "does not name one of their step keys", and there is no selector to name one. The actor reported this as a gap without working around it, which is correct per the pack.

## Verdict
pass - checks 22/22 and every criterion met. Next run should re-check two things: whether the security-context / no-privilege question is asked during the grill, before code; and whether adding a step on an existing trigger still costs a human question.
