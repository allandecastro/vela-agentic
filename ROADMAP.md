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
- [x] 2026-09-29: `ambiguous-story-grill` and the two baseline scenarios pass blind; their minors fixed
      (all seven scenarios now pass)
- [x] Dev org for evals (DYN-PREMIUM-DEV, solution `VelaEvals`, prefix `veval`, read-only use):
      `org-models-and-plan` passes - every skill now has a passing scenario
- [x] Re-verified against vela CLI 0.21.0 / Vela.Plugins 0.29.1 (help surface unchanged; `models`
      without `--namespace` now exits 2)

## v0.3 (2026-09-29)

- [x] Every skill has a passing blind scenario (8 scenarios, one against a dev org); a real `vela apply`
      to the dev org verified end to end
- [x] The isolated `vela-reviewer` is the default review path; self-review is a labelled fallback
- [x] `scripts/check.sh` = the CI, run locally by a pre-push hook (`git config core.hooksPath .githooks`)

## v0.4 (2026-10) - guaranteed runs, lean pack, business rules

- [x] **Guaranteed runs:** hidden criteria, deterministic checks (`evals/checks/`), separate grader, planted
      violations replayed against a fresh reviewer, N runs per scenario, pass rate generated into
      `evals/README.md`; run records pin the CLI, framework and model versions
- [x] Scenarios for outbound calls (Integrations, secure config), typed bound Custom API, Delete, deactivate
      (Update on `statecode`), debug from the real trace log, changing a deployed plugin, `diagnosing-vela`
- [x] **Lean pack** (29.8k -> 19.4k words): skills drive Vela; API/CLI detail is discovered (`--help`, the
      generated code, Vela's `docs/llms.txt`), not copied; no version stamps in running text
- [x] **Rules registry** (`docs/rules/<table>.md`, English Given/When/Then, read at intake, contradictions
      asked) and the **test intent guard** (cases as the functional spec of the tests, `[Trait("Case", ...)]`,
      registry read-only in the build, `tools/spec-check.cs`)
- [x] Every Vela gap found by the evals reported to and fixed in Vela (WithService, typed images on choice
      columns, `{Handler}Context` in the scaffold, VELA025/026/027, ...) - pack verified on vela 0.27 /
      Vela.Plugins 0.39

## Next

- [x] Omitted Vela features as decisions + pointers (localized messages, environment variables, cache,
      telemetry, `WithSecurity`, harness limitations)
- [x] A concrete trigger to extract a service + a scenario (`contact-shared-default`)
- [x] Re-run `account-deactivate-cascade` x3; a managed identity + signing scenario (`account-mi-outbound`)
- [x] Small follow-ups from the graders (failing test names, `retiring` state, step removal, regression commit)
- [ ] Distribution of the pack: through the `vela` CLI in addition to the plugin marketplace, or the CLI
      installing from the marketplace - to design
- [ ] A dedicated agent to migrate an existing plugin project to Vela
- [ ] `debug-live-trace`: refresh the live trace rows before a run (plug-in trace logs expire, often after 24h)
- [ ] Web resources (`form-script`, `ribbon-script`) - out of scope while in preview
