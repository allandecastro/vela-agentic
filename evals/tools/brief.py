#!/usr/bin/env python3
"""Print the part of a scenario the ACTING agent may see (hidden-criteria evals).

    python3 evals/tools/brief.py <scenario>

Only sections whose heading starts with "Context", "User story" or "Setup" are printed. Everything else
(what the skills must get right, success criteria, planted violations, scripted human answers, messages
the evaluator will send) stays with the evaluator and the grader.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VISIBLE = ("context", "user story", "setup")

md = open(os.path.join(ROOT, "evals", "scenarios", sys.argv[1] + ".md"), encoding="utf-8").read()
md = re.sub(r"^---\n.*?\n---\n", "", md, flags=re.S)
out = []
for block in re.split(r"(?m)^(?=## )", md):
    head = block.splitlines()[0][3:].strip().lower() if block.startswith("## ") else ""
    if head.startswith(VISIBLE):
        out.append(block.rstrip())
# The setup command is the evaluator's: the actor is told never to open evals/.
brief = re.sub(r" ?\(`sh evals/[^`]*`[^)]*\)", "", "\n\n".join(out))
# The scenarios name the dev org with a placeholder; the actor sees the real one (VELA_EVAL_ORG) when it is set.
print(brief.replace("https://<dev-org>.crm.dynamics.com", os.environ.get("VELA_EVAL_ORG", "https://<dev-org>.crm.dynamics.com")))
