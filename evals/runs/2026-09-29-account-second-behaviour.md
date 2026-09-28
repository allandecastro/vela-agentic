---
scenario: account-second-behaviour
date: 2026-09-29
verdict: pass
vela_cli: 0.19.6
framework: 0.28.2
runner: fresh subagent, local, no org
---

## Loop outcome
Pack as read at the start of the run: main @ 1ce4c5b. Commit 0d88781 landed during the run (see Environment). Solution: `ZavaSales/`, git-initialised in the scratch dir.

**Baseline (depends_on: account-default-description, setup)**
- `vela version` → `vela 0.19.6` (exit 0).
- `vela init ZavaSales --prefix Zava -o <scratch> --no-integrations --no-console` → exit 0, 3 projects. The untouched scaffold was committed as a8ebc0c; demos were removed per `vela-scaffold` step 6.
- `vela add plugin AccountDefaultDescription --entity Account --message Create --filtering-attributes name` → exit 0 with a warning ("'name' may not compile. Did you mean 'Name'?"). Step 5 then changed `e => e.name` → `e => e.Name`, PostOperation → PreOperation and `ICreatePostContext` → `ICreatePreContext`.
- `vela models --entities account --out src/Zava.Shared/Models/Generated --overwrite -i` was skipped (no org). A labelled `// STAND-IN for vela-models (no org)` Description property was added in its place.
- `vela add test AccountDefaultDescription --kind plugin --entity Account` → exit 0.
- RED: `Total: 3, Errors: 0, Failed: 2`. GREEN: `Total: 3, Errors: 0, Failed: 0`. Runner: mono xunit.console 2.9.2 `-parallel none`.
- Solution build: 0 Error(s), 0 Warning(s). Self-review PASS with 1 Nit (the stand-in). Build Report written.

**Scenario**
- Plan-review: the Canvas `docs/vela-builds/account-second-behaviour.md` records the key decisions:
  - `reuse: add-step:AccountDefaultDescription`
  - `service: new:AccountDescriptionDefault`
  - Sync PreOperation, with the reason
  - `FilterOn(Description)`
  - 7 acceptance cases
  - 3 assumptions flagged
- `vela add step AccountDefaultDescription --entity Account --message Update` → exit 0, generating `HandleUpdate`.
- `vela add service AccountDescriptionDefault --entity Account` → exit 0.
- `dotnet build` → exit 1 on VELA001 `'Id' is not a Dataverse column` from the placeholder, as documented. After aligning PreOperation / `IUpdatePreContext` / `FilterOn(e => e.Description)` → 0 Error(s).
- Right after `add step`, the existing Create tests failed 3/3 with "has no registered step matching message 'Update'", as documented. Fixed with `.OnCreate().Stage(PluginStages.PreOperation)`.
- RED: `Total: 12, Errors: 0, Failed: 6`. The Update null, whitespace and pipeline cases and the service's 3 empty cases fail on assertion. The guard and no-fire cases pass, as expected.
- GREEN: `Total: 12, Errors: 0, Failed: 0` (mono xunit.console 2.9.2 `-parallel none`). `dotnet build ZavaSales.sln --no-incremental` → 0 Warning(s), no VELA00x.
- Review: an isolated `vela-reviewer` subagent (read-only) gave **PASS** with 4 Nits after it received the RED lines and the Run trace.
- Package: `dotnet build ZavaSales.sln -c Release` → exit 0. `artifacts/Zava.Plugins.1.0.0.nupkg` contains `lib/net462/Zava.Plugins.dll`, sha256 `e58b8f64…d713`.
- `vela plan -p artifacts/Zava.Plugins.1.0.0.nupkg --connection-string "$DATAVERSE_CONNECTION_STRING" --out plan.json` → skipped (no org).
- Stopped at the apply gate. No `vela apply` was run.

