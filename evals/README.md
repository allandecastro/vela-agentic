# evals - loop engineering for the Vela skills

We apply TDD to the skills themselves (the `pack-writing-skills` discipline). An eval is a
**pressure scenario**: a fresh agent is told to satisfy it while following the skills *to the
letter*, and every place it deviates, gets stuck, or hits a wrong command/flag is a **finding**
against a skill - not a problem with the agent.

## The loop (RED → GREEN → REFACTOR)

1. **RED** - dispatch a fresh subagent to run a scenario following the skills literally, in an
   isolated scratch dir, with the read-only dev org. It reports findings.
2. **GREEN** - fix the offending skill/reference so the correct path is what the skill says.
3. **REFACTOR** - close the loophole: add the rationalization/red-flag that would have stopped
   the agent from taking the wrong path, so it cannot recur.
4. **Re-run** until a scenario passes with **no blocking finding**. That clean pass is the
   definition of "ready" - not a vibe.

## Protocol for a run

- Give the subagent: the scenario file, the scratch dir, the list of skills to obey, and the
  autonomy boundary (local only, **never** `vela apply`, no `--auto-approve`).
- It must produce: loop outcome (per step), numbered findings (file + what the skill said + what
  actually happened + the correct command), evidence (build/test output), and a verdict.
- Findings feed skill edits; edits get a new eval run. Record each run as
  `runs/<campaign>-<scenario>.r<k>.md` (campaign = the date, plus a letter for a second campaign that day;
  format in `runs/README.md`); the lint checks its frontmatter.

## Coverage

Generated from each scenario's `skills_exercised` by `scripts/sync-copilot.mjs` (do not edit by hand).
Shipped skills only (`skills/`); the lint warns about any that no scenario exercises.

<!-- coverage:start -->
| Skill | Exercised by |
| --- | --- |
| `using-vela` | account-delete-role-privilege, ambiguous-story-grill, apply-gate, dispatched-no-human, feature-multi-rule |
| `vela-apply` | account-deactivate-cascade, account-default-description, account-delete-guard, account-erp-outbound, account-mi-outbound, account-rule-conflict, apply-gate, contact-association, creditlimit-threshold-role, debug-live-trace, deployed-plugin-change, feature-multi-rule, org-models-and-plan, regression-test-guard |
| `vela-code-review` | account-credit-function, account-deactivate-cascade, account-default-description, account-delete-guard, account-erp-outbound, account-mi-outbound, account-multi-step, account-rule-conflict, account-second-behaviour, account-territory-cache, account-typed-images, account-update-recursion, apply-gate, bulk-update-multiple, contact-association, contact-shared-default, creditlimit-threshold-role, debug-live-trace, deployed-plugin-change, feature-multi-rule, lead-score-custom-api, org-models-and-plan, regression-test-guard |
| `vela-custom-api` | account-credit-function, lead-score-custom-api |
| `vela-debug-plugin` | debug-filter-miss, debug-live-trace |
| `vela-grill` | account-rule-conflict, account-territory-cache, ambiguous-story-grill, contact-association, dispatched-no-human, feature-multi-rule |
| `vela-models` | account-credit-function, account-delete-role-privilege, account-erp-outbound, account-mi-outbound, account-territory-cache, creditlimit-threshold-role, org-models-and-plan |
| `vela-plan-review` | account-credit-function, account-deactivate-cascade, account-default-description, account-delete-guard, account-delete-role-privilege, account-erp-outbound, account-mi-outbound, account-multi-step, account-rule-conflict, account-second-behaviour, account-territory-cache, account-typed-images, account-update-recursion, ambiguous-story-grill, bulk-update-multiple, contact-association, contact-shared-default, creditlimit-threshold-role, deployed-plugin-change, dispatched-no-human, feature-multi-rule, lead-score-custom-api, regression-test-guard |
| `vela-plugin-authoring` | account-deactivate-cascade, account-default-description, account-delete-guard, account-erp-outbound, account-mi-outbound, account-multi-step, account-rule-conflict, account-second-behaviour, account-territory-cache, account-typed-images, account-update-recursion, bulk-update-multiple, contact-association, contact-shared-default, creditlimit-threshold-role, debug-filter-miss, deployed-plugin-change, feature-multi-rule, org-models-and-plan, regression-test-guard |
| `vela-plugin-testing` | account-credit-function, account-deactivate-cascade, account-default-description, account-delete-guard, account-erp-outbound, account-mi-outbound, account-multi-step, account-rule-conflict, account-second-behaviour, account-territory-cache, account-typed-images, account-update-recursion, bulk-update-multiple, contact-association, contact-shared-default, creditlimit-threshold-role, debug-filter-miss, debug-live-trace, deployed-plugin-change, feature-multi-rule, lead-score-custom-api, org-models-and-plan, regression-test-guard |
| `vela-scaffold` | account-credit-function, account-deactivate-cascade, account-default-description, account-delete-guard, account-erp-outbound, account-mi-outbound, account-multi-step, account-second-behaviour, account-typed-images, account-update-recursion, bulk-update-multiple, contact-association, contact-shared-default, lead-score-custom-api, org-models-and-plan |
<!-- coverage:end -->

