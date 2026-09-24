# Roadmap

`vela-agentic` is the AI layer on top of the Vela CLI. It ships on its own cadence,
independent of the framework/CLI NuGet releases.

## Compatibility policy

- Skills target the **public `vela` CLI command surface**, which is the stable,
  versioned contract.
- Every skill declares a **minimum CLI version** in its `SKILL.md` frontmatter/body.
  Agents must run `vela --version` and stop if the installed CLI is older.
- Skills discover exact flags at runtime via `vela --help`, so additive CLI changes do
  not break them. Breaking CLI changes are matched by a skill update and a bumped
  minimum version.

## v0.1 (initial)

- [x] Single source of truth: `skills/`, `agents/`, `AGENTS.md`, `references/`
- [x] Dual-target distribution: Claude Code plugin marketplace + generated Copilot surface
- [x] Skills grounded in the verified CLI + harness surface (references are verbatim)
- [x] Gated build loop with two artifacts (Plan artifact + Build Report)
- [x] Front challenge gate: `vela-plan-review` (self-grill) + `/vela-grill` (interview human)
- [x] Loop engineering: `evals/` + `writing-vela-skills` + `diagnosing-vela`
- [x] Skill taxonomy: model-invoked vs user-invoked
- [x] Agent: vela-builder (Intake→…→apply gate)

## Doing

- [ ] Iterate the eval loop to a clean autonomous pass (no blocking finding) = "ready"
- [ ] Thin command wrappers so `/vela-build`, `/vela-grill`, `/vela-apply` are real slash commands

## Backlog

- [ ] Skills for relationships / alternate keys, custom API round-trips, ribbon scripts
- [ ] More eval scenarios (one per gotcha: association, images, deep insert, custom-API naming)
- [ ] A CI job that validates SKILL.md frontmatter and the generated Copilot surface
- [ ] Compatibility matrix (skill version to CLI version) once the first CLI break lands
- [ ] `vela-reviewer` persona (two-axis: standards + spec) once the loop is stable
