---
scenario: account-update-recursion
date: 2026-09-28
verdict: fail
vela_cli: 0.19.6
framework: 0.28.2
runner: fresh subagent, local, no org
---

## Loop outcome
- Version: `vela version` → `vela 0.19.6` (exit 0). dotnet 10.0.302, Mono 6.14.1.
- Intake/Plan/Challenge (vela-plan-review): Canvas `docs/vela-builds/account-normalize-description.md`; Approach = **Sync PreOperation** on `ctx.Request.Target` (same-record column, no extra write, nothing re-triggered); recursion recorded as a Safeguard. Assumptions: prefix `Zava` stand-in, "repeated spaces" = space char; open question: target solution.
- Scaffold (vela-scaffold): `vela init ZavaSales --prefix Zava -o src-root` exit 0 (Vela.Plugins 0.28.2); baseline `dotnet build` 0 errors / 4 demo VELA013. `vela add plugin AccountNormalizeDescription --entity Account --message Update --filtering-attributes description` exit 0, warned `filtering attribute 'description' may not compile`, generated **`.PostOperation()` + `IUpdatePostContext<Account>` + `FilterOn(e => e.description)`**. Hand-edited to `.PreOperation()`, `IUpdatePreContext<Account>`, `e => e.Description` (see finding 1). Rebuild 0 errors.
- Model (vela-models): skipped, no org. Would run `vela models --entities account --out src/Zava.Shared/Models/Generated --overwrite -i`. `Description` added as `// STAND-IN for vela-models (no org)` to the sealed generated `Account.cs`.
- Test RED (vela-test-harness): `vela add test AccountNormalizeDescription --kind plugin --entity Account` exit 0; 6 tests (5 Canvas cases + PluginPipeline recursion case). `mono ~/.nuget/packages/xunit.runner.console/2.9.2/tools/net462/xunit.console.exe …/Zava.Plugins.Tests.dll -parallel none -class …AccountNormalizeDescriptionTests` → `Total: 6, Errors: 0, Failed: 3, Skipped: 0` exit 1. The 3 normalisation cases fail (`Expected: "Hello world"`, `Actual: "  Hello   world  "`); normal/null/empty pass vacuously.
- Implement (vela-plugin-authoring): `OnExecute(IUpdatePreContext<Account>)` edits `ctx.Request.Target.Description` (trim + `Regex(" {2,}")` → " ", assigned only when changed; null/empty → return). No `UserService` write, no `ctx.Depth`, no mutable field. GREEN `Total: 6, Errors: 0, Failed: 0` exit 0.
- Verify: `dotnet build ZavaSales.sln -c Release --no-incremental` → `4 Warning(s)`, `0 Error(s)`. All 4 are VELA013 in scaffold demo tests; 0 VELA in authored files. Full suites: `Zava.Plugins.Tests Total: 15, Failed: 0` and `Zava.Integrations.Tests Total: 3, Failed: 0`, both exit 0.
- Review (vela-code-review): self-review **PASS** (3 Nits). The isolated `vela-reviewer` on the same diff returned **BLOCK**: 1 Required on the sanctioned no-org model stand-in, plus 4 Nits (finding 6). Diff = `diff -ruN base-ZavaSales src-root/ZavaSales` (no git, finding 7).
- Package & preview (vela-apply): `dotnet pack src/Zava.Plugins/Zava.Plugins.csproj -c Release -o artifacts` exit 0 → `Zava.Plugins.1.0.0.nupkg` sha256 `889a37c1a663cdc0845f522b730e5b8f9b2a6bff4c3035bd35ae43d2b949d781`; the packaged DLL hash equals the built DLL. Sign skipped (no certificate). `vela plan -p artifacts/Zava.Plugins.1.0.0.nupkg --connection-string "$DATAVERSE_CONNECTION_STRING" --out plan.json` skipped (no org).
- Apply gate: Build Report `docs/vela-builds/account-normalize-description.build.md` emitted; stopped. `vela apply` not run.
- Report: draft PR skipped (eval).

### Planted-violation check
Each variant is a separate copy under `planted/<v>/`, built and run against the same 6 tests, then reviewed by an isolated read-only reviewer that received only the diff, the Canvas and the review skill.

| variant | build | harness (6 cases) | isolated review | expected | match |
|---|---|---|---|---|---|
| (a) PostOp + unconditional `ctx.UserService.Update` | 0 err, 0 VELA | Failed 4; pipeline test throws `InvalidPluginExecutionException : Plugin execution stopped to prevent recursion.` | **Critical** (Recursion rule) + Required (Stage) → BLOCK | Critical | yes |
| (a2) same, write only if changed | 0 err, 0 VELA | Failed 2; pipeline test **passes** | **Required** (Stage); explicitly not Critical ("has a guard") → BLOCK | (not in scenario) | n/a, see finding 5 |
| (b) (a) + `if (ctx.Depth > 1) return;` | 0 err, 0 VELA | Failed 3; pipeline test **passes** | **Critical** (Recursion rule + depth gotcha) + Required ×3 → BLOCK | Required | severity differs (blocks either way), finding 4 |
| (c) correct impl + `private string lastDescription;` | `warning VELA011: Field 'lastDescription' is mutable state on a plugin type` | **all 6 pass** | **Required** (VELA011; "the checklist gives no explicit severity") → BLOCK | Required (VELA011) | yes |