**Success criteria**
1. Canvas Approach/Structure record `add step` reuse, the shared service and Sync with a reason (lines 20-21, 48-53) - ✓
2. No duplicated logic - ✓. `grep -rn "Created via Vela plugin\|IsNullOrWhiteSpace" src` finds only `Services/AccountDescriptionDefault.cs:18,22`. Both handlers call `ctx.GetRequiredService<IAccountDescriptionDefault>().Execute(ctx.Request.Target)`.
3. RED then GREEN (above) - ✓
4. `vela-code-review` PASS (isolated reviewer) - ✓. On SOLID/DRY: "one rule, thin handlers". On spec: "Trace steps 2 and 3 are exactly the `vela add step` and `vela add service` commands … no class was written by hand".

**Planted-violation check.** Each violation was planted in a separate repo copy with its own diff and reviewed by a separate isolated reviewer. The tests in all three copies were green (12/12, 12/12 and 11/11), so only the review could catch them.

| Plant | What was planted | Verdict | Severity | Expected |
|---|---|---|---|---|
| (a) | `AccountUpdateDescriptionDefault`, a copied rule used by `HandleUpdate` | BLOCK | **Required** (DRY + Canvas drift) | Required ✓ |
| (b) | Hand-written `AccountDescriptionUpdatePlugin` instead of `add step` | BLOCK | **Required** (reuse decision contradicted) | Required ✓ |
| (c) | Update step set to `.PostOperation().Async()`; the failing pipeline test was deleted so the suite stayed green | BLOCK | **Critical** (Target edit is lost after commit; contradicts the Approach) plus Required (missing acceptance case) | Required → blocked, one severity higher (finding 6) |

## Findings
1. minor - `skills/vela-plan-review/SKILL.md` and `skills/vela-scaffold/SKILL.md` (as read) contradict each other on an unknown prefix.
   - **What the skills said:** plan-review said "otherwise scaffold with a flagged assumption"; scaffold said "Don't invent a prefix".
   - **What happened:** neither said which value to scaffold with, so the agent used `Zava` (from the examples). That is a prefix that could pass for real.
   - **Correct path:** a placeholder that cannot pass for real, such as `--prefix tbd`. Mid-run commit 0d88781 now says exactly this. Re-check it next run.
2. minor - `references/plugin-authoring-api.md` ("Dependency injection") and `skills/vela-scaffold/SKILL.md` do not document the shape `vela add service` generates.
   - **What the CLI generates:** `public sealed class X(IOrganizationService service) : IX` with a `private readonly IOrganizationService _service` field and a `void Execute(Account target)` stub. It also prints the hint `services.AddScoped<IX>(r => new X(r.GetRequiredService<IOrganizationService>()))`.
   - **What the pack shows:** only `new RevenueRollupService()`. Scaffold Verification also says a scaffolded file's "only edits are … stage/context type, `FilterOn`".
   - **What the agent had to work out:**
     - whether to keep the org-service ctor for a pure rule (it dropped it and recorded that in the Canvas);
     - whether the CLI hint resolves in the harness. A probe copy showed it does: 12/12 green.
   - **Correct path:** document the generated service shape and the ConfigureServices hint, and say to drop the `IOrganizationService` ctor parameter when the rule needs no org access.
3. minor - `skills/vela-code-review/references/review-checklist.md` (SOLID/DRY) is too narrow and has no severity.
   - **What it says:** "no logic duplicated across plugins", with no severity.
   - **What happened:** plant (a) duplicates logic within one plugin across two helper classes. Reviewer (a) had to infer both scope and severity: "The duplication here is inside one plugin … I got Required from the general 'violated repo standard' definition."
   - **Correct path:** "logic duplicated anywhere (plugins, services, helpers) - **Required**".
4. minor - `review-checklist.md` has no rule for a PostOperation/Async handler that edits `ctx.Request.Target`, which is silently lost.
   - **What happened:** reviewer (c) found no rule for it: "The checklist's Stage rule covers only … `Update`s its own primary record".
   - **Severity conflict:** "Drift from the Canvas … is Required" versus the Critical definition, "will fail or misbehave on a live org". Reviewer (c) chose Critical, while the scenario expects Required.
   - **Correct path:** add a Critical line for "PostOperation/Async handler edits Target (lost)". Also either align the scenario's expected severity with it or state "drift that breaks live behaviour is Critical".
