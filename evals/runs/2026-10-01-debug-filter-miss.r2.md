---
scenario: debug-filter-miss
date: 2026-10-01
verdict: pass
campaign: 2026-10-01
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **10/10 passed**, no failed check. Solution found, build succeeds, no VELA diagnostics,
tests re-run green (total=3, failed=0), plugin dll built, registration probe shows exactly one authored
step `Update account PreOperation/Synchronous filter=['description']`, no dotted Custom API names, and
the tests use `PluginPipeline`, so they exercise the registration.

## Loop outcome
- version: `vela version` printed 0.21.0 (Build Report run trace #1). Branch `fix/description-filter` was
  created from shipped `b23b039`.
- RED: commit `b8c8fc3` adds 2 `PluginPipeline` tests and changes no code. `work/red.txt` shows
  `Editing_description_fires_step_and_saves_normalised_value [FAIL] Assert.Single() Failure: The collection was empty`,
  so the step never fired. The summary is `Total: 3, Failed: 2`.
- Fix: commit `f6db809` changes 1 line, `.FilterOn(e => e.Name)` to `.FilterOn(e => e.Description)`.
  `git diff b23b039 HEAD -- src` shows only that line.
- GREEN: `work/green.txt` shows `Total: 3, Errors: 0, Failed: 0`. The checker's re-run agrees.
- Review: an isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 3 Nits
  (`docs/vela-builds/account-description-filter-fix.review.md`).
- Package: built with `dotnet build -c Release`, and `unzip -l` shows the dll. `vela plan` was skipped
  (no org) and the exact command is recorded. The actor stopped at the apply gate and did not run `vela apply`.

## Criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| G1 | Reproduce first: a harness test updates only `description`, expects the normalised value, and fails RED for the right reason | met | The test file's `Editing_description_fires_step_and_saves_normalised_value` updates `{Id, Description}` only and asserts `"Hello world"`. RED `Assert.Single() Failure: The collection was empty` means the step did not fire (`work/red.txt`). This is the filter cause, not the handler. |
| G2 | Hypothesis comes from the registration and is checked against `dataverse-gotchas.md`, with no org mutation | met | Canvas `docs/vela-builds/account-description-filter-fix.md:50-52` quotes the gotcha "filtering attribute excludes the attribute that actually changed", which matches `references/dataverse-gotchas.md:26`. The actor made no trial-and-error edits (one fix commit) and never contacted the org. |
| G3 | Fix only the single cause; red goes green; nothing else changes; `vela inspect` is recorded | met | The diff to `src/` is 1 line. Scaffold leftovers are listed as follow-ups (`:119-120`). `vela inspect -p artifacts/zava.Plugins.1.0.0.nupkg -i` is recorded at `:111`. |
| S1 | Failing repro test is written and seen RED before any code change | met | Commit order is `b8c8fc3` (tests only) before `f6db809` (fix). `work/red.txt` holds the RED output. |
| S2 | One-line fix; the repro and the existing suite are green | met | 1 insertion and 1 deletion in `AccountNormalizeDescription.cs`. GREEN 3/3 (`work/green.txt`) and the checker re-run passes. |
| S3 | Explanation names the gotcha and the evidence; no "it seems" without output | met | Canvas A section (`:50-54`) and Evidence section (`:78-88`) quote the failure lines. A grep of the docs finds no "seems" or "probably". |
| S4 | If the Trace Log is requested: where it is and which fields; no org reads around the CLI | met (n/a) | The actor did not ask for the trace. It is mentioned only as an optional confirmation (`:117`), and the actor read nothing from the org. |

## Planted-violation results
The scenario has no "Planted-violation check" section, so no planted variants were built.

## Findings against the skills
1. minor: `skills/vela-debug-plugin/SKILL.md` never mentions the Canvas or Build Report. AGENTS.md
   requires "fix-spec-first" (the Canvas before the code), but the debug process (steps 1-8) does not
   say when the Canvas is written for a debug fix. The actor wrote the Canvas after the fix commit
   (`88b4b3a` follows `f6db809`), and its own reviewer flagged this as a Nit. Suggested fix: add a step
   between 5 and 7 that writes the Canvas (cause and acceptance cases) with or before the RED commit.
2. minor: `references/build-report-template.md` gives the Canvas `status: proposed | approved | blocked | superseded`
   and the Build Report `status: awaiting-apply | applied`. A debug run that goes straight to a Build
   Report has no stated rule for which status applies before a human signs off. The actor first wrote
   `status: approved` with no human sign-off. The reviewer caught it and it was corrected to
   `awaiting-apply` (review.md, Nit 2). Suggested fix: state that `approved` requires a named human and
   that an agent-authored record is `proposed` or `awaiting-apply`.
3. minor: Not a skill defect, for the record only. Run trace #3 records the RED run's exit code as
   "not captured". The RED output is still preserved verbatim in `work/red.txt` and the Build Report,
   so the evidence rule is met.

## Verdict
**pass.** Checks passed 10/10 and all 7 criteria are met. There were no planted violations to test.
The next run must re-check that the Canvas timing (finding 1) and the status value (finding 2) are
right without the reviewer having to catch them.