## Scenarios

One file per scenario in `scenarios/` (its title says what it covers); the coverage and pass-rate tables
list them all, so this README never drifts from the folder.

## Guaranteed runs (hidden criteria, separate grader, deterministic checks, N runs)

A single self-graded run is not evidence. A new scenario runs **N = 3 times**; a re-run after a skill fix
runs the affected scenarios once each (the table shows N per scenario). Each run has independent parts:

1. **Setup (deterministic):** where a scenario starts from a project, `evals/setup/<name>.sh <work>`
   builds it: `baseline.sh` (the reviewed account-default-description), `debug-filter-miss.sh` (a planted
   filter bug), `regression.sh`, `live.sh` (the project deployed in the dev org), `diagnose.sh`, `signing.sh`.
   The scenario's Setup section names its script (`brief.py` hides it from the actor).
2. **Actor (hidden criteria):** a fresh agent receives only `python3 evals/tools/brief.py <scenario>`
   (the Context / User story / Setup sections) and the work dir - never the expected outcome, the
   planted violations, the scripted human answers or earlier run records. Human questions and scripted
   user messages are delivered by the evaluator during the run.
3. **Deterministic checks:** `python3 evals/checks/check.py <scenario> <work> [--org <url>]` re-verifies
   the result against `evals/checks/<scenario>.json`: rebuild, **the evaluator's own test run**, the
   registration read from the compiled dll (`evals/tools/probe`), the package, forbidden / required
   source patterns, the Canvas, and (org scenarios) a read-only `vela plan`.
4. **Grader (separate agent):** reads the full scenario (hidden sections included), the artifacts and
   the check report; judges the non-deterministic criteria with cited evidence and runs the planted
   violations (mutated copy → fresh `vela-reviewer` → expected severity). The actor never grades itself.

5. **Mutation (measure):** `dotnet run evals/tools/mutate.cs -- --solution <dir>` plants one bug at a time in the
   authored code (negated `if`, flipped comparison, dropped `throw` / assignment / query filter, flipped bool),
   rebuilds and reruns the tests. The grader triages each survivor: a **missing test** or an **equivalent**
   mutant. Recorded as `mutation:`; it does not fail a run while the score is being calibrated.

