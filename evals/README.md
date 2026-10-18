# evals - loop engineering for the Vela skills

We apply TDD to the skills themselves (the `writing-vela-skills` discipline). An eval is a
**pressure scenario**: a fresh agent is told to satisfy it while following the skills *to the
letter*, and every place it deviates, gets stuck, or hits a wrong command/flag is a **finding**
against a skill - not a problem with the agent.

## The loop (RED → GREEN → REFACTOR)

1. **RED** - dispatch a fresh subagent to run a scenario following the skills literally, in an
   isolated scratch dir, with no org (or a dev org for the connected steps). It reports findings.
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
  `runs/<YYYY-MM-DD>-<scenario>.md` (format in `runs/README.md`); the lint checks its frontmatter.

## Coverage

Generated from each scenario's `skills_exercised` by `scripts/sync-copilot.mjs` (do not edit by hand).
The lint warns about any non-meta skill no scenario exercises.

<!-- coverage:start -->
| Skill | Exercised by |
| --- | --- |
| `diagnosing-vela` | diagnose-failed-run |
| `using-vela` | ambiguous-story-grill, apply-gate |
| `vela-apply` | account-deactivate-cascade, account-default-description, account-delete-guard, account-erp-outbound, account-rule-conflict, apply-gate, contact-association, debug-live-trace, deployed-plugin-change, org-models-and-plan, regression-test-guard |
| `vela-code-review` | account-credit-function, account-deactivate-cascade, account-default-description, account-delete-guard, account-erp-outbound, account-multi-step, account-rule-conflict, account-second-behaviour, account-typed-images, account-update-recursion, apply-gate, bulk-update-multiple, contact-association, debug-live-trace, deployed-plugin-change, lead-score-custom-api, org-models-and-plan, regression-test-guard |
| `vela-custom-api` | account-credit-function, lead-score-custom-api |
| `vela-debug-plugin` | debug-filter-miss, debug-live-trace |
| `vela-grill` | account-rule-conflict, ambiguous-story-grill, contact-association |
| `vela-models` | account-credit-function, account-erp-outbound, org-models-and-plan |
| `vela-plan-review` | account-credit-function, account-deactivate-cascade, account-default-description, account-delete-guard, account-erp-outbound, account-multi-step, account-rule-conflict, account-second-behaviour, account-typed-images, account-update-recursion, ambiguous-story-grill, bulk-update-multiple, contact-association, deployed-plugin-change, lead-score-custom-api, regression-test-guard |
| `vela-plugin-authoring` | account-deactivate-cascade, account-default-description, account-delete-guard, account-erp-outbound, account-multi-step, account-rule-conflict, account-second-behaviour, account-typed-images, account-update-recursion, bulk-update-multiple, contact-association, debug-filter-miss, deployed-plugin-change, org-models-and-plan, regression-test-guard |
| `vela-scaffold` | account-credit-function, account-deactivate-cascade, account-default-description, account-delete-guard, account-erp-outbound, account-multi-step, account-second-behaviour, account-typed-images, account-update-recursion, bulk-update-multiple, contact-association, lead-score-custom-api, org-models-and-plan |
| `vela-test-harness` | account-credit-function, account-deactivate-cascade, account-default-description, account-delete-guard, account-erp-outbound, account-multi-step, account-rule-conflict, account-second-behaviour, account-typed-images, account-update-recursion, bulk-update-multiple, contact-association, debug-filter-miss, debug-live-trace, deployed-plugin-change, lead-score-custom-api, org-models-and-plan, regression-test-guard |
| `writing-vela-skills` | **none** |
<!-- coverage:end -->

## Scenarios

One line each (title of the scenario file); the history lives in git and the latest records in `runs/`.

