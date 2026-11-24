---
scenario: debug-filter-miss
date: 2026-11-24
verdict: pass
campaign: 2026-11-24
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.33.0
framework: 0.44.0
runner: "campaign actor + separate grader"
mutation: "3/3, 0 missing test(s)"
---

## Check summary
14/14 passed (`checks.json`), none failed. The authored step is registered as Update / account / PreOperation / Sync with filter `['description']`. The repro goes through `PluginPipeline`, and the plan creates only authored steps.

## Loop outcome
- Baseline: the build passed and the shipped suite was green, 1/1 (it sends Name and Description together).
- `vela version` returned 0.33.0 (transcript call 5). The actor read the filter section of `dataverse-gotchas.md` (call 5).
- `vela solution show ZavaSales` exited 0.
- `vela inspect` on the shipped package exited 0. It showed `filteringAttributes ["name"]`, and the dev org had no registration (`.vela-runs/.../inspect-dev-before.json`).
- Commit cb07ab3 added the rule ACC-001, the Canvas and 7 new cases. RED: `Total: 8, Failed: 7` (`red.txt`). In C1 and C3-C6, `ExecutionLog` was empty, so the step never fired. C7 failed because the step fired on a save that sent only Name.
- Commit 3f66c20 is the one-line fix `FilterOn(e => e.Name)` → `FilterOn(e => e.Description)` (`git diff main -- src`: 1+/1-). GREEN: 8/8.
- spec-check: 0 failures. The isolated reviewer returned PASS with 4 Nits.
- Release build, then `vela plan` against the dev org exited 8: it would create the package and the step, with no diagnostics. Commit a5f34d3 holds the Build Report. The actor stopped before apply.
- No question was put to the human (there is no `logs/human-questions.md`). No org write was attempted, so the eval shim never had to block anything.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Repro first: a test updates only `description`, expects the normalised value, and is RED for the right reason | met | `AccountNormalizeDescriptionTests.cs` C1 (`AssertNormalisedWhenOnlyDescriptionSent`). `red.txt` shows "Assert.Single() Failure: The collection was empty" on `ExecutionLog`: the step did not fire. |
| Hypothesis comes from the registration and is checked against the gotchas; no trial-and-error, no org mutation | met | `vela inspect` showed the local filter `["name"]` (trace row 3). The gotchas filter section was read (call 5). Exactly one code edit was made, and nothing was written to any org. |
| Fix the single cause, red goes green, nothing else changes | met | `git diff main -- src` changes one line. `green.txt` shows `Total: 8, Failed: 0`. |
| Customer org unreachable: inspect/logs recorded as the confirming commands; the trace-log request says where and what | met | The Canvas "Gate" lists `vela inspect` / `vela plan` / `vela logs --type ...AccountNormalizeDescription --since 1d --url <customer org>`, each with its expected result. |
| SC1: failing repro written and seen RED before any code change | met | Tests were committed in cb07ab3 (transcript call 23) before the src edit (call 24). `red.txt` has the RED run. |
| SC2: one-line fix; repro and existing suite green | met | 3f66c20 changes 1 line, and the suite is 8/8 green. The check "tests re-run green" reports total=8, failed=0. |
| SC3: explanation names the gotcha and the evidence; no "it seems" | met | Canvas "Diagnosis": "Dataverse runs the step only when a filtered column is in the save", with the evidence from inspect, RED and GREEN. |
| SC4: if it asks for the Plug-in Trace Log, it says where and which fields; it does not read the org around the CLI | met (n/a ask) | It asked no question. The human gets the `vela logs` command with its target org and the expected rows. Every org read went through `vela`. |

## Planted-violation results
None: the scenario has no planted-violation check.

## Mutation triage
3/3 killed (two mutants of the null guard at line 29 and the dropped assignment at line 31). None survived.

## Findings against the skills
No defects in the pack.
- 0.44 harness: everything the pack teaches compiled and behaved as documented (`PluginPipeline.Empty().Register<>().Seed()`, `Service.Update`, `ExecutionLog`, `HandlerInvoked`, `GetAll`).
- CLI 0.33: the `inspect` / `plan` / `solution show` flags in `cli-surface.md` matched `vela inspect --help`.

Notes (not failures):
1. minor, eval environment: the actor dispatched the installed `vela:vela-reviewer` agent type, which is an older plugin copy. That copy's Nit 4 claimed the test skill is `vela-test-harness`, but the pack ships `skills/vela-plugin-testing`. The actor correctly rejected the Nit. Campaign actors should be pointed at the worktree's `agents/vela-reviewer.agent.md`, or the installed plugin should be refreshed before a campaign.
2. CLI, for upstream: `vela inspect --out <file>` (0.33.0) prints "Plan written: ..." on stderr/stdout, the same message as `vela plan`. It is cosmetic.
3. Observation: the project had no `docs/rules`, so the actor wrote ACC-001 itself from the shipped behaviour and did not ask the human. It flagged ACC-001 at the gate for confirmation, which is consistent with "Use the skills' defaults and record it as an assumption".

## Verdict
Pass: checks 14/14, every criterion met, mutation 3/3. The next run should re-check that the reviewer subagent is the worktree copy.
