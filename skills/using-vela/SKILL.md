---
name: using-vela
description: Read first when starting any Vela work. Explains how the Vela skills fit together, the build loop, and the non-negotiable rules (CLI is the contract, stop before apply, evidence over claims).
---

# Using Vela

Meta-skill: how to work with Vela through its CLI. Read this before the other Vela skills.

## The build loop

A user story becomes a shipped plugin through this loop. Everything is local and
reversible until the gate; the org is only touched at `apply`.

1. **Intake** — turn the story into a concrete spec (entity, message, images, rules).
   State your assumptions; only ask the user if something is genuinely blocking.
2. **Plan** — list the tasks: scaffold or existing project? which models? what logic?
3. **Scaffold** — `vela-scaffold`
4. **Model** — `vela-models`
5. **Implement** — `vela-plugin-authoring`
6. **Verify** — `vela-test-harness` (build + `dotnet test` + `vela plan`)
7. **🚧 Gate** — stop. A human runs `vela apply`.
8. **Report** — PR with the evidence.

If something misbehaves, switch to `vela-debug-plugin`.

## Non-negotiable rules

- **The CLI is the contract.** Confirm flags with `vela <command> --help`; never invent one.
- **Version first.** `vela version` before you rely on any feature.
- **Announce the skill.** Say `Using <skill> to <purpose>` when you start one.
- **Evidence over claims.** No "seems right" — paste the build/test/plan output.
- **Stop before `apply`.** Never write to a live org without explicit human go-ahead; never
  pass `--auto-approve` unless told to for this run.

## References

- `references/cli-surface.md` — exact commands and flags.
- `references/dataverse-gotchas.md` — the real failure modes to watch for.
