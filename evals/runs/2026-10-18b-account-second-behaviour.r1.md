---
scenario: account-second-behaviour
date: 2026-10-18
verdict: pass
campaign: 2026-10-18b
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.3
framework: 0.38.0
runner: "campaign actor + separate grader"
---

`vela_cli`: the actor's logs and Build Report record `vela 0.26.3` (`actor-report.md:13`, `logs/review-material.md:27`, Canvas `vela_cli: 0.26.3`). The evaluator upgraded the installed CLI to 0.27.0 mid-run, and that version is what the grader saw. `framework`: `src/zava.Plugins/zava.Plugins.csproj:36` has `Vela.Plugins 0.38.0`. Evaluator notes, none of them a criterion:
- The human authorized the `.OnCreate()` trigger line in the ACC-001 tests (harness plumbing).
- The spec-guard hook was removed mid-run.
- The CLI was upgraded to 0.27.0 mid-run.

## Check summary
`checks.json`: **25/25 passed**, no failed checks. They cover:
- canvas present, with reuse;
- registry holds ACC-001 plus ACC-002 in Given/When/Then;
- spec-check 0 failures;
- build green, no VELA diagnostics;
- 9 tests re-run green;
- Create PreOp/Sync with filter `name`, and Update PreOp/Sync with filter `description`, exactly 2 authored steps;
- no `Service.Update/Create`;
- the default literal is in one file;
- `vela solution show` ok;
- read-only `vela plan` creates only the authored steps.

## Loop outcome
- **Intake:**
  - `vela version` returned 0.26.3.
  - The registry was read: Q1 cites "new rule ACC-002, next to ACC-001 on Create".
  - `vela solution show ZavaSales --json` exited 0 (zava).
- **Q1** (`logs/human-questions.md:3-10`) covered the already-empty edge, plus a one-line ride-along on the meaning of "empty". The human gave no rule, so the edge was recorded as an assumption.
- **Q2** (`:12-26`) was asked after a throwaway probe showed that `vela add step` makes ACC-001's `Run` helper ambiguous. The human chose option (1), one plugin with two steps, and authorized `.OnCreate()`.
- **Design commit** 05cd199 (Canvas + ACC-002 `proposed`), then `vela add step ... --message Update --stage PreOperation --mode Sync --filtering-attributes Description` (exit 0, 258b1a5), then `vela add test` (exit 0).
- **RED** (d5e56a3, mono xunit `-parallel none`): `Total: 9, Errors: 0, Failed: 3`. The failures are C1-C3, each expecting "Created via Vela plugin" (`logs/red.txt`).
- **GREEN** (34b979b): `Total: 9, Failed: 0` (`logs/green.txt`). Release build: 0 warnings, 0 errors.
- spec-check: 0 failures.
- **Review:** an isolated vela-reviewer returned PASS, 0 Critical, 0 Required, 2 Nits (`logs/review-verdict.md`).
- **Plan:** `vela plan ... --solution ZavaSales --detailed-exitcode` exited 8 (changes: package + 2 steps, 0 diagnostics). The run stopped before apply (`apply: pending`, Gate section).

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| D1 | Reuse vs new: `vela add step` on the existing plugin, no hand-made class | met | Canvas `reuse: add-step:AccountDefaultDescription` (l.10), Approach l.61-63, Run trace row 4. Commit 258b1a5 is the scaffold. There is only one plugin class in `src/`. Check "exactly 2 authored step(s)", both on `AccountDefaultDescription`. |
| D2 | DRY: defaulting logic defined once and shared by both paths | met | `AccountDefaultDescription.cs:11` const `DefaultDescription`; `:53` `IsEmpty`; `:56` `ApplyDefault`. Used by Update `:35-37` and Create `:46-48`. Check "default lives in exactly one place". |
| D3 | Sync PreOperation, set on `ctx.Request.Target` | met | `.cs:22-24` and `:34-37`. Check "step registered: Update 'account' PreOperation/Synchronous". No `Service.Update`. |
| D4 | `FilterOn(e => e.Description)` on Update | met | `.cs:25`. Check filter=['description']. |
| S1 | Canvas Approach/Structure record the reuse, how the rule is shared, and Sync with a reason | met | Approach l.61-63: "part of the same write (no second Update, no recursion). Sync because the user must see the default on save. Reuse: ... via `vela add step`". Structure l.67-69: "No service: a one-line rule shared by the two steps of one plugin -> a private helper (`IsEmpty`) + constant". |
| S2 | No duplicated logic; one definition used by Create and Update; decision recorded with a correct reason | met | Code as in D2. Canvas `service: none` (l.11), Structure l.67-69, Norms l.83. |
| S3 | Test-first: RED acceptance tests (cleared → default; real value → untouched) before implementation, green after | met | Tests `AccountDefaultDescriptionTests.cs:47-94` (C1-C3 cleared → default, C4 new text kept, C5 not sent, C6 already empty). Commit order: d5e56a3 (tests only) → 34b979b (feat). `logs/red.txt`: `Failed: 3` for the right reason. `logs/green.txt`: `Failed: 0`. |
| S4 | vela-code-review PASS; SOLID/DRY axis confirms no duplication; spec axis confirms reuse honoured | met | `logs/review-verdict.md`: "DRY helper+constant, no service"; "Decisions checked: ... reuse add-step on AccountDefaultDescription; private helper, no service". |
| S5 | Registry read at intake; ACC-002 added in Given/When/Then with implementation trace; Canvas `rules:` lists it | met | Q1 (`human-questions.md:4`) cites ACC-001 and ACC-002. `docs/rules/account.md:3-24` has Given/When/Then, cases, `Implementation:` and `Tests:`. ACC-001 is kept at `:26-43`. Canvas `rules: - {id: ACC-002, change: add}` (l.15-16). Commit 05cd199. Checks for the registry ACC-00[2-9] and ACC-001 both pass. |
| Q | One question at a time; ask vs assume | met | Q1 and Q2 are separate and each is load-bearing. Q1 has a one-line edge ride-along, which `vela-grill` permits ("a one-line edge follow-up may ride along"). The solution and prefix were read with `vela solution show`, not asked. The human's "no rule" answer was recorded as an assumption. Q2 was a real design conflict, backed by probe evidence. |
| G | Stop before apply | met | Canvas `apply: pending` and Gate section l.127-132. No `vela apply` in the logs. |

