# Releasing

`vela-agentic` ships on its own cadence, independent of Vela's NuGet releases. Plans and follow-ups are
[issues](https://github.com/allandecastro/vela-agentic/issues); what each release delivered is in
[`CHANGELOG.md`](CHANGELOG.md).

## Versioning

- A **release** is a minor version `vX.Y.0` (`1.0.0` waits for Vela 1.0, the CLI contract the pack drives). Its
  scope is the `[Unreleased]` section of `CHANGELOG.md`.
- Every other merge to `main` bumps the patch (`X.Y.1`, `X.Y.2`, ...) of `.claude-plugin/plugin.json` and
  `marketplace.json`, so `claude plugin update` sees it; skills and hook scripts carry their own patch versions,
  bumped when they change (`.github/workflows/version-bump.yml`).

## Cutting a release

1. One pull request: set `.claude-plugin/plugin.json` and `marketplace.json` to `X.Y.0` (the version-bump workflow
   skips a push that changed the version itself), fold `[Unreleased]` into `## [X.Y.0] - YYYY-MM-DD` in
   `CHANGELOG.md`, and point the links to this repository in `docs/` at the new tag (`/blob/vX.Y.0/`).
2. Before merging: `sh scripts/check.sh`, and the DocFX build of the docs in a Vela checkout:
   ```bash
   rm -rf docs/agents && cp -R ../vela-agentic/docs docs/agents
   dotnet tool restore && dotnet tool run docfx docs/docfx.json --warningsAsErrors   # 0 warnings
   rm -rf docs/agents
   ```
3. After merging: tag the merge commit `vX.Y.0` and publish a GitHub release whose notes are the `[X.Y.0]` section.
   The Vela site picks the docs up when Vela bumps its pinned tag.

## Compatibility with Vela

- Skills target the **public `vela` CLI command surface**, the stable, versioned contract, and discover exact flags
  at run time with `vela <command> --help`, so additive CLI changes do not break them. A breaking change is
  matched by a skill update.
- The Vela version the pack is verified against lives in **one place**, the top of `references/cli-surface.md`.
  Skills carry no version (the lint rejects one in `compatibility`). Agents run `vela version`, ask for
  `vela update` if older, and stop only if a named feature is genuinely missing (`AGENTS.md`, golden rule 2).
- On a Vela CLI or framework release: diff `vela help --json`, update `references/cli-surface.md` and any skill
  whose guidance changed, smoke-test a fresh `vela init` + `vela add`, and rerun the affected evals.
