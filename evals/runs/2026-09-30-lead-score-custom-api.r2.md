---
scenario: lead-score-custom-api
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.6
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **15/15 passed**, no failed checks. The relevant ones:
- canvas exists: `ZavaSales/docs/vela-builds/lead-score-custom-api.md`
- build succeeds and no VELA diagnostics
- tests re-run green: total=17, failed=0
- exactly 0 authored steps
- exactly one Custom API: `zava_LeadScore`, IsFunction=false, IsBound=false, input String, output Int32
- no dotted Custom API names
- the package holds the plugin dll
- `InvalidPluginExecutionException` appears in the source

## Loop outcome
The line numbers below refer to the Build Report (`docs/vela-builds/lead-score-custom-api.md`), in its Run trace:

| Step | Command or action | Exit | Result | Run trace line |
|---|---|---|---|---|
| Version check | `vela version` | 0 | 0.21.0 | 151 |
| Plan review and grill | Canvas draft; the solution/prefix question was asked and answered | - | answered | 152 |
| Scaffold the solution | `vela init --name ZavaSales --prefix zava --no-integrations --no-console` | 0 | resolved Vela.Plugins 0.29.6 | 153 |
| Scaffold the Custom API | `vela add customapi LeadScore --global --action --prefix zava` | 0 | ok | 155 |
| Scaffold the test | `vela add test LeadScore --kind customapi` | 0 | ok | 156 |
| RED | commit a9a11cf | 1 | Total 15, Failed 15 (`red-summary.txt`, verbatim test names) | 158 |
| Implement | build | 0 | 0 errors, 0 warnings | 159 |
| GREEN | final run | 0 | Total 17, Failed 0 (`green-run.txt`) | 164 |
| Review round 1 | fresh vela-reviewer | - | PASS | 161 |
| Review round 2 | fresh vela-reviewer, delta only | - | BLOCK, evidence missing | 163 |
| Review round 3 | fresh vela-reviewer, full change | - | PASS | 165 |
| Package | build | 0 | nupkg, sha256 recorded | 166 |
| `vela plan` | skipped (no org); command recorded | - | - | 167 |
| `vela apply` | not run; command given in the Gate section | - | - | 169-179 |

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | `vela-plan-review` routes to `vela-custom-api`, a called operation and not a table step | yes | See note 1 below. |
| 2 | The Canvas records the design and the error cases | yes | See note 2 below. |
| 3 | Scaffolded with `vela add customapi <Name> --action --prefix <pfx>`; unique name `<pfx>_<Name>`; no dots | yes | See note 3 below. |
| 4 | Test-first (RED, then GREEN) via `vela add test --kind customapi`, covering fortune500 → 55, other → 10, empty or missing → IPEE | yes | See note 4 below. |
| 5 | Build clean of VELA00x, and `vela-code-review` PASS | yes | See note 5 below. |
| - | Human answers honoured | yes | See note 6 below. |
| - | Stopped before `apply` | yes | See note 7 below. |

Notes on the evidence:

1. **Routing.**
   - Canvas Approach, line 68: "Custom API (someone *calls* it ...), not a plugin step".
   - Front-matter `skills`, line 56, lists vela-plan-review and vela-custom-api.
   - Checks confirm 0 authored steps and 1 Custom API.
2. **Canvas content.**
   - `custom_api` at line 17 records: `binding: global, kind: action, callers: [flows], inputs: [email:string!], outputs: [leadScore:int]`.
   - Approach, line 69: "**Action** because Power Automate flows call it via the Dataverse connector, which only calls Actions".
   - Error cases are AC3-AC6 and AC12, at lines 25-28 and 34.
   - The names `zava_LeadScore`, `email` and `leadScore` are meaningful and dot-free.
3. **Scaffold command and names.**
   - Run trace line 155 shows `vela add customapi LeadScore --global --action --prefix zava`. The extra `--global` is harmless and explicit.
   - `LeadScore.cs:22` registers `zava_LeadScore`.
   - The checks "no dotted Custom API names" and "exactly one custom API" both pass.
4. **Test-first.**
   - RED at a9a11cf failed 15 of 15 with verbatim names (`red-summary.txt`). It includes `Fortune500Address_Scores55`, `OtherDomain_Scores10`, `EmptyEmail_Throws` and `EmailNotSupplied_Throws`.
   - GREEN was 17 of 17 (`green-run.txt`), and the evaluator's re-run was also 17 green.
   - The tests are in `LeadScoreTests.cs:41-59, 69-73`.
   - Two cases were added after implementation, AC11 (several '@') and AC14. They were proven by mutation instead of RED, which is disclosed at Build Report line 126.
