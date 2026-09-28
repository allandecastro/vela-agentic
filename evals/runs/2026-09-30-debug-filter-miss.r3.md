---
scenario: debug-filter-miss
date: 2026-09-30
verdict: fail
campaign: 2026-09-30
run: 3/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **10/10 passed**, no failed checks (build clean, no VELA diagnostics, 4/4 tests green,
single authored step `Update account PreOperation/Synchronous filter=['description']`, repro uses `PluginPipeline`).

## Loop outcome
- `vela version` -> `vela 0.21.0` (Build Report run trace #1).
- Baseline: 1/1 green (the `Execute` test cannot see `FilterOn`).
- Repro commit `2d91236` (3 `PluginPipeline` tests) before fix commit `512a932`. **Re-verified by the grader** on a
  fresh clone at `2d91236`: `Total: 4, Errors: 0, Failed: 3` - description-only edit `Assert.Single() Failure: The collection was empty`
  (step never fires, right reason), name-only edit fires.
- Fix `512a932`: `FilterOn(e => e.Name)` -> `FilterOn(e => e.Description)` **and** `WithDescription("Update Account handler.")`
  -> `WithDescription("Normalises account description whitespace on update.")`.
- GREEN 4/4, build 0 warnings; reviewer subagent PASS (5 Nits); package built + sha256; `vela plan` recorded, skipped (no org);
  stopped before apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reproduce first: harness test updating only `description`, RED for the right reason | met | `AccountNormalizeDescriptionPipelineTests.cs:24-34`; commit order 2d91236 < 512a932; grader re-run at 2d91236: 3 failed, "The collection was empty" |
| Hypothesis from the registration, checked against dataverse-gotchas; no trial-and-error, no org mutation | met | Canvas `docs/vela-builds/account-description-filter-fix.md:52-55` names the gotcha "Create/Update step never triggers on the change you expect"; single fix commit; no org commands run |
| Fix the single cause, red goes green, **nothing else changes** | **not met** | `git diff 629c5b8 HEAD -- src`: 2 lines changed - the filter plus the step `WithDescription` text, a second registration change the human never asked for (actor's own `vela plan` expectation, Canvas :101, lists "and the new description") |
| `vela inspect` recorded as the command that would confirm the live registration | met (weak) | Canvas :122 `vela inspect -p artifacts/zava.Plugins.1.0.0.nupkg -i` - recorded only as a post-apply check, not as the pre-fix confirmation of the live `name` filter; `vela plan` expectation (:101, name -> description) covers the diagnostic side |
| SC1 Failing repro written and seen RED before any code change | met | as above; Canvas :83-86 |
| SC2 One-line fix; repro + existing suite green | **not met** | fix is two lines (filter + description text); suite green 4/4 (checks.json "tests re-run green") |
| SC3 Explanation names the gotcha and the evidence; no "it seems" | met | Canvas :52-55, :81-101 with runner output lines; actor-report "Cause"/"Evidence" |
| SC4 Asking for the Trace Log says where and which fields; no reading the org around the CLI | **not met** | actor-report "Open questions" and Canvas :39 ask for the Plug-in Trace Log ("no row for AccountNormalizeDescription ... tracing on") without saying where it is (Advanced settings -> Plug-in Trace Log) or how to enable tracing / which fields to check; org was not read (ok) |

## Planted-violation results
None - the scenario has no planted-violation check.

## Findings against the skills
1. minor - `skills/vela-debug-plugin/SKILL.md` step 7 says "**Fix** the single most-likely cause with evidence" but never
   says the fix must change nothing else (no cosmetic edits such as `WithDescription`, which also alter the live registration
   and add noise to `vela plan`). The actor bundled a step-description rewrite into the fix. Add: "the fix diff touches only the
   cause; other cleanups are separate, reviewed changes (and each registration field change shows in `plan`)."
2. minor - `skills/vela-debug-plugin/SKILL.md` step 2 gives the where/what for the Trace Log only under "when the fault is on a
   live org" and lists fields of a *failing row* (exception details, message block). For "does not fire" the useful ask is the
   absence of a row (filter by type name + time window, tracing on), and the skill gives no where/what template for that case.
   The actor asked for exactly that "no row" confirmation without where/how - the Red flag "Asking for the logs without saying
   where" did not catch it. Add a "never fires" variant of the ask (where, enable tracing, filter on type name `...AccountNormalizeDescription`,
   paste the list of rows or "none" for the time of the edit).
3. minor - `skills/vela-debug-plugin/SKILL.md` step 5 "otherwise record the exact `vela inspect` command for the human" does not say
   *what the human should read in it* (the live step's filtering attributes). The actor recorded inspect only as a post-apply check
   with `-i` (browser login, not headless). Suggest: record `vela inspect -p <pkg> <connection> --json` and the field to read
   (`current.steps[].filteringAttributes` of the step) as the confirmation of the diagnosis.

## Verdict
fail - checks 10/10 pass, but the grader fails SC2 (fix not limited to the single cause: the step description was also rewritten)
and SC4 (Trace Log asked for without where/which fields). Diagnosis and RED-first repro were correct and verified.
Next run must re-check: fix diff is exactly the `FilterOn` line; any Trace Log ask carries location + tracing + fields.
