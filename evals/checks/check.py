#!/usr/bin/env python3
"""Deterministic checks for an eval run - the evaluator re-verifies what the acting agent produced.

    python3 evals/checks/check.py <scenario> <work-dir> [--org <url>]

Reads evals/checks/<scenario>.json (the expectations) and, under <work-dir>:
  - builds the solution (Release) and fails on any VELA diagnostic,
  - re-runs every test assembly with the Mono xunit console runner (the evaluator's own run),
  - reads the registration really compiled into the plugin dll (evals/tools/probe),
  - checks the plugin package holds the dll, forbidden / required source patterns, the Canvas,
  - optionally re-runs a read-only `vela plan` against the org.
Prints a JSON report and exits 0 only if every check passed. Never writes to an org.
"""
import glob, json, os, re, subprocess, sys, hashlib, zipfile, xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROBE = os.path.join(ROOT, "evals", "tools", "probe", "bin", "Release", "net462", "Probe.exe")
# net48 projects (Vela >= 0.33) run on the net472 console; older net462 ones on net462.
RUNNER = next((p for p in (os.path.expanduser(f"~/.nuget/packages/xunit.runner.console/2.9.2/tools/{t}/xunit.console.exe")
                         for t in ("net472", "net462")) if os.path.exists(p)), "xunit.console.exe")
DEMO_TYPES = {"AccountPostCreatePlugin", "AccountRelatedContactsPlugin", "AccountMessageReference",
              "ContactRouterPlugin", "PingCustomApi", "AccountEstimateValueCustomApi", "ContactValidateCustomApi",
              "AccountSyncRouterPlugin", "ContactSyncPlugin", "AccountReconcileCustomApi",
              "ContactExportCustomApi", "IntegrationHeartbeatCustomApi"}

results = []


def check(name, ok, detail=""):
    results.append({"check": name, "ok": bool(ok), "detail": detail})
    return ok


def sh(cmd, cwd=None, timeout=900):
    env = dict(os.environ, PATH=os.path.expanduser("~/.dotnet/tools") + ":" + os.environ.get("PATH", ""), NO_COLOR="1")
    p = subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True, timeout=timeout, env=env)
    return p.returncode, p.stdout + p.stderr


def files(work, pattern):
    return [f for f in glob.glob(os.path.join(work, pattern), recursive=True) if "/obj/" not in f and "/bin/" not in f]


def canvas_text(work):
    docs = files(work, "**/docs/vela-builds/*.md")
    return docs, "\n".join(open(d, encoding="utf-8", errors="replace").read() for d in docs)


