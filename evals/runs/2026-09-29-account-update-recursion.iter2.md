---
scenario: account-update-recursion
date: 2026-09-29
verdict: pass
vela_cli: 0.19.6
framework: 0.28.2
runner: fresh subagent, local, no org, iteration 2
---

## Loop outcome
- Version: `vela version` -> `vela 0.19.6` (exit 0).
- Intake/Plan/Challenge (vela-plan-review): Canvas `ZavaSales/docs/vela-builds/account-description-normalise.md`
  records Update / **Sync PreOperation** / `FilterOn description`, with the reason (same-record column set on
  `ctx.Request.Target`, no extra write, nothing re-triggered) and a **Recursion** safeguard (a PostOperation
  `UserService.Update` would re-trigger the step until the depth guard throws; no `ctx.Depth` return).
  Assumptions: stand-in prefix `zava`, spaces-only collapse, whitespace-only -> ''. Open: target solution + prefix.
  Agent deviation (not a skill defect): `vela init` ran before the Canvas file was written. The decisions were
  already made; the file was written straight after.
- Scaffold (vela-scaffold): `vela init ZavaSales --prefix zava -o .` (exit 0, 6 projects);
  `vela add plugin AccountDescriptionNormalise --entity Account --message Update --filtering-attributes description`
  (exit 0; CLI warned "filtering attribute 'description' may not compile"). Step 5 applied:
  `.PostOperation()` -> `.PreOperation()`, `IUpdatePostContext` -> `IUpdatePreContext`, `e => e.description` ->
  `e => e.Description`. Step 6: all demo plugins, Custom APIs, services and their tests deleted. `dotnet build` ->
  `0 Warning(s) 0 Error(s)`.
- Model (vela-models): no org. Would run `vela models --entities account --out src/zava.Shared/Models/Generated --overwrite -i`.
  Used the sanctioned `// STAND-IN for vela-models (no org)` `Description` property (vela-plugin-authoring step 2).
- Test RED (vela-test-harness): `vela add test AccountDescriptionNormalise --kind plugin --entity Account`, then 7
  cases (the 4 scenario cases + null/empty split + "not sent" + a `PluginPipeline` recursion case). Mono
  xunit.console 2.9.2 `-parallel none`: `Total: 7, Errors: 0, Failed: 3` (exit 1): the 3 behaviour cases failed with
  `Expected: "Hello world" / Actual: "  Hello   world  "`; the 4 guard cases passed before implementation, which the
  skill anticipates.
- Implement (vela-plugin-authoring): `OnUpdate().PreOperation().Sync().FilterOn(e => e.Description)`; the handler
  sets the normalised value on `ctx.Request.Target` only when it changed. There is no `UserService.Update` and no
  `ctx.Depth` check.
- Verify: `dotnet build ZavaSales.sln -c Release` -> `Build succeeded. 0 Warning(s) 0 Error(s)`; the same runner ->
  `zava.Plugins.Tests  Total: 7, Errors: 0, Failed: 0, Skipped: 0` (exit 0).
- Review (vela-code-review, isolated vela-reviewer subagent, diff `git diff --ignore-cr-at-eol 375deda...HEAD` + Canvas):
  **PASS**, 0 Critical/Required, 3 Nits (no whitespace-only test; stand-in model to regenerate; solution/prefix open).
- Package (vela-apply): `dotnet build ZavaSales.sln -c Release` (exit 0) -> `artifacts/zava.Plugins.1.0.0.nupkg`,
  `unzip -l` shows `lib/net462/zava.Plugins.dll`, sha256 `9703f2dde3abee17aa100a3864d106823d46ec25c22c350ae8b2518b2695338a`, unsigned.
- Plan: skipped - no org. Would run `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg --connection-string "$DATAVERSE_CONNECTION_STRING" --out plan.json`.
- Apply gate: Build Report written into the same file (`kind: vela-build`, `status: awaiting-apply`). Stopped. `vela apply` not run.
- Report: draft PR / `gh pr ready` skipped (eval). Local git only (branch `feature/account-description-normalise`, 4 commits).

### Planted-violation check (separate copies `variant-a|b|c`, each reviewed by a fresh isolated vela-reviewer)
| Variant | Expected | Review result | Also caught by |
| --- | --- | --- | --- |
| (a) PostOperation + `ctx.UserService.Update` of the same account | Critical | **Critical** (self-trigger: written column is in `FilterOn`) + Critical (unplanned write) + Required (stage drift). BLOCK | harness: `InvalidPluginExecutionException : Plugin execution stopped to prevent recursion.` (pipeline test); 4/7 fail |
| (b) same + `if (ctx.Depth > 1) return;` | Required | Flagged, but rated **Critical** ("hides the self-trigger"), alongside the recursion Critical. BLOCK | harness: `Assert.Single() Failure: The collection contained 2 items ... (depth 1) ... (depth 2)`; 4/7 fail |
| (c) mutable `private string lastDescription;` field | Required (VELA011) | **Required** (VELA011). BLOCK | build: `warning VELA011: Field 'lastDescription' is mutable state on a plugin type` |

All three were flagged and blocked the gate. The one mismatch is the severity on (b); see finding 1.

## Findings
Skill defects (none blocking):
1. minor - `skills/vela-code-review/references/review-checklist.md` has two rules that point different ways for
   planted variant (b). The **Recursion** bullet says "a write that can re-trigger the same step ... without a guard -
   **Critical**". The **Runtime** bullet says "no `ctx.Depth` early return without a reason in the Canvas
   (**Required**; the unguarded self-trigger it hides is the **Critical** one)". The isolated reviewer rated the
   depth check itself **Critical**, not the expected Required, and noted the ambiguity: "a `ctx.Depth` check is
   technically a guard. Only the Runtime bullet makes clear that a depth check does not count". The gate outcome was
   still correct (BLOCK). Fix: state that a depth check is not a guard, and that the depth line is Required while the
   write-back it masks is Critical, each reported once.
