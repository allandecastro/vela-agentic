---
name: diagnosing-vela
description: Model-invoked. Use after an autonomous run to turn a transcript into concrete skill findings — where an agent deviated from a skill, with line-level evidence — feeding the loop-engineering cycle.
---

# Diagnosing Vela runs

Read a run's transcript and produce precise findings against the skills, so the loop-engineering
cycle (`writing-vela-skills`) has something concrete to fix. This is how a messy autonomous run
becomes a numbered list of skill defects.

## When to use

- After an eval/rehearsal or a real run, especially one that stalled or produced wrong output.

## Process

Announce: `Using diagnosing-vela to analyse the run`.

1. Reconstruct what the agent did, step by step, against the build loop.
2. For each deviation, wrong command, or stuck point, record a **finding**:
   - which skill/reference file and what it said,
   - what the agent actually did / the exact error,
   - what the correct command/API is (grounded in source or `--help`),
   - severity: **blocker** (a literal reading fails) vs minor.
3. Separate **skill defects** (fix the skill) from **environment issues** (e.g. no org, a Mono
   segv) — the latter get a note in the relevant skill, not a logic change.
4. Output the numbered findings + a verdict (ready / not ready, top fixes), and hand them to
   `writing-vela-skills`.

## Rationalizations (excuse → rebuttal)

- "The agent was just wrong." → If the skill's literal text allowed it, that's a skill finding.
- "One-off, won't recur." → If nothing closes the loophole, it recurs. Record it and refactor.

## Red flags

- Findings without file + evidence (unactionable).
- Blaming the model instead of the skill for a literal-reading failure.

## Verification

- Every finding names a file, quotes what the skill said, and states the correct path — precise
  enough to edit the skill directly.
