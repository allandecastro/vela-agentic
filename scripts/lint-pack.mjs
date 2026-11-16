#!/usr/bin/env node
// Structural lint for the vela-agentic pack (runs in CI).
// Fails on: missing/!kebab skill/agent frontmatter, name != dir, broken references/*.md links,
//           missing skill `compatibility`, a version number in a skill's `compatibility`,
//           or a skill citing a reference that is not bundled in its own references/ folder.
//           Also fails on: a cited `vela-*` skill/agent that does not exist, a forbidden term,
//           an agent whose name != file name, a README skills table out of step with skills/,
//           an eval scenario/run with bad frontmatter or unknown skills.
// Warns on: descriptions that look like workflow summaries instead of trigger-only, and
//           non-meta skills that no eval scenario exercises.
//
//   node scripts/lint-pack.mjs
// Exit 0 = clean (warnings allowed), 1 = errors.

import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const errors = [];
const warnings = [];

function frontmatter(md) {
  const m = md.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return null;
  const attrs = {};
  for (const line of m[1].split("\n")) {
    const kv = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (kv) attrs[kv[1]] = kv[2].trim();
  }
  return attrs;
}

const KEBAB = /^[a-z0-9]+(-[a-z0-9]+)*$/;

const cliSurface = await fs.readFile(path.join(root, "references", "cli-surface.md"), "utf8");
const verifiedCli = cliSurface.match(/Verified against:\*\*\s*`vela (\d+\.\d+\.\d+)`/)?.[1];
if (!verifiedCli) errors.push("references/cli-surface.md: missing '**Verified against:** `vela x.y.z`' line");

async function lintSkills() {
  const base = path.join(root, "skills");
  for (const e of await fs.readdir(base, { withFileTypes: true })) {
    if (!e.isDirectory()) continue;
    const file = path.join(base, e.name, "SKILL.md");
    let md;
    try {
      md = await fs.readFile(file, "utf8");
    } catch {
      errors.push(`skills/${e.name}: missing SKILL.md`);
      continue;
    }
    const fm = frontmatter(md);
    if (!fm) { errors.push(`skills/${e.name}: no frontmatter`); continue; }
    if (!fm.name) errors.push(`skills/${e.name}: frontmatter missing 'name'`);
    else if (fm.name !== e.name) errors.push(`skills/${e.name}: name '${fm.name}' != directory`);
    else if (!KEBAB.test(fm.name)) errors.push(`skills/${e.name}: name not kebab-case`);
    if (!fm.description) errors.push(`skills/${e.name}: frontmatter missing 'description'`);
    else if (/\bthen\b|; |\bemit\b/i.test(fm.description))
      warnings.push(`skills/${e.name}: description looks like a workflow summary - keep it trigger-only ("Use when…")`);
    // Hosts may resolve relative paths against the working directory: say they are skill-relative.
    if (/references\/[a-z0-9-]+\.md/.test(md) && !md.includes("relative to **this skill's folder**"))
      errors.push(`skills/${e.name}: cites references/ but lacks the skill-relative path note (see writing-vela-skills)`);
    // Self-contained once installed: every cited reference must be bundled next to SKILL.md.
    for (const m of md.matchAll(/references\/([a-z0-9-]+\.md)/g)) {
      try { await fs.access(path.join(base, e.name, "references", m[1])); }
      catch { errors.push(`skills/${e.name}: cites references/${m[1]} but it is not bundled - run node scripts/sync-copilot.mjs`); }
    }
    if (!fm.compatibility) errors.push(`skills/${e.name}: frontmatter missing 'compatibility'`);
    else {
      if (/\d+\.\d+\.\d+/.test(fm.compatibility))
        errors.push(`skills/${e.name}: 'compatibility' carries a version - the version lives only in references/cli-surface.md`);
    }
  }
}

