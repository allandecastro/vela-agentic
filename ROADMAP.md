# Roadmap

`vela-agentic` is the AI layer on top of the Vela CLI. It ships on its own cadence,
independent of the framework/CLI NuGet releases.

## Compatibility policy

- Skills target the **public `vela` CLI command surface**, which is the stable,
  versioned contract.
- The version the pack is verified against lives in **one place**, the top of `references/cli-surface.md`.
  Skills carry no version (their `compatibility` is `vela CLI + dotnet SDK.`; the lint rejects a version
  there). Agents run `vela version`, ask for `vela update` if older, and stop only if a named feature is
  genuinely missing (`AGENTS.md`, golden rule 2).
- On a CLI or framework release: diff `vela help --json`, update `references/cli-surface.md` and any skill
  whose guidance changed, smoke-test a fresh `vela init` + `vela add`, and rerun the affected evals.
- Skills discover exact flags at runtime via `vela <command> --help`, so additive CLI changes do not break
  them. A breaking CLI change is matched by a skill update.

## Versioning

- A **release** is a section of this roadmap: `vX.Y.0`. Its release commit sets `.claude-plugin/plugin.json` and
  `marketplace.json` to `X.Y.0` (the version-bump workflow then leaves it), is tagged `vX.Y.0`, and gets a GitHub
  release whose notes are the section.
- Every other merge to `main` bumps the patch (`X.Y.1`, `X.Y.2`, ...), so `claude plugin update` sees it; skills and
  hook scripts carry their own patch versions, bumped when they change.
- A new section starts at the next minor; `1.0.0` waits for Vela 1.0 (the public CLI contract it drives).

## v0.1 (initial)

- [x] Single source of truth: `skills/`, `agents/`, `AGENTS.md`, `references/`
- [x] Dual-target distribution: Claude Code plugin marketplace + generated Copilot surface
- [x] Skills grounded in the verified CLI + harness surface (references are verbatim)
- [x] Gated build loop with two artifacts (Vela Canvas + Build Report)
- [x] Front challenge gate: `vela-plan-review` (self-grill) + `/vela-grill` (interview human)
- [x] Loop engineering: `evals/` + the maintainer skills `pack-writing-skills` + `pack-diagnosing-runs`
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

- [x] Verified against `vela` 0.19.6 / `Vela.Plugins` 0.28.2 (a per-skill version floor at the time, since removed)
- [x] Skills self-contained once installed: cited references bundled into each skill
- [x] Agents declare their tools; `vela-reviewer` read-only by construction; `<name>.agent.md` for
      Claude Code + Copilot CLI, `.github/agents/` generated (chat modes dropped)
- [x] Apply-guard parses commands (quoted text and heredocs are data), fails closed without `jq`,
      pinned by table tests; embedded in the generated Copilot hook configs
- [x] Loop: preview (package → `vela sign` → `vela plan`) after review, on the final package
- [x] PreOperation on `ctx.Request.Target` as the default for same-record columns; runtime gotchas
      (recursion guard, plugin state, sandbox, transactions, secrets)
- [x] `vela-custom-api`; `sign` / `inspect` in `vela-apply`; `vela-debug-plugin` evidence discipline
- [x] Lint catches phantom skills, renamed terms, README drift, eval metadata; tiered eval rule, run
      records, generated coverage table

## v0.2 iterations (2026-09)

- [x] Iteration 1 (2026-09-28): the five new scenarios run by fresh agents, all **fail** - 6 distinct
      blockers (Execute ignores FilterOn, dotnet pack emits no assembly, no sanctioned stage edit, the
      review blocked the no-org stand-in, Function for a flow-called API) fixed; records in `evals/runs/`
- [x] Iteration 2 (2026-09-28/29): the five scenarios **pass** blind (no blocking finding); their minor
      findings fixed
- [x] 2026-09-29: `ambiguous-story-grill` and the two baseline scenarios pass blind; their minors fixed
      (all seven scenarios now pass)
- [x] Dev org for evals (solution `VelaEvals`, prefix `veval`, read-only use):
      `org-models-and-plan` passes - every skill now has a passing scenario
- [x] Re-verified against vela CLI 0.21.0 / Vela.Plugins 0.29.1 (help surface unchanged; `models`
      without `--namespace` now exits 2)

## v0.3 (2026-09-29)

- [x] Every skill has a passing blind scenario (8 scenarios, one against a dev org); a real `vela apply`
      to the dev org verified end to end
- [x] The isolated `vela-reviewer` is the default review path; self-review is a labelled fallback
- [x] `scripts/check.sh` replays the CI locally, run by a pre-push hook (`git config core.hooksPath .githooks`)

## v0.4 (2026-10) - guaranteed runs, lean pack, business rules

- [x] **Guaranteed runs:** hidden criteria, deterministic checks (`evals/checks/`), separate grader, planted
      violations replayed against a fresh reviewer, N runs per scenario, pass rate generated into
      `evals/README.md`; run records pin the CLI, framework and model versions
- [x] Scenarios for outbound calls (Integrations, secure config), typed bound Custom API, Delete, deactivate
      (Update on `statecode`), debug from the real trace log, changing a deployed plugin, `pack-diagnosing-runs`
- [x] **Lean pack** (29.8k -> 19.4k words): skills drive Vela; API/CLI detail is discovered (`--help`, the
      generated code, Vela's `docs/llms.txt`), not copied; no version stamps in running text
- [x] **Rules registry** (`docs/rules/<table>.md`, English Given/When/Then, read at intake, contradictions
      asked) and the **test intent guard** (cases as the functional spec of the tests, `[Trait("Case", ...)]`,
      registry read-only in the build, `tools/spec-check.cs`)
- [x] Every Vela gap found by the evals reported to and fixed in Vela (WithService, typed images on choice
      columns, `{Handler}Context` in the scaffold, VELA025/026/027, ...) - pack verified on vela 0.27 /
      Vela.Plugins 0.39

## v0.5 (2026-11) - Vela 0.43 / CLI 0.31, one requirement per story, repo hygiene

- [x] `PROJECT.md` as the only source of the publisher prefix and solutions; `--solution` required on plan/apply
- [x] One plugin class per table with behaviour-named handlers; `PluginPipeline` as the default test runner;
      `change: tests` when tests are rewired without changing a rule
- [x] One requirement = one story (one Canvas, branch and PR), however many rules
- [x] Security-role models (`vela models --roles`) and read-denied cases; typed `Retrieve<T>` / `RetrieveByKey<T>`
- [x] Campaign 2026-11-15: five scenarios pass on checks and grader
- [x] Secret scan (gitleaks) in CI and the local check; the spec-check tests in CI

## v0.6 (2026-11) - Vela 0.44 / CLI 0.33, PluginPipeline only, GitHub Copilot

- [x] `PluginPipeline` is the only harness taught (`PluginContext` is internal in Vela.Testing 0.44); harness,
      gotchas and CLI references aligned with framework 0.44.0 / CLI 0.33.0
- [x] GitHub Copilot CLI as an eval actor (`evals/tools/copilot_actor.sh`); the generated Copilot agents load
      skills with Copilot's `skill` tool
- [x] Mutation checks in the evals: planted behaviour bugs after a run, every survivor a missing test
- [x] Campaign 2026-11-24 (Copilot, Vela 0.44): 3 of 4 scenarios pass; the fail (an unasked solution) fixed

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
