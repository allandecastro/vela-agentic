#:package Microsoft.CodeAnalysis.CSharp@4.14.0
#:property JsonSerializerIsReflectionEnabledByDefault=true
#:property NoWarn=IL3050
// mutate - do the tests of a Vela project catch a wrong behaviour? (vela-agentic evals)
//
//   dotnet run evals/tools/mutate.cs -- --solution <dir> [--max 25] [--json <out.json>]
//
// Plants one bug at a time in the authored plugin code (src/, generated models and the registration excluded),
// rebuilds, runs every test assembly, and reports which mutants the suite kills. A mutant that does not compile is
// discarded. Operators: negate an `if` condition, flip a comparison, drop a `throw`, drop an assignment to a
// member, drop a query `.Where(...)`, flip a boolean literal. A surviving mutant is either a missing test or an
// equivalent mutant (no observable change) - the grader tells which. Restores every file it touches.
// Exit: 0 report written, 2 cannot run (no solution, baseline build or tests not green).
using System.Diagnostics;
using System.Text.Json;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

string Arg(string name, string? fallback = null)
{
    int i = Array.IndexOf(args, name);
    if (i >= 0 && i + 1 < args.Length) return args[i + 1];
    if (fallback != null) return fallback;
    Console.WriteLine($"mutate: {name} <value> is required");
    Environment.Exit(2);
    return "";
}

string sol = Path.GetFullPath(Arg("--solution"));
int max = int.Parse(Arg("--max", "25"));
string? jsonOut = args.Contains("--json") ? Arg("--json") : null;
string? slnFile = Directory.GetFiles(sol, "*.sln").FirstOrDefault();
if (slnFile == null) { Console.WriteLine($"mutate: no .sln in {sol}"); return 2; }

// --- build + test -----------------------------------------------------------------------------------------------
(int code, string output) Run(string file, params string[] a)
{
    var psi = new ProcessStartInfo(file) { WorkingDirectory = sol, RedirectStandardOutput = true, RedirectStandardError = true };
    foreach (var x in a) psi.ArgumentList.Add(x);
    using var p = Process.Start(psi)!;
    var err = p.StandardError.ReadToEndAsync();
    string o = p.StandardOutput.ReadToEnd(); p.WaitForExit();
    return (p.ExitCode, o + err.Result);
}

string? runner = OperatingSystem.IsWindows() ? null : Directory
    .GetDirectories(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".nuget", "packages", "xunit.runner.console"))
    .OrderByDescending(d => d).Select(d => Path.Combine(d, "tools", "net472", "xunit.console.exe")).FirstOrDefault(File.Exists);

bool Build() => Run("dotnet", "build", slnFile, "-c", "Release", "--no-restore", "-v", "q", "-nologo").code == 0;

// true = every test passed
bool Tests()
{
    if (runner == null) return Run("dotnet", "test", slnFile, "-c", "Release", "--no-build", "-v", "q", "-nologo").code == 0;
    var dlls = Directory.GetFiles(Path.Combine(sol, "tests"), "*.Tests.dll", SearchOption.AllDirectories)
        .Where(d => d.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}Release{Path.DirectorySeparatorChar}")
                    && Path.GetFileNameWithoutExtension(d) == Path.GetFileName(Path.GetDirectoryName(Path.GetDirectoryName(Path.GetDirectoryName(Path.GetDirectoryName(d))))))
        .ToList();
    if (dlls.Count == 0) return false;
    foreach (var dll in dlls)
        if (Run("mono", runner, dll, "-parallel", "none").code != 0) return false;
    return true;
}

Run("dotnet", "restore", slnFile, "-v", "q");
if (!Build() || !Tests()) { Console.WriteLine("mutate: the baseline must build and pass its tests first"); return 2; }

// --- mutation sites ---------------------------------------------------------------------------------------------
bool Authored(string f) =>
    !f.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}") && !f.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}")
    && !f.Contains("Models" + Path.DirectorySeparatorChar + "Generated") && !f.EndsWith(".g.cs") && !f.EndsWith(".generated.cs")
    && Path.GetFileName(f) is not ("ProjectServices.cs" or "Messages.cs");

