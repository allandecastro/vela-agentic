---
scenario: debug-filter-miss
skills_exercised: [vela-debug-plugin, vela-plugin-testing, vela-plugin-authoring]
entity: account
message: Update
gotchas_exercised: [filtering-attributes, repro-before-fix, no-org-debugging]
org_required: false
---

# Scenario: "my plugin does not fire"

## Setup for the run
- The evaluator provides the project (`sh evals/setup/debug-filter-miss.sh <work>` → `<work>/DescNorm`,
  a git repo). The plugin runs in the **customer's** org, which you cannot reach. The dev org `https://dyn-premium-dev.crm.dynamics.com` is available **read-only** (`vela models` / `vela solution show` / `vela plan` / `vela inspect` / `vela logs`); never `vela apply` (the plugin is not deployed there).
- A user reports: "When I edit the description, nothing happens."

## Planted bug (evaluator only)
The Update step that normalises `Description` is registered with `FilterOn(e => e.Name)` (copy/paste
from a Create step); its only test calls the handler through `Execute`, which can't reveal it.

## What the skills must get right
- **Reproduce first:** a harness test that updates only `description` and expects the normalised value
  - it fails (RED) for the right reason (the step's filter excludes `description`).
- **Hypothesis from the registration,** checked against `references/dataverse-gotchas.md` (filtering
  attribute excludes the changed column) - not trial-and-error edits, and no org mutation.
- **Fix the single cause** (`FilterOn(e => e.Description)`), the red test goes green, nothing else
  changes. The customer's org is unreachable: `vela inspect` / `vela logs` against it are recorded as the commands
  that would confirm the live registration, and the trace-log request to the human says where and what.

## Success criteria (a clean pass)
1. Failing repro test written and seen RED before any code change.
2. One-line fix; the repro and the existing suite are green.
3. The explanation names the gotcha and the evidence; no "it seems" without output.
4. If the agent asks for the Plug-in Trace Log, it says where it is and which fields to paste; it does
   not read the org around the CLI.

## Human answers (evaluator only - never shown to the acting agent)
- The expected behaviour is exactly what the plugin already does, only when Description is edited.
- Target solution / publisher prefix: `ZavaSales` / `zava`.
- Anything not listed: "Use the skills' defaults and record it as an assumption."