The correct build in `src-root/` was never modified; the planted copies are separate.

## Findings

### Skill defects
1. **blocker** - `skills/vela-plugin-authoring/SKILL.md` said "Keep generated files untouched; put logic in the `OnExecute` handler the scaffold created". `skills/vela-scaffold/SKILL.md` said "Generated code must compile and apply **without hand edits**" and "If generated code doesn't compile, that's a bug to report, not to patch. Re-run the command with correct inputs", and step 5 sanctions editing only the `FilterOn`. `references/plugin-authoring-api.md` shows only the PostOperation shape.
   - What happened: `vela add plugin … --message Update` always generates `.PostOperation()` / `IUpdatePostContext<Account>`. `vela add --help` has no stage or mode flag. Read literally, the skills keep the step PostOperation, which is exactly the trap this scenario targets, even though vela-plan-review and the Canvas require PreOperation. The only way to PreOperation is an edit the skills never sanction.
   - Correct path, observed to compile and pass: in the scaffolded plugin, change `.PostOperation()` to `.PreOperation()` and the handler parameter `IUpdatePostContext<Account>` to `IUpdatePreContext<Account>`, then set `ctx.Request.Target.<Col>`. The skills should say the stage/mode line and the context type of an `add plugin` step are authored code to set from the Canvas, like `FilterOn`.
2. minor - `skills/vela-test-harness/SKILL.md` said "RED first (mandatory): run the tests before implementing and confirm they **fail** for the right reason."
   - What happened: with the declared cases, the guard cases (already-normal, null, empty) pass against the empty handler. RED was `Total: 6, Failed: 3`. The skill does not say that no-op/guard cases legitimately pass at RED, so "confirm they fail" is ambiguous.
   - Correct: RED = every case that asserts new behaviour fails; guard or no-op cases may pass and should be listed as such.
3. minor - `skills/vela-test-harness/SKILL.md` / `references/harness-api.md` said "`mono ~/.nuget/packages/xunit.runner.console/2.9.2/tools/net462/xunit.console.exe`".
   - What happened: the scaffolded test project references `xunit` 2.9.2 and `xunit.runner.visualstudio` 2.8.2 only. `grep -rn runner.console` over the solution returns nothing (exit 1), so a restore never downloads that path. It worked here only because `~/.nuget/packages/xunit.runner.console/2.9.2` already existed (dated Aug 8). On a clean macOS/Linux machine the documented command fails.
   - Correct: tell the agent to obtain the runner first, e.g. `nuget install xunit.runner.console -Version 2.9.2 -OutputDirectory <dir>` or a `PackageReference` to `xunit.runner.console`.
4. minor - `skills/vela-code-review/references/review-checklist.md` Runtime bullet said "no `ctx.Depth` early return without a reason in the Canvas", with **no severity**. The Recursion rule says "without a guard - **Critical**".
   - What happened: the isolated reviewer graded planted (b) **Critical**, not the scenario's expected **Required**. Its words: "Read literally, the depth check counts as 'a guard' … I rate it Critical anyway". The gate result was right (BLOCK), the label was not.
   - Correct: give the depth-return bullet an explicit severity (Required), and say whether a depth check counts as a "guard" for the Recursion rule.
5. minor - `review-checklist.md` Recursion rule said "a write that can re-trigger the same step … **without a guard** - Critical".
   - What happened: variant (a2), PostOp write-back with `if (normalised != description)`, was graded Required only. The reviewer treated the value-changed check as the guard. Its PluginPipeline test also passes, so neither harness nor review flags the re-trigger as Critical.
   - The scenario's (a) is unconditional, so it still matched Critical. But the obvious "fixed" PostOp variant drops to Required. This is defensible (it still BLOCKs), but the checklist should state it explicitly so the classification is not reviewer-dependent.
