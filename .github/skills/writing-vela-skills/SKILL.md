---
name: writing-vela-skills
description: Use when adding, fixing, or reviewing a Vela skill or its wording.
---

# Writing Vela skills

We treat skills as process documentation under test. A skill is only "done" when a fresh agent
following it literally reaches the right outcome without having to rediscover the real API.

## House style (every skill)

Frontmatter: `name` (kebab), and a **trigger-only `description`**: state *when* the skill
applies ("Use when…"), never a summary of what it does. A workflow summary in the description
becomes a shortcut an agent follows instead of reading the skill body - this is an observed
failure mode (an agent that reads "…then emit the artifact. Advisory gate…" skips the actual
steps). User-invoked skills may name their command (e.g. `/vela-grill`); the model/user-invoked
kind otherwise lives in the body and the README table, not the description. Body:
`Overview → When to use → Process (announce "Using <skill> to <purpose>") → Rationalizations
(excuse → rebuttal) → Red flags → Verification (the evidence required)`. Keep the body lean;
push verbatim code and long reference into `references/` and point at it.

## The loop (RED → GREEN → REFACTOR)

1. **RED** - write or pick an eval scenario (`evals/`) and run a fresh subagent against it
   following the skills to the letter. Capture where it deviates, gets stuck, or hits a wrong
   command/flag. A deviation is a skill defect, not an agent failure.
2. **GREEN** - fix the skill/reference so the correct path is exactly what the skill says.
   Ground it in source (read the CLI/framework, don't guess); verbatim shapes go in `references/`.
3. **REFACTOR** - close the loophole: add the rationalization/red-flag that would have stopped
   the wrong path, so it cannot recur.
4. Re-run the eval until it passes with **no blocking finding**.

## Rationalizations (excuse → rebuttal)

- "I'm sure the command is X." → Confirm against source or `--help`; iteration 1 proved several
  "obvious" commands were wrong. Ground it.
- "It's a small doc tweak, no test needed." → No skill change ships without a scenario that
  would have caught the defect. That is the iron law.
- "The agent just made a mistake." → If a literal reading of the skill let it, the skill is the
  bug. Fix the skill.

## Red flags

- Editing a skill without an eval that exercises the change.
- Paraphrasing an API in the skill body instead of citing `references/`.
- A verification section that accepts "seems right" instead of pasted evidence.

## Verification

- The changed skill has an eval that fails before the change and passes after, and the eval run
  is recorded (findings → fixes → clean pass).
