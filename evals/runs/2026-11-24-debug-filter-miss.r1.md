---
scenario: debug-filter-miss
date: 2026-11-24
verdict: pass
campaign: 2026-11-24
run: 1/1
checks: pass
grader: pass
model: claude-sonnet-5.5
vela_cli: 0.33.0
framework: 0.44.0
runner: "copilot-cli actor + separate grader"
mutation: "3/3, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), `--agent vela-builder`, pack installed as its Copilot
surface. One turn (`copilot-turn1.md`); no human question (`work/logs/` empty). Validates main 06e591d.
Not counted: repo hooks skipped, folder untrusted (`copilot-turn1.err`); eval shim blocks org writes.
`skill` tool loads: using-vela (l.53), vela-debug-plugin (l.117), vela-code-review (l.774, plus inside both
reviewer rounds l.1126, l.1569), vela-apply (l.798).

## Checks
14/14 passed (`checks.json`): filter `['description']`, 1 authored step, repro through `PluginPipeline`,
`ZavaSales` exists, evaluator plan creates only package + step.

## Loop outcome
- Triage: read the registration (`FilterOn(e => e.Name)`, l.~150); no `docs/rules/` → wrote ACC-001 C1/C2 as an
  assumption (no question asked).
- RED: `Normalises_description_when_only_description_changes [FAIL]` Expected "Hello world" Actual
  "  Hello   world  ", `Total: 2, Failed: 1` (l.~665-680), before the src edit; repro + Canvas committed first.
- Fix: 1cec5eb, `FilterOn(e => e.Description)`, 1+/1-. GREEN `Total: 2, Failed: 0` (l.~745). spec-check 0 failures.
- History rewritten once (reset --soft, recommitted docs → tests → src) to put the registry before the tests.
- Review r1 BLOCK (Required: Run trace missing; Required: `xunit.runner.console` added to the test csproj is
  outside debug scope). Actor wrote trace.md, reverted the csproj line (dca5dbe). r2 PASS, nits only.
- Preview: `vela version` → 0.33.0; Release build, sha256; `vela solution show ZavaSales` → `{"solution":"ZavaSales",
  "publisherPrefix":"zava"}`; `vela plan ... --solution ZavaSales --detailed-exitcode` → exit 8, added 1 (package + step),
  no diagnostics (l.2001-2010). Build Report appended to the Canvas; stopped at the apply gate.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Repro first: description-only update, RED for the right reason | met | `AccountNormalizeDescriptionTests.cs` C1 via `PluginPipeline`; RED l.~670 before the src edit (l.~720) |
| Hypothesis from the registration + gotcha, no trial and error, no org mutation | met | Canvas `decisions:` hypothesis names the filter; only read-only `solution show`/`plan` ran. (gotchas file not opened; the gotcha is named) |
| Fix the single cause, nothing else changes | met | `git diff 74126ec..HEAD -- src`: 1 line; runner csproj line added then removed (net diff: tests + docs + .gitignore) |
| Customer org unreachable: inspect/plan recorded | met | Canvas l.17-20: `vela inspect --url <faulty org>`, `vela plan --package ... --solution ZavaSales ... --detailed-exitcode` |
| SC1 RED before any code change | met | trace.md l.4; commit c19b821 before 1cec5eb |
| SC2 one-line fix, repro + suite green | met | check "tests re-run green (>= 2)"; trace.md l.6 |
| SC3 explanation names the gotcha and evidence | met | actor-report "Cause" + RED/GREEN lines; Canvas Build Report l.24 |
| SC4 trace-log request says where/which fields | n/a | no request made; no org read around the CLI |

No planted-violation section in the scenario.

## Mutation
3/3 killed, 0 survived. No missing tests.

## Did 06e591d's changes hold?
- PluginPipeline-only: held. Repro compiles and runs on Vela.Testing 0.44 (`PluginPipeline.Empty().Register<>().Seed()`,
  `p.Service.Update`, `p.GetAll`). No `PluginContext` anywhere.
- CLI 0.33: `solution show` exit 0 and `plan --detailed-exitcode` exit 8 match `cli-surface.md` l.68, l.128.
- Skills via `skill` tool: held (all loads).
- Debug step 9 pointer: held (vela-code-review, then vela-apply).
- PROJECT.md names ZavaSales: held; the plan targeted ZavaSales on the first try.
- review.md saved verbatim as soon as the reviewer returns: **not held** - written once after both rounds
  (l.1971) as two summary lines, not the reviewer's output.

## Findings
1. minor - `skills/vela-plugin-testing/references/harness-api.md` (copy in every skill) l.169-170: "If
   `~/.nuget/packages/xunit.runner.console/<ver>/` is missing, add `<PackageReference Include="xunit.runner.console" ...>`
   to the test project once." Copilot's glob could not see `~/.nuget` (l.491, "No files matched"; the runner 2.9.2 was
   there, l.665), so the actor edited the test csproj; the reviewer then flagged it Required against
   `vela-debug-plugin` step 8 ("The diff is the cause - no incidental edit elsewhere"). The two instructions collide in a
   debug run; harness-api could say to resolve the cache with `dotnet nuget locals global-packages -l` before editing.
2. minor - `skills/vela-debug-plugin/SKILL.md` l.39 "No rule covers it → ask the human which it is" vs l.72-74 "No
   registry, or no rule covering the expected behaviour → write that rule and case in `docs/rules/<table>.md`". The actor
   took l.72 and wrote ACC-001 as an assumption without asking (trace.md l.3). Outcome matched the answer key, but
   the skill reads as both "ask" and "write it yourself".
3. minor (host/actor, not a clean pack defect) - every commit carries `Co-authored-by: Copilot <...>` (l.735, l.985,
   l.1525) despite `.github/copilot-instructions.md` l.132 and `vela-builder.agent.md` l.74 "No AI attribution". Copilot's
   own commit habit wins over a rule that sits last in the instructions; consider stating it in the builder's commit step.
4. minor (actor) - `vela-code-review` step 4 "append its verbatim output to `.vela-runs/<slug>/review.md`" not followed
   (two summary lines, written after round 2). The wording is clear; second Copilot run in a row where it slips.

## Verdict
pass - checks 14/14 and every criterion met; no pack error about the 0.44 harness or CLI 0.33. Next run: re-check
review.md verbatim saving and AI-trailer suppression on Copilot.
