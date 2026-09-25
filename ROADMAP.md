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
- [x] Code-review gate before apply: `vela-code-review` (two-axis, severities)
- [x] Two agents: `vela-builder` + isolated read-only `vela-reviewer`
- [x] Vela Canvas (REASONS-adapted structured spec, after SPDD) as the plan artifact, with a
      living-spec discipline (fix-spec-first, sync-back)
- [x] Decision guidance in the skills: Sync-vs-Async, reuse-vs-new, service/DI, naming, SOLID/DRY,
      registration legality (`references/registration-rules.md`)
- [x] Trigger-only skill descriptions + claim->proof evidence table
- [x] Observability: machine-readable Run trace in the Build Report
- [x] Dual-target enforcement hooks (Claude Code + Copilot): deny `vela apply` without approval,
      auto-log the run trace
- [x] CI: pack lint (frontmatter, references) + `.github/` sync check
- [x] Agent: vela-builder (Intake→…→review→apply gate)

## Doing

- [ ] Iterate the eval loop to a clean autonomous pass (no blocking finding) = "ready"
- [ ] Thin command wrappers so `/vela-build`, `/vela-grill`, `/vela-apply` are real slash commands

## Backlog

- [ ] Skills for relationships / alternate keys, custom API round-trips, ribbon scripts
- [ ] More eval scenarios (one per gotcha: association, images, deep insert, custom-API naming)
- [ ] A CI job that validates SKILL.md frontmatter and the generated Copilot surface
- [ ] Compatibility matrix (skill version to CLI version) once the first CLI break lands
- [ ] Turn on the isolated review subagent in `vela-code-review` once the loop is stable
- [ ] Sharpen `vela-debug-plugin` with the "no red repro, no hypothesis" + regression-test-before-fix discipline
- [ ] Scoped `vela-security-review` (tiered Always/Ask-first/Never for plugins; align with the harness security plan, don't duplicate)
- [ ] `vela-simplify` gate (behavior-preserving) if plugin diffs start accreting complexity
