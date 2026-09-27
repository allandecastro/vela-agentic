---
scenario: lead-score-custom-api
date: 2026-09-28
verdict: pass
vela_cli: 0.19.6
framework: 0.28.2
runner: "fresh subagent, local, no org, iteration 2"
---

## Loop outcome
- Intake/Plan: story -> global operation, input `email`, output `leadScore`, error on empty.
- Challenge (vela-plan-review): routed to **vela-custom-api** ("Step or Custom API?" branch). Canvas records
  `custom_api: {unique_name: zava_ScoreLead, binding: global, kind: action, callers: [flows], inputs: [email:string!], outputs: [leadScore:int]}`,
  Action "because the callers are flows ... even though it is a pure computation", 7 acceptance cases incl. empty/missing/whitespace -> IPE.
  Assumptions flagged: solution `ZavaSales` / prefix `zava` (not in the story, no org), exact-domain match.
- Scaffold: `vela version` -> `vela 0.19.6` (exit 0); `vela add --help` (exit 0).
  `vela init ZavaSales --prefix zava -o .` (exit 0, 6 projects, Integrations also builds a package with demos) ->
  re-ran `vela init ZavaSales --prefix zava -o . --no-integrations --no-console` (exit 0, 3 projects); deleted all demo
  plugins/Custom APIs/services/tests; `dotnet build` 0 warnings 0 errors. `git init` + baseline commit 4e7b8cb.
  `vela add customapi ScoreLead --global --action --prefix zava` -> "Created global Custom API ScoreLead (zava_ScoreLead)" (exit 0), shape
  identical to `plugin-authoring-api.md`. `vela add test ScoreLead --kind customapi` (exit 0), shape identical to `harness-api.md`.
- Model: n/a (global API, no entity). `vela models` not needed.
- Test RED: mono xunit.console 2.9.2 `-parallel none`: `Total: 8, Errors: 0, Failed: 8, Skipped: 0` (exit 1), failures are
  `KeyNotFoundException 'leadScore'` / "Exception type was not an exact match" - right reason.
- Implement: `RequestParameter<string>("email", optional: false, ...)`, `ResponseParameter<int>("leadScore", ...)`, `.AsAction()`,
  `.AllowedCustomProcessingSteps(None)`, guard throws `InvalidPluginExecutionException`.
- Verify: `Total: 8, Errors: 0, Failed: 0` -> +`CustomApiDefinitionReader` self-check `Total: 9 ... Failed: 0` (API worked exactly as
  documented: `UniqueName`, `IsFunction`, `IsBound`, `InputParameters`, `OutputParameters`, `Name`, `IsOptional`).
  `dotnet build ZavaSales.sln -c Release --no-incremental`: `0 Warning(s)` `0 Error(s)`.
- Review: committed, `git diff 4e7b8cb...HEAD -- src tests`, dispatched isolated `vela-reviewer` (diff text + Canvas only): **PASS**,
  0 Critical / 0 Required / 5 Nits. Fixed 3 Nits (Canvas sync + 2 tests) -> `Total: 11, Errors: 0, Failed: 0, Skipped: 0`.
- Package: `dotnet build ZavaSales.sln -c Release` (exit 0) -> `artifacts/zava.Plugins.1.0.0.nupkg` containing
  `lib/net462/zava.Plugins.dll`; sha256 `9363cea985cf70aaa0441d2f5d747957c3825b6bf36913733f83c549a0de1b2e`; unsigned.
- Plan: skipped - no org; would run `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg <connection> --out plan.json`.
- Apply gate: Build Report `ZavaSales/docs/vela-builds/lead-score.md` (kind vela-build, awaiting-apply). `vela apply` NOT run.
- Report: draft PR skipped (eval).
- Planted-violation check (each variant in its own copy under `planted/`, tests adjusted so build = 0 warnings and suite = 9/9 green,
  i.e. nothing local catches them; each reviewed by a fresh isolated `vela-reviewer`):
  - (a) `EmailParameter = "lead.email"` -> **Critical** ("dotted parameter name ... uncallable on a real org") -> BLOCK. Expected Critical: met.
  - (b) empty email -> `leadScore = -1` -> **Required** ("error code in an output parameter instead of an InvalidPluginExecutionException") -> BLOCK. Expected Required: met.
  - (c) `.AsFunction()` + `ctx.UserService.Create(...)` -> **Required** ("a Function with a side effect"), plus **Critical** (Function called by flows)
    and Critical (unplanned write / scope creep) -> BLOCK. Expected Required: met (and over).

