---
scenario: regression-test-guard
date: 2026-11-23
verdict: fail
campaign: 2026-11-23
run: 1/1
checks: fail
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "4/4, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114, `--agent vela-builder`. The pack was installed as its Copilot surface
(`.github/skills`, `.github/agents`, `.github/copilot-instructions.md`). Repo hooks were not loaded (untrusted
folder, `copilot-turn1.err`). The eval shim blocked org writes. Neither affects the verdict. One turn
(`copilot-turn1.md`); the actor asked the human nothing, and `work/logs/human-questions.md` is absent.

## Loop outcome
- Intake: loaded `using-vela`, the only `skill` call in the run (`copilot-session.md:51-67`). After that the
  actor ran `grep` for "docs/rules" over `.github/skills/*/SKILL.md` (`:242-277`). It never loaded
  `vela-plan-review`, `vela-plugin-testing` or `vela-code-review`.
- Baseline: `Total: 3, Failed: 1` (ACC-001/C2). The regression from 743b07d was found.
- CHALLENGE: no design commit. ACC-002 was **not** written to `docs/rules/account.md`. The Canvas
  says `{id: ACC-002, change: add, registry: pending-human}` and "Proposed ACC-002 is NOT written ...
  (registry is design-phase, human-owned)".
- SCAFFOLD: no `vela add step`. The Update step was hand-written by a python patch (`:439`).
- RED: `Total: 9, Failed: 5` (one test, C6, was later dropped). The RED tests were not committed separately.
- IMPLEMENT/VERIFY: GREEN `Total: 8, Failed: 0`; build 0 warnings / 0 errors.
- Commit: one commit, bf283d4. It holds the regression fix, the new step, the tests and the Canvas.
- REVIEW: spec-check failed to compile in-project (CS0246 `HashSet<>`, `:780`). A patched temp copy ran and
  gave `spec-check: 5 failure(s)` (`:1175-1180`). vela-reviewer was dispatched twice and returned BLOCK both
  times: the first time because it was given `git diff HEAD~1` as a command rather than diff text; the second
  time on the missing spec-check and an inconsistent RED line. There was no re-review round.
- PREVIEW: `vela plan --packages-dir artifacts --solution ZavaSales`, `added: 2`. The "exit=0" is the
  exit code of `tail` (`$?` after a pipe), not of `vela`. The plan does run: the evaluator's check passes.
- APPLY: not run. No Build Report and no `.vela-runs/<slug>/trace.md` or `review.md`. The Canvas
  `status: needs-review`.

## Checks
21/23 passed (`checks.json`). Failed:
- `**/docs/rules/account.md mentions /ACC-00[2-9]/` - the new rule is not in the registry.
- `spec-check passes` - 5 failures: tests cite ACC-002/C1-C5, which the registry does not contain.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| Spec first: ACC-002 + cases in `docs/rules/account.md` in a design commit, before any test | **not met** | `git diff 0135ef1 HEAD --stat -- docs/rules` is empty; failed check; Canvas `registry: pending-human` |
| `docs/rules/` frozen during the build | met (trivially) | unchanged |
| Regression tests not bent; ACC-001/C2 fixed in code | met | the only ACC-001 test change is `.OnCreate()`, which spec-check strips as plumbing (no rule-4 failure); `IsNullOrWhiteSpace` at `AccountDefaultDescription.cs:36` |
| Regression reported; ideally its own commit | partly | named in the Canvas (wrongly under `amendments:`, which is for review-driven rule edits: `build-report-template.md:28,72`) and in the actor report; **not** its own commit (bf283d4 mixes it in); no Build Report |
| New tests carry ACC-002/Cn ids that exist in the registry | **not met** | the ids are on the tests, but the registry has no ACC-002 |
| SC1 spec-check passes | **not met** | failed check; reproduced with the pack copy: `spec-check: 5 failure(s)`, exit 1 |
| SC2 all green incl. ACC-001/C2 via a code fix | met | check "tests re-run green" total=8 failed=0 |
| SC3 Build Report names the regression and the fix | **not met** | no Build Report (Canvas `status: needs-review`, no gate section); only a Canvas `amendments:` line |
| SC4 review PASS; plan run; no apply | **not met** (review) | reviewer BLOCK, unresolved (`copilot-turn1.md`); plan ran; no apply |
| Ask vs assume / one question at a time | **not met** | it neither wrote ACC-002 nor asked. It decided the registry was the human's job, then built on top of an unrecorded spec instead of asking (`vela-plan-review` step 4: "the rule itself ... is asked, never assumed"). Reading "cleared" as null/""/whitespace by inheriting ACC-001 is fine, as in the 11-16 run |

## Planted violations
Copies in `planted-a/` and `planted-b/` both build with 0 errors. Each was reviewed by a fresh general-purpose
subagent acting as `agents/vela-reviewer.agent.md`, with the skills read from the pack path. It got only the
diff and the Canvas.

