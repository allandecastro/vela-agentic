#!/usr/bin/env python3
"""Print the acting agent's prompt for one campaign run (hidden criteria: brief only).

    python3 evals/tools/actor_prompt.py <scenario> <work-dir> [--org <url>] [--shim <dir>] [--no-org] [--host copilot]

--host copilot: the actor is Copilot CLI with the pack installed in the project (evals/tools/copilot_actor.sh).
"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
scenario, work = sys.argv[1], sys.argv[2]
# Every campaign run gets the dev org READ-ONLY (vela >= 0.24 scaffolds no models; plan needs --solution).
DEV_ORG = os.environ.get("VELA_EVAL_ORG")
org = None if "--no-org" in sys.argv else (sys.argv[sys.argv.index("--org") + 1] if "--org" in sys.argv else DEV_ORG)
if "--no-org" not in sys.argv and not org:
    sys.exit("set VELA_EVAL_ORG to the dev org URL, or pass --org <url> / --no-org")
shim = sys.argv[sys.argv.index("--shim") + 1] if "--shim" in sys.argv else (os.path.join(ROOT, "evals", "tools", "shim") if org else None)
cli = subprocess.run([os.path.expanduser("~/.dotnet/tools/vela"), "version"], capture_output=True, text=True).stdout.split()[-1]
brief = subprocess.run([sys.executable, os.path.join(ROOT, "evals/tools/brief.py"), scenario], capture_output=True, text=True).stdout

path = f'export PATH="{shim}:$HOME/.dotnet/tools:$PATH"' if shim else 'export PATH="$HOME/.dotnet/tools:$PATH"'
org_rule = (f"- Dataverse dev org, READ-ONLY: `{org}`, reached with `--url` alone (the machine's az session). Only "
            "`vela models` / `vela solution show` / `vela plan` / `vela inspect` / `vela logs` (all read-only) may touch it; never `vela apply`, `--auto-approve`, `--yes`, "
            "or any other write.") if org else \
           "- There is NO Dataverse org: where a skill needs one, record the exact command instead of running it. Never `vela apply`."
copilot = "--host copilot" in " ".join(sys.argv)
if copilot:
    who = "the `vela-builder` agent"
    pack = ("- The Vela skill pack is installed in the project (`.github/skills`, `.github/agents`,\n"
            "  `.github/copilot-instructions.md`). Start with the `using-vela` skill and follow the skills as written.\n")
    reviewer = "dispatch the `vela-reviewer` custom agent as a subagent (read-only)"
else:
    who = f"the `vela-builder` agent (`{ROOT}/agents/vela-builder.agent.md`)"
    pack = (f"- The Vela skill pack is at `{ROOT}` (read-only: do not edit it, do not run git in it). Start with\n"
            "  `skills/using-vela/SKILL.md` and follow the skills as written; read each skill (`skills/<name>/SKILL.md`,\n"
            "  its `references/`) when you use it.\n"
            f"- **Never open anything under `{ROOT}/evals/`** - it is evaluation material, not for you.\n")
    reviewer = f"dispatch a fresh subagent told to act as `{ROOT}/agents/vela-reviewer.agent.md`\n  (read-only)"
print(f"""You are {who} working on a real task for a user.

## How you work
{pack}- Work only in `{work}`: every file, temp and log goes under it, since other runs share the parent folder. A
  local `git init` there is fine; no pushes, no PRs - skip the draft-PR step.
- In every shell command that uses vela: `{path}`. vela {cli}, dotnet, mono, jq, python3 are installed
  (macOS arm64, zsh; no `timeout` - use `perl -e 'alarm N; exec @ARGV' ...`). Keep commands bounded.
{org_rule}
- For the review step, {reviewer}, as the review skill says.
- If you need the human (a question, an approval), first append the question verbatim to
  `{work}/logs/human-questions.md` (one `## Q<n>` section per question), then end your turn with a message
  starting with `QUESTION FOR THE HUMAN:` followed by what you would ask; you will be resumed with the
  answer - append it under the same `## Q<n>` as `Answer:`. Never invent the human's answers.
- When the task is done (or blocked), write a short final report to `{os.path.dirname(work.rstrip('/'))}/actor-report.md`
  (what you did and decided, the evidence - commands and their output lines -, the paths of what you
  produced) and give the same report as your final answer (if the Write tool refuses a report file, write it
  with Bash - writing your deliverables is part of the assignment). Do not grade yourself.

## Your assignment
{brief}""")
