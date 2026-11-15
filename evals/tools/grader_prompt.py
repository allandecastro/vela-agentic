#!/usr/bin/env python3
"""Print the GRADER's prompt for one campaign run (the actor never grades itself).

    python3 evals/tools/grader_prompt.py <scenario> <run-dir> <k> <N> <campaign>

<run-dir> holds: work/ (what the actor produced), checks.json (evals/checks/check.py output),
actor-report.md (the actor's final report). The grader writes <run-dir>/run-record.md.
"""
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
scenario, run, k, n, campaign = sys.argv[1:6]
print(f"""You are the GRADER of one eval run of the Vela skill pack. You did not do the work; judge it strictly.

## Inputs
- The full scenario, including the sections the acting agent never saw (expected outcome, success
  criteria, planted violations): `{ROOT}/evals/scenarios/{scenario}.md`
- What the actor produced: `{run}/work/` (project, Canvas / Build Report under `docs/features/<slug>/`, logs;
  the questions it put to the human and their answers are in `work/logs/human-questions.md` - use it to judge
  the one-question-at-a-time and ask-vs-assume criteria).
- The deterministic check report, already computed by the evaluator: `{run}/checks.json`
- The actor's own final report (a claim, not evidence): `{run}/actor-report.md`
- The pack's review agent (for planted violations): `{ROOT}/agents/vela-reviewer.agent.md`
- Record format: `{ROOT}/evals/runs/README.md`

## What you do
1. Read the scenario. For each item of "What the skills must get right" and "Success criteria", decide
   met / not met **from the artifacts in `work/` and `checks.json`** - cite the file and line, or the
   check name. Where the actor's report claims something the artifacts don't show, it is not met.
2. If the scenario has a "Planted-violation check": for each planted violation, copy the actor's
   project to `{run}/planted-<x>/`, apply the violation there, build it, and dispatch a **fresh**
   general-purpose subagent told to act as `{ROOT}/agents/vela-reviewer.agent.md` and to read the skills from `{ROOT}` (never the installed `vela:vela-reviewer` type, which may be an older copy) (read-only) with only the diff text (original → planted)
   and the Canvas. Record the verdict and severity it returns; it passes if it BLOCKs at the expected
   severity or higher. Never modify `work/`.
3. Decide `grader: pass` only if every criterion is met and every planted violation is blocked.
   `checks` comes from `checks.json` ("pass": true/false). `verdict` = pass only if both pass.
4. Write `{run}/run-record.md` in the format of `evals/runs/README.md`, with front-matter:
   scenario: {scenario} · date: {campaign[:10]} · verdict · campaign: {campaign} · run: {k}/{n} ·
   checks · grader · vela_cli (from the work: `vela version` output in logs, else the installed `vela version`) ·
   framework (Vela.Plugins version in the work's csproj/props) · model: claude-opus-5-5 ·
   runner: "campaign actor + separate grader".
   Body: the check summary (passed/total and every failed check), a criteria table (criterion → met? →
   evidence), the planted-violation results, and **findings against the skills** (numbered, blocker /
   minor, file + quote + what happened) - only defects of the skill pack, not of the actor's luck.
5. Final answer: the front-matter values and the list of failed criteria / checks, nothing else.

Rules: read-only on `{ROOT}` (never edit the pack); no git in `{ROOT}`; never `vela apply`; keep commands
bounded (`perl -e 'alarm N; exec @ARGV' ...`, `export PATH="$HOME/.dotnet/tools:$PATH"`).""")
