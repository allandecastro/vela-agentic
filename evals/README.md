# evals — loop engineering for the Vela skills

We apply TDD to the skills themselves (the `writing-vela-skills` discipline). An eval is a
**pressure scenario**: a fresh agent is told to satisfy it while following the skills *to the
letter*, and every place it deviates, gets stuck, or hits a wrong command/flag is a **finding**
against a skill — not a problem with the agent.

## The loop (RED → GREEN → REFACTOR)

1. **RED** — dispatch a fresh subagent to run a scenario following the skills literally, in an
   isolated scratch dir, with no org (or a dev org for the connected steps). It reports findings.
2. **GREEN** — fix the offending skill/reference so the correct path is what the skill says.
3. **REFACTOR** — close the loophole: add the rationalization/red-flag that would have stopped
   the agent from taking the wrong path, so it cannot recur.
4. **Re-run** until a scenario passes with **no blocking finding**. That clean pass is the
   definition of "ready" — not a vibe.

## Protocol for a run

- Give the subagent: the scenario file, the scratch dir, the list of skills to obey, and the
  autonomy boundary (local only, **never** `vela apply`, no `--auto-approve`).
- It must produce: loop outcome (per step), numbered findings (file + what the skill said + what
  actually happened + the correct command), evidence (build/test output), and a verdict.
- Findings feed skill edits; edits get a new eval run. Track iterations.

## Scenarios

- `scenarios/account-default-description.md` — baseline: Account create → default Description.
  Iterations 1-4 (2026-09-24/25) drove the pack from 9 defects (3 blockers) to a clean pass with
  the code-review gate; see the repo history.
- `scenarios/account-second-behaviour.md` — decisions + review: a second behaviour on a table that
  already has a plugin, exercising reuse-vs-new, DRY/service extraction, Sync-vs-Async, and the
  review's SOLID/DRY axis (with a planted-violation check).

## Adding a scenario

Cover a real behaviour and at least one gotcha from `references/dataverse-gotchas.md`
(association matching, images, filtering attributes, custom-API dot-free naming, deep insert).