async function lintAgents() {
  const base = path.join(root, "agents");
  for (const f of await fs.readdir(base)) {
    if (!f.endsWith(".md")) continue;
    if (!f.endsWith(".agent.md")) { errors.push(`agents/${f}: agent files must be named <name>.agent.md (Copilot loads only that)`); continue; }
    const fm = frontmatter(await fs.readFile(path.join(base, f), "utf8"));
    if (!fm) { errors.push(`agents/${f}: no frontmatter`); continue; }
    if (!fm.name) errors.push(`agents/${f}: frontmatter missing 'name'`);
    else if (fm.name !== path.basename(f, ".agent.md")) errors.push(`agents/${f}: name '${fm.name}' != file name`);
    if (!fm.description) errors.push(`agents/${f}: frontmatter missing 'description'`);
  }
}

const list = (v) => (v || "").replace(/^\[|\]$/g, "").split(",").map((x) => x.trim()).filter(Boolean);
const skillNames = async () =>
  (await fs.readdir(path.join(root, "skills"), { withFileTypes: true })).filter((e) => e.isDirectory()).map((e) => e.name);
const agentNames = async () =>
  (await fs.readdir(path.join(root, "agents"))).filter((f) => f.endsWith(".agent.md")).map((f) => path.basename(f, ".agent.md"));
const META_SKILLS = new Set(["writing-vela-skills", "diagnosing-vela"]);

// Terms that must not come back (renamed or never real). [regex, hint]
const FORBIDDEN = [
  [/Plan artifact/i, 'the artifact is the "Vela Canvas"'],
  [/`\/vela-(build|apply)`/, "no such slash command - the loop is the vela-builder agent"],
];

// Sources an agent reads (generated copies and the forward-looking ROADMAP excluded).
async function sourceDocs() {
  const out = ["AGENTS.md", "README.md", "hooks/README.md"];
  for (const s of await skillNames()) out.push(`skills/${s}/SKILL.md`);
  for (const a of await agentNames()) out.push(`agents/${a}.agent.md`);
  for (const d of ["references", "evals", "evals/scenarios", "evals/runs"]) {
    try { for (const f of await fs.readdir(path.join(root, d))) if (f.endsWith(".md")) out.push(`${d}/${f}`); }
    catch { /* optional dir */ }
  }
  return out;
}

async function lintNamesAndTerms() {
  // Also the repo name.
  const known = new Set([...(await skillNames()), ...(await agentNames()), "vela-agentic"]);
  for (const rel of await sourceDocs()) {
    const md = await fs.readFile(path.join(root, rel), "utf8");
    for (const m of md.matchAll(/`\/?(vela-[a-z-]+)`/g))
      if (!known.has(m[1])) errors.push(`${rel}: cites \`${m[1]}\`, which is neither a skill nor an agent`);
    for (const [re, hint] of FORBIDDEN) if (re.test(md)) errors.push(`${rel}: forbidden term ${re} - ${hint}`);
  }
}

