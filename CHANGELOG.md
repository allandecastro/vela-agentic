# Changelog

All notable changes to Vela Agentic are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Versioning policy

- A **release** is a minor version `vX.Y.0`, tagged and published as a GitHub release whose notes are its section
  below. How to cut one: [`RELEASING.md`](RELEASING.md).
- Versions change only in a release pull request (`node scripts/release.mjs vX.Y.Z`): a patch for fixes and docs,
  a minor for new behaviour. Skills and hook scripts carry their own patch versions, bumped in that pull request.
- The pack is pre-1.0 (public preview): a minor release may break compatibility, a patch does not. `1.0.0` waits for
  Vela 1.0, the public CLI contract the pack drives.
- The Vela version a release is verified against is recorded in
  [`references/cli-surface.md`](references/cli-surface.md).

## [Unreleased]

### Changed

- Versions change only in a release pull request, prepared by `node scripts/release.mjs vX.Y.Z` (plugin version,
  changed skills and hook scripts, docs tag references, CHANGELOG section); the version-bump workflow that pushed a
  commit to `main` after every merge is removed, and `main` is protected (pull request with green CI, no force
  push, no deletion).

## [0.8.0] - 2026-11-26

Verified against Vela CLI 0.34.0 and `Vela.Plugins` / `Vela.Testing` 0.45.0 (campaign 2026-11-26:
account-erp-outbound passes on Claude Code).

### Changed

- Verified against Vela CLI `0.34.0` and `Vela.Plugins` / `Vela.Testing` `0.45.0`: `contract/` refreshed,
  `references/cli-surface.md` points to the schemas of `vela help --json` (`documents.<name>.schema`, per-command
  `exitCodes`) instead of copying the JSON shapes; `plan`/`apply` exit `4` writes no JSON document.
- The CLI contract check also covers the JSON output: `contract/pack-reads.json` declares the fields the pack reads
  per document and the exit codes it handles per command. The daily drift fails only when one of them breaks (a read
  field removed, retyped or no longer required, a handled code gone, an unhandled code added, a read mode gone, a
  `schemaVersion` change); additive changes are reported as information.
- Vela.Plugins 0.45.0 disposes the `IDisposable` services an `AddScoped` factory creates: `plugin-authoring-api.md`
  says to return a new instance per execution (never a static one), and the review checklist rates a static one
  Required.
- `docs/index.md`: a clearer intro (the pack builds a Dataverse plugin from a user story and stops before
  deploying).

## [0.7.6] - 2026-11-26

### Changed

- The Vela site section is named **AI layer** and lives at `/vela/ai-layer/` (was "AI agents", `/vela/agents/`):
  it covers the whole pack, not only the agents (`docs/index.md`, `docs/toc.yml`, README, RELEASING.md).

## [0.7.5] - 2026-11-26

Documentation and release-process fix on top of v0.7.3; verified against the same Vela versions as 0.7.0.

### Fixed

- The pages of v0.7.3 named v0.7.0 (`docs/index.md` and the links to this repository). They now name their own tag;
  `scripts/check-docs.mjs --release vX.Y.Z` fails on any other tag or a plugin version that differs, and the
  `release-check` workflow runs it on every published release.
- The build loop diagram is back on one row (the two-row version lost the Verify → Review and findings → Implement
  arrows); the findings loop is dashed.

### Changed

- `RELEASING.md`: every release, a patch included, goes through a release pull request that names its tag.

## [0.7.3] - 2026-11-26

- Documentation patch: the build loop diagram on two rows (reverted in 0.7.5), `RELEASING.md` in three steps, the
  tag check in `scripts/check-docs.mjs`.

## [0.7.0] - 2026-11-25

Verified against Vela CLI 0.33.0 (0.33.1 has the same contract) and `Vela.Plugins` / `Vela.Testing` 0.44.0.

### Added

