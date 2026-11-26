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

Pushing a tag triggers nothing in this repository: a release is three manual steps, the tag comes last.

### 1. Before the tag: the release pull request

One pull request, `release/vX.Y.0`:

- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`: `"version": "X.Y.0"`. The version-bump
  workflow skips a push that changed the version itself, so `main` stays at `X.Y.0`.
- `CHANGELOG.md`: rename `[Unreleased]` to `## [X.Y.0] - YYYY-MM-DD` (with the Vela versions it is verified
  against), and open an empty `[Unreleased]` above it.
- `docs/`: every tag reference names the new tag - links (`/blob/vX.Y.0/`, `/tree/vX.Y.0/`) and the text of
  `docs/index.md` ("at tag `vX.Y.0`"). `scripts/check-docs.mjs` fails on any other tag.
- Checks: `sh scripts/check.sh`, then the DocFX build of the docs inside a Vela checkout (0 warnings):
  ```bash
  rm -rf docs/agents && cp -R ../vela-agentic/docs docs/agents
  dotnet tool restore && dotnet tool run docfx docs/docfx.json --warningsAsErrors
  rm -rf docs/agents
  ```
- Merge once CI is green; check that `main` still says `X.Y.0` after the version-bump run.

### 2. The tag and the GitHub release

On the merge commit of the release pull request, one command creates the tag and the release; its notes are the
`[X.Y.0]` section of `CHANGELOG.md`:

```bash
git fetch
awk '/^## \[X.Y.0\]/{f=1;next} f&&/^## /{exit} f' CHANGELOG.md > notes.md
gh release create vX.Y.0 --target <merge commit sha> --title vX.Y.0 --notes-file notes.md
```

A tag is never moved or deleted: the Vela site and the links in `docs/` resolve through it. A mistake is fixed
by a new release.

**Patch release** (a docs or wording fix to publish before the next minor): no release pull request. Merges have
already bumped the patch, so tag the latest commit of `main` with the version its `plugin.json` holds (e.g.
`v0.7.3`), never a lower one, and write short notes listing the merged pull requests:

```bash
git fetch && git show origin/main:.claude-plugin/plugin.json | grep '"version"'
gh release create vX.Y.Z --target "$(git rev-parse origin/main)" --title vX.Y.Z --notes-file notes.md
```

`--target` takes the full commit sha.

### 3. After the tag: the Vela side

- Vela watches this repository's releases and opens an issue when one is newer than the tag it pins.
- The Vela maintainer moves the pin of `docs/agents` to `vX.Y.0`. Vela's docs build then runs on the pack's pages
  (DocFX `--warningsAsErrors`): a link to a renamed Vela page fails that pull request, not the published site.
- Once merged, Vela deploys the site: the "AI agents" section shows the new release.
- Plugin users need nothing: their host's plugin update picks up the new version.

### Minor or patch

- Every merge to `main` is a patch, published automatically.
- A release (`X.Y.0`) is a decision: a coherent set of changes, or a change of behaviour. During the public
  preview it is the only place a breaking change may land.

## Compatibility with Vela

- Skills target the **public `vela` CLI command surface**, the stable, versioned contract, and discover exact flags
  at run time with `vela <command> --help`, so additive CLI changes do not break them. A breaking change is
  matched by a skill update.
- The Vela version the pack is verified against lives in **one place**, the top of `references/cli-surface.md`.
  Skills carry no version (the lint rejects one in `compatibility`). Agents run `vela --version`: an older minor
  stops the run with `vela update`, an older patch warns (`AGENTS.md`, golden rule 2).
- On a Vela CLI or framework release: diff `vela help --json`, update `references/cli-surface.md` and any skill
  whose guidance changed, smoke-test a fresh `vela init` + `vela add`, and rerun the affected evals.

## Vela CLI contract

`contract/vela-help.json` is `vela help --json` of the CLI the pack is verified against, `contract/vela-cli.version`
its version. `scripts/check-cli-contract.mjs` (in `scripts/check.sh`) fails when a skill or doc cites a `vela`
command or option the snapshot lacks, or when `references/cli-surface.md` ("Verified against") or `docs/install.md`
(minimum CLI) state another version. `.github/workflows/cli-contract.yml` diffs the newest Vela.Cli daily and opens
an issue "Vela CLI X.Y.Z changes the contract" listing what changed and where the pack uses it.

The update is one pull request:

1. `node scripts/check-cli-contract.mjs --latest --update` - installs the newest Vela.Cli, prints the diff, and
   rewrites `contract/` from it.
2. Fix every skill and doc the diff (or the issue) lists as used; set the same version in the "Verified against"
   line of `references/cli-surface.md` and the minimum of `docs/install.md`; `node scripts/sync-copilot.mjs`.
3. `sh scripts/check.sh` green; the pull request's `--pinned` job confirms the snapshot matches its version.
4. Decide whether the pack needs a release (a breaking change does) and add a `CHANGELOG.md` entry.