async function lintReadmeTable() {
  const md = await fs.readFile(path.join(root, "README.md"), "utf8");
  const table = md.match(/^#{2,3} Skills\n([\s\S]*?)(?=^## |(?![\s\S]))/m)?.[1] || "";
  const listed = new Set([...table.matchAll(/^\| `([a-z-]+)` \|/gm)].map((m) => m[1]));
  const skills = new Set(await skillNames());
  for (const s of skills) if (!listed.has(s)) errors.push(`README.md: skill '${s}' missing from the Skills table`);
  for (const s of listed) if (!skills.has(s)) errors.push(`README.md: Skills table lists '${s}', which does not exist`);
  for (const [, count] of md.matchAll(/\b(\d+) (?:\[Agent Skills\]|skills\b)/gi))
    if (Number(count) !== skills.size) errors.push(`README.md: says ${count} skills, there are ${skills.size}`);
}

async function lintEvals() {
  const skills = new Set(await skillNames());
  const dir = path.join(root, "evals", "scenarios");
  const covered = new Set();
  const scenarios = new Set();
  for (const f of (await fs.readdir(dir)).filter((f) => f.endsWith(".md"))) {
    const rel = `evals/scenarios/${f}`;
    const fm = frontmatter(await fs.readFile(path.join(dir, f), "utf8"));
    if (!fm) { errors.push(`${rel}: no frontmatter`); continue; }
    if (fm.scenario !== path.basename(f, ".md")) errors.push(`${rel}: scenario '${fm.scenario}' != file name`);
    try { await fs.access(path.join(root, "evals", "checks", f.replace(/\.md$/, ".json"))); }
    catch { errors.push(`${rel}: no evals/checks/${f.replace(/\.md$/, ".json")}`); }
    scenarios.add(fm.scenario);
    for (const k of ["skills_exercised", "gotchas_exercised", "org_required"])
      if (!fm[k]) errors.push(`${rel}: frontmatter missing '${k}'`);
    for (const s of list(fm.skills_exercised)) {
      if (!skills.has(s)) errors.push(`${rel}: skills_exercised names unknown skill '${s}'`);
      covered.add(s);
    }
  }
  for (const s of skills)
    if (!covered.has(s) && !META_SKILLS.has(s)) warnings.push(`skills/${s}: no eval scenario exercises it (evals/README.md coverage)`);
  let runs = [];
  try { runs = (await fs.readdir(path.join(root, "evals", "runs"))).filter((f) => f.endsWith(".md") && f !== "README.md"); }
  catch { /* no runs yet */ }
  for (const f of runs) {
    const rel = `evals/runs/${f}`;
    const fm = frontmatter(await fs.readFile(path.join(root, "evals", "runs", f), "utf8"));
    if (!fm) { errors.push(`${rel}: no frontmatter`); continue; }
    if (!scenarios.has(fm.scenario)) errors.push(`${rel}: unknown scenario '${fm.scenario}'`);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(fm.date || "")) errors.push(`${rel}: 'date' must be YYYY-MM-DD`);
    if (!["pass", "fail"].includes(fm.verdict)) errors.push(`${rel}: 'verdict' must be pass | fail`);
    if (fm.campaign !== undefined) {
      if (!/^\d{4}-\d{2}-\d{2}[a-z]?$/.test(fm.campaign)) errors.push(`${rel}: 'campaign' must be YYYY-MM-DD (a letter suffix for a re-run the same day)`);
      if (!/^\d+\/\d+$/.test(fm.run || "")) errors.push(`${rel}: campaign run needs 'run: k/N'`);
      for (const k of ["checks", "grader"])
        if (!["pass", "fail"].includes(fm[k])) errors.push(`${rel}: campaign run needs '${k}: pass | fail'`);
      if (!fm.model) errors.push(`${rel}: campaign run needs 'model'`);
      if (fm.verdict === "pass" && (fm.checks !== "pass" || fm.grader !== "pass"))
        errors.push(`${rel}: verdict pass requires checks: pass and grader: pass`);
    }
  }
}

async function* walk(dir) {
  for (const e of await fs.readdir(dir, { withFileTypes: true })) {
    if (e.name === ".git" || e.name === "node_modules" || e.name === ".github") continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) yield* walk(p);
    else if (e.name.endsWith(".md")) yield p;
  }
}

async function lintReferenceLinks() {
  for await (const file of walk(root)) {
    const md = await fs.readFile(file, "utf8");
    for (const m of md.matchAll(/references\/([a-z0-9-]+\.md)/g)) {
      const ref = path.join(root, "references", m[1]);
      try { await fs.access(ref); }
      catch { errors.push(`${path.relative(root, file)}: broken link references/${m[1]}`); }
    }
  }
}

await lintSkills();
await lintAgents();
await lintReferenceLinks();
await lintNamesAndTerms();
await lintReadmeTable();
await lintEvals();

for (const w of warnings) console.warn(`WARN  ${w}`);
for (const e of errors) console.error(`ERROR ${e}`);
console.log(`\nlint-pack: ${errors.length} error(s), ${warnings.length} warning(s).`);
process.exit(errors.length ? 1 : 0);