- Vela CLI contract check: `contract/` holds `vela help --json` of the verified CLI (0.33.0) and its version, the
  pack's single source of it. `scripts/check-cli-contract.mjs` (in `scripts/check.sh`) fails on a `vela` command
  or option the skills, references, agents or docs cite that the CLI lacks, and on a version mismatch with
  `references/cli-surface.md` or `docs/install.md`. A daily workflow diffs the newest Vela.Cli and opens an issue
  when a release changes something the pack uses (#149).
- `docs/install.md` states the minimum Vela CLI version and how to check it.

### Changed

- Version policy (`AGENTS.md` golden rule 2, `using-vela`, the session hook): an older minor Vela CLI stops the
  run with `vela update`, an older patch warns.
- Public preview: until 1.0 a minor release may break compatibility, a patch does not (`docs/overview.md`,
  `docs/install.md`, README).
- `ROADMAP.md` removed: the versioning rule, the release steps and the Vela compatibility policy are in
  `RELEASING.md`; plans and follow-ups are GitHub issues, triaged with `priority:` and `area:` labels.
- CI runs on GitHub-hosted runners only (the repository is public); the self-hosted runner is removed.

## [0.6.0] - 2026-11-24

Verified against Vela CLI 0.33.0 and `Vela.Plugins` / `Vela.Testing` 0.44.0.

### Changed

- `README.md` shortened to what the pack is, how to install it and how to contribute; the rest moved to `docs/`.
- `PluginPipeline` is the only test harness the skills teach, now that `PluginContext` is internal in
  `Vela.Testing` 0.44. The harness, pitfalls and CLI references are aligned with framework 0.44.0 and CLI 0.33.0.
- The generated Copilot agents load skills with Copilot's `skill` tool.

### Added

- `docs/`: the user documentation of the pack (overview, install, the build loop, project files, the deploy guard,
  one page per agent and per skill, how the pack is tested, FAQ). The Vela docs site publishes it as its "AI agents"
  section, copied from a pinned tag.
- `scripts/check-docs.mjs`, run by `scripts/check.sh`: every skill and agent has a page, every page is in the
  section's `toc.yml` with a description and one title, links stay inside the section or point at Vela's docs,
  links to this repository use a tag.
- GitHub Copilot CLI as an eval actor (`evals/tools/copilot_actor.sh`).
- Mutation checks in the evals: behaviour bugs planted after a run; each one the tests miss is a missing test.
- Campaign 2026-11-24 on Vela 0.44 / CLI 0.33: four scenarios pass on Claude Code and on GitHub Copilot CLI (on
  Copilot after a fix: the target solution is asked of the human, never `tbd` when one is reachable).

## Earlier releases

Condensed; the full history is in git (`ROADMAP.md` at [v0.6.0](https://github.com/allandecastro/vela-agentic/blob/v0.6.0/ROADMAP.md)).

- **0.5 (2026-11):** `PROJECT.md` as the only source of the publisher prefix and solutions, `--solution` required on
  plan and apply; one plugin class per table with behaviour-named handlers; one requirement per story; security-role
  models and read-denied cases; gitleaks and the `spec-check` tests in CI.
- **0.4 (2026-10):** guaranteed eval runs (hidden criteria, deterministic checks, a separate grader, N runs, pass
  rate); a leaner pack that discovers CLI and API detail instead of copying it; the rules registry and the test
  intent guard (`spec-check`).
- **0.3 (2026-09):** every skill has a passing blind scenario, one against a dev org; the isolated `vela-reviewer`
  as the default review; `scripts/check.sh` and a pre-push hook.
- **0.2 (2026-09):** skills self-contained once installed; agents with declared tools and a read-only reviewer; the
  apply guard parses commands and is embedded for Copilot; preview on the final package; `vela-custom-api`.
- **0.1:** the initial pack: skills, agents and references from one source for Claude Code and Copilot; the gated
  build loop with the Vela Canvas and the Build Report; the code-review gate; the optional apply guard; evals and
  the maintainer skills.

[Unreleased]: https://github.com/allandecastro/vela-agentic/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/allandecastro/vela-agentic/releases/tag/v0.6.0