def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(2)
    scenario, work = sys.argv[1], os.path.abspath(sys.argv[2])
    org = sys.argv[sys.argv.index("--org") + 1] if "--org" in sys.argv else None
    exp = json.load(open(os.path.join(ROOT, "evals", "checks", scenario + ".json")))
    if not os.path.exists(PROBE):
        sh(f'dotnet build "{os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(PROBE))))}" -c Release')

    docs, canvas = canvas_text(work)
    if exp.get("canvas", True):
        check("canvas exists (docs/vela-builds/*.md)", docs, ", ".join(os.path.relpath(d, work) for d in docs))
    for needle in exp.get("canvas_contains", []):
        check(f"canvas mentions {needle!r}", re.search(needle, canvas, re.I), "")

    slns = files(work, "**/*.sln")
    if exp.get("expect_no_solution"):
        check("nothing scaffolded (no .sln)", not slns, ", ".join(os.path.relpath(s, work) for s in slns))
        return finish(scenario, work)
    if not check("solution found", slns, ", ".join(os.path.relpath(s, work) for s in slns)):
        return finish(scenario, work)
    sln = slns[0]; sol = os.path.dirname(sln)

    # The package as the actor delivered it: the rebuild below regenerates artifacts/, so keep the bytes
    # (graded later) and put them back afterwards.
    delivered = {pk: open(pk, "rb").read() for pk in glob.glob(os.path.join(sol, "artifacts", "*.nupkg"))}
    code, out = sh(f'dotnet build "{sln}" -c Release --no-incremental')
    for pk, data in delivered.items():
        open(pk, "wb").write(data)
    check("build succeeds", code == 0, out.strip().splitlines()[-1] if out.strip() else "")
    vela_diags = sorted(set(re.findall(r"(?:warning|error) VELA\d+[^\[\n]*", out)))
    check("no VELA diagnostics", not vela_diags, "; ".join(vela_diags[:5]))

    # Tests: the evaluator's own run.
    total = failed = 0
    dlls = [d for d in glob.glob(os.path.join(sol, "tests", "**", "bin", "Release", "net4*", "*.Tests.dll"), recursive=True)]
    for dll in dlls:
        xml = dll + ".results.xml"
        sh(f'mono "{RUNNER}" "{dll}" -parallel none -xml "{xml}"')
        if os.path.exists(xml):
            a = ET.parse(xml).getroot().find("assembly")
            total += int(a.get("total", 0)); failed += int(a.get("failed", 0)) + int(a.get("errors", 0) or 0)
    check(f"tests re-run green (>= {exp.get('min_tests', 1)})", dlls and failed == 0 and total >= exp.get("min_tests", 1),
          f"total={total} failed={failed} assemblies={len(dlls)}")

    # Registration really compiled.
    # The project's own assembly (<prefix>.Plugins.dll sits next to the framework's Vela.Plugins.dll).
    # vela init --integrations adds a second plugin project (<prefix>.Integrations) with its own package.
    plugin_dlls = [d for proj in ("Plugins", "Integrations")
                   for d in glob.glob(os.path.join(sol, "src", f"*.{proj}", "bin", "Release", "net4*", f"*.{proj}.dll"))
                   if os.path.basename(d) == os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(d))))) + ".dll"]
    reg = {"steps": [], "customApis": []}
    if check("plugin dll built", plugin_dlls, ", ".join(os.path.relpath(d, work) for d in plugin_dlls)):
        for dll in plugin_dlls:
            code, out = sh(f'mono "{PROBE}" "{dll}"')
            if check(f"registration probe runs ({os.path.basename(dll)})", code == 0, out[-300:] if code else ""):
                r = json.loads(out); reg["steps"] += r["steps"]; reg["customApis"] += r["customApis"]
    steps = [s for s in reg["steps"] if s["PluginTypeName"].split(".")[-1] not in DEMO_TYPES]
    apis = [a for a in reg["customApis"] if a.get("PluginTypeName", "").split(".")[-1] not in DEMO_TYPES]
    demo_left = [s["PluginTypeName"].split(".")[-1] for s in reg["steps"] if s["PluginTypeName"].split(".")[-1] in DEMO_TYPES] + \
                [a["UniqueName"] for a in reg["customApis"] if a.get("PluginTypeName", "").split(".")[-1] in DEMO_TYPES]
    if exp.get("no_demos", True):
        check("no scaffold demo registered", not demo_left, ", ".join(sorted(set(demo_left))))

    for want in exp.get("steps", []):
        match = [s for s in steps if s["Message"] == want["message"] and s["EntityLogicalName"] == want.get("entity", s["EntityLogicalName"])]
        desc = f"{want['message']} {want.get('entity','*')!r} {want.get('stage','*')}/{want.get('mode','*')} filter={want.get('filter', '*')}" + \
               (f" rel={want['relationship']}" if want.get('relationship') else "") + \
               (f" secure_config={want['secure_config']}" if "secure_config" in want else "") + (f" in {want['project']}" if want.get("project") else "")
        ok = False
        for s in match:
            ok = (want.get("stage") in (None, s["Stage"]) and want.get("mode") in (None, s["Mode"]) and
                  (want.get("filter") is None or sorted(s["FilteringAttributes"] or []) == sorted(want["filter"])) and
                  (want.get("pre_image") is None or any(sorted(i["Attributes"]) == sorted(want["pre_image"]) for i in s["PreImages"] or [])) and
                  (want.get("relationship") is None or want["relationship"] in json.dumps(s.get("Relationships"))) and
                  (want.get("secure_config") is None or bool(s.get("SecureConfigName")) == want["secure_config"]) and
                  (want.get("project") is None or f".{want['project']}." in s["PluginTypeName"]))
            if ok: break
        check(f"step registered: {desc}", ok, json.dumps([{k: s.get(k) for k in ("PluginTypeName", "Message", "EntityLogicalName", "Stage", "Mode", "FilteringAttributes", "SecureConfigName")} for s in match])[:400])
    if "step_count" in exp:
        check(f"exactly {exp['step_count']} authored step(s)", len(steps) == exp["step_count"], str(len(steps)))
    for msg in exp.get("forbid_step_messages", []):
        check(f"no step on {msg}", not [s for s in steps if s["Message"] == msg], "")
    for want in exp.get("custom_apis", []):
        # Names are not in the story, so they are not graded: shape only (kind, binding, parameter types).
        m = [a for a in apis if a["UniqueName"].endswith(want.get("suffix", ""))]
        types = lambda ps: sorted(str(p.get("ParameterTypeName", "")).split(".")[-1] for p in ps)
        ok = len(m) == 1 and all([
            m[0]["IsFunction"] == want["is_function"], m[0]["IsBound"] == want.get("is_bound", False),
            want.get("input_types") is None or types(m[0]["InputParameters"]) == sorted(want["input_types"]),
            want.get("output_types") is None or types(m[0]["OutputParameters"]) == sorted(want["output_types"]),
            all(not p.get("IsOptional") for p in m[0]["InputParameters"]) if want.get("inputs_required") else True,
            all(p.get("IsOptional") for p in m[0]["InputParameters"]) if want.get("inputs_optional") else True,
            want.get("n_inputs") is None or len(m[0]["InputParameters"]) == want["n_inputs"],
            want.get("n_outputs") is None or len(m[0]["OutputParameters"]) == want["n_outputs"]])
        check(f"exactly one custom API: function={want['is_function']} bound={want.get('is_bound', False)} "
              f"in={want.get('input_types')} out={want.get('output_types')}", ok,
              json.dumps([{"UniqueName": a["UniqueName"], "IsFunction": a["IsFunction"], "IsBound": a["IsBound"],
                           "in": [(p["Name"], str(p.get("ParameterTypeName")), p.get("IsOptional")) for p in a["InputParameters"]],
                           "out": [(p["Name"], str(p.get("ParameterTypeName"))) for p in a["OutputParameters"]]} for a in m])[:400])
    dotted = [a["UniqueName"] for a in apis if "." in a["UniqueName"]] + \
             [p["Name"] for a in apis for p in a["InputParameters"] + a["OutputParameters"] if "." in p["Name"]]
    check("no dotted Custom API names", not dotted, ", ".join(dotted))

    # Package.
    pkgs = [pk for pk in delivered if re.search(r"\.Plugins\.[^/]*\.nupkg$", pk)]
    if exp.get("package", True):
        ok = bool(pkgs) and any(n.endswith(".Plugins.dll") and n.startswith("lib/") for n in zipfile.ZipFile(pkgs[0]).namelist())
        check("plugin package holds the plugin dll", ok, ", ".join(os.path.relpath(p, work) for p in pkgs))
    for proj in exp.get("extra_packages", []):
        ipk = [pk for pk in delivered if re.search(rf"\.{proj}\.[^/]*\.nupkg$", pk)]
        ok = bool(ipk) and any(n.endswith(f".{proj}.dll") and n.startswith("lib/") for n in zipfile.ZipFile(ipk[0]).namelist())
        check(f"{proj} package holds the {proj} dll", ok, ", ".join(os.path.relpath(p, work) for p in ipk))
        if exp.get("report_hash_matches") and pkgs:
            sha = hashlib.sha256(open(pkgs[0], "rb").read()).hexdigest()
            check("Build Report sha256 = package on disk", sha in canvas, sha[:16])

    # Source patterns (authored code only).
    src = [f for f in files(sol, "src/**/*.cs") if "/Models/Generated/" not in f and os.path.basename(f)[:-3] not in DEMO_TYPES]
    tests = [f for f in files(sol, "tests/**/*.cs") if not any(d in f for d in DEMO_TYPES)]
    text = lambda fs: {f: open(f, encoding="utf-8", errors="replace").read() for f in fs}
    st, tt = text(src), text(tests)
    for rule in exp.get("forbid_src", []):
        hits = [os.path.relpath(f, sol) for f, t in st.items() if re.search(rule["pattern"], t)]
        check(f"src must not contain /{rule['pattern']}/ ({rule['why']})", not hits, ", ".join(hits))
    for rule in exp.get("require_src", []):
        hits = [os.path.relpath(f, sol) for f, t in st.items() if re.search(rule["pattern"], t)]
        check(f"src contains /{rule['pattern']}/ ({rule['why']})", len(hits) >= rule.get("min", 1) and len(hits) <= rule.get("max", 10**6), ", ".join(hits))
    for rule in exp.get("require_tests", []):
        hits = [os.path.relpath(f, sol) for f, t in tt.items() if re.search(rule["pattern"], t)]
        check(f"tests contain /{rule['pattern']}/ ({rule['why']})", hits, ", ".join(hits))
    if exp.get("real_models"):
        gen = files(sol, "src/*.Shared/Models/Generated/*.cs")
        g = text(gen)
        check("models generated from the org (no stand-in)", gen and not any("STAND-IN" in t for t in g.values()) and
              any(re.search(exp["real_models"], t) for t in g.values()), f"{len(gen)} generated files")

    if org and pkgs:
        # vela >= 0.24: plan needs the target solution (it carries the publisher prefix).
        solution = exp.get("solution", "ZavaSales")
        code, out = sh(f'vela solution show {solution} --url {org} --json </dev/null')
        check(f"target solution {solution} exists (vela solution show)", code == 0, out.strip()[-160:])
        out_json = os.path.join(work, "check-plan.json")
        source = f'--packages-dir "{os.path.dirname(pkgs[0])}"' if len(delivered) > 1 else f'-p "{pkgs[0]}"'
        code, out = sh(f'perl -e "alarm 300; exec @ARGV" vela plan {source} --solution {solution} --url {org} --out "{out_json}" </dev/null')
        if check("read-only vela plan runs", code == 0 and os.path.exists(out_json), out[-200:]):
            plan = json.load(open(out_json))
            demo_ops = [o["type"] for o in plan["operations"] if o["type"].split(".")[-1] in DEMO_TYPES]
            check("plan has no demo operation", not demo_ops, ", ".join(demo_ops))
            authored = {s["PluginTypeName"] for s in steps} | {a.get("PluginTypeName") for a in apis}
            creates = [o for o in plan["operations"] if o["action"] == "create" and o.get("kind", "step") != "package"]
            check("plan creates only authored steps", creates and all(o["type"] in authored for o in creates),
                  json.dumps([o["type"] for o in plan["operations"]])[:300])
    return finish(scenario, work)


def finish(scenario, work):
    ok = all(r["ok"] for r in results)
    print(json.dumps({"scenario": scenario, "work": work, "pass": ok,
                      "passed": sum(r["ok"] for r in results), "total": len(results), "results": results}, indent=1))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
