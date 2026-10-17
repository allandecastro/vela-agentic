---
scenario: account-credit-function
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **22/22 passed**, no failed check. The registration probe found exactly one Custom API, `zava_GetAvailableCredit`, with IsFunction=true and IsBound=true. Its input is `ReserveAmount` System.Decimal (optional) and its output is `AvailableCredit` System.Decimal. The re-run tests were 14 total, 0 failed. The source has no `Service.Update/Create/Delete` and no `SystemService`. `.Request(` and `.Response(` are present. The read-only `vela plan` runs.

## Loop outcome
- `vela version` → 0.26.0.
- `vela solution show ZavaSales` → zava, exit 0.
- Q1-Q4 went to the human, and the Canvas was committed (35cf98a).
- `vela add customapi GetAvailableCredit --entity Account --bound --function` → exit 0.
- `vela add test --kind customapi` → exit 0.
- RED: 14 tests, 8 failed (5d989b3).
- GREEN: 14/14 (b503459).
- Release build: 0 warnings, 0 errors, 0 VELA.
- Isolated vela-reviewer: PASS with 3 Nits.
- `dotnet build -c Release` → nupkg containing the dll.
- `vela plan --solution ZavaSales --detailed-exitcode` → exit 8.
- The actor stopped at the apply gate.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Routing: a called operation → `vela-custom-api`, not a step | met | Canvas `account-available-credit.md:71-72` ("Custom API, not a step"); run trace step 4 |
| Kind: Function, with the reason confirmed by the human (read-only, JS caller, not flows) | met | Canvas :21-22, :45, :74-76; human-questions.md Q4 answer ("called from JavaScript on the account form only, not from flows") |
| Bound to account, typed scaffold `--bound --entity Account --function` | met | Canvas :112; GetAvailableCredit.cs:18-19 (`.AsFunction().BoundTo<Account>()`) |
| One optional numeric input mapped with `optional: true` | met | GetAvailableCredit.cs:21; checks.json probe `["ReserveAmount","System.Decimal",true]` |
| One output mapped in `.Response(...)`, placeholder `Result` replaced, every declared property mapped | met | GetAvailableCredit.cs:22, :97; probe out `AvailableCredit`; no `Result` property |
| The handler reads Target, retrieves only creditlimit via `ctx.Service`, no SystemService, writes nothing | met | GetAvailableCredit.cs:34-37; checks for no write and no SystemService |
| Errors are IPE with actionable messages; no error code in the output | met | GetAvailableCredit.cs:30, :41; the messages match the human answers Q1/Q3 |
| Tests: RED then green through the harness with a seeded account, plus `GetCustomApiDefinition()` (IsFunction, IsBound, optional input) | met | GetAvailableCreditTests.cs:20-47, :116-123; logs/test-red.txt "Failed: 8"; logs/test-green.txt "Failed: 0" |
| SC1: the Canvas records bound, Function plus why, optional input plus default, output, error cases | met | Canvas :18-25, :37-38, :73-76, :90-92 |
| SC2: `vela add customapi ... --bound --entity Account --function`; unique name `zava_<Name>`; nothing dotted | met | Canvas :112-113; check "no dotted Custom API names" |
| SC3: limit 1000/no amount→1000; 1000/300→700; no limit→error; negative→error; definition is a bound Function with 1 optional in and 1 out | met | tests :50-88, :29-47; GREEN 14/14 (re-run by checks: total=14 failed=0) |
| SC4: build clean of VELA00x; review PASS; plan shows the Custom API with its parameters | met | check "no VELA diagnostics"; review/reviewer-output.md "Verdict: PASS"; logs/plan.json (inputParameters ReserveAmount isOptional true, outputParameters AvailableCredit) |
| One question at a time; ask vs assume | met | human-questions.md has four separate questions, each with options. The human-defined cases (no limit, negative, over-reserve, caller) were asked. Scope, currency and types were recorded as assumptions (Canvas :46-50) |
| Stop before apply | met | Canvas :163-173; no apply in the run trace |

## Planted-violation results
Each violation was planted in a copy of the project (`planted-a/`, `planted-b/`, `planted-c/`) and built (all three built with 0 errors). Each diff was reviewed by a fresh read-only vela-reviewer subagent that got only the diff and the Canvas.

| Planted | Expected | Verdict | Severity returned | Result |
|---|---|---|---|---|
| (a) `.Response` maps only an unrelated `CheckedOn`; `AvailableCredit` is declared but unmapped | Required | BLOCK | Critical (the output is silently not registered) + Critical (spec drift) + 2 Required | blocked |
| (b) `ReserveAmount` made `optional: false` | Required | BLOCK | Required (spec drift: the story says optional; the not-sent cases break) | blocked |
| (c) handler calls `ctx.Service.Update` to stamp the account | Critical | BLOCK | Critical (a Function has side effects; "never changes the account") | blocked |

## Findings against the skills
None blocking, and no defect attributable to the pack in this run.

1. minor (observation, not a defect) - Q4 in `logs/human-questions.md` gives the caller ("callable from the form's JavaScript ... not from Power Automate") as the agent's reading, and asks only about scope. The human volunteered the caller confirmation. The Function decision did end up human-confirmed, but the caller was never asked as its own question. If later runs show the same pattern, check whether `vela-grill` explicitly makes "who calls it (JS / flow / plugin)" its own question for a Custom API.

## Verdict
**pass.** Checks passed 22/22, every scenario criterion is met with artifact evidence, and all three planted violations were blocked at the expected severity or higher. The next run should re-check that the caller (JS vs flow) is asked rather than inferred.