- `scenarios/account-credit-function.md` - a read-only operation bound to an account (typed Custom API)
- `scenarios/account-deactivate-cascade.md` - deactivate the contacts when their account is deactivated
- `scenarios/account-default-description.md` - default an Account's Description on create
- `scenarios/account-rule-conflict.md` - a story that contradicts an existing business rule
- `scenarios/account-delete-guard.md` - block deleting an account that still has active contacts
- `scenarios/account-erp-outbound.md` - notify an external ERP when an account is created (outbound call)
- `scenarios/account-multi-step.md` - add a second step to an existing plugin
- `scenarios/account-second-behaviour.md` - second behaviour on a table that already has a plugin
- `scenarios/account-typed-images.md` - compare old and new values with a typed pre-image
- `scenarios/account-update-recursion.md` - normalise a column on update without re-triggering yourself
- `scenarios/ambiguous-story-grill.md` - a story too vague to build
- `scenarios/apply-gate.md` - reach the apply gate and stop
- `scenarios/bulk-update-multiple.md` - a bulk-aware plugin
- `scenarios/contact-association.md` - react to an association
- `scenarios/debug-filter-miss.md` - "my plugin does not fire"
- `scenarios/debug-live-trace.md` - a deployed plugin fails in the org - diagnose from the real trace log
- `scenarios/deployed-plugin-change.md` - change a plugin that is already deployed (a step goes away)
- `scenarios/diagnose-failed-run.md` - turn a failed builder run into findings against the skills
- `scenarios/lead-score-custom-api.md` - a callable lead-scoring operation
- `scenarios/regression-test-guard.md` - a regression test fails - fix the code, not the test
- `scenarios/org-models-and-plan.md` - real models and a real preview against a dev org

## Guaranteed runs (hidden criteria, separate grader, deterministic checks, N runs)

A single self-graded run is not evidence. A **campaign** runs every scenario **N = 3 times**, and each
run has four independent parts:

1. **Setup (deterministic):** where a scenario starts from a project, `evals/setup/<name>.sh <work>`
   builds it (e.g. `baseline.sh` = the reviewed account-default-description; `debug-filter-miss.sh` =
   the project with the planted bug).
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

A run **passes** only if the checks pass **and** the grader passes. Its record
(`runs/<date>-<scenario>.r<k>.md`) pins `campaign`, `run`, `checks`, `grader`, `vela_cli`, `framework`
and `model`. The pass-rate table below is generated from the records of the latest campaign;
"ready" = every run of the campaign passes.

<!-- passrate:start -->
Latest campaign per scenario - 40/41 runs pass.

| Scenario | Campaign | Runs passed | Checks | Grader | Status |
| --- | --- | --- | --- | --- | --- |
| `account-credit-function` | 2026-10-17 | **3/3** | 3/3 | 3/3 | ready |
| `account-deactivate-cascade` | 2026-10-17c | **0/1** | 1/1 | 0/1 | not ready |
| `account-default-description` | 2026-10-17e | **1/1** | 1/1 | 1/1 | ready |
| `account-delete-guard` | 2026-10-18c | **1/1** | 1/1 | 1/1 | ready |
| `account-erp-outbound` | 2026-10-18c | **1/1** | 1/1 | 1/1 | ready |
| `account-multi-step` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `account-rule-conflict` | 2026-10-18b | **1/1** | 1/1 | 1/1 | ready |
| `account-second-behaviour` | 2026-10-18b | **1/1** | 1/1 | 1/1 | ready |
| `account-typed-images` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `account-update-recursion` | 2026-10-17e | **1/1** | 1/1 | 1/1 | ready |
| `ambiguous-story-grill` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `apply-gate` | 2026-10-17e | **1/1** | 1/1 | 1/1 | ready |
| `bulk-update-multiple` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `contact-association` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `debug-filter-miss` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `debug-live-trace` | 2026-10-17e | **1/1** | 1/1 | 1/1 | ready |
| `deployed-plugin-change` | 2026-10-17 | **3/3** | 3/3 | 3/3 | ready |
| `diagnose-failed-run` | 2026-10-17b | **3/3** | 3/3 | 3/3 | ready |
| `lead-score-custom-api` | 2026-10-17e | **1/1** | 1/1 | 1/1 | ready |
| `org-models-and-plan` | 2026-10-13 | **3/3** | 3/3 | 3/3 | ready |
| `regression-test-guard` | 2026-10-18b | **1/1** | 1/1 | 1/1 | ready |
<!-- passrate:end -->

## Two tiers of checking

- **Structural (CI, every PR):** `scripts/lint-pack.mjs` + the `.github/` sync check in
  `.github/workflows/ci.yml` - frontmatter, trigger-only descriptions, reference links, and that
  the generated Copilot surface matches the source. Cheap, runs on the free runner.
- **Behavioural (agent runner):** the pressure scenarios above need an LLM agent + `vela` + `dotnet`
  (+ Mono on Linux/macOS), so they run on demand / on a self-hosted agent runner, not the free CI.

## Adding a scenario

Cover a real behaviour and at least one gotcha from `references/dataverse-gotchas.md`
(association matching, images, filtering attributes, custom-API dot-free naming, deep insert).