## Planted-violation results
Each plant was applied to a copy of the project (`planted-<x>/ZavaSales`) and built with `dotnet build -c Release`. A fresh general-purpose subagent, told to act as the vela-reviewer (read-only, following `agents/vela-reviewer.agent.md` and `vela-code-review`), was then given only the diff (`planted-<x>/diff.txt`) and the Canvas. `work/` was not modified.

| Plant | What | Build | Reviewer verdict | Highest severity | Expected | Result |
|---|---|---|---|---|---|---|
| (a) | `HandleUpdate` calls a new `AccountUpdateDescriptionDefaulter` class that copies the constant `"Created via Vela plugin"` and the IsNullOrWhiteSpace test | 0 err, 0 warn | BLOCK: "default text and the 'empty' rule now exist in two places" (DRY) and a Canvas S/N mismatch | Required | Required | blocked |
| (b) | Update step moved into a hand-created `AccountDescriptionCleared` plugin class. The helpers were made `internal`, so the logic is not duplicated. | 0 err, 0 warn | BLOCK: the reuse decision is overridden with no Canvas change and no `vela add`; the ACC-002 tests no longer run the step; one plugin depends on another's internals; the registry is stale | Critical | Required | blocked |
| (c) | Update step `.PostOperation().Async()` | 0 err, 1 warn (VELA018) | BLOCK: "Target edit is lost and the default is never saved", plus drift from the Canvas Sync decision | Critical | Critical | blocked |

## Findings against the skills
None blocking, and no minor pack defects observed in this run.

Observations (not defects):
- **Q2 friction.** At run time the pack forbade any edit to ACC-001 regression tests. Making the plugin multi-step (`vela add step`) therefore forced a human question for a one-line `.OnCreate()` trigger selection. The pack has since been changed to allow that harness plumbing, and spec-check ignores it (commits f2493e9, b9ce7af), so the next run should not need Q2.
- **Mixed context types.** The pre-existing Create handler still uses `ICreatePreContext<Account>` while the new step uses the generated `HandleUpdateContext`. The reviewer flagged this as a Nit. It comes from the baseline, not the pack.

## Verdict
pass. Checks are 25/25, every criterion is met, and all three planted violations are blocked at the expected severity or higher. The next run should re-check this on the 0.27.0 CLI / Vela.Plugins 0.39.0 floor from the start. Without the old test-edit restriction, Q2 should no longer be needed.
