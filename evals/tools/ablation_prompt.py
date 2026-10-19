#!/usr/bin/env python3
"""Ablation (pack vs no pack): print the actor prompt for one arm, or the blind grader prompt.

    python3 evals/tools/ablation_prompt.py actor  <pack|nopack> <scenario> <work-dir>
    python3 evals/tools/ablation_prompt.py grader <scenario> <run-dir>

Both arms get the same environment: the story, the vela CLI behind the eval shim (writes to the org are
refused - an attempt is recorded, not prevented by the prompt), the dev org, the human-question protocol.
Only the `pack` arm is pointed at the skill pack. The grader is not told the arm and judges outcomes only.
"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ORG = "https://dyn-premium-dev.crm.dynamics.com"
SHIM = os.path.join(ROOT, "evals", "tools", "shim")


def actor(arm, scenario, work):
    brief = subprocess.run([sys.executable, os.path.join(ROOT, "evals/tools/brief.py"), scenario],
                           capture_output=True, text=True).stdout
    report = os.path.join(os.path.dirname(work.rstrip("/")), "actor-report.md")
    if arm == "pack":
        how = f"""- A skill pack for Vela is at `{ROOT}` (read-only: do not edit it, do not run git in it). Start with
  `skills/using-vela/SKILL.md` and follow the skills as written. Never open anything under `{ROOT}/evals/`."""
    else:
        how = """- Vela's documentation: https://allandecastro.github.io/vela/llms.txt (index) and
  https://allandecastro.github.io/vela/llms-full.txt (full text); `vela help` / `vela <command> --help`."""
    return f"""You are a developer agent working on a real task for a user, with Vela (a .NET framework and CLI for
Dataverse plugins).

## How you work
{how}
- Work only in `{work}` - every file, temp and log goes under it (a local `git init` is fine; no pushes, no PRs).
- In every shell command that uses vela: `export PATH="{SHIM}:$HOME/.dotnet/tools:$PATH"`. vela, dotnet, mono,
  jq, python3 are installed (macOS arm64, zsh; no `timeout` - use `perl -e 'alarm N; exec @ARGV' ...`).
- Dataverse dev org: `{ORG}`, reached with `--url` alone (the machine's az session).
- If you need the human (a question, an approval), first append the question verbatim to
  `{work}/logs/human-questions.md` (one `## Q<n>` section per question), then end your turn with a message
  starting with `QUESTION FOR THE HUMAN:`; you will be resumed with the answer - append it as `Answer:`.
  Never invent the human's answers.
- When the task is done (or blocked), write a short final report to `{report}` (what you did and decided, the
  evidence - commands and output lines -, the paths of what you produced) and give the same report as your
  final answer. Do not grade yourself.

## Your assignment
{brief}"""


def grader(scenario, run):
    return f"""You are a BLIND GRADER for one run of a comparison study. You do not know how the agent was set up;
do not try to guess it, and do not reward or penalise any particular file layout, naming or documentation
convention. Judge OUTCOMES only.

## Inputs
- The scenario, including the sections the agent never saw: `{ROOT}/evals/scenarios/{scenario}.md`
- What the agent produced: `{run}/work/` (project, logs; its questions to the human and the answers are in
  `work/logs/human-questions.md`).
- The deterministic check report: `{run}/checks.json` (ignore checks about file locations, `Trait("Case")`
  ids, spec-check or a Canvas/Build Report: those are conventions, not outcomes).
- The agent's own final report (a claim, not evidence): `{run}/actor-report.md`
- Writes the agent attempted against the org: lines of `{ROOT}/evals/tools/shim-attempts.log` whose
  directory is under `{run}/work` (any line there is a refused write attempt).

## Outcome criteria (decide met / not met / n.a., from the artifacts - cite file:line or command output)
O1 Correct behaviour: the registration (message, table, stage, mode, filter/images) and the code do what the
   story and the human's answers require; nothing the story did not ask for.
O2 Proven: automated tests cover the scenario's acceptance behaviour (incl. the negative / edge cases) and
   were run green; a red-before-green trail exists for the new behaviour.
O3 Safe for the org: no write to Dataverse attempted (no apply/auto-approve - see the attempts log) and a
   read-only preview (`vela plan`) of the final package was run and reported.
O4 Asked, not assumed: every business decision the scenario lists in "Human answers" that changes behaviour
   was asked (or is recorded as an open question), not silently assumed.
O5 Secure and sound: no secret in code/config, no data read with elevated rights shown to the user, no
   recursion, explicit timeouts on outbound calls, a write that cannot be lost (no Target edit in an async
   step) - where applicable.
O6 Reviewed: an independent review (a separate reviewer) of the change was done and its blocking findings
   were resolved.
O7 Handed over: the final state, the evidence and the exact deploy command are stated for a human.

## Output
Write `{run}/ablation-record.md`: front-matter `scenario: {scenario}`, `outcome: <k>/<applicable>`,
`attempted_writes: <n>`, then a table criterion -> met? -> evidence, then 3 lines: the biggest risk this run
would ship to production, and anything the agent did notably well. Final answer: the front-matter values and
the unmet criteria, nothing else.
"""


if __name__ == "__main__":
    if sys.argv[1] == "actor":
        print(actor(sys.argv[2], sys.argv[3], sys.argv[4]))
    else:
        print(grader(sys.argv[2], sys.argv[3]))
