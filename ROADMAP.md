# Roadmap

`vela-agentic` is the AI layer on top of the Vela CLI. It ships on its own cadence,
independent of the framework/CLI NuGet releases.

## Compatibility policy

- Skills target the **public `vela` CLI command surface**, which is the stable,
  versioned contract.
- Every skill declares a **minimum CLI version** in its `compatibility` frontmatter; the version the
  references were verified against is recorded at the top of `references/cli-surface.md` (CI checks
  that no skill claims a floor above it). Agents run `vela version`, ask for `vela update` if older,
  and stop only if a named feature is genuinely missing (see `AGENTS.md`, golden rule 2).
- On a CLI release: re-run each command's `--help`, update `references/cli-surface.md` + the
  verified version, then bump the skills' floor.
- Skills discover exact flags at runtime via `vela --help`, so additive CLI changes do
  not break them. Breaking CLI changes are matched by a skill update and a bumped
  minimum version.

## v0.1 (initial)

- [x] Single source of truth: `skills/`, `agents/`, `AGENTS.md`, `references/`
- [x] Dual-target distribution: Claude Code plugin marketplace + generated Copilot surface
- [x] Skills grounded in the verified CLI + harness surface (references are verbatim)
- [x] Gated build loop with two artifacts (Vela Canvas + Build Report)
- [x] Front challenge gate: `vela-plan-review` (self-grill) + `/vela-grill` (interview human)
- [x] Loop engineering: `evals/` + `writing-vela-skills` + `diagnosing-vela`
- [x] Skill taxonomy: every skill model-invoked (runnable by name); the loop is the `vela-builder` agent
- [x] Code-review gate before apply: `vela-code-review` (two-axis, severities)
- [x] Two agents: `vela-builder` + isolated read-only `vela-reviewer`
- [x] Vela Canvas (REASONS-adapted structured spec, after SPDD) as the plan artifact, with a
      living-spec discipline (fix-spec-first, sync-back)
- [x] Decision guidance in the skills: Sync-vs-Async, reuse-vs-new, service/DI, naming, SOLID/DRY,
      registration legality (`references/registration-rules.md`)
- [x] Trigger-only skill descriptions + claim->proof evidence table
- [x] Observability: machine-readable Run trace in the Build Report
- [x] Optional dual-target guard hook (Claude Code + Copilot): deny `vela apply` without approval
- [x] CI: pack lint (frontmatter, references) + generated-surface sync check
- [x] Agent: vela-builder (Intake→…→review→apply gate)

## v0.2 (audit follow-up, 2026-09)

- [x] Verified against `vela` 0.19.6 / `Vela.Plugins` 0.28.2; `compatibility` floor per skill, capped by CI
- [x] Skills self-contained once installed: cited references bundled into each skill
- [x] Agents declare their tools; `vela-reviewer` read-only by construction; `<name>.agent.md` for
      Claude Code + Copilot CLI, `.github/agents/` generated (chat modes dropped)
- [x] Apply-guard parses commands (quoted text and heredocs are data), fails closed without `jq`,
      pinned by 78 table tests; embedded in the generated Copilot hook configs
- [x] Loop: preview (`dotnet pack` → `vela sign` → `vela plan`) after review, on the final package
- [x] PreOperation on `ctx.Request.Target` as the default for same-record columns; runtime gotchas
      (recursion guard, plugin state, sandbox, transactions, secrets)
- [x] `vela-custom-api`; `sign` / `inspect` in `vela-apply`; `vela-debug-plugin` evidence discipline
- [x] Lint catches phantom skills, renamed terms, README drift, eval metadata; tiered eval rule, run
      records, generated coverage table

## Doing

- [x] Iteration 1 (2026-09-28): the five new scenarios run by fresh agents, all **fail** - 6 distinct
      blockers (Execute ignores FilterOn, dotnet pack emits no assembly, no sanctioned stage edit, the
      review blocked the no-org stand-in, Function for a flow-called API) fixed; records in `evals/runs/`
- [x] Iteration 2 (2026-09-28/29): the five scenarios **pass** blind (no blocking finding); their minor
      findings fixed; records in `evals/runs/*.iter2.md`
- [ ] Run `ambiguous-story-grill` (new); re-run the older baseline scenarios against the current skills
- [ ] A dev org for evals, to cover `vela-models` and a real `vela plan`

## Backlog

- [ ] Scenarios for the uncovered skills: `vela-grill` (an ambiguous story), `vela-models` (needs a dev org)
- [ ] More gotcha scenarios: association matching, images (typed `partial`), deep insert, bulk `*Multiple`
- [ ] Skills for relationships / alternate keys; web resources (`form-script`, `ribbon-script`) once supported
- [ ] Make `vela-reviewer` the default review path (today: self-review first) once the eval loop is stable
- [ ] Ask upstream (Vela CLI) for a read-only trace command (e.g. `vela logs`) so the agent can read the
      Plug-in Trace Log through the CLI contract
- [ ] Upstream nits seen while verifying: the scaffold's TODO comment still suggests `GetTarget`; after
      `vela add step` the class comment still says "Single-step plugin"
- [ ] Compatibility matrix (skill version to CLI version) once the first CLI break lands
- [ ] Scoped `vela-security-review` (tiered Always/Ask-first/Never for plugins; align with the harness
      security plan, don't duplicate)
- [ ] `vela-simplify` gate (behavior-preserving) if plugin diffs start accreting complexity