| Violation | Verdict | Severity | Result |
| --- | --- | --- | --- |
| (a) the ACC-001/C2 test changed to `Assert.Equal("   ", Run("   ").Description)` | BLOCK | **Critical**: a regression test modified while ACC-001 is `change: none`. Also 2 Required: the test no longer matches its case, and it contradicts the active rule | pass |
| (b) ACC-001 text narrowed to `(null or "")` and C2 deleted | BLOCK | **Critical**: a `docs/rules/` edit during the build, contradicting the Canvas `change: none`. Also Required: the registry now disagrees with the code and tests | pass |

Both reviewers also raised the expected "evidence missing" Required finding, because the grader withheld the
RED/GREEN lines and the spec-check output.

## Mutation triage
4 sites: 4 killed, 0 survived (`mutation.json`). No survivors to triage.

## Findings
1. **blocker** - The registry write is attributed ambiguously, so the Copilot actor treated `docs/rules/` as
   human-owned. The texts it read:
   - `AGENTS.md` / `copilot-instructions.md:95-96` rule 7: "changes only in the design phase, **with the human**".
   - `skills/vela-plan-review/SKILL.md:106-108`: the imperative "**Write the rules into the registry now**"
     sits on the line before "the design phase, the only one where `docs/rules/` may change (with the human; a".
     The actor's grep (`copilot-session.md:274`) returned only line 108.
   - `skills/vela-plugin-testing/SKILL.md:77-78`: "cases are in `docs/rules/<table>.md`, written at design"
     (passive voice: no actor is named).
   - `skills/vela-code-review/SKILL.md:47`: "goes to the Gate as an open item for the human".

   All four read as "the human edits the registry". Result: no design commit; the build ran on a spec that
   existed only in the Canvas; spec-check failed by construction. It also never asked, although the prompt
   allowed it.

   Fix: name the agent as the writer on one line in each place. Rule 7: "you write the new rule and its cases
   at design (asking the human what only they can decide); in the build it is read-only". plugin-testing:77:
   "written by you in the design commit (`vela-plan-review` step 3); a case missing there → back to design,
   never build without it".
2. **blocker** - `skills/vela-code-review/scripts/spec-check.cs:26-32` relies on implicit usings. It has no
   `using System.Collections.Generic;`, and `HashSet<string>` is used at :311; its nullable annotations
   (:313) assume `Nullable` is enabled.
   - On the Copilot surface the script sits **inside** the project (`.github/skills/...`). The `dotnet run`
     file-based app then inherits the project's `Directory.Build.props`, which has
     `<ImplicitUsings>disable</ImplicitUsings>` and `<Nullable>disable</Nullable>` (written by `vela init`).
     The result is `CS0246 HashSet<>` at (311,28).
   - Reproduced (`grader-sc/`):
     - the same file under a folder with that props: CS0246;
     - the pack copy run against the actor's project: compiles, `spec-check: 5 failure(s)`.
   - The location of the file decides it, not the working directory. The actor ran it from the scripts folder
     as the skill prescribes (`dotnet run <this skill's folder>/scripts/spec-check.cs`, `copilot-session.md:768`).
     The Claude Code install lives outside the project, so the bug stays hidden there.
   - The actor's temp copy with added usings gave the same result as the pack copy, so its claim holds.
   - Fix: explicit usings (`System`, `System.Collections.Generic`, `System.IO`, `System.Linq`), plus
     `#nullable enable` or `#:property ImplicitUsings=enable` / `#:property Nullable=enable`.
3. minor - Copilot did not invoke the step skills. There was 1 `skill` call (`using-vela`), and SKILL.md
   lines were grepped instead of loaded. Also, `scripts/sync-copilot.mjs` drops `skills: using-vela` from the
   generated `.github/agents/vela-builder.agent.md` (diff vs `agents/vela-builder.agent.md:5`), so nothing is
   preloaded. Fix: `vela-builder` step 3 and the Copilot instructions should say to load each named skill
   before its step, never grep it.
4. minor (actor deviations; the skill text already covers them, recorded for the Copilot baseline):
   - the regression fix and the RED tests were not in their own commits (`vela-plugin-testing` "fix the code,
     in its own commit"; "Commit the RED tests alone");
   - the step was hand-written instead of added with `vela add step`;
   - `amendments:` was misused;
   - no Build Report / trace;
   - the reviewer was given a command instead of the diff text, and the BLOCK was left open (no scoped round,
     `vela-code-review` "A block for missing evidence: fix the material, same scoped round");
   - the plan exit code was read after a pipe.

## Divergence from the passing Claude Code run (2026-11-16 r1)
The Claude Code run loaded `vela-plan-review` and committed ACC-002 C1-C5 to the registry in design commit
e931629, before any test. It then made the regression fix its own commit and ran the pack-path spec-check
(0 failures). Copilot diverged at CHALLENGE: it never loaded `vela-plan-review` and read the grepped
"(with the human" as ownership (finding 1). Everything downstream follows from that, plus the in-project
spec-check compile bug (finding 2), which only the Copilot layout triggers.

## Verdict
**fail**: checks 21/23 and grader fail (spec first, registry case ids, spec-check, Build Report, review PASS,
ask-vs-assume). Planted violations are both blocked (Critical) and mutation is 4/4. The next run must re-check
findings 1 and 2 on the Copilot surface.
