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

- [x] Single source of truth: `skills/`, `agents/`, `AGENTS.md`
- [x] Dual-target distribution: Claude Code plugin marketplace + generated Copilot surface
- [x] Skills: scaffold, models, apply, debug-plugin
- [x] Agent: vela-builder (end-to-end)

## Backlog

- [ ] Skills for relationships / alternate keys, custom API round-trips, ribbon scripts
- [ ] A verification/CI job that validates SKILL.md frontmatter and the generated surface
- [ ] Compatibility matrix (skill version to CLI version) once the first CLI break lands
- [ ] Examples / recorded transcripts of end-to-end builds
