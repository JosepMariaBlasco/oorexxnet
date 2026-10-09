// Types and namespaces by name, caselessly (ooRexx uppercases message names).
//  - Type names: full names, C# aliases (int, string, ...), generics in C#
//    syntax ("System.Collections.Generic.Dictionary<string, int>"), arrays
//    ("int[]", "int[,]"), nested types with '+'. A generic name without its
//    arguments ("System.Collections.Generic.List") is the open generic.
//  - Where types are looked for: the assemblies loaded, then the shared
//    framework's assemblies whose name is a prefix of the type's full name
//    (System.Text.RegularExpressions.Regex -> System.Text.RegularExpressions.dll),
//    loaded on demand.
//  - Namespaces: those of the types in the loaded assemblies, plus every
//    prefix of the framework's assembly names; known caselessly, spelled as
//    .NET spells them.
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;
using System.Runtime.Loader;

namespace Rexx.Net;

public static class Types
{
    static readonly Dictionary<string, Type> aliases = new(StringComparer.OrdinalIgnoreCase)
    {
        ["bool"] = typeof(bool), ["byte"] = typeof(byte), ["sbyte"] = typeof(sbyte),
        ["char"] = typeof(char), ["decimal"] = typeof(decimal), ["double"] = typeof(double),
        ["float"] = typeof(float), ["int"] = typeof(int), ["uint"] = typeof(uint),
        ["nint"] = typeof(nint), ["nuint"] = typeof(nuint), ["long"] = typeof(long),
        ["ulong"] = typeof(ulong), ["short"] = typeof(short), ["ushort"] = typeof(ushort),
        ["object"] = typeof(object), ["string"] = typeof(string),
    };

    static readonly ConcurrentDictionary<string, Type?> byName = new(StringComparer.OrdinalIgnoreCase);

