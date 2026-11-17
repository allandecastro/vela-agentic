---
name: writing-vela-skills
description: Use when adding, fixing, or reviewing a Vela skill or its wording.
compatibility: "Meta skill - no vela CLI dependency."
license: MIT
metadata:
  version: "0.1.1"
---

# Writing Vela skills

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Skills are process documentation under test. A skill is "done" when a fresh agent following it
literally reaches the right outcome.

## Lean principle

- **Skills drive Vela; they do not document it.** A skill carries the process, the decisions, the gates,
  and the non-obvious traps an agent cannot discover itself. It is not a copy of Vela's docs.
- **Discoverable detail stays out.** Flags (`vela <cmd> --help`, `vela help --json`), API surface (the
  generated code, IntelliSense) and what the compiler or an analyzer reports: point to the source in one
  line ("confirm with `vela <cmd> --help`", "read the generated `<file>`", "raw IP - VELA025"). Keep only
  the smallest code snippet that shows a non-obvious shape.
- **One fact, one place.** Facts live in the root `references/`; skills keep process and cite
  `references/<file>.md`. Never restate a fact in a second file.
- **No version stamps in running text** ("verified x.y", "since", "used to"). The single "Verified
  against" line in `references/cli-surface.md` is the version record.
- **Fixing an eval failure: prefer a general method over a new fact.** First ask whether the skill should
  have told the agent to run `--help`, read the generated code, or write a probe test; add a framework
  fact only when no such method would have found it.

## House style (every skill)

Frontmatter: `name` (kebab) and a **trigger-only `description`** - *when* it applies ("Use when…"),
never a workflow summary (an agent follows the summary instead of the body - observed). Every skill is
model-invoked; one meant for a human conversation may name its slash command (e.g. `/vela-grill`).
Never promise a command that does not exist - the end-to-end loop is the `vela-builder` agent.
**`compatibility`** names the dependency, never a version (`"vela CLI + dotnet SDK."`): the verified version
lives only in `references/cli-surface.md`; meta skills say so instead. The frontmatter follows the
[Agent Skills specification](https://agentskills.io/specification): `license: MIT` and `metadata:` `version:
"x.y.z"` - the skill's own version, never hand-edited (CI bumps it when the skill's folder changes). Code a
skill runs ships in its `scripts/` folder (`vela-code-review/scripts/spec-check.cs`). Body: `Overview → When to use → Process
(announce "Using <skill> to <purpose>") → Rationalizations (excuse → rebuttal) → Red flags →
Verification (the evidence required)`.
`node scripts/sync-copilot.mjs` copies every cited reference (and what it cites) into the skill's own
`references/` folder - never edit those copies. A skill that cites a reference carries, under its title,
the note that `references/` paths are relative to the skill's folder.

## Framework gaps: report them, don't compensate

Vela and its CLI are owned upstream. When a capability is missing or misbehaves, don't invent a
workaround pattern in a skill: state the gap in one or two factual lines (observed behaviour), make the
agent stop or mark the story **blocked** where it matters, and list the gap (with the version) for the
owner. When the fix ships, delete the gap note - no compatibility layers.

## The loop (RED → GREEN → REFACTOR)

1. **RED** - pick or write an eval scenario (`evals/`) and run a fresh subagent against it, following the
   skills to the letter. A deviation, a stuck point or a wrong command/flag is a skill defect.
2. **GREEN** - fix the skill so the correct path is exactly what it says, grounded in source (read the
   CLI/framework, don't guess) and per the lean principle.
3. **REFACTOR** - add the rationalization/red flag that would have stopped the wrong path.
4. Re-run until it passes with **no blocking finding**; record the run in
   `evals/runs/<YYYY-MM-DD>-<scenario>.md` (findings → fixes → verdict).

## What needs an eval (tiered)

- **Behaviour change → an eval that would have caught it, run before and after.** A new or changed
  step, command, flag, API shape, gate, decision rule or red flag. Add or extend a scenario
  (`skills_exercised` lists the skills it covers) and record the run.
- **Grounding change → proof from the source, no run.** Re-verifying a reference against a new version,
  fixing a fact to match `--help` or a compiled/harness-proven sample: paste the output or passing test
  in the PR.
- **Wording change → lint + review.** No change to what an agent does.
When in doubt, it is a behaviour change.

## Rationalizations (excuse → rebuttal)

- "I'm sure the command is X." → Confirm against source or `--help`; "obvious" commands have been wrong.
- "It's a small doc tweak, no test needed." → If it changes what an agent does, it needs an eval.
- "The agent just made a mistake." → If a literal reading let it, the skill is the bug.
- "The eval failed on a missing fact, so I'll add the fact." → Ask first whether `--help`, the generated
  code or a probe test would have found it; teach the method.

## Red flags

- A behaviour change without an eval that exercises it, or an unrecorded run.
- Flag/API catalogues in a skill that `--help`, the generated code or the compiler already show.
- The same fact in two files, or a version stamp in running text.
- A verification section that accepts "seems right" instead of pasted evidence.

## Verification

- Behaviour change: the eval fails before and passes after, recorded under `evals/runs/`.
- Grounding change: the PR carries the `--help` output / compiled or harness-proven sample.
- Every change: `node scripts/lint-pack.mjs` clean, generated surfaces in sync.