var sites = new List<(string file, TextSpanLite span, string op, string before, string after)>();
foreach (var file in Directory.GetFiles(Path.Combine(sol, "src"), "*.cs", SearchOption.AllDirectories).Where(Authored).OrderBy(f => f, StringComparer.Ordinal))
{
    var root = CSharpSyntaxTree.ParseText(File.ReadAllText(file)).GetRoot();
    bool InRegistration(SyntaxNode n) => n.Ancestors().OfType<MethodDeclarationSyntax>().Any(m => m.Identifier.Text is "RegisterPluginSteps" or "ConfigureServices");
    void Add(SyntaxNode n, string op, string after)
    {
        if (!InRegistration(n)) sites.Add((file, new TextSpanLite(n.SpanStart, n.Span.Length), op, n.ToString(), after));
    }
    foreach (var n in root.DescendantNodes())
    {
        switch (n)
        {
            case IfStatementSyntax s:
                Add(s.Condition, "negate if", $"!({s.Condition})"); break;
            case BinaryExpressionSyntax b when Flip(b.Kind()) is string to:
                Add(b, "flip comparison", $"{b.Left} {to} {b.Right}"); break;
            case ThrowStatementSyntax t:
                Add(t, "drop throw", ";"); break;
            case ExpressionStatementSyntax { Expression: AssignmentExpressionSyntax { Left: MemberAccessExpressionSyntax } } e:
                Add(e, "drop assignment", ";"); break;
            case InvocationExpressionSyntax { Expression: MemberAccessExpressionSyntax { Name.Identifier.Text: "Where" } m }:
                Add(n, "drop Where", m.Expression.ToString()); break;
            case LiteralExpressionSyntax l when l.IsKind(SyntaxKind.TrueLiteralExpression) || l.IsKind(SyntaxKind.FalseLiteralExpression):
                Add(l, "flip bool", l.IsKind(SyntaxKind.TrueLiteralExpression) ? "false" : "true"); break;
        }
    }
}

static string? Flip(SyntaxKind k) => k switch
{
    SyntaxKind.EqualsExpression => "!=", SyntaxKind.NotEqualsExpression => "==",
    SyntaxKind.LessThanExpression => "<=", SyntaxKind.LessThanOrEqualExpression => "<",
    SyntaxKind.GreaterThanExpression => ">=", SyntaxKind.GreaterThanOrEqualExpression => ">",
    SyntaxKind.LogicalAndExpression => "||", SyntaxKind.LogicalOrExpression => "&&",
    _ => null,
};

// Deterministic sample spread over the sites (same project → same mutants).
var picked = sites.Count <= max ? sites : Enumerable.Range(0, max).Select(i => sites[i * sites.Count / max]).ToList();

// --- run --------------------------------------------------------------------------------------------------------
var results = new List<object>();
int killed = 0, survived = 0, invalid = 0;
foreach (var s in picked)
{
    string original = File.ReadAllText(s.file);
    string mutated = original[..s.span.Start] + s.after + original[(s.span.Start + s.span.Length)..];
    string where = $"{Path.GetRelativePath(sol, s.file)}:{original[..s.span.Start].Count(c => c == '\n') + 1}";
    string status;
    try
    {
        File.WriteAllText(s.file, mutated);
        status = !Build() ? "invalid" : Tests() ? "survived" : "killed";
    }
    finally { File.WriteAllText(s.file, original); }
    if (status == "killed") killed++; else if (status == "survived") survived++; else invalid++;
    Console.WriteLine($"{status,-8} {s.op,-16} {where}  {Short(s.before)} -> {Short(s.after)}");
    results.Add(new { status, op = s.op, where, before = s.before, after = s.after });
}
Build();   // leave the binaries matching the restored sources

static string Short(string x) { x = string.Join(" ", x.Split((char[])null!, StringSplitOptions.RemoveEmptyEntries)); return x.Length > 70 ? x[..67] + "..." : x; }

int valid = killed + survived;
Console.WriteLine($"mutate: {killed}/{valid} mutants killed ({survived} survived, {invalid} did not compile, {sites.Count} sites)");
if (jsonOut != null)
    File.WriteAllText(jsonOut, JsonSerializer.Serialize(new { killed, survived, invalid, sites = sites.Count, score = valid == 0 ? 0 : Math.Round((double)killed / valid, 2), mutants = results },
        new JsonSerializerOptions { WriteIndented = true }));
return 0;

record struct TextSpanLite(int Start, int Length);