Campaign helpers: `evals/tools/actor_prompt.py` (the actor's prompt; `--host copilot` with `evals/tools/copilot_actor.sh` runs Copilot CLI as the actor), `evals/tools/after_actor.sh` (checks +
the grader's prompt from `grader_prompt.py`). The dev org is never committed: set `VELA_EVAL_ORG` to its URL (the docs write `https://<dev-org>.crm.dynamics.com`).

A run **passes** only if the checks pass **and** the grader passes. Its record
(`runs/<date>-<scenario>.r<k>.md`) pins `campaign`, `run`, `checks`, `grader`, `vela_cli`, `framework`
and `model`. The pass-rate table below is generated from the records of the latest campaign;
"ready" = every run of the campaign passes.

<!-- passrate:start -->
Latest campaign per scenario - 51/58 runs pass.

| Scenario | Campaign | Runs passed | Checks | Grader | Status |
| --- | --- | --- | --- | --- | --- |
| `account-credit-function` | 2026-10-17 | **3/3** | 3/3 | 3/3 | ready |
| `account-deactivate-cascade` | 2026-10-19 | **3/3** | 3/3 | 3/3 | ready |
| `account-default-description` | 2026-11-23 | **1/1** | 1/1 | 1/1 | ready |
| `account-delete-guard` | 2026-11-23 | **1/1** | 1/1 | 1/1 | ready |
| `account-delete-role-privilege` | 2026-11-02 | **1/1** | 1/1 | 1/1 | ready |
| `account-erp-outbound` | 2026-10-20 | **1/1** | 1/1 | 1/1 | ready |
| `account-mi-outbound` | 2026-10-20 | **1/1** | 1/1 | 1/1 | ready |
| `account-multi-step` | 2026-11-15 | **1/1** | 1/1 | 1/1 | ready |
| `account-rule-conflict` | 2026-10-19 | **3/3** | 3/3 | 3/3 | ready |
| `account-second-behaviour` | 2026-10-19b | **1/1** | 1/1 | 1/1 | ready |
| `account-territory-cache` | 2026-10-19 | **3/3** | 3/3 | 3/3 | ready |
| `account-typed-images` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `account-update-recursion` | 2026-10-19 | **1/1** | 1/1 | 1/1 | ready |
| `ambiguous-story-grill` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `apply-gate` | 2026-10-20 | **1/1** | 1/1 | 1/1 | ready |
| `bulk-update-multiple` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `contact-association` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `contact-shared-default` | 2026-10-23b | **1/1** | 1/1 | 1/1 | ready |
| `creditlimit-threshold-role` | 2026-11-15 | **1/1** | 1/1 | 1/1 | ready |
| `debug-filter-miss` | 2026-11-23 | **0/3** | 3/3 | 0/3 | not ready |
| `debug-live-trace` | 2026-10-20 | **1/1** | 1/1 | 1/1 | ready |
| `deployed-plugin-change` | 2026-10-17 | **3/3** | 3/3 | 3/3 | ready |
| `diagnose-failed-run` | 2026-10-17b | **3/3** | 3/3 | 3/3 | ready |
| `dispatched-no-human` | 2026-10-23 | **1/1** | 1/1 | 1/1 | ready |
| `feature-multi-rule` | 2026-11-23 | **1/3** | 3/3 | 1/3 | not ready |
| `lead-score-custom-api` | 2026-11-23 | **1/1** | 1/1 | 1/1 | ready |
| `org-models-and-plan` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `regression-test-guard` | 2026-11-23 | **3/5** | 3/5 | 3/5 | not ready |
<!-- passrate:end -->

## Two tiers of checking

- **Structural (CI, every PR):** `scripts/check.sh` (lint, configs, shell syntax, the apply-guard tests, the
  generated Copilot surface in sync), the `spec-check` fixture tests and a gitleaks secret scan. Cheap, runs
  on the free runner.
- **Behavioural (agent runner):** the pressure scenarios above need an LLM agent + `vela` + `dotnet`
  (+ Mono on Linux/macOS), so they run on demand / on a self-hosted agent runner, not the free CI.

## Adding a scenario

Each scenario needs `scenarios/<name>.md`, `checks/<name>.json` (the lint enforces the pair) and, when it starts
from a project, a setup script. Cover a real behaviour and at least one gotcha from `references/dataverse-gotchas.md`
(association matching, images, filtering attributes, custom-API dot-free naming, deep insert).
