---
name: writing-vela-skills
description: Use when adding, fixing, or reviewing a Vela skill or its wording.
compatibility: "Meta skill - no vela CLI dependency."
---

# Writing Vela skills

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

We treat skills as process documentation under test. A skill is only "done" when a fresh agent
following it literally reaches the right outcome without having to rediscover the real API.

## House style (every skill)

Frontmatter: `name` (kebab), and a **trigger-only `description`**: state *when* the skill
applies ("Use when…"), never a summary of what it does. A workflow summary in the description
becomes a shortcut an agent follows instead of reading the skill body - this is an observed
failure mode (an agent that reads "…then emit the artifact. Advisory gate…" skips the actual
steps). Every skill is model-invoked; one meant for a human conversation may name its slash
command in the description (e.g. `/vela-grill`). Never promise a command that does not exist - the
end-to-end loop is the `vela-builder` agent, not a slash command. A **`compatibility`**
field states the CLI floor (`"vela CLI >= x.y.z ..."`, never above the version verified in
`references/cli-surface.md`; meta skills say so instead). Body:
`Overview → When to use → Process (announce "Using <skill> to <purpose>") → Rationalizations
(excuse → rebuttal) → Red flags → Verification (the evidence required)`. Keep the body lean;
push verbatim code and long reference into the root `references/` and cite it as
`references/<file>.md`. `node scripts/sync-copilot.mjs` copies every cited reference (and what it cites)
into the skill's own `references/` folder, so the skill stays self-contained once installed. Never edit
those copies. A skill that cites a reference carries, under its title, the note that `references/`
paths are relative to the skill's folder (some hosts resolve relative paths against the working directory).

## Framework gaps: report them, don't compensate

The pack is the agent layer on top of Vela; Vela and its CLI are owned upstream. When a capability is
missing or misbehaves (e.g. Associate could not be registered at message level before Vela.Plugins
0.33.0), don't invent a workaround pattern in a skill. State the gap in one or two factual lines (observed behaviour + version), make the
agent stop or mark the story **blocked** where it matters, and list the gap for the owner, who fixes it
in Vela / the CLI. When the fix ships, delete the gap note - no compatibility layers.

## The loop (RED → GREEN → REFACTOR)

1. **RED** - write or pick an eval scenario (`evals/`) and run a fresh subagent against it
   following the skills to the letter. Capture where it deviates, gets stuck, or hits a wrong
   command/flag. A deviation is a skill defect, not an agent failure.
2. **GREEN** - fix the skill/reference so the correct path is exactly what the skill says.
   Ground it in source (read the CLI/framework, don't guess); verbatim shapes go in `references/`.
3. **REFACTOR** - close the loophole: add the rationalization/red-flag that would have stopped
   the wrong path, so it cannot recur.
4. Re-run the eval until it passes with **no blocking finding**, and record the run in
   `evals/runs/<YYYY-MM-DD>-<scenario>.md` (findings → fixes → verdict).

## What needs an eval (tiered)

- **Behaviour change → an eval that would have caught it, run before and after.** A new or changed
  step, command, flag, API shape, gate, decision rule or red flag: anything that changes what an agent
  *does*. Add or extend a scenario (`skills_exercised` lists the skills it covers) and record the run.
- **Grounding change → proof from the source, no eval run required.** Re-verifying a reference against
  a new CLI/framework version, fixing a fact to match `--help` or a compiled/harness-proven sample:
  paste the command output or the passing test in the PR instead.
- **Wording change → lint + review.** Typos, renames, links, formatting, with no change to what an
  agent does.
When in doubt, it is a behaviour change.

## Rationalizations (excuse → rebuttal)

- "I'm sure the command is X." → Confirm against source or `--help`; iteration 1 proved several
  "obvious" commands were wrong. Ground it.
- "It's a small doc tweak, no test needed." → If it changes what an agent does, it is a behaviour
  change and needs an eval. Only wording and source-proven grounding fixes skip the run.
- "The agent just made a mistake." → If a literal reading of the skill let it, the skill is the
  bug. Fix the skill.

## Red flags

- A behaviour change without an eval that exercises it, or an eval run that was not recorded.
- Paraphrasing an API in the skill body instead of citing `references/`.
- A verification section that accepts "seems right" instead of pasted evidence.

## Verification

- Behaviour change: the eval fails before and passes after, recorded under `evals/runs/`.
- Grounding change: the PR carries the `--help` output / compiled or harness-proven sample.
- Every change: `node scripts/lint-pack.mjs` clean, generated surfaces in sync.
