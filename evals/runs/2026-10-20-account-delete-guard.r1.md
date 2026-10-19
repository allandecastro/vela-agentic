---
scenario: account-delete-guard
date: 2026-10-20
verdict: pass
campaign: 2026-10-20
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.4
framework: 0.41.0
runner: campaign actor + separate grader
---

## Loop outcome
- Checks: **23/23 passed** (`checks.json`), no failed check.
- Intake/challenge: Q1-Q3 to the human, one at a time (`work/logs/human-questions.md`), Canvas + ACC-002 committed first (d8ca640).
- `vela solution show` exit 0; `vela models --verify` exit 0 (in sync); `vela add plugin ... --message Delete --stage PreValidation --mode Sync`, `vela add service`, `vela add test` exit 0.
- RED (f3a55df): Mono xunit `-parallel none`, `Total: 10, Failed: 2` (C1, C5, "No exception was thrown"); mutation (SystemService) `Failed: 1` (C6); GREEN (df1c19e) `Total: 10, Failed: 0`.
- Build Release 0 warnings / 0 errors / 0 VELA; spec-check 0 failures; isolated vela-reviewer PASS (0 Critical/Required, 3 Nits).
- `vela plan --solution ZavaSales` exit 8 (changes): create package + AccountDeleteGuard (Delete, stage 10, mode 0) + baseline AccountDefaultDescription. No apply.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Registration: Delete of account, Sync PreValidation, via `vela add plugin --message Delete` | met | `AccountDeleteGuard.cs:19-21`; Canvas run trace row 5; check "step registered: Delete 'account' PreValidation/Synchronous" |
| Target is an EntityReference; reads contacts, not target columns | met | `AccountDeleteGuard.cs:39` uses `ctx.PrimaryEntityId`; Canvas `images: []` |
| Typed query `Query.For<Contact>()` + ParentCustomerId + StateCode Active, `ctx.Service`, minimal columns, no logical names | met | `ActiveContactCount.cs:25-28` (`CountScalar` on ContactId); injected `IOrganizationService` (`AccountDeleteGuard.cs:28`); checks "must not contain QueryExpression", "Query.For<Contact>", "StateCode" |
| Error: InvalidPluginExecutionException with actionable message (count; deal with contacts first) | met | `ctx.BusinessError` (`AccountDeleteGuard.cs:43`), template line 31; test asserts exact text (`AccountDeleteGuardTests.cs:68-70`) |
| Tests RED then green through PluginPipeline: throws with active, succeeds with none / only inactive, other account's contact does not count | met | C1-C4 tests lines 58-118, `pipeline.Service.Delete`; `logs/test-red.txt` Failed: 2, `logs/test-green.txt` Failed: 0; check "tests re-run green (>= 6)" total=10 |
| Localized message: `ctx.BusinessError("KEY")`, source registered in ConfigureServices, EN + FR, convention asked at design, test asserts message | met | Q2 in `human-questions.md:13-20`; `AccountDeleteGuard.cs:26-33` (1033 + 1036); C5 test lines 120-136 asserts French text |
| SC1 Canvas: Delete, PreValidation, Sync with reason; error message; what "active" means | met | Canvas front-matter lines 18-20, A section line 71-72, assumptions 45-46, decision line 40 |
| SC2 Typed query, no QueryExpression / logical-name strings in plugin code | met | `ActiveContactCount.cs`; plugin code has none (logical names only in test seeds/security setup, reviewer Nit) |
| SC3 RED then green; review PASS; `vela plan --solution ZavaSales` shows the Delete step; no apply | met | logs above; `docs/vela-builds/account-delete-guard.review.md` Verdict PASS; `logs/plan.json` step AccountDeleteGuard Delete stage 10 mode 0; Canvas `apply: pending` |
| One question at a time; ask vs assume | met | Q1-Q3 asked separately with recommendation; unanswered items (wording, security context) recorded as assumptions / open questions (Canvas lines 44-55) |

### C6 (security context) on Vela.Plugins / Vela.Testing 0.41.0
Behaves as expected. Resolved packages are 0.41.0 (`tests/.../obj/project.assets.json`: Vela.Plugins/Vela.Testing/Vela.Messages 0.41.0). With the inherited-access change, Alice (owner of the account, User-level contact Read) still does not see Bob's seeded contact - seeding a child with a parent is not a reparent, so no inherited access - and C6 is green with `ctx.Service`. The mutation to `SystemService` turns C6 red with the expected message ("it still has 1 active contact(s)", `logs/test-mutation-system.txt`), so the test discriminates the security context.

## Planted-violation results
Each planted in a copy (`r1/planted-<x>/`), built Release (0 errors, 0 warnings, no VELA diagnostic for any of them - the analyzers catch none), and reviewed by a fresh read-only vela-reviewer given only the diff and the Canvas.

| Plant | Expected | Reviewer verdict | Top severity | Result |
|---|---|---|---|---|
| (a) `.PostOperation().Async()` | Critical | BLOCK | Critical - Async PostOperation cannot refuse the delete; plus Required spec drift / stale evidence | pass |
| (b) StateCode condition removed | Required | BLOCK | Critical - inactive contacts block, C2 regresses (rated above expected) | pass |
| (c) QueryExpression with logical-name strings | Required | BLOCK | Required - logical-name strings where `Query.For<T>()` fits (checklist Models), also unpaged `RetrieveMultiple(...).Entities.Count` | pass |

## Findings
1. minor - `skills/vela-plugin-authoring/references/plugin-authoring-api.md:241` points to the Vela localization guide for where the message source is registered ("the source ... is the project's convention - ask the human" + external link); the read-only reviewer (Read/Grep/Glob, no web) could not verify that `IMessageService.AddSource(...)` in `ConfigureServices` is the documented per-execution pattern and left a Nit ("I could not verify Vela's lifetime from the pack"). Not a defect in the outcome; one line in the bundled reference naming the registration point would let the isolated reviewer close it. Weigh against lean-skills.
2. minor (observation, not a pack defect) - none of the three plants trips a VELA analyzer; all three blocks rest on the reviewer alone. Plant (c) in particular (logical-name `QueryExpression` in plugin code) is caught by the review checklist, not the build.

No blocker against the skill pack.

## Fixes
- none needed for this run.

## Verdict
pass - 23/23 checks, every criterion met from the artifacts, all three planted violations BLOCKed at or above the expected severity. C6 holds on 0.41.0 (green with the user context, red under SYSTEM). Next run: re-check C6 if the harness's inherited-access model changes again (e.g. if seeding with a parent starts to grant inherited read).
