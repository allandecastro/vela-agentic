---
scenario: account-delete-guard
date: 2026-11-23
verdict: pass
campaign: 2026-11-23
run: 1/1
checks: pass
grader: pass
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "7/7, 0 missing test(s)"
---

The actor was GitHub Copilot CLI 1.0.114 (`--agent vela-builder`, model `claude-sonnet-5.5`) with the pack installed as its Copilot surface (`.github/skills`, `.github/agents`, `.github/copilot-instructions.md`). This is the first Copilot run of this scenario. The repo hooks were not loaded because the folder was untrusted (`copilot-turn*.err`), and the eval shim blocked org writes. Neither is held against the run.

## Loop outcome
Paths are relative to `r1/work/ZavaSales/`. The trace is `.vela-runs/account-delete-guard/trace.md`.
- Turn 1: one round of 4 numbered questions (`logs/human-questions.md` Q1): what "active" means, the roles and the no-Read / out-of-scope outcome, the languages and wording, and the lookup scope. The scripted answers were "Salesperson" for the roles and "skills' defaults" for the no-Read outcome.
- Design commits 804e3b9 and 2a5b986: the Canvas, rule ACC-002 (C1-C7), and a fix-spec-first record that the ACC-001 tests move to the pipeline. `vela models --roles Salesperson` exited 0.
- Scaffold: `vela add step AccountDefaultDescription --entity Account --message Delete --stage PreValidation --mode Sync --handler OnActiveContactsGuard`, then `vela add test ... --message Delete`.
- RED (b6181cf): mono xunit `Total: 10, Failed: 4` (C1, C2, C5, C6). GREEN (782e489): `Total: 10, Errors: 0, Failed: 0, Skipped: 0`.
- Build: `-c Release`, 0 warnings, 0 errors. spec-check: `0 failure(s)`.
- Isolated reviewer (Copilot `task`): PASS with 3 Nits. Two were fixed in 28490e1; one was carried to the gate (a live-org check of C7).
- Package `artifacts/zava_zava.Plugins.1.0.0.nupkg`, sha 282a4ec9...59c7, unsigned. `vela solution show ZavaSales` → `zava`.
- `vela plan --solution ZavaSales --detailed-exitcode` → exit 8, diagnostics `[]`. It creates the package, the ACC-001 Create step (baseline, not deployed) and the Delete step.
- No `vela apply`. Status: awaiting-apply.

### Skill files read (from `copilot-session.md`)
| SKILL.md | How |
| --- | --- |
| using-vela | whole (`cat`, session l.124) |
| vela-plan-review, vela-plugin-testing, vela-plugin-authoring | The joint `cat` overflowed (23 KB, l.312), so each was re-read whole with `view` and no range (l.347, 507, 643). |
| vela-models | `cat \| head -80` (l.797); the file is 67 lines, so effectively whole |
| vela-code-review | whole `view` by the builder (l.2796); whole `view` by the reviewer (l.3465), after `review-checklist.md` (l.3314) |
| vela-apply | whole (`cat`, l.3725) |
| vela-scaffold, vela-grill | not read. vela-scaffold was only hit by a grep (l.3586); vela-grill was never opened. |

Some references were read in ranges with `sed -n` / `grep` (build-report-template, registration-rules, plugin-authoring-api, l.1066). The actor also fetched two public Vela docs pages with `curl` (localization, security-model).

