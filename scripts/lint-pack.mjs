#!/usr/bin/env node
// Structural lint for the vela-agentic pack (runs in CI).
// Fails on: missing/!kebab skill/agent frontmatter, name != dir, broken references/*.md links,
//           missing skill `compatibility`, a CLI floor above the version verified in cli-surface.md,
//           or a skill citing a reference that is not bundled in its own references/ folder.
// Warns on: descriptions that look like workflow summaries instead of trigger-only.
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

const semver = (v) => v.split(".").map(Number);
const newer = (a, b) => {
  const [x, y] = [semver(a), semver(b)];
  for (let i = 0; i < 3; i++) if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0);
  return false;
};
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
    // Self-contained once installed: every cited reference must be bundled next to SKILL.md.
    for (const m of md.matchAll(/references\/([a-z0-9-]+\.md)/g)) {
      try { await fs.access(path.join(base, e.name, "references", m[1])); }
      catch { errors.push(`skills/${e.name}: cites references/${m[1]} but it is not bundled - run node scripts/sync-copilot.mjs`); }
    }
    if (!fm.compatibility) errors.push(`skills/${e.name}: frontmatter missing 'compatibility'`);
    else {
      const floor = fm.compatibility.match(/vela CLI >= (\d+\.\d+\.\d+)/)?.[1];
      if (floor && verifiedCli && newer(floor, verifiedCli))
        errors.push(`skills/${e.name}: CLI floor ${floor} is above the verified ${verifiedCli} (references/cli-surface.md)`);
    }
  }
}

async function lintAgents() {
  const base = path.join(root, "agents");
  for (const f of (await fs.readdir(base)).filter((f) => f.endsWith(".md"))) {
    const fm = frontmatter(await fs.readFile(path.join(base, f), "utf8"));
    if (!fm) { errors.push(`agents/${f}: no frontmatter`); continue; }
    if (!fm.name) errors.push(`agents/${f}: frontmatter missing 'name'`);
    if (!fm.description) errors.push(`agents/${f}: frontmatter missing 'description'`);
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

for (const w of warnings) console.warn(`WARN  ${w}`);
for (const e of errors) console.error(`ERROR ${e}`);
console.log(`\nlint-pack: ${errors.length} error(s), ${warnings.length} warning(s).`);
process.exit(errors.length ? 1 : 0);