    // The shared frameworks' assemblies, name -> path (System.Private.* left
    // out): every framework the runtime was started with, as its trusted
    // platform assemblies list them (Microsoft.NETCore.App; on Windows also
    // Microsoft.WindowsDesktop.App, with Windows Forms, System.Drawing...),
    // only those inside dotnet's shared/ (not a host application's own);
    // else the core library's directory.
    static readonly Lazy<Dictionary<string, string>> frameworkPaths = new(() =>
    {
        var core = Path.GetDirectoryName(typeof(object).Assembly.Location)!;
        var shared = Path.GetDirectoryName(Path.GetDirectoryName(core));   // .../shared
        var tpa = AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES") as string;
        IEnumerable<string> files = string.IsNullOrEmpty(tpa)
            ? Directory.GetFiles(core, "*.dll")
            : tpa.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries);
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var f in files)
        {
            if (!f.EndsWith(".dll", StringComparison.OrdinalIgnoreCase)) continue;
            var dir = Path.GetDirectoryName(f);
            if (!SameDir(dir, core) && (shared == null || !SameDir(Path.GetDirectoryName(Path.GetDirectoryName(dir)), shared))) continue;
            var n = Path.GetFileNameWithoutExtension(f);
            if (n.Contains(".Private.", StringComparison.Ordinal) || n.StartsWith("api-ms-", StringComparison.Ordinal)
                || n.StartsWith("Microsoft.VisualBasic", StringComparison.Ordinal) || n == "netstandard" || n == "mscorlib") continue;
            map.TryAdd(n, f);
        }
        return map;
    });

    static readonly Lazy<string[]> frameworkAssemblies = new(() => frameworkPaths.Value.Keys.ToArray());

    static bool SameDir(string? a, string? b) =>
        string.Equals(a, b, OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal);

    // Every public type of the shared framework -> its assembly, and every
    // namespace (with its prefixes), read from the assemblies' metadata
    // without loading them. The last resort, for a type whose assembly is not
    // named by its namespace (System.Timers.Timer is in
    // System.ComponentModel.TypeConverter): built the first time it is needed.
    sealed class FrameworkIndex
    {
        public readonly Dictionary<string, string> Types = new(StringComparer.OrdinalIgnoreCase);
        public readonly Dictionary<string, string> Namespaces = new(StringComparer.OrdinalIgnoreCase);
    }

    static readonly Lazy<FrameworkIndex> frameworkIndex = new(() =>
    {
        var index = new FrameworkIndex();
        foreach (var (an, path) in frameworkPaths.Value)
        {
            try
            {
                using var file = File.OpenRead(path);
                using var pe = new PEReader(file);
                if (!pe.HasMetadata) continue;
                var md = pe.GetMetadataReader();
                foreach (var h in md.TypeDefinitions)
                {
                    var td = md.GetTypeDefinition(h);
                    if ((td.Attributes & TypeAttributes.VisibilityMask) != TypeAttributes.Public) continue;
                    var ns = md.GetString(td.Namespace);
                    index.Types.TryAdd(ns.Length > 0 ? ns + "." + md.GetString(td.Name) : md.GetString(td.Name), an);
                    for (var n = ns; n.Length > 0; n = n.LastIndexOf('.') is int dot && dot > 0 ? n.Substring(0, dot) : "")
                        index.Namespaces.TryAdd(n, n);
                }
            }
            catch (Exception e) when (e is IOException or BadImageFormatException or UnauthorizedAccessException) { }
        }
        return index;
    });

    // ------------------------------------------------------------------ types

    /// A type by its (C#-like) name; throws if there is none.
    public static Type Parse(string text)
    {
        int i = 0;
        var t = ParseType(text, ref i);
        SkipBlanks(text, ref i);
        if (i != text.Length) throw new BridgeException($"bad type name \"{text}\"");
        return t;
    }

    /// A comma-separated list of types: "int, string" (a generic method's type arguments).
    public static Type[] ParseList(string text)
    {
        var list = new List<Type>();
        int i = 0;
        while (true)
        {
            list.Add(ParseType(text, ref i));
            SkipBlanks(text, ref i);
            if (i == text.Length) return list.ToArray();
            if (text[i] != ',') throw new BridgeException($"bad list of types \"{text}\"");
            i++;
        }
    }

    static void SkipBlanks(string s, ref int i) { while (i < s.Length && char.IsWhiteSpace(s[i])) i++; }

    static Type ParseType(string s, ref int i)
    {
        SkipBlanks(s, ref i);
        int start = i;
        while (i < s.Length && (char.IsLetterOrDigit(s[i]) || s[i] == '.' || s[i] == '_' || s[i] == '+' || s[i] == '`')) i++;
        string name = s.Substring(start, i - start);
        if (name.Length == 0) throw new BridgeException($"bad type name \"{s}\"");
        var args = new List<Type>();
        SkipBlanks(s, ref i);
        if (i < s.Length && s[i] == '<')
        {
            i++;
            while (true)
            {
                args.Add(ParseType(s, ref i));
                SkipBlanks(s, ref i);
                if (i < s.Length && s[i] == ',') { i++; continue; }
                if (i < s.Length && s[i] == '>') { i++; break; }
                throw new BridgeException($"bad type name \"{s}\"");
            }
        }
        Type t;
        if (args.Count == 0 && aliases.TryGetValue(name, out var a)) t = a;
        else
        {
            t = Find(name, args.Count) ?? throw new BridgeException($"no .NET type \"{name}\"" +
                (args.Count > 0 ? $" with {args.Count} type arguments" : ""));
            if (args.Count > 0) t = t.MakeGenericType(args.ToArray());
        }
        while (true)                                    // [] [,] ...
        {
            SkipBlanks(s, ref i);
            if (i >= s.Length || s[i] != '[') break;
            int rank = 1; i++;
            while (i < s.Length && s[i] == ',') { rank++; i++; }
            if (i >= s.Length || s[i] != ']') throw new BridgeException($"bad type name \"{s}\"");
            i++;
            t = rank == 1 ? t.MakeArrayType() : t.MakeArrayType(rank);
        }
        return t;
    }

    /// A type by full name (caseless). arity: the number of generic type
    /// arguments expected; -1: any (a non-generic type first, else the open
    /// generic with that name and the fewest arguments).
    public static Type? Find(string fullName, int arity = -1)
    {
        if (fullName.Contains('`')) return FindExact(fullName);
        if (arity > 0) return FindExact(fullName + "`" + arity);
        var t = FindExact(fullName);
        if (t != null || arity == 0) return t;
        for (int n = 1; n <= 8; n++)
            if ((t = FindExact(fullName + "`" + n)) != null) return t;
        return null;
    }

    static Type? FindExact(string name) => byName.GetOrAdd(name, n =>
    {
        foreach (var asm in AssemblyLoadContext.Default.Assemblies)
        {
            var t = SafeGetType(asm, n);
            if (t != null) return t;
        }
        // Not loaded yet: the framework assemblies named by it or by a prefix of it.
        string? best = null;
        foreach (var an in frameworkAssemblies.Value)
            if ((n.StartsWith(an + ".", StringComparison.OrdinalIgnoreCase) || n.Equals(an, StringComparison.OrdinalIgnoreCase))
                && (best == null || an.Length > best.Length))           // (System.Console is in System.Console.dll)
                best = an;
        for (string? an = best; an != null; an = Shorter(an))
        {
            var asm = TryLoad(an);
            var t = asm == null ? null : SafeGetType(asm, n);
            if (t != null) return t;
        }
        // The last resort: the framework's index (an assembly not named by the namespace)
        if (frameworkIndex.Value.Types.TryGetValue(n, out var where) && TryLoad(where) is Assembly found)
            return SafeGetType(found, n);
        return null;
    });

    static string? Shorter(string an)
    {
        int dot = an.LastIndexOf('.');
        if (dot < 0) return null;
        var s = an.Substring(0, dot);
        return frameworkAssemblies.Value.Contains(s, StringComparer.OrdinalIgnoreCase) ? s : Shorter(s);
    }

    static Type? SafeGetType(Assembly asm, string name)
    {
        try
        {
            var t = asm.GetType(name, false, true);
            return t != null && (t.IsPublic || t.IsNestedPublic) ? t : null;
        }
        catch { return null; }
    }

    static Assembly? TryLoad(string name)
    {
        try { return Assembly.Load(new AssemblyName(name)); }
        catch { return null; }
    }

    /// Loads an assembly by name, or by path (a name with a slash or ending
    /// in .dll). A name the runtime does not know is looked for as name.dll
    /// in the current directory, then next to the bridge (an assembly that
    /// was in .NET Framework's GAC and is a package now, such as
    /// System.Speech: its .dll copied there). Forgets the "not found"
    /// answers cached so far.
    public static Assembly Load(string nameOrPath)
    {
        Assembly asm;
        if (nameOrPath.Contains('/') || nameOrPath.Contains('\\') || nameOrPath.EndsWith(".dll", StringComparison.OrdinalIgnoreCase))
            asm = AssemblyLoadContext.Default.LoadFromAssemblyPath(Path.GetFullPath(nameOrPath));
        else
        {
            try { asm = Assembly.Load(new AssemblyName(nameOrPath)); }
            catch (FileNotFoundException) when (LocalAssembly(nameOrPath) is string path)
            {
                asm = AssemblyLoadContext.Default.LoadFromAssemblyPath(path);
            }
        }
        foreach (var kv in byName) if (kv.Value == null) byName.TryRemove(kv.Key, out _);
        namespaces = null;
        return asm;
    }

    static string? LocalAssembly(string name)
    {
        foreach (var dir in new[] { Directory.GetCurrentDirectory(), Path.GetDirectoryName(typeof(Types).Assembly.Location) })
        {
            if (string.IsNullOrEmpty(dir)) continue;
            var path = Path.Combine(dir, name + ".dll");
            if (File.Exists(path)) return path;
        }
        return null;
    }

    // ------------------------------------------------------------- namespaces

    static volatile Dictionary<string, string>? namespaces;     // UPPER -> as spelled

    static Dictionary<string, string> Namespaces()
    {
        var ns = namespaces;
        if (ns != null) return ns;
        ns = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        void AddWithPrefixes(string? n)
        {
            while (!string.IsNullOrEmpty(n))
            {
                ns.TryAdd(n, n);
                int dot = n.LastIndexOf('.');
                n = dot < 0 ? null : n.Substring(0, dot);
            }
        }
        foreach (var asm in AssemblyLoadContext.Default.Assemblies)
        {
            Type[] types;
            try { types = asm.GetExportedTypes(); } catch { continue; }
            foreach (var t in types) AddWithPrefixes(t.Namespace);
        }
        foreach (var an in frameworkAssemblies.Value) AddWithPrefixes(an);
        namespaces = ns;
        return ns;
    }

    /// prefix~name: a namespace (returned as its full name, kind "P") or a
    /// type. prefix "" is the root.
    public static object NamespaceMember(string prefix, string name)
    {
        string full = prefix.Length == 0 ? name : prefix + "." + name;
        if (prefix.Length > 0)
        {
            var t = Find(full);
            if (t != null) return t;
        }
        var ns = Namespaces();
        if (ns.TryGetValue(full, out var spelled)) return spelled;
        // A namespace only some assembly not loaded yet has: load it, try again.
        if (TryLoad(full) != null || (prefix.Length > 0 && Find(full) is Type))
        {
            namespaces = null;
            var t = prefix.Length > 0 ? Find(full) : null;
            if (t != null) return t;
            if (Namespaces().TryGetValue(full, out spelled)) return spelled;
        }
        // The framework's index: a namespace no assembly is named after (System.Timers)
        if (frameworkIndex.Value.Namespaces.TryGetValue(full, out spelled)) return spelled;
        throw new BridgeException(prefix.Length == 0
            ? $"no .NET namespace \"{name}\""
            : $"no .NET namespace or type \"{name}\" in {prefix}");
    }

    /// The full name of a namespace spelled as .NET spells it.
    public static string NamespaceName(string full) =>
        Namespaces().TryGetValue(full, out var s) || frameworkIndex.Value.Namespaces.TryGetValue(full, out s)
            ? s : throw new BridgeException($"no .NET namespace \"{full}\"");

    /// A readable name: System.Collections.Generic.List<System.Int32>.
    public static string Display(Type t)
    {
        if (t.IsArray) return Display(t.GetElementType()!) + "[" + new string(',', t.GetArrayRank() - 1) + "]";
        if (!t.IsGenericType) return t.FullName ?? t.Name;
        var name = t.GetGenericTypeDefinition().FullName ?? t.Name;
        int tick = name.IndexOf('`');
        if (tick >= 0) name = name.Substring(0, tick);
        if (t.IsGenericTypeDefinition)
            return name + "<" + new string(',', t.GetGenericArguments().Length - 1) + ">";
        return name + "<" + string.Join(", ", t.GetGenericArguments().Select(Display)) + ">";
    }
}