2. minor - `review-checklist.md` Runtime bullet "no mutable fields on the plugin class (VELA011)" gives no explicit
   severity. The reviewer reached **Required** only through AGENTS.md golden rule 5, and remarked that "it could be
   argued as Critical". Fix: label it Required inline.
3. minor - `skills/vela-code-review/references/` does not include `harness-api.md`. All four reviewers raised it as an
   ambiguity or a Nit: "The references do not say what message or stage `PluginContext.For<T>().Execute(...)`
   defaults to". The fact they needed ("a single-step plugin auto-derives") lives only in
   `vela-test-harness/references/harness-api.md`. Fix: bundle it with the review skill, or add a one-line note to the checklist.
4. minor - The Update "not sent vs cleared" coverage and the pipeline recursion case appear only at TEST.
   `vela-test-harness/SKILL.md` requires "on **Update**: a column **not sent** vs a column **cleared**" and
   "`PluginPipeline` ... cascades, recursion". `vela-plan-review`'s "Acceptance cases" grilling item ("primary
   behaviour, each edge, each applicable gotcha") does not name either, so the Canvas had to be amended mid-build
   (fix-spec-first; recorded in the Sync log). Fix: add both to the plan-review grilling list for Update steps.
5. minor - `skills/vela-models/SKILL.md` has no no-org branch or pointer. The MODEL step comes before IMPLEMENT, but
   the sanctioned stand-in rule lives only in `vela-plugin-authoring` step 2 ("No-org exception (evals/rehearsals only)").
   A literal reader at MODEL, with only vela-models loaded, has no path forward. Fix: add "No org: see
   vela-plugin-authoring step 2 (stand-in)" to vela-models.
6. minor - `skills/vela-scaffold/SKILL.md` step 2 says "**Don't invent a prefix - use the target Dataverse solution's
   own publisher customization prefix**", but gives no no-org fallback. The agent picked a stand-in `zava` and logged
   it as an assumption plus an open question. Fix: say "no org: stand-in prefix, recorded as an open question in the Canvas".
7. minor - `skills/vela-scaffold/SKILL.md` step 6 ("Delete them (keep what the Canvas asks for)") says nothing about the
   emptied `zava.Integrations` project. After deleting its demos, `dotnet build -c Release` still produced
   `artifacts/zava.Integrations.1.0.0.nupkg` (containing a 4096-byte `zava.Integrations.dll`). `vela-apply` step 5
   (plan the plugin package only) contains it, but `--packages-dir artifacts` would pick it up. Fix: recommend
   `vela init ... --no-integrations` when the Canvas needs no Integrations project, or removing the emptied projects from the sln.
8. minor - `skills/vela-code-review/SKILL.md` step 1 says "base = the branch point". In a fresh `git init` where the
   feature branch is created before the first commit, `main` has no commits, so there is no branch point. The skill's
   fallback ("commit right after scaffolding and diff against that commit") worked (`375deda...HEAD`). The skill also
   does not say how to hand an isolated reviewer a diff dominated by demo deletions (24 files, 1151 deleted lines).
   The agent pasted `--diff-filter=AM` plus the list of deleted names. It also does not mention that the scaffold
   writes CRLF files (`ASCII text, with CRLF line terminators`), so any LF rewrite shows as a whole-file diff. The
   agent used `--ignore-cr-at-eol`.
9. minor - `skills/vela-scaffold/SKILL.md` step 4 lists `vela add customapi <Name> [--entity <E>] [--function|--action] [--prefix <pub>]`.
   `vela add --help` (0.19.6) prints `vela add customapi <Name> [--entity <ModelType>] [--bound|--global] [--function|--action] [--project <csproj>] [--force]`,
   with no `--prefix`. This scenario does not exercise it; it was observed while confirming flags.
10. minor - The Canvas `assumptions` vs `acceptance_cases` boundary is unclear. A behaviour recorded only as an
    assumption (whitespace-only -> '') got no test. Two reviewers asked whether it needs one and rated it a Nit.
    Neither `vela-plan-review` nor the checklist says whether an assumed behaviour needs a test.

Environment (not skill defects):
- `xunit.runner.console` 2.9.2 was already in `~/.nuget/packages`, so the PackageReference step in harness-api was not needed.
  Mono runner worked with `-parallel none`, and there was no segv.
- `vela plan --help` / `vela init --help` print the global help page. `-p` and `vela init <Name>`/`-o` are not shown
  there but are documented in cli-surface.md, and both worked.

## Fixes
- None yet (this is the iteration 2 record; findings 1-10 are inputs for the next iteration).

## Verdict
**pass** - no blocking finding. All four success criteria were met:
- The Canvas has Sync PreOperation with its reason and a recursion safeguard.
- The code has `OnUpdate().PreOperation().Sync().FilterOn(e => e.Description)` and edits `ctx.Request.Target`, with no
  `UserService.Update` and no `ctx.Depth` check.
- RED 3/7 went to GREEN 7/7 on Mono xunit.console, and `crm.GetAll("account")` stayed empty.
- The build has 0 VELA00x, and the review PASSed.

The planted-violation check flagged and blocked all three variants. The only miss is that (b)'s depth check was
rated Critical instead of Required (finding 1).

The next run must re-check:
- (b)'s severity after the checklist wording is fixed;
- that reviewers can confirm harness defaults (finding 3);
- the no-org paths in vela-models and vela-scaffold (findings 5 and 6).
