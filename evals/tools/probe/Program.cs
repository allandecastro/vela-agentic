// Usage: mono Probe.exe <path/to/Plugins.dll>
// Prints {"steps":[...],"customApis":[...]} as JSON. Exit 0 on success, 3 if the dll is missing, 4 on error.
using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;

internal static class Program
{
    private static int Main(string[] args)
    {
        if (args.Length != 1 || !File.Exists(args[0])) { Console.Error.WriteLine("usage: Probe.exe <plugins.dll>"); return 3; }
        string dll = Path.GetFullPath(args[0]);
        string dir = Path.GetDirectoryName(dll);
        AppDomain.CurrentDomain.AssemblyResolve += (s, e) =>
        {
            string candidate = Path.Combine(dir, new AssemblyName(e.Name).Name + ".dll");
            return File.Exists(candidate) ? Assembly.LoadFrom(candidate) : null;
        };
        try
        {
            Assembly plugin = Assembly.LoadFrom(dll);
            Assembly vela = Assembly.LoadFrom(Path.Combine(dir, "Vela.Plugins.dll"));
            // Vela.Plugins >= 0.33: the public FrameworkManifestScanner returns steps + Custom APIs in one pass.
            Type scanner = vela.GetType("Vela.Manifest.FrameworkManifestScanner", false);
            object stepsObj, apisObj;
            if (scanner != null)
            {
                Type optsType = vela.GetType("Vela.Manifest.FrameworkManifestScanOptions", true);
                MethodInfo scan = scanner.GetMethod("Scan", new[] { typeof(Assembly), optsType });
                object target = scan.IsStatic ? null : Activator.CreateInstance(scanner);
                object manifest = scan.Invoke(target, new object[] { plugin, Activator.CreateInstance(optsType) });
                stepsObj = manifest.GetType().GetProperty("PluginSteps").GetValue(manifest);
                apisObj = manifest.GetType().GetProperty("CustomApis").GetValue(manifest);
            }
            else
            {
                // Older framework (<= 0.30): the static readers.
                stepsObj = vela.GetType("Vela.Steps.StepDefinitionReader", true)
                    .GetMethod("GetStepDefinitions", new[] { typeof(Assembly) }).Invoke(null, new object[] { plugin });
                apisObj = vela.GetType("Vela.CustomApi.CustomApiDefinitionReader", true)
                    .GetMethod("GetCustomApiDefinitions", new[] { typeof(Assembly) }).Invoke(null, new object[] { plugin });
            }
            var sb = new StringBuilder("{\"steps\":[");
            sb.Append(string.Join(",", ((IEnumerable)stepsObj ?? new object[0]).Cast<object>().Select(ToJson)));
            sb.Append("],\"customApis\":[");
            sb.Append(string.Join(",", ((IEnumerable)apisObj ?? new object[0]).Cast<object>().Select(ToJson)));
            sb.Append("]}");
            Console.WriteLine(sb.ToString());
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine((ex.InnerException ?? ex).ToString());
            return 4;
        }
    }

    // Minimal reflection JSON: public readable properties; strings, numbers, bools, enums, nested lists/objects.
    private static string ToJson(object o)
    {
        if (o == null) return "null";
        if (o is string s) return "\"" + s.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
        if (o is bool b) return b ? "true" : "false";
        Type t = o.GetType();
        if (t.IsEnum) return "\"" + o + "\"";
        if (t.IsPrimitive || o is decimal) return Convert.ToString(o, System.Globalization.CultureInfo.InvariantCulture);
        if (o is Guid || o is DateTime) return "\"" + o + "\"";
        if (o is IEnumerable e) return "[" + string.Join(",", e.Cast<object>().Select(ToJson)) + "]";
        var props = t.GetProperties(BindingFlags.Public | BindingFlags.Instance).Where(p => p.CanRead && p.GetIndexParameters().Length == 0);
        return "{" + string.Join(",", props.Select(p =>
        {
            object v; try { v = p.GetValue(o); } catch { v = null; }
            return "\"" + p.Name + "\":" + ToJson(v);
        })) + "}";
    }
}
