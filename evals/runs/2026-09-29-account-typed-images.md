---
scenario: account-typed-images
date: 2026-09-29
verdict: pass
vela_cli: 0.21.0
framework: 0.29.3
runner: "fresh subagent, local, no org"
---

## Loop outcome
- Intake/Plan/Challenge (vela-plan-review): Canvas `docs/vela-builds/account-credit-limit-reduced.md` - Update / PreOperation / Sync,
  `FilterOn(CreditLimit)`, pre-image `[CreditLimit]`, new plugin, no service, `--no-integrations`; 7 acceptance cases; assumptions
  A1 (cleared != lowered), A2 (no previous limit != lowered), A3 (Money.Value only); prefix/solution `tbd` placeholder blocking apply.
- Scaffold (vela-scaffold): `vela init CreditWatch --prefix tbd -o . --no-integrations --no-console` exit 0 (Vela.Plugins 0.29.3);
  git init + scaffold commit (review base); demos removed, build 0 warnings; `vela add plugin AccountCreditLimitReduced --entity Account
  --message Update --filtering-attributes CreditLimit` exit 0 (warned: "'CreditLimit' ... is not a property on the early-bound 'Account'
  model"); stage edited to `.PreOperation()` / `IUpdatePreContext<Account>`; build exit 1 `CS1061 'Account' does not contain a definition for 'CreditLimit'`.
- Model (vela-models): skipped, no org. Would run `vela models --entities account --out src/tbd.Shared/Models/Generated --overwrite --url <org>`.
  Labelled STAND-IN `CreditLimit` (Money) + `Description` added to the sealed demo model; build 0 errors.
- Test RED (vela-test-harness): `vela add test AccountCreditLimitReduced --kind plugin --entity Account` exit 0; 7 tests (5 PluginContext
  + `.WithPreImage(preImage)`, 2 PluginPipeline). Mono `xunit.console.exe ... -parallel none` exit 1:
  `Lowered_SetsDescriptionOnTarget [FAIL]`, `Lowered_EndToEnd_DescriptionSavedAndStepRunsOnce [FAIL]` (Expected "Credit limit reduced",
  Actual null) - `Total: 7, Errors: 0, Failed: 2`. Guard cases (raised, same, cleared, no previous, not sent) pass pre-code, as the skill allows.
- Implement (vela-plugin-authoring): `.WithPreImage(e => e.CreditLimit)` without `partial` -> build exit 1
  `error CS0260: Missing partial modifier on declaration of type 'AccountCreditLimitReduced'` (skill prediction confirmed);
  `public sealed partial class`; handler compares `ctx.Request.Target.CreditLimit` vs `ctx.PreImage?.CreditLimit`, sets Target.Description only on a decrease.
- Verify: `Total: 7, Errors: 0, Failed: 0, Skipped: 0` (Mono + xunit.console 2.9.2, exit 0); `dotnet build CreditWatch.sln -c Release
  --no-incremental` -> `0 Warning(s) 0 Error(s)`. Mutation (image registration removed): only the pipeline end-to-end test fails (1/7).
- Review (vela-code-review): isolated vela-reviewer subagent -> **PASS**, 4 Nits (Description overwritten when also sent -> Canvas A4;
  Canvas date/status; model STAND-IN; unconditional set even if already equal).
- Package & preview (vela-apply): `rm -rf artifacts; dotnet build CreditWatch.sln -c Release` exit 0 -> `artifacts/tbd.Plugins.1.0.0.nupkg`
  (contains `lib/net462/tbd.Plugins.dll`), sha256 `ca8b8969a61947fbeb1ef83adc212c31a26f46a7de3f9dff89837e134d7d5b56`; unsigned;
  `vela plan -p artifacts/tbd.Plugins.1.0.0.nupkg --url <org> --out plan.json` skipped (no org).
- Apply gate: Build Report committed; stopped. `vela apply` never run. Draft PR skipped (eval).

Scenario checks:
- Pre-image via `WithPreImage(e => e.CreditLimit)`, read through typed `ctx.PreImage`, class `partial`: yes (CS0260 seen and fixed).
- "Lowered" = value actually differs: same-value case sent and asserted no Description.
- PreOperation on `ctx.Request.Target`: yes; `Assert.Empty(crm.GetAll("account"))`; pipeline `Assert.Single(ExecutionLog)` (no recursion).
- Tests supply the pre-image (`WithPreImage(entity)` and the pipeline) and cover lowered, raised, same, cleared: yes (+ no previous, not sent, end to end).
- Success criteria 1-3: met (CS0260 fixed; RED 2 fail -> GREEN 7/7; 0 VELA00x; review PASS).

## Findings
1. minor - `skills/vela-test-harness/references/harness-api.md` gives only "`.WithPreImage(entity, alias)`" and no typed-image
   test recipe. What alias does typed `ctx.PreImage` read? I had to open `~/.nuget/packages/vela.testing/0.29.3/lib/net462/Vela.Testing.xml`:
   "Adds a pre-image under the given alias (default `PluginImageAliases.PreImage`)", and `Vela.Plugins.xml`: `ctx.PreImage` "reads the
   pre-image registered under the default alias". Correct: `PluginContext.For<Account>().WithTarget(t).WithPreImage(pre).Execute(plugin)`
   (omit the alias), and say so in the reference.
2. minor - `harness-api.md` says "`.Execute(...)` ignores `FilterOn` - and the registered stage/mode", but it does not say that it also
   ignores the **image registration**. With `.WithPreImage(...)` removed from the step, the `Execute` "lowered" test still passed;
   only the `PluginPipeline` end-to-end test failed (`Total: 7, Failed: 1`). It also doesn't say that the pipeline builds registered
   pre-images from the seeded row. I verified that it does. Correct: add "an image-dependent case needs a `PluginPipeline` test
   (Seed + Update): `Execute` hands the handler whatever image the builder was given, registered or not".
3. minor - `skills/vela-scaffold/SKILL.md` step 7 / Verification says "`dotnet build` succeeds" right after `vela add plugin`. When the
   filtering attribute is a non-demo column, the build fails (`CS1061 ... 'CreditLimit'`) until MODEL (or the no-org stand-in) runs.
   Only after MODEL could the scaffold gate pass. Correct: say that a filter or image on a column not yet in the model is expected to
   fail the build until `vela-models`, and do MODEL before the scaffold build.
4. minor - `skills/vela-plugin-authoring/references/plugin-authoring-api.md` documents "the typed image projection is generated inside
   it", but not how to read it. The framework exposes `ctx.PreImageAs<TImage>()` / `PostImageAs<TImage>()` (Vela.Plugins.xml,
   `ImageProjectionExtensions`), while the skill uses `ctx.PreImage` (the full early-bound entity). Both compile. The reference should
   say which one is intended and name the generated projection type.
