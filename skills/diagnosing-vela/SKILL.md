---
name: diagnosing-vela
description: Use after an autonomous or eval run when you need to turn what happened into concrete, line-level findings against the skills.
compatibility: "Meta skill - no vela CLI dependency."
---

# Diagnosing Vela runs

Turn a run into numbered, line-level findings against the skills, for `writing-vela-skills` to fix.

## When to use

- After an eval/rehearsal or real run, especially one that stalled or went wrong.

## Process

Announce: `Using diagnosing-vela to analyse the run`.

1. Reconstruct the run against the build loop - from the Build Report's **Run trace** when present,
   else the transcript.
2. Per deviation, wrong command or stuck point, a **finding**: the file and what it said; what the agent
   did / the exact error; the correct command/API (from source or `--help`); severity, exactly one of:
   - **blocker** - a literal reading of the skill leads to the failure, or a missing rule let a gate
     (tests, analyzers, review, preview) pass what it should have stopped;
   - **minor** - anything else (clarity, wording, a gap nothing slipped through).
3. Separate **skill defects** from **environment issues** (no org, a Mono segv): those get a note, not a
   logic change.
4. Output the findings + a verdict (ready / not ready, top fixes).

## Rationalizations (excuse → rebuttal)

- "The agent was just wrong." → If the literal text allowed it, it's a skill finding.
- "One-off, won't recur." → If nothing closes the loophole, it recurs.

## Red flags

- Findings without file + evidence.
- Blaming the model for a literal-reading failure.
- A severity outside blocker / minor ("required" is the review checklist's scale).
- Rating "minor" the rule whose absence let a gate pass the defect.

## Verification

- Every finding names a file, quotes the skill and states the correct path - precise enough to edit it.
