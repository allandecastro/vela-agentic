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
| `diagnosing-vela` | **none** |
| `using-vela` | apply-gate |
| `vela-apply` | account-default-description, apply-gate |
| `vela-code-review` | account-default-description, account-multi-step, account-second-behaviour, account-update-recursion, apply-gate, lead-score-custom-api |
| `vela-custom-api` | lead-score-custom-api |
| `vela-debug-plugin` | debug-filter-miss |
| `vela-grill` | **none** |
| `vela-models` | **none** |
| `vela-plan-review` | account-default-description, account-multi-step, account-second-behaviour, account-update-recursion, lead-score-custom-api |
| `vela-plugin-authoring` | account-default-description, account-multi-step, account-second-behaviour, account-update-recursion, debug-filter-miss |
| `vela-scaffold` | account-default-description, account-multi-step, account-second-behaviour, account-update-recursion, lead-score-custom-api |
| `vela-test-harness` | account-default-description, account-multi-step, account-second-behaviour, account-update-recursion, debug-filter-miss, lead-score-custom-api |
| `writing-vela-skills` | **none** |
<!-- coverage:end -->

## Scenarios

- `scenarios/account-default-description.md` - baseline: Account create → default Description.
  Iterations 1-4 (2026-09-24/25) drove the pack from 9 defects (3 blockers) to a clean pass with
  the code-review gate; see the repo history.
- `scenarios/account-second-behaviour.md` - decisions + review: a second behaviour on a table that
  already has a plugin, exercising reuse-vs-new, DRY/service extraction, Sync-vs-Async, and the
  review's SOLID/DRY axis (with a planted-violation check).
- `scenarios/account-update-recursion.md` - stage + recursion: normalise a column on Update. The
  PostOperation write-back trap recurses until the depth guard throws (reproduced with
  `PluginPipeline`); the skills must lead to PreOperation on `ctx.Request.Target`. Not yet run by a
  fresh agent.
- `scenarios/lead-score-custom-api.md` - Custom API: routing (step vs Custom API), Action vs
  Function, dot-free naming, errors as `InvalidPluginExecutionException`. Not yet run by a fresh agent.
- `scenarios/account-multi-step.md` - `vela add step` on an existing plugin: `Handle<Message>` handler,
  the VELA001 `FilterOn` placeholder, multi-step harness triggers. Not yet run.
- `scenarios/apply-gate.md` - "ship it" is not an apply authorization: build the package → plan on the final
  package, re-plan after a planted change, no self-approval past the hook. Not yet run.
- `scenarios/debug-filter-miss.md` - "my plugin does not fire": failing repro first, then the
  one-line filtering-attribute fix. Not yet run.

## Two tiers of checking

- **Structural (CI, every PR):** `scripts/lint-pack.mjs` + the `.github/` sync check in
  `.github/workflows/ci.yml` - frontmatter, trigger-only descriptions, reference links, and that
  the generated Copilot surface matches the source. Cheap, runs on the free runner.
- **Behavioural (agent runner):** the pressure scenarios above need an LLM agent + `vela` + `dotnet`
  (+ Mono on Linux/macOS), so they run on demand / on a self-hosted agent runner, not the free CI.

## Adding a scenario

Cover a real behaviour and at least one gotcha from `references/dataverse-gotchas.md`
(association matching, images, filtering attributes, custom-API dot-free naming, deep insert).
