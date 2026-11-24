#!/usr/bin/env node
// Structural check of docs/ - the "AI agents" section the Vela docs site copies to vela/docs/agents/ at a pinned tag
// and builds with DocFX --warningsAsErrors (runs in CI through scripts/check.sh).
// Fails on: a skill (skills/<name>) without docs/skills/<name>.md, an agent (agents/<name>.agent.md) without
//           docs/<name>.md; a docs/**/*.md page missing from docs/toc.yml, or a toc href to a missing file; a page
//           without `_description` front matter or without exactly one H1; a relative link to a missing file inside
//           docs/, or one that leaves docs/ other than into a top-level folder of the Vela docs; a link to this repo
//           on GitHub at a branch instead of a tag; page-level layout (`<div`, `<style`, `<script`, `style=`); an
//           opening code fence without a language; an emoji; docs/index.md not pointing pack issues to this repo.
//
//   node scripts/check-docs.mjs
// Exit 0 = clean, 1 = errors.

import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const docs = path.join(root, "docs");
const errors = [];

// Top-level folders of the Vela docs (vela/docs) a page may link into, as ../<folder>/... from docs/agents/.
const VELA_DIRS = new Set(["getting-started", "guides", "configuration", "reference", "advanced", "contributing", "images"]);
const REPO = "https://github.com/allandecastro/vela-agentic";
const ISSUES = `${REPO}/issues`;

const rel = (p) => path.relative(root, p).split(path.sep).join("/");

async function* walk(dir) {
  for (const e of await fs.readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) yield* walk(p);
    else yield p;
  }
}

async function exists(p) {
  try { await fs.access(p); return true; } catch { return false; }
}

try { await fs.access(docs); } catch { console.error("ERROR docs/ is missing"); process.exit(1); }

const pages = [];
for await (const f of walk(docs)) if (f.endsWith(".md")) pages.push(f);

// Every skill and agent has a page.
for (const e of await fs.readdir(path.join(root, "skills"), { withFileTypes: true }))
  if (e.isDirectory() && !(await exists(path.join(docs, "skills", `${e.name}.md`))))
    errors.push(`docs/skills/${e.name}.md missing - every skill has a page`);
for (const f of await fs.readdir(path.join(root, "agents")))
  if (f.endsWith(".agent.md") && !(await exists(path.join(docs, f.replace(/\.agent\.md$/, ".md")))))
    errors.push(`docs/${f.replace(/\.agent\.md$/, ".md")} missing - every agent has a page`);

// The toc lists every page, and every href exists.
const toc = await fs.readFile(path.join(docs, "toc.yml"), "utf8").catch(() => "");
if (!toc) errors.push("docs/toc.yml missing");
const hrefs = new Set();
for (const m of toc.matchAll(/^\s*-?\s*href:\s*(.+?)\s*$/gm)) {
  const href = m[1].replace(/^["']|["']$/g, "");
  hrefs.add(href);
  if (!(await exists(path.join(docs, href)))) errors.push(`docs/toc.yml: href '${href}' does not exist`);
}
for (const p of pages) {
  const r = path.relative(docs, p).split(path.sep).join("/");
  if (!hrefs.has(r)) errors.push(`docs/${r}: not listed in docs/toc.yml`);
}

const EMOJI = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}]/u;

for (const p of pages) {
  const name = rel(p);
  const md = (await fs.readFile(p, "utf8")).replace(/\r\n/g, "\n");
  const fm = md.match(/^---\n([\s\S]*?)\n---\n/);
  if (!fm || !/^_description:\s*"[^"]+"\s*$/m.test(fm[1])) errors.push(`${name}: front matter with _description: "..." missing`);

  // Outside fenced code: count H1s, check fences carry a language.
  let inFence = false, h1 = 0;
  const prose = [];
  md.slice(fm ? fm[0].length : 0).split("\n").forEach((line, i) => {
    const fence = line.match(/^\s*(```+|~~~+)(.*)$/);
    if (fence) {
      if (!inFence && !fence[2].trim()) errors.push(`${name}:${i + 1}: code fence without a language (bash, text, yaml, markdown, json, mermaid ...)`);
      inFence = !inFence;
      return;
    }
    if (inFence) return;
    if (/^# \S/.test(line)) h1++;
    prose.push(line);
  });
  if (h1 !== 1) errors.push(`${name}: ${h1} H1 headings - exactly one expected`);

  for (const [re, what] of [[/<div\b/i, "<div"], [/<style\b/i, "<style"], [/<script\b/i, "<script"], [/\bstyle\s*=/i, "style="]])
    if (re.test(md)) errors.push(`${name}: '${what}' - pages bring content only; the Vela template does the layout`);
  if (EMOJI.test(md)) errors.push(`${name}: emoji - none in the docs`);

  // Links: [text](target) outside code.
  const text = prose.join("\n").replace(/`[^`\n]*`/g, "");
  for (const m of text.matchAll(/\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g)) {
    const target = m[1];
    if (/^https?:/.test(target)) {
      if (target.startsWith(REPO + "/") && !target.startsWith(ISSUES)) {
        const ref = target.slice(REPO.length).match(/^\/(?:blob|tree)\/([^/]+)\//)?.[1];
        if (!ref || !/^v\d+\.\d+\.\d+$/.test(ref)) errors.push(`${name}: '${target}' - link this repo at a tag (/blob/vX.Y.Z/), never a branch`);
      }
      continue;
    }
    if (/^(mailto:|#)/.test(target)) continue;
    const file = target.split("#")[0];
    const resolved = path.resolve(path.dirname(p), file);
    const inside = path.relative(docs, resolved);
    if (!inside.startsWith("..")) {
      if (!(await exists(resolved))) errors.push(`${name}: link '${target}' - no such file in docs/`);
      continue;
    }
    // Leaves docs/: must land in docs/agents/../<Vela folder>/..., i.e. exactly one level up, into a known folder.
    const parts = inside.split(path.sep);
    if (parts[0] !== ".." || parts[1] === ".." || !VELA_DIRS.has(parts[1]) || parts.length < 3)
      errors.push(`${name}: link '${target}' leaves docs/ - only into a Vela docs folder (${[...VELA_DIRS].join(", ")})`);
  }
}

const index = await fs.readFile(path.join(docs, "index.md"), "utf8").catch(() => "");
if (!index.includes(ISSUES)) errors.push(`docs/index.md: must point pack issues to ${ISSUES} (the site footer opens Vela's)`);

for (const e of errors) console.error(`ERROR ${e}`);
console.log(`\ncheck-docs: ${pages.length} page(s), ${errors.length} error(s).`);
process.exit(errors.length ? 1 : 0);