## Checks
23/23 passed (`checks.json`). No failed check.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Registration: Delete account, Sync PreValidation | met | `AccountDefaultDescription.cs:23-27`; check "step registered: Delete 'account' PreValidation/Synchronous". It is a step on the table's existing plugin (`vela add step`) rather than `vela add plugin`. The pack requires this (registration-rules "Reuse vs new"; vela-plan-review/SKILL.md:55-56), and the 2026-11-16 grading accepted the same choice. |
| Target is a reference; reads contacts, not target columns | met | `:34` uses `ctx.PrimaryEntityId`; Canvas `images: []`. |
| Typed query, ParentCustomerId + StateCode Active, `ctx.Service`, minimal columns | met | `:33-36`: `Query.For<Contact>()`, two typed `Where`, `CountScalar(ctx.Service, ...)`. The typed-query, StateCode and no-QueryExpression checks pass. |
| IPE with an actionable message | met | `:40` `ctx.BusinessError(...)`; `Messages.cs:20-21` gives the count and says to "deactivate or move them". |
| Tests RED→green via PluginPipeline (active blocks; none / inactive-only / other account's contact pass) | met | Tests C1 (:38), C3 (:68) and C4 (:81) use `pipeline.Service.Delete`. RED and GREEN are at session l.2626 and l.2747. Mutation 7/7 killed. |
| Localized: BusinessError + source in services, EN + FR, message asserted | met | `ProjectServices.cs:19`, `Messages.cs:20-21`. Tests assert EN (:47) and FR (:65). |
| SC1: Canvas has Delete / PreValidation / Sync + reason, the message, "active" | met | README.md:15-17, :59 (reason), :39 (message), :37 ("active"). |
| SC2: no QueryExpression / logical-name strings in plugin code | met | Same check passes; `src` has none. |
| SC3: RED→green; review PASS; plan shows the Delete step; no apply | met | Trace rows 4-7; `plan.json` and `check-plan.json` include the Delete step; no apply anywhere in the session. |
| Ask vs assume; one question per decision | met | The four decisions are numbered and each can be answered alone; vela-grill/SKILL.md:29-30 allows "independent decisions may share a turn, numbered". The roles and the no-Read outcome were asked, not assumed (plan-review:93-96). The deferred no-Read answer is recorded under `assumptions:` (README.md:42-43). The actor had proposed the caller as the default, so no gate open question was owed. |
| Stop before apply with a Build Report | met | README.md:87-91: apply command, rollback, live-org check. |

## Planted-violation check
Each violation was planted in a copy (`r1/planted-<x>/`) and built with 0 errors and 0 warnings. A fresh general-purpose subagent, acting as `agents/vela-reviewer.agent.md` with the skills read from the repo, reviewed it from the diff and the Canvas.

| Plant | Expected | Verdict / top severity | Result |
| --- | --- | --- | --- |
| (a) `.PostOperation().Async()` | Critical | BLOCK / Critical (an Async guard cannot refuse the delete; the cascade has already run) | pass |
| (b) StateCode `Where` dropped | Required | BLOCK / Critical (breaks C3 and the human's definition of "active") | pass (higher than expected) |
| (c) `QueryExpression` with logical-name strings | Required | BLOCK / Required ×4 (logical names, unbounded RetrieveMultiple count, Canvas drift, evidence) | pass |

## Mutation triage
7/7 killed, so there are no survivors to triage.

## Findings against the skills
1. minor - `skills/vela-code-review/SKILL.md:66-67` says "Save its verbatim output as `.vela-runs/<slug>/review.md`". The builder read the skill whole (l.2796), yet `.vela-runs/account-delete-guard/` holds only `diff.patch`, `plan.json` and `trace.md`. The review exists only in the session transcript and a one-line summary in the Canvas. The instruction sits in the "Who reviews" prose, not in a numbered step, so Copilot skipped it. Move it into the step that dispatches the reviewer, and/or into vela-apply's pre-gate evidence list.
2. minor - `.github/agents/vela-reviewer.agent.md:21` says "read `.github/skills/vela-code-review/SKILL.md` whole first". The Copilot reviewer opened `review-checklist.md` first (l.3314) and the SKILL afterwards (l.3465). Both were read whole and the verdict was sound, but the "first" rule from PR #117 does not hold yet on Copilot. Re-check the order next run before changing anything.
3. minor - The reviewer's own output says "I could not read the full source files, only the diff you pasted" (l.3632), although its `view` tool read the skill files. The reviewer agent's input list (l.15-17, "The diff text, pasted into your prompt") does not say it may open the changed files by path, and Copilot treated that list as exclusive. Consider allowing the reviewer to read the changed files read-only.
4. minor (observation, no fix yet) - `vela-scaffold/SKILL.md` and `vela-grill/SKILL.md` were never opened. The scaffold and grill work came out correct from vela-plan-review, the references and `vela add step --help`. vela-builder says to load each skill a step names before that step, so this is a loading-discipline gap on Copilot. It did no harm here; watch for it in the next runs.

## Verdict
Pass: 23/23 checks, every criterion met, every planted violation blocked, mutation 7/7. All four findings are minor. On the next Copilot run, re-check the reviewer's read order and whether `review.md` is saved.
