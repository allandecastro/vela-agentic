---
scenario: bulk-update-multiple
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
`checks.json`: **19/19 passed**, `pass: true`. No failed checks. Highlights: build clean, no VELA diagnostics,
tests re-run green (12 total, 0 failed), exactly one authored step `UpdateMultiple / account / PreOperation /
Synchronous / filter [name]`, no step on `Update`, no `Service.Update/Create` in `src`, tests use
`WithTargets`, solution ZavaSales / prefix zava exists, read-only plan creates only the package and the authored step.

## Loop outcome
- Canvas first (commit f627eb8), then `vela init` scaffold (250100d), `vela models` + `vela add plugin/test` + RED tests (fd4aba4:
  plugin is still the scaffold TODO stub; 9/12 fail on assertions, 3 guard cases pass), implementation GREEN 12/12 (4699b10),
  Canvas updated (80e9d31), review recorded (0b77b99), Build Report (1113eee).
- `dotnet build -c Release` 0 warnings / 0 errors; `vela plan` exit 8 (changes): create package + one step, 0 diagnostics.
- Stopped at the apply gate; no `apply`. No AI trailer in commits.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| M1 | Message choice: Canvas decides UpdateMultiple vs Update and records why (merged pipelines, not both) | met | `docs/vela-builds/account-trim-name-update-multiple.md:63-67` ("UpdateMultiple (not Update) because the story is about bulk and one execution per batch is cheaper ...; registering on **one** message only (merged pipelines - never both)"); assumption line 34; check "no step on Update" |
| M2 | Bulk surface: iterates the batch, edits each target in PreOperation, never calls Update per record | met | `src/Zava.Plugins/Account/Plugins/AccountTrimNameOnUpdateMultiple.cs:21-47` (`OnUpdateMultiple().PreOperation()`, `foreach (Entity entity in ctx.Request.Targets.Entities)`, in-place `ToEntity<Account>()` edit, no `ctx.Service`); check "src must not contain Service.(Update/Create)". `ctx.Request.Targets` is the documented equivalent of `ctx.BulkTargets` (`references/plugin-authoring-api.md:166-167`) |
| M3 | Tests supply the batch via `WithTargets(...)` (+ `OnMessage` where needed); cases: several records with spaces, record without a name, mixed batch | met | Tests file: `UpdateMultiple_Trims_..._Every_Target` (l.51, 3 padded records via `UpdateMultipleRequest`), `Name_Not_Sent_...` (l.145), `Cleared_Name_Stays_Null` (l.132), `Mixed_Batch_...` (l.158, `WithTargets(padded, blank, notSent, clean)`). `OnMessage` omitted - correct for a single-step plugin per `references/harness-api.md:69-71` |
| H  | Human answers honoured: whitespace-only -> null; single Updates acceptable; ZavaSales / zava | met | Canvas l.22, 29-31; tests l.102-129 and l.179; plugin l.41; check "target solution ZavaSales exists" |
| S1 | Canvas records the message decision with its reason | met | see M1 |
| S2 | RED then GREEN on the batch cases; no per-record write inside the handler | met | `git show fd4aba4` - plugin body is the scaffold TODO; Build Report l.100-101 (RED 9 fail / GREEN 12/12); checks "tests re-run green" (12/0) and no `Service.Update`; `Mixed_Batch` asserts the in-memory service has no writes (l.175) |
| S3 | Build clean of VELA00x; `vela-code-review` PASS | met | check "no VELA diagnostics", "build succeeds"; `docs/vela-builds/account-trim-name-update-multiple.review.md` - isolated subagent, VERDICT PASS, 0 Critical / 0 Required, 3 Nits |
| G  | Stop before apply; plan on the final package | met | Build Report l.49 `apply: pending`, l.107-109 plan output, l.131-135 gate; check "read-only vela plan runs" |

## Planted-violation results
The scenario has no "Planted-violation check" section; none applied.

## Findings against the skills
None. The pack's references led the actor directly to the right surface: `dataverse-gotchas.md:21-24`
(merged pipelines, register one), `registration-rules.md:25`, `plugin-authoring-api.md:166-169` (in-place
`Targets` edit) and `harness-api.md:69-75` (`WithTargets` + pipeline `UpdateMultipleRequest`).

## Verdict
pass - 19/19 checks and every scenario criterion met with artifact evidence. Next run should re-check that the
message decision and its reason still land in the Canvas (the core judgement of this scenario).