## Findings
Skill defects:
1. minor - `skills/vela-scaffold/SKILL.md` step 6 said "`vela init` adds demo plugins and Custom APIs (an Account create step that creates a
   task, `Ping`, ...) ... Delete them"; it does not say that the default scaffold's **Integrations** project is a second deployable package
   (`<PackageOutputPath>..\..\artifacts</PackageOutputPath>`, `GeneratePackageOnBuild`) with its own demos (`AccountSyncRouterPlugin`,
   `ContactSyncPlugin`, `IntegrationHeartbeatCustomApi`, ...), nor the Shared demo `GreetingService`. `vela init` prints
   `vela plan --packages-dir artifacts` as a next step, which would pick up both packages. Correct path: for a Canvas that needs neither,
   `vela init <Name> --prefix <pfx> --no-integrations --no-console`; otherwise delete demos in Plugins, Integrations and Shared.
2. minor - `references/build-report-template.md` / `agents/vela-builder.agent.md`: the Canvas is "committed under `docs/vela-builds/<slug>.md`"
   of the target project and produced at Challenge (step 3), but for a **new** solution the project only exists after Scaffold (step 4).
   Had to write the Canvas in the scratch dir and copy it in after `vela init`. Correct path: say "write it next to the project, move it
   into `<solution>/docs/vela-builds/` right after `vela init`".
3. minor - `skills/vela-code-review/SKILL.md` step 1 said "`git init` + commit right after scaffolding and diff against that commit". Ambiguous:
   after `vela init` (+ demo removal) or after `vela add`? With the base taken after `vela init` + demo deletion, the demo removal and
   Canvas are not in the reviewed diff; the reviewer reported "I couldn't confirm the Canvas was kept in sync or that demos were removed".
   The skill also does not say whether `docs/vela-builds/` belongs in the diff (I passed `-- src tests`). Correct path: base = commit
   right after the raw `vela init`; review the full `git diff <base>...HEAD` including `docs/`.
4. minor - `skills/vela-code-review/references/review-checklist.md` gives no severity for a spec divergence (fix-spec-first "flag if not")
   or for an unconfirmable publisher prefix in a no-org run. Observed: the real-diff reviewer rated behaviour drift (`.Trim()`) Nit; the
   variant (c) reviewer rated the unplanned write "scope creep" Critical. Both defensible, but the severity was reviewer-chosen, not
   checklist-given. Correct path: e.g. "divergence that changes a declared contract/acceptance case - Required; behaviour-neutral drift - Nit;
   prefix recorded as a no-org assumption - Nit + open question".
5. minor - `skills/vela-custom-api/references/harness-api.md` said "A missing required input should throw `InvalidPluginExecutionException` -
   test it". It does not say **who** throws. Observed (probe with the guard removed): `Missing_Email_Throws [FAIL] Expected:
   typeof(Microsoft.Xrm.Sdk.InvalidPluginExecutionException)` - the harness does not enforce `optional: false`; only the handler's
   `IsNullOrWhiteSpace` guard makes the test pass. Correct text: "the harness does not enforce `optional: false`; the handler must guard
   and throw `InvalidPluginExecutionException`, and the test proves that guard".
6. minor - `skills/vela-plan-review/SKILL.md` / `registration-rules.md` said "Don't invent a prefix - take the target solution's publisher
   customization prefix", but the story names none and no Vela command reads a solution's publisher prefix; the skill does not say whether
   to stop (`vela-grill`) or proceed with a flagged assumption. Proceeded with `zava` as an assumption + open question (advisory gate).

Environment (not skill defects):
- `xunit.runner.console` 2.9.2 was already in `~/.nuget/packages` (the skill's restore step not needed).
- No org: `vela models` / `vela plan` / `vela inspect` skipped by protocol.
- Own slip (not a skill defect): a first Python replace of the Canvas O section missed because of line wrapping; caught when growing
  the Canvas into the Build Report and corrected.

## Fixes
- none yet (findings feed iteration 3)

## Verdict
**pass** - no blocking finding. All 5 success criteria met: routed to vela-custom-api; Canvas records global + Action (because flows) +
`email:string!` -> `leadScore:int` + error cases; scaffolded with `vela add customapi ScoreLead --global --action --prefix zava` -> `zava_ScoreLead`,
dot-free; RED 8/8 fail then GREEN (final 11/11) with the Mono xunit console runner; build 0 warnings/0 errors, isolated review PASS. All three
planted violations flagged at (at least) the expected severity. Next run must re-check findings 1 and 3 (demo removal across all packages
and the review base / diff scope) and 5 (required-parameter wording).