6. **blocker** - `skills/vela-code-review/references/review-checklist.md` said "**Models:** … models regenerated, not hand-edited" (no severity). `skills/vela-plugin-authoring/SKILL.md` sanctions a `// STAND-IN for vela-models (no org)` edit to the sealed generated model ("the **one sanctioned exception**"). The review skill, the checklist and the `vela-reviewer` agent never mention that exception.
   - What happened: the isolated `vela-reviewer` run on the **correct** diff returned **BLOCK**: "Required - src/Zava.Shared/Models/Generated/Account.cs:46-53 - someone added the `Description` property to the generated model by hand … violated repo standard (AGENTS.md golden rule 7)". The reviewer of planted (b) also rated it Required; the reviewers of (a), (a2) and (c), and my self-review, rated it Nit.
   - So the scenario's success criterion 4 ("`vela-code-review` PASS") depends on which review mode the skill's "self-review (default) / isolated reviewer (upgrade)" choice picks. Taking the upgrade literally blocks a correct no-org build on a finding that only an org can resolve.
   - Correct: the checklist and the reviewer need the no-org stand-in rule, e.g. "a `// STAND-IN for vela-models (no org)` property is a Nit plus an open question in a no-org run; on a run with an org it is Required (regenerate)".
7. minor - `skills/vela-code-review/SKILL.md` step 1 said "Pin the base and confirm a non-empty diff: `git diff <base>...HEAD`".
   - There is no fallback when there is no repo or base commit; a fresh `vela init` in a new dir has none. Git was forbidden in this eval, so this is partly an environment issue.
   - Used instead: a pristine scaffold snapshot taken right after `vela init` (`rsync … base-ZavaSales`) and `diff -ruN -x bin -x obj base-ZavaSales src-root/ZavaSales`.
8. minor - `skills/vela-scaffold/SKILL.md` step 1 said "confirm the exact flags with `vela init --help`", and `skills/vela-apply/SKILL.md` step 1 said "`vela plan --help` / `vela apply --help` / `vela sign --help`".
   - What happened: all of these print the same global usage page. Only `vela add --help` and `vela models --help` have command-specific help. The flags are still in the global page, so nothing broke, but the skill implies per-command help exists.
9. minor - `skills/vela-scaffold/SKILL.md` step 2 said "`<Prefix>.Shared/Models/Generated` - that is the `--project` target for `vela models`", and `references/cli-surface.md` said "`--out <dir>` (default: current dir) or `--project <csproj>`".
   - What happened: `vela models --help` lists `--out <dir>` and no `--project`. It could not be verified without an org.
   - Recorded command: `vela models --entities account --out src/Zava.Shared/Models/Generated --overwrite -i`.
10. minor - `references/harness-api.md` "Generated test shape (verbatim)" shows the comment "Assert: PreOperation -> check `target` … and that `crm` got no extra write".
    - What happened: `vela add test … --kind plugin --entity Account` (0.19.6) generates the older comment "retrieve the affected record(s) … `new QueryExpression("task")` … `"subject"`". The reference is not verbatim. It is harmless, because the guidance itself was right: `Assert.Empty(crm.GetAll("account"))` and the `PluginPipeline.Empty().Register<T>().Seed(...)` recipe compiled and behaved exactly as documented.

### Environment issues (not skill defects)
- E1. Git and PRs were forbidden by the eval, so the review diff used a snapshot diff and the draft PR was skipped. No org, so `vela models` and `vela plan` were skipped with the commands recorded.
- E2. `xunit.runner.console` 2.9.2 happened to be pre-installed in `~/.nuget`, which masked finding 3.

### What worked as the skills say
The plan-review stage rule led directly to Sync PreOperation. `vela add plugin` echoed `e => e.description` exactly as vela-scaffold predicted. The CLI's own warning also fired: `filtering attribute 'description' may not compile`. The `ctx.Request.Target` edit lands on the harness target. `crm.GetAll("account")` stays empty. `PluginPipeline` reproduces the recursion exception on (a). VELA011 fires on (c). `-parallel none` Mono runs were stable.

## Fixes
- none yet (eval run; findings to feed skill edits).

## Verdict
**fail**: findings 1 and 6 are blockers. Read literally, the scaffold and authoring skills forbid the edit needed to turn the generated PostOperation step into the PreOperation step the Canvas requires, so a literal agent ships the recursion trap. Finding 6: the isolated reviewer BLOCKs the correct no-org build on the stand-in model that vela-plugin-authoring sanctions.

Everything else passed:
- all 6 acceptance cases went RED then GREEN;
- authored code is VELA-clean;
- the correct build passed self-review (the isolated reviewer BLOCKed it, finding 6);
- all three planted violations were BLOCKed ((a) Critical as expected, (c) Required as expected, (b) BLOCKed but graded Critical instead of Required).

The next run must re-check:
- the stage-edit guidance (finding 1);
- the stand-in severity in the review checklist (finding 6);
- the RED wording for guard cases;
- how the runner is obtained;
- explicit severities for the depth-return and "guarded" recursion cases.

## Fixes (iteration 1)

add212a (scaffolded files are yours: PreOperation edit), 7fef67e (stand-in is not a review finding; Depth severity; review without a repo), f6b5aa3 (guard cases may pass at RED; runner restore)

Next: re-run this scenario against the fixed skills and record iteration 2.
