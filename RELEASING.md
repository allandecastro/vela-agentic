# Releasing

`vela-agentic` ships on its own cadence, independent of Vela's NuGet releases. Plans and follow-ups are
[issues](https://github.com/allandecastro/vela-agentic/issues); what each release delivered is in
[`CHANGELOG.md`](CHANGELOG.md).

## Versioning

- Versions change **only in a release pull request**, never on an ordinary merge: `main` always carries the version
  of the last release (or of the one being cut). Plugin users get releases, not every merge.
- A **release** is a minor `vX.Y.0` or a patch `vX.Y.Z` (`1.0.0` waits for Vela 1.0, the CLI contract the pack
  drives). Its scope is the `[Unreleased]` section of `CHANGELOG.md`.
- Skills (`metadata.version`) and hook scripts (`# version:`) carry their own patch versions, bumped in the release
  pull request when they changed since the last tag.
- `main` is protected (ruleset): changes go through a pull request with green CI; no force push, no deletion.

## Cutting a release

Pushing a tag triggers nothing in this repository: a release is three manual steps, the tag comes last.

### 1. Before the tag: the release pull request

Every release - a minor `vX.Y.0` or the next patch `vX.Y.Z` - has one pull request, `release/vX.Y.Z`, prepared by
one command:

```bash
node scripts/release.mjs vX.Y.Z
```

It sets `.claude-plugin/plugin.json` and `marketplace.json` to `X.Y.Z`; bumps the patch of every skill and hook
script changed since the last tag; points every tag reference in `docs/` at `vX.Y.Z` (links `/blob/`, `/tree/` and
the "at tag" text of `docs/index.md` - the Vela site serves these pages at that tag); opens `## [X.Y.Z] - <today>`
under `[Unreleased]` in `CHANGELOG.md`; syncs the generated copies; and runs `check-docs --release vX.Y.Z`. Then:

- `CHANGELOG.md`: add the Vela versions the release is verified against at the top of its section.
- Checks: `sh scripts/check.sh`, then the DocFX build of the docs inside a Vela checkout (0 warnings):
  ```bash
  rm -rf docs/ai-layer && cp -R ../vela-agentic/docs docs/ai-layer
  dotnet tool restore && dotnet tool run docfx docs/docfx.json --warningsAsErrors
  rm -rf docs/ai-layer
  ```
- Commit `chore(release): vX.Y.Z`, open the pull request, merge once CI is green.

### 2. The tag and the GitHub release

On the merge commit of the release pull request (`--target` takes the full sha), check again, then one command
creates the tag and the release; its notes are the `[X.Y.Z]` section of `CHANGELOG.md`:

```bash
git fetch && git switch --detach <merge commit sha>
node scripts/check-docs.mjs --release vX.Y.Z
awk '/^## \[X.Y.Z\]/{f=1;next} f&&/^## /{exit} f' CHANGELOG.md > notes.md
gh release create vX.Y.Z --target <merge commit sha> --title vX.Y.Z --notes-file notes.md
```

The `release-check` workflow runs the same check on every published release and fails if the pages name another
tag. A tag is never moved or deleted: the Vela site and the links in `docs/` resolve through it. A mistake is
fixed by a new release.

### 3. After the tag: the Vela side

- Vela watches this repository's releases and opens an issue when one is newer than the tag it pins.
- The Vela maintainer moves the pin of `docs/ai-layer` to `vX.Y.Z`. Vela's docs build then runs on the pack's pages
  (DocFX `--warningsAsErrors`): a link to a renamed Vela page fails that pull request, not the published site.
- Once merged, Vela deploys the site: the "AI layer" section shows the new release.
- Plugin users need nothing: their host's plugin update picks up the new version.

### Minor or patch

- A patch (`X.Y.Z`): fixes, docs, wording - nothing that changes what a user must do.
- A minor (`X.Y.0`) is a decision: a coherent set of changes, or a change of behaviour. During the public
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

`contract/pack-reads.json` declares what the pack reads from the CLI's JSON output: per document (`plan`,
`inspect`, `solution`), the fields the skills and references read (`operations[].kind`), each with the files that
read it; per command, the exit codes the pack handles and the documents (and `mode` values) it reads. The offline
check requires every field to exist in the snapshot's `documents.<name>.schema` and to be named by the files it
cites, and every exit code a declared command returns to be handled. The drift is breaking only where the pack
reads: a read field removed, retyped or no longer required, a handled exit code gone, a declared command returning
a new code, a read mode or document gone, a read document's `schemaVersion` changed. An added field, mode or code
elsewhere, or a changed description, is information (reported, exit 0).

When a skill or reference starts reading a new field (or handling a new exit code, or relying on a `mode`), add it
to `contract/pack-reads.json` in the same pull request: the path as `a.b` / `a[].b` (`vela help --json`,
`documents.<name>.schema`), the files that read it; `node scripts/check-cli-contract.mjs` must pass. When one stops
reading it, remove the entry or the file from its list.

The update is one pull request:

1. `node scripts/check-cli-contract.mjs --latest --update` - installs the newest Vela.Cli, prints the diff, and
   rewrites `contract/` from it.
2. Fix every skill and doc the diff (or the issue) lists as used; set the same version in the "Verified against"
   line of `references/cli-surface.md` and the minimum of `docs/install.md`; `node scripts/sync-copilot.mjs`.
3. `sh scripts/check.sh` green; the pull request's `--pinned` job confirms the snapshot matches its version.
4. Decide whether the pack needs a release (a breaking change does) and add a `CHANGELOG.md` entry.