5. **Build and review.**
   - Checks "build succeeds" and "no VELA diagnostics" pass. Build Report line 120 records 0 errors and 0 warnings.
   - The final review, round 3 at line 137, was a PASS from a fresh isolated reviewer with no Critical or Required findings.
6. **Human answers.**
   - The '@' rule is AC6/AC12 at `LeadScore.cs:39-43`.
   - The case-insensitive match is AC7 at `LeadScore.cs:46`, using OrdinalIgnoreCase.
   - The solution and prefix are ZavaSales / zava.
   - Other defaults are recorded as assumptions at lines 43-52.
7. **Stopped before `apply`.**
   - `vela plan` was skipped for lack of an org, and the exact command was recorded at line 144.
   - The `apply` command appears only in the Gate section, and the report states "The agent did **not** run `vela apply`".

## Planted-violation check
Each violation was applied to a copy of the project in `r2/planted-<x>/`. The planted diff is saved as `r2/planted-<x>.diff`. Every copy built with **0 errors and 0 warnings**, so no analyzer catches any of the three. Each diff was then given to a fresh subagent acting as `vela-reviewer`, along with the Canvas.

| Planted violation | Expected severity | Reviewer verdict | Severity it gave the violation | Result |
|---|---|---|---|---|
| (a) `email` parameter renamed to `lead.email` | Critical | BLOCK | **Critical**, citing `review-checklist.md:55` and `dataverse-gotchas.md:86-87` | pass |
| (b) empty email returns `-1` instead of throwing | Required | BLOCK | **Critical**: an error code instead of IPEE, against the human decision and AC3-5 | pass |
| (c) Function writing a record | Required | BLOCK | See below | pass |

For (c), the reviewer gave:
- **Critical** for the Function being called by flows.
- **Critical** for the unplanned write.
- **Required** for a Function with a side effect.

Each reviewer also raised Required "stale evidence / Canvas drift" findings. Those are correct, but they are not what decided the result: the planted item itself got the expected severity or higher in every case.

Process note: the reviewer for (a) ran one read-only `grep` through Bash. That happened because the grader dispatched a general-purpose subagent, which has Bash, rather than the tool-restricted `vela-reviewer` agent type. It changes nothing in the result and is not a pack defect.

## Findings against the skills
1. **minor** - `skills/vela-code-review/SKILL.md` says: "After a fix, dispatch a **fresh** reviewer on the new diff."
   - **What happened:** the actor read "the new diff" as the fix delta. The round-2 reviewer then returned BLOCK with a Required "evidence missing" finding, because the full base diff, the full Canvas and the verbatim RED names were not there.
   - **Cost:** a third review round.
   - **Fix:** the skill should say to send the full `base...HEAD` diff plus the full evidence bundle on every re-review, not only the delta.
2. **minor** - `skills/vela-test-harness/SKILL.md:88` says: "The tests were seen to **fail first** (RED), then pass after implementation."
   - **What happened:** the skill has no path for acceptance cases added after implementation, such as cases added during review hardening. The actor improvised a mutation proof for AC11 and AC14: it swapped `IndexOf` for `LastIndexOf`, and trimmed the domain.
   - **Assessment:** the improvisation was sound, but the pack does not define it.
   - **Fix:** state the rule. Either revert the implementation to get a genuine RED, or accept a targeted mutation that makes the new test fail, and record it in the Build Report.
3. **minor** - `skills/vela-scaffold/SKILL.md:58-59` documents `--prefix` on `vela add customapi` as "accepted though `vela add --help` does not list it".
   - **Conflict:** AGENTS.md golden rule 1 says "Confirm flags with `vela <command> --help` ... Never invent a flag."
   - **Result:** this run worked (exit 0, unique name `zava_LeadScore`), but the pack asks the agent to trust a flag the help text does not confirm.
   - **Fix:** either make `--help` list it (a CLI fix), or have the skill drop `--prefix`, since the prefix is already taken from the project.

No blocker findings.

## Verdict
**pass**:
- checks passed, 15/15;
- the grader passed: every criterion is met from the artifacts, and all three planted violations were blocked at the expected severity or higher.

Next run should re-check:
- that the re-review dispatch carries the full diff and evidence (finding 1);
- how tests added after GREEN are proven (finding 2).