5. minor - `references/harness-api.md` warns that `.Execute` ignores `FilterOn`, but not that it ignores the stage.
   - **What happened:** in plant (c) the Execute-based Update tests, restated as `.Stage(PluginStages.PostOperation).Async()`, stayed green even though the edit would be lost live. Only the `PluginPipeline` "fires once, stores default" case failed.
   - **Correct path:** add "asserting on `target` proves nothing about stage/mode; a case that the value is *persisted* needs `PluginPipeline`", and require that pipeline case in plan-review for any Target edit.
6. minor - `skills/vela-code-review/SKILL.md` and `agents/vela-reviewer.agent.md` disagree on the reviewer's inputs and actions.
   - **Missing inputs:** after 0d88781 the reviewer expects "RED and GREEN … and the Run trace", but nothing says what to do or which severity applies when they are absent. All three planted reviewers raised "Required - no RED evidence" as a result.
   - **Per-test lines needed:** the RED check needs the failing test lines verbatim; totals are not enough. The main reviewer said: "The skill should require them."
   - **Builder-only steps:** SKILL steps 1 and 5 (commit / `git init`, "Record the findings list in the Build Report") are builder actions that a read-only reviewer cannot take.
   - **Reference list:** the agent lists 3 bundled references, but the skill also uses `harness-api.md`.
   - **Correct path:** a dispatcher checklist (diff text, Canvas, per-test RED lines, GREEN summary, Run trace) and a "reviewer skips steps 1 and 5" note.
7. minor - `references/dataverse-gotchas.md` says "A committed source file was named `*.generated.cs`, which is gitignored". The 0.19.6 scaffold's `.gitignore` does not contain `*.generated.cs` (it lists `bin/ obj/ *.user *.suo .vs/ artifacts/ *.pfx`). The claim depends on an ignore rule outside the scaffold. Correct path: say where the rule comes from, or add it to the scaffold.
8. minor - The `filtering_attributes: [name]` example in `build-report-template.md` uses logical names, while `vela add plugin --filtering-attributes` needs model property names. Following the Canvas literally produced `e => e.name` plus a warning. Fixed mid-run in `vela-scaffold` (0d88781: "pass the **model property** names"). The template example still reads `[name]`. Correct path: say in the template that the CLI flag takes property names (`Name`).

No blocker. Iteration-1/2 regressions did not recur:
- `EntityPluginBase`/`OnExecute`/`HandleUpdate`, `ctx.Request.Target`, the DI API and the harness API all worked verbatim.
- The Mono runner with `-parallel none` worked as documented.
- The VELA001 placeholder and the multi-step trigger restatement behaved exactly as documented.

### Environment / procedure (not skill findings)
- **The pack changed mid-run.** Commit 0d88781 ("reviewer inputs, stand-in timing, filter casing, CRLF") landed at 09:24, after the skills were read and before the reviewers read theirs. The reviewers therefore reviewed against the newer contract. The main reviewer was re-sent the per-test RED lines and the Run trace and confirmed PASS. The planted reviewers' extra "missing RED" Required is an artefact of that first dispatch; they blocked on the planted defect regardless.
- **Diffs were passed as file paths** (read-only, no other files) rather than pasted text, to keep dispatch size down. The reviewers flagged this as a deviation from "pasted into its prompt".
- **The first RED command hung** because of a stray `cat` reading stdin in the eval's shell line. This was an agent error, fixed by using a runner script.
- **The draft-PR step was skipped** (eval). No network writes.

## Fixes
- Pending: findings 2-8 are open. Finding 1, and part of 6 and 8, are already addressed by 0d88781 and must be re-checked next run.

## Verdict
**pass.** All 4 success criteria have evidence, and the review BLOCKs all three planted violations: (a) and (b) as Required, as expected; (c) as Critical, stricter than the expected Required. There is no blocking finding against the skills.

The next run must re-check:
- the `tbd` prefix path;
- the dispatcher inputs (per-test RED lines and Run trace);
- the planted-(c) severity once finding 4 settles Required vs Critical;
- that `vela add service`'s generated shape is documented.
