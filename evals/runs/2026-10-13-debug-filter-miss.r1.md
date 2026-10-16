---
scenario: debug-filter-miss
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **14/14 passed**, no failed check. Notable ones: `step registered: Update 'account' PreOperation/Synchronous filter=['description']`,
`exactly 1 authored step(s)`, `tests contain /PluginPipeline/ (the repro exercises the registration)`, `tests re-run green (>= 2)` (total=3 failed=0),
`no VELA diagnostics`, `read-only vela plan runs`, `plan creates only authored steps`.

## Loop outcome
- `vela version` -> 0.25.0 (exit 0).
- `vela solution show DescNorm` -> exit 4 (guessed name); `vela solution show ZavaSales` -> exit 0, prefix `zava`.
- Repro tests committed first (c0523f7), RED: `Total: 3, Errors: 0, Failed: 2` (runner exit not captured, output captured in `work/logs/evidence.txt`).
- `vela inspect` (dev, read-only) exit 0: local filter `["name"]`, nothing deployed on dev.
- One-line fix (335361d) -> GREEN `Total: 3, Errors: 0, Failed: 0` (`work/logs/green.txt`), Release build 0 warnings / 0 errors.
- `vela inspect` after the fix: `["description"]`, same stepKey `dv-18abfbbfcfb1`.
- Isolated `vela-reviewer` subagent: PASS, Nits only.
- `dotnet build -c Release` -> package + sha256; `vela plan` (dev) exit 8, diagnostics `[]`. Stopped before apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reproduce first: harness test updating only `description`, expecting the normalised value, RED for the right reason | met | `tests/.../AccountNormalizeDescriptionTests.cs` `Editing_only_description_fires_and_normalises` uses `PluginPipeline` + `Service.Update(new Account { Id, Description })`; RED "Assert.Single() Failure: The collection was empty" (`logs/evidence.txt:2-3`) = step never fired; commit order c0523f7 (tests) before 335361d (fix) |
| Hypothesis from the registration, checked against dataverse-gotchas; no trial-and-error, no org mutation | met | Canvas `docs/vela-builds/account-description-filter-fix.md:52-55` names `RegisterPluginSteps()` `.FilterOn(e => e.Name)` and the gotcha "filtering attribute excludes the changed attribute"; only read-only `inspect`/`solution show`/`plan` in the run trace (lines 103-114) |
| Fix the single cause; red goes green; nothing else changes | met | `git diff d036f2b -- src` is exactly `-.FilterOn(e => e.Name)` / `+.FilterOn(e => e.Description)`; check `exactly 1 authored step(s)`; GREEN 3/3 (`logs/green.txt`) |
| Customer org unreachable: commands that would confirm the live registration recorded; trace-log request says where and what | met (see finding 1) | Gate, Build Report lines 119-121: customer-org `vela plan ... --url https://<customer-org>` with the expected `update` of the filter (name -> description); trace-log request lines 130-133 gives the setting, the navigation path and the fields to paste. No customer-org `vela inspect` / `vela logs` command is written out |
| SC1 Failing repro written and seen RED before any code change | met | commit order + `logs/evidence.txt:1-7` |
| SC2 One-line fix; repro and existing suite green | met | diff above; `Total: 3, Failed: 0`; check `tests re-run green` |
| SC3 Explanation names the gotcha and the evidence; no "it seems" without output | met | Canvas A section + Evidence section (lines 79-97) quote the test failures, the inspect output and the build summary |
| SC4 Trace Log request says where and which fields; does not read the org around the CLI | met | Build Report lines 130-133 (System Settings -> Customization -> Enable logging; Advanced settings -> Settings -> Plug-in Trace Log; type name, message, entity, stage/mode, depth, correlation id, exception, message block); no raw Web API calls in logs |

## Planted-violation check
The scenario has no "Planted-violation check" section (only an evaluator-only "Planted bug", which the actor found and fixed). Nothing to run.

## Findings against the skills
1. minor - `skills/vela-debug-plugin/SKILL.md` step 5 says "Compare intent with the live registration via `vela inspect -p <pkg> --solution <uniquename> <connection>` when a connection is available ...; otherwise record the exact command for the human", but the Verification section says "`vela inspect`/`vela plan` confirm the registration now matches intent, or the exact commands are recorded". The actor recorded only a customer-org `vela plan` command and no customer-org `vela inspect` (nor a `vela logs` command the human could run instead of the UI path). This is acceptable, because the plan diff shows the live filter. Still, the skill is inconsistent about which command the human gets, and it never suggests recording `vela logs ... --url <customer-org>` as a CLI alternative to the UI Trace Log path when the human does have access.
2. minor - The run trace records "runner not captured" for the RED run's exit code (Build Report line 107). The skill's evidence rule does not ask for the RED runner's exit code explicitly, but the failing output was captured, so this is not a defect of this run.

No blocker found. The evaluator note on Create filters does not apply: the actor made no Create-filter Vela-gap claim.

## Verdict
pass: checks 14/14, and the grader found every criterion met. The next run must re-check that a customer-org `vela inspect` (or `vela plan`) command is recorded for the human when the org is unreachable.
