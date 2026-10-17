---
name: diagnosing-vela
description: Use after an autonomous or eval run when you need to turn what happened into concrete, line-level findings against the skills.
compatibility: "Meta skill - no vela CLI dependency."
---

# Diagnosing Vela runs

Read a run's transcript and produce precise findings against the skills, so the loop-engineering
cycle (`writing-vela-skills`) has something concrete to fix. This is how a messy autonomous run
becomes a numbered list of skill defects.

## When to use

- After an eval/rehearsal or a real run, especially one that stalled or produced wrong output.

## Process

Announce: `Using diagnosing-vela to analyse the run`.

1. Reconstruct what the agent did, step by step, against the build loop. Start from the **Run
   trace** in the Build Report (commands, exit codes, gate verdicts) when present - it is
   the structured record; fall back to the host transcript otherwise.
2. For each deviation, wrong command, or stuck point, record a **finding**:
   - which skill/reference file and what it said,
   - what the agent actually did / the exact error,
   - what the correct command/API is (grounded in source or `--help`),
   - severity - exactly one of two, no other scale: **blocker** when a literal reading of the skill leads
     to the failure, or when a missing rule let a quality gate (tests, analyzers, review, preview) pass what it
     should have stopped; **minor** otherwise (clarity, wording, a gap nothing slipped through).
3. Separate **skill defects** (fix the skill) from **environment issues** (e.g. no org, a Mono
   segv) - the latter get a note in the relevant skill, not a logic change.
4. Output the numbered findings + a verdict (ready / not ready, top fixes), and hand them to
   `writing-vela-skills`.

## Rationalizations (excuse → rebuttal)

- "The agent was just wrong." → If the skill's literal text allowed it, that's a skill finding.
- "One-off, won't recur." → If nothing closes the loophole, it recurs. Record it and refactor.

## Red flags

- Findings without file + evidence (unactionable).
- Blaming the model instead of the skill for a literal-reading failure.
- A severity outside blocker / minor (e.g. "required" - that is the review checklist's scale, not this one).
- Rating "minor" the rule whose absence let a gate pass the defect.

## Verification

- Every finding names a file, quotes what the skill said, and states the correct path - precise
  enough to edit the skill directly.
