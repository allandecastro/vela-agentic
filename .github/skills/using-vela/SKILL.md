---
name: using-vela
description: Read first when starting any Vela work, or when unsure which Vela skill applies.
compatibility: "vela CLI >= 0.19.6 (Vela.Plugins >= 0.28.2); dotnet SDK."
---

# Using Vela

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Meta-skill: how to work with Vela through its CLI. Read this before the other Vela skills.

## The build loop

A user story becomes a shipped plugin through this loop. Everything is local and
reversible until the gate; the org is only touched at `apply`.

1. **Intake** - turn the story into a concrete spec (entity, message, images, rules).
2. **Plan** - list the tasks: scaffold or existing project? which models? what logic?
3. **Challenge** - `vela-plan-review`: self-grill the plan and fill the **Vela Canvas** (the
   REASONS-adapted spec holding the Sync/Async, reuse-vs-new, service, naming and safeguard
   decisions), flag assumptions. Advisory gate - continue (the user may interrupt). If only the
   human can resolve an ambiguity, use `vela-grill`. The Canvas is a **living spec**: if the
   requirement changes later, update the Canvas before the code.
4. **Scaffold** - `vela-scaffold`
5. **Model** - `vela-models`
6. **Test (RED)** - `vela-test-harness`: write the failing harness tests for the declared
   acceptance cases, and watch them fail. Test-first is mandatory.
7. **Implement** - `vela-plugin-authoring`: write logic until the tests go **green**.
8. **Verify** - full harness suite green **and** build clean of analyzer (VELA00x) violations.
9. **Review** - `vela-code-review`: review the diff on the spec + standards axes; unresolved
   Critical/Required findings block the gate (fix and re-verify).
10. **Package & preview** - `vela-apply`: `dotnet pack` → `vela sign` (when the org requires signed
    packages) → `vela plan` on that exact package (preview, never writes). Always run the preview,
    and run it last: a code change after it means re-pack and re-plan.
11. **Apply gate** - emit the **Build Report**, stop. A human runs `vela apply`.
12. **Report** - PR with the Build Report as its body; commit the artifact in the project.

If something misbehaves, switch to `vela-debug-plugin`.

## Skills, agents and how they run

- **Every skill is model-invoked**: you load it when its description matches the situation. A human
  can also run any skill by name as a slash command where the host supports it (`/vela-grill`).
- **`vela-grill`** is the one meant for a conversation with the human. Invoke it yourself when only
  the human can resolve an ambiguity; a human may also start it with `/vela-grill`.
- **The end-to-end loop is the `vela-builder` agent** and the isolated review is the
  **`vela-reviewer` agent** - agents, not skills. There is no `/vela-build` or `/vela-apply` command:
  hand a story to `vela-builder`, and `vela-apply` is the skill it uses to preview.

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
