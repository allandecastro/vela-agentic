---
scenario: debug-filter-miss
date: 2026-11-23
verdict: fail
campaign: 2026-11-23
run: 2/2
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "3/3, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114, `--agent vela-builder`, pack installed as `.github/skills|agents|copilot-instructions.md`.
One turn, no questions to the human (`work/logs/` is empty). Repo hooks were not loaded (untrusted folder,
`copilot-turn1.err`); the eval shim blocked org writes. Neither counts against the run.

## Checks
14/14 passed (`checks.json`). Filter is `['description']`, exactly 1 authored step, the repro uses `PluginPipeline`,
plan creates only the authored step.

## Loop outcome (copilot-session.md)
- 4s: read PROJECT.md and `vela-debug-plugin` SKILL.md. Only `using-vela` and `harness-api` were grepped. Neither `vela-code-review` nor `vela-apply` nor `dataverse-gotchas.md` was ever loaded by the actor.
- 18–25s: added 2 `PluginPipeline` tests. RED `Total: 3, Errors: 0, Failed: 2`, both failing for the right reason (session :437-457).
- 31s: one-line fix `FilterOn(e => e.Name)` → `FilterOn(e => e.Description)`.
- 10m4s: GREEN `Total: 3, Failed: 0`. `vela solution show DescNorm` gave "SSL connection could not be established". `vela plan --solution DescNorm` gave "Solution not found: DescNorm". The exit code was never captured: `echo exit $?` after a pipe, then an empty `${pipestatus[1]}`. No `--detailed-exitcode`/`--out`. The package listed was timestamped 20:44, before the fix (likely stale).
- 10m21s: wrote the Canvas, including a "Build Report" line, and committed it in the same commit as the fix and tests (6dea887). The commit carries a `Co-authored-by: Copilot` trailer.
- 10m20s–11m5s: dispatched `vela-reviewer` twice. Both rounds returned BLOCK (Required, evidence missing). Round 1 lacked the diff, the RED lines, spec-check and the trace. Round 2 lacked spec-check and the trace. The reviewer judged the fix itself correct.
- 11m5s: stopped and wrote the report. It said "BLOCK only for missing evidence (it has no shell ...)". No `.vela-runs/`, no review.md, no trace.md, no exact customer-org commands.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Repro: harness test updating only description, RED for the right reason | met | session :437-457, `Expected "Hello world" / Actual "  Hello   world  "` + name-only step fired |
| Hypothesis from registration, against gotchas, no org mutation | met (partially) | Canvas `decisions:` states the filter hypothesis. `dataverse-gotchas.md` was never opened. No org writes. |
| Fix the single cause, red → green, nothing else changes | met | `git diff HEAD~1 -- src`: 1 line. Check "tests re-run green". |
| Customer org unreachable: exact `vela inspect`/`vela logs`(/`plan`) commands recorded | **not met** | actor-report.md: "Plan/inspect/logs must be run against the customer org" only. No command lines (r1 defect persists). |
| SC1 RED before any code change | met | RED at 25s, fix edit at 31s |
| SC2 one-line fix, suite green | met | diff + check |
| SC3 names the gotcha + evidence, no "it seems" | met | actor-report.md Root cause + RED lines |
| SC4 trace-log request says where/what, no org read around CLI | n/a / met | no request made, no raw API |
| debug step 7 (#120): Canvas committed **before** the fix | **not met** | Canvas written at 10m21s, after the fix (31s). It is in the same commit 6dea887 as the fix. |
| debug step 9 (#120): review → preview → Build Report → stop | **not met** | Review happened, but the preview ran *before* it. It stopped with an unresolved Required BLOCK. The Canvas "Build Report" predates the review and has no findings list or verdict. |
| Evidence rule: plan output **and exit code** | **not met** | exit code never captured (session :487, :516) |
| #121: review.md + trace.md saved under `.vela-runs/<slug>/` | **not met** | no `.vela-runs/` in `work/DescNorm` |
| House rule: no AI co-author trailer | not met (minor) | `git log -1`: `Co-authored-by: Copilot`, against `.github/copilot-instructions.md:132` |

## Should the actor have run spec-check and a trace?
Yes, for both:
- **spec-check.** `vela-code-review` SKILL.md:53 runs spec-check unconditionally before dispatch. With no registry, `spec-check.cs:21,73` prints "nothing to check" and exits 0. SKILL.md:60-61 says that result is recorded as **not checked**. The actor's reason for skipping it ("no docs/rules exist, so spec-check was not run") is its own invention. It never read that section: the only load of `vela-code-review` (session :835) is inside the reviewer task.
- **Trace.** The Run trace is required by `vela-builder.agent.md:51-52,65` and by `vela-code-review` SKILL.md:34.

Both BLOCKs could have been closed by the actor. The skill's rule is "A block for missing evidence: fix the material, same scoped round". The actor instead attributed the gap to the reviewer having no shell.

Did it preview past an unresolved BLOCK? Not literally. `vela plan` ran at 10m4s/10m11s, before the first review round, so the order was inverted. It then reached the apply-gate hand-off with the BLOCK still open and no post-review Build Report. That is the same failure in effect.

## Fix status
- **#120, Canvas before fix: did not hold.** `vela-debug-plugin` SKILL.md:71-72 says "7. **Canvas, then fix only the most-likely cause.** First commit a small-story Canvas …". This sits as step 7 of a list the actor short-circuited: it fixed straight after RED (step 3) and wrote the Canvas as a closing artifact. No step gates editing `src/` on a committed Canvas.
- **#120, step 9 back through the loop: half held.** The reviewer was dispatched, which is new since r1. But SKILL.md:78-79 names `vela-code-review` / `vela-apply` only in parentheses, and the actor never loaded either. So it missed the spec-check, review.md, preview order, `--detailed-exitcode --out`, and the "exit 4 = open question" handling (`vela-apply` SKILL.md:48-51).
- **#121, review.md / trace.md: did not hold.** `vela-builder.agent.md:44-45,51-52,65` was in the agent's own prompt and ignored. The debug path never re-enters the builder's numbered loop, and `vela-code-review` step 6, which is where review.md lives, was never read by the actor.
- **#116, reviewer blocks on missing spec-check: held.** Session :1116 shows "Required – evidence missing: `spec-check` output". The reviewer also wrote "'nothing to check' … is never a pass", which shows SKILL.md:60-61 can be read as blocking even a supplied no-registry result (finding 4).

## Planted violations
None in this scenario.

## Mutation
3/3 killed, 0 survivors. No triage needed.

## Findings against the skills
1. **blocker** – `skills/vela-debug-plugin/SKILL.md:71-72`: "7. **Canvas, then fix …** First commit a small-story Canvas". Copilot edited `src/` 6 seconds after RED and wrote the Canvas 10 minutes later, in the fix commit. The Canvas commit needs to be a hard precondition stated at step 3/4, e.g. "commit Canvas + RED tests before touching src/", plus a red flag: "a fix commit that also adds the Canvas".
2. **blocker** – `skills/vela-debug-plugin/SKILL.md:78-79`: "the fix goes through the same gates - review (`vela-code-review`), package and preview (`vela-apply`), Build Report". The skills are named in parentheses but never loaded. That loses spec-check, review.md, trace.md, the preview order, the plan exit code and solution-not-found handling. It needs to be an explicit "load `vela-code-review`, then `vela-apply`, in that order; keep `.vela-runs/<slug>/trace.md`".
3. **blocker** (carried over from r1) – `skills/vela-debug-plugin/SKILL.md:75-77`: "record the exact `vela inspect` / `vela plan` / `vela logs` commands against **that** org". The actor wrote prose ("run plan, inspect and logs there") instead of commands. The skill should give the literal command shapes, with a `<customer-org-url>` placeholder and `--solution <uniquename from the human>`.
4. minor – `skills/vela-code-review/SKILL.md:60-61`: "\"nothing to check\" (no registry) is recorded as **not checked**, never as a pass". The reviewer paraphrased this as a blocking condition. It should say explicitly that the reviewer accepts a supplied "nothing to check" output, records it as not checked, and does not BLOCK. Otherwise a project without a registry can never PASS.
5. minor – the builder's "stop with an unresolved BLOCK" was reported as the reviewer's limitation. `vela-code-review` red flags do not cover "reaching the apply gate with an open evidence-missing BLOCK". Worth adding to the red flags next to "no findings list in the Build Report".
6. minor – the house rule "never add an AI co-author trailer" (`.github/copilot-instructions.md:132`) was broken by Copilot CLI's automatic `Co-authored-by: Copilot`. The Copilot surface may need an explicit "remove Copilot's default trailer" line, or the CLI setting documented.

## Verdict
**fail.** Checks are 14/14 and the debugging core is clean: a PluginPipeline RED repro, a one-line fix, 3/3 mutants killed. The process gates failed:
- Canvas after the fix (#120).
- No exact customer-org commands (as in r1).
- Unresolved BLOCK at the hand-off, with spec-check and trace not run.
- No review.md or trace.md (#121).
- Plan exit code not captured.

The next run must re-check debug steps 7 and 9 after fixes 1–3.