5. minor - `plugin-authoring-api.md` "Generated plugin shape" has no `using Microsoft.Xrm.Sdk;`. The first handler that reads a
   `Money` column fails with `CS0246: The type or namespace name 'Money' could not be found`. It's a trivial fix, but the "verbatim" shape
   should note it.
6. minor - `skills/vela-plan-review/SKILL.md` step 4 says to use `vela-grill` "unless a branch is a business decision only the human
   can make (what a story term means...)". Whether a cleared (null) limit, or a first-time limit, counts as "lowered" is exactly that. With no human
   (eval/unattended), the skill doesn't say whether to continue on a flagged assumption. I continued with assumptions A1 and A2 plus
   an open question. The skill should state that fallback.
7. minor - `skills/vela-scaffold/SKILL.md` step 5 covers only stage, context type and `FilterOn`. The Canvas image (`WithPreImage`) and
   `partial` are in `vela-plugin-authoring` step 6, after RED. It's unclear whether the registered image belongs to Scaffold or Implement. I added it at
   Implement; the RED pipeline test failed either way.
8. minor (own deviation) - `skills/vela-code-review/SKILL.md` says "the diff **text pasted into its prompt**". I gave the reviewer the
   diff as a file path (300 lines) instead, and it read the file. The reviewer's pack notes ask that `agents/vela-reviewer.agent.md` allow either.
9. minor (from the reviewer's pack notes) - `review-checklist.md` has no item for three things:
   - a PreOperation plugin overwriting a column the caller sent in the same request;
   - guard/no-op tests that pass at RED (valid only if a wrong implementation would fail them);
   - Money comparisons across currencies.
   It also doesn't say whether the STAND-IN comment must match exactly.

Environment issues (not skill defects):
- The reviewer subagent took ~22 minutes. Its response was cut off mid-stream once and then retried.
- zsh: `echo =====` fails with "= not found", and an unquoted `$G` holding `git -c ...` is not word-split. Both were my shell mistakes, fixed.

## Fixes
- None yet (eval run; findings feed the next GREEN step).

## Verdict
**pass** - every "must get right" item and success criteria 1-3 were met with evidence, and there is no blocking finding. Findings 1-2
(the typed-image harness recipe, and `Execute` ignoring the image registration) are the most valuable to fix. Next run must re-check:
- that a fresh agent writes the pipeline end-to-end case without the mutation insight;
- that the scaffold build gate handles a non-demo filter column.

## Fixes

Minors fixed: WithPreImage alias default, Execute ignores image registration, using Microsoft.Xrm.Sdk, build-after-MODEL note, no-human fallback.
