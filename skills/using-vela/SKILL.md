---
name: using-vela
description: Read first when starting any Vela work, or when unsure which Vela skill applies.
---

# Using Vela

Meta-skill: how to work with Vela through its CLI. Read this before the other Vela skills.

## The build loop

A user story becomes a shipped plugin through this loop. Everything is local and
reversible until the gate; the org is only touched at `apply`.

1. **Intake** - turn the story into a concrete spec (entity, message, images, rules).
2. **Plan** - list the tasks: scaffold or existing project? which models? what logic?
3. **Challenge** - `vela-plan-review`: self-grill the plan and fill the **Vela Canvas** (the
   REASONS-adapted spec holding the Sync/Async, reuse-vs-new, service, naming and safeguard
   decisions), flag assumptions. Advisory gate - continue (the user may interrupt). If only the
   human can resolve an ambiguity, use `/vela-grill`. The Canvas is a **living spec**: if the
   requirement changes later, update the Canvas before the code.
4. **Scaffold** - `vela-scaffold`
5. **Model** - `vela-models`
6. **Test (RED)** - `vela-test-harness`: write the failing harness tests for the declared
   acceptance cases, and watch them fail. Test-first is mandatory.
7. **Implement** - `vela-plugin-authoring`: write logic until the tests go **green**.
8. **Verify** - full harness suite green **and** build clean of analyzer (VELA00x) violations,
   then `vela plan` (preview, never writes).
9. **Review** - `vela-code-review`: review the diff on the spec + standards axes; unresolved
   Critical/Required findings block the gate (fix and re-verify).
10. **Apply gate** - emit the **Build Report**, stop. A human runs `vela apply`.
11. **Report** - PR with the Build Report as its body; commit the artifact in the project.

If something misbehaves, switch to `vela-debug-plugin`.

## Skill kinds

- **Model-invoked** (auto): `using-vela`, `vela-plugin-authoring`, `vela-test-harness`,
  `vela-plan-review`, `vela-code-review`, `writing-vela-skills`, `diagnosing-vela`.
- **User-invoked** (`/command`): `/vela-build` (the whole loop), `/vela-grill` (interview the
  story), `/vela-apply` (gated deploy).

## Non-negotiable rules

- **The CLI is the contract.** Confirm flags with `vela <command> --help`; never invent one.
- **Version first.** `vela version` before you rely on any feature.
- **Announce the skill.** Say `Using <skill> to <purpose>` when you start one.
- **Evidence over claims.** No "seems right" - paste the build/test/plan output.
- **Stop before `apply`.** Never write to a live org without explicit human go-ahead; never
  pass `--auto-approve` unless told to for this run.

## References

- `references/cli-surface.md` - exact commands and flags.
- `references/dataverse-gotchas.md` - the real failure modes to watch for.
