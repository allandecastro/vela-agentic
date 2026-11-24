# Changelog

All notable changes to Vela Agentic are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Versioning policy

- A **release** is a section of [`ROADMAP.md`](ROADMAP.md): `vX.Y.0`, tagged and published as a GitHub release
  whose notes are that section. See the roadmap's **Versioning** section.
- Every other merge to `main` publishes a patch (`X.Y.1`, `X.Y.2`, ...), so plugin hosts see the update. Skills and
  hook scripts carry their own patch versions, bumped when they change.
- The pack is pre-1.0. `1.0.0` waits for Vela 1.0, the public CLI contract the pack drives.
- The Vela version a release is verified against is recorded in
  [`references/cli-surface.md`](references/cli-surface.md).

## [Unreleased]

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

Condensed; the full history is in [`ROADMAP.md`](ROADMAP.md).

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
