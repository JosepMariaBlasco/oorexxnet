// The ooRexx object API from C#, with no native shim (notes/rexx-from-net-
// design.md, Architecture): RexxCreateInterpreter is the only exported
// function used; everything else goes through the two tables of function
// pointers a RexxInstance and a RexxThreadContext point to. Every member of
// both tables is one pointer-sized slot (smoke/hostapi/layout.cpp checks it;
// Slots.cs is generated from oorexxapi.h by smoke/hostapi/gen-slots.sh).
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;

namespace Rexx.Net;

[StructLayout(LayoutKind.Sequential)]
internal struct RexxConditionData
{
    public nint code, rc; public nuint position;
    public nint conditionName, message, errortext, program, description, additional;
}

/// RexxOption: { const char *optionName; ValueDescriptor option } (24 bytes:
/// the descriptor's value union at 8, its type, a uint16, at 16).
[StructLayout(LayoutKind.Sequential)]
internal struct RexxOptionData
{
    public nint name;
    public nint value;
    public ushort type, flags;
    public uint pad;
}

internal static unsafe class Native
{
    public const ushort REXX_VALUE_CSTRING = 15, REXX_VALUE_POINTER = 16;
    public const long InstanceInterfaceVersion = 101, ThreadInterfaceVersion = 103;   // ooRexx 5.0 or later

    static Native()
    {
        NativeLibrary.SetDllImportResolver(typeof(Native).Assembly, Resolve);
    }

    // "rexx": REXX_HOME first (its lib/ or bin/), then the system's search,
    // then the installation the `rexx` on the PATH belongs to, then where
    // ooRexx installs itself. "libc" on macOS: libSystem (pthread_self).
    static IntPtr Resolve(string name, Assembly asm, DllImportSearchPath? path)
    {
        if (name == "libc" && OperatingSystem.IsMacOS())
            return NativeLibrary.TryLoad("/usr/lib/libSystem.B.dylib", out var sys) ? sys : IntPtr.Zero;
        if (name != "rexx") return IntPtr.Zero;
        string file = OperatingSystem.IsWindows() ? "rexx.dll" : OperatingSystem.IsMacOS() ? "librexx.dylib" : "librexx.so";
        var home = Environment.GetEnvironmentVariable("REXX_HOME");
        if (!string.IsNullOrEmpty(home))
            foreach (var d in new[] { home, Path.Combine(home, "lib"), Path.Combine(home, "bin") })
                if (TryLoadRexx(d, file, out var h)) return h;
        if (NativeLibrary.TryLoad(file, asm, path, out var h2)) return h2;
        foreach (var d in Candidates())
            if (TryLoadRexx(d, file, out var h3)) return h3;
        return IntPtr.Zero;
    }

    static IEnumerable<string> Candidates()
    {
        // <home>/bin/rexx (a link followed: /usr/local/bin/rexx may point
        // elsewhere): <home>/bin (Windows: rexx.dll next to rexx.exe), <home>/lib
        string exe = OperatingSystem.IsWindows() ? "rexx.exe" : "rexx";
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        {
            var f = Path.Combine(dir, exe);
            if (!File.Exists(f)) continue;
            string real;
            try { real = File.ResolveLinkTarget(f, returnFinalTarget: true)?.FullName ?? f; }
            catch (IOException) { real = f; }
            var bin = Path.GetDirectoryName(real);
            if (bin is null) break;
            yield return bin;
            var root = Path.GetDirectoryName(bin);
            if (root is not null) { yield return Path.Combine(root, "lib"); yield return Path.Combine(root, "lib64"); }
            break;
        }
        if (OperatingSystem.IsWindows())
        {
            yield return @"C:\Program Files\ooRexx";
            yield return @"C:\Program Files (x86)\ooRexx";
            yield break;
        }
        if (OperatingSystem.IsMacOS())
        {
            // ooRexx's default installation on macOS: ~/Applications/ooRexx5
            var user = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            yield return Path.Combine(user, "Applications", "ooRexx5", "lib");
            yield return "/Applications/ooRexx5/lib";
            yield return "/opt/homebrew/lib";
        }
        foreach (var d in new[] { "/usr/local/lib", "/usr/lib", "/opt/ooRexx/lib", "/usr/local/lib64", "/usr/lib64" })
            yield return d;
    }

    // librexx from a directory. On macOS librexx names librexxapi through
    // @rpath, and ooRexx's rpath is @executable_path/../lib: right for rexx,
    // not for a .NET host (dotnet's own directory). librexxapi loaded first,
    // from the same directory, is the one dyld then uses (it matches loaded
    // images by install name). Linux's rpath is $ORIGIN-relative: no need.
    static bool TryLoadRexx(string dir, string file, out IntPtr handle)
    {
        handle = IntPtr.Zero;
        var full = Path.Combine(dir, file);
        if (!File.Exists(full)) return false;
        if (OperatingSystem.IsMacOS())
        {
            var api = Path.Combine(dir, "librexxapi.dylib");
            if (File.Exists(api)) NativeLibrary.TryLoad(api, out _);
        }
        return NativeLibrary.TryLoad(full, out handle);
    }

    [DllImport("rexx")]
    public static extern int RexxCreateInterpreter(out nint instance, out nint context, RexxOptionData* options);

    // RexxSetHalt(process_id_t, thread_id_t), the classic API: halts the Rexx
    // code running on one thread, from any thread (it takes only the
    // interpreter's resource lock; the thread API's HaltThread must run on
    // the halted thread itself). thread_id_t is a pthread_t on Unix, a DWORD
    // (GetCurrentThreadId) on Windows.
    [DllImport("rexx", EntryPoint = "RexxSetHalt")]
    static extern int SetHaltUnix(int process, nuint thread);
    [DllImport("rexx", EntryPoint = "RexxSetHalt")]
    static extern int SetHaltWindows(uint process, uint thread);
    [DllImport("libc", EntryPoint = "pthread_self")]
    static extern nuint PthreadSelf();
    [DllImport("kernel32", EntryPoint = "GetCurrentThreadId")]
    static extern uint WindowsThreadId();

    /// This OS thread, as ooRexx identifies threads.
    public static nuint CurrentThread() => OperatingSystem.IsWindows() ? WindowsThreadId() : PthreadSelf();

    /// Halts the Rexx code on that thread (0 if it was running Rexx code).
    public static int SetHalt(nuint thread) =>
        OperatingSystem.IsWindows() ? SetHaltWindows(0, (uint)thread) : SetHaltUnix(0, thread);

    public static byte[] Z(string s) => Encoding.UTF8.GetBytes(s + "\0");
}

/// A RexxInstance: { RexxInstanceInterface *functions; void *applicationData; }.
internal readonly unsafe struct Inst
{
    public readonly nint P;
    public Inst(nint p) { P = p; }
    nint F(int slot) => ((nint*)((nint*)P)[0])[slot];
    public long Version => (long)((nint*)((nint*)P)[0])[InstanceInterface.interfaceVersion];

    public nint Attach()
    {
        nint tc;
        return ((delegate* unmanaged<nint, nint*, nuint>)F(InstanceInterface.AttachThread))(P, &tc) != 0 ? tc : 0;
    }
    public long InterpreterVersion => (long)((delegate* unmanaged<nint, nuint>)F(InstanceInterface.InterpreterVersion))(P);
    public long LanguageLevel => (long)((delegate* unmanaged<nint, nuint>)F(InstanceInterface.LanguageLevel))(P);
    public void Halt() => ((delegate* unmanaged<nint, void>)F(InstanceInterface.Halt))(P);
    public void SetTrace(bool on) => ((delegate* unmanaged<nint, nuint, void>)F(InstanceInterface.SetTrace))(P, on ? 1u : 0u);
    public void Terminate() => ((delegate* unmanaged<nint, void>)F(InstanceInterface.Terminate))(P);

    /// Registers a command handler (DIRECT_COMMAND_ENVIRONMENT 1, or
    /// REDIRECTING_COMMAND_ENVIRONMENT 2: ADDRESS ... WITH).
    public void AddCommandEnvironment(string name, nint handler, int type)
    {
        var n = Native.Z(name);
        fixed (byte* pn = n) ((delegate* unmanaged<nint, byte*, nint, int, void>)F(InstanceInterface.AddCommandEnvironment))(P, pn, handler, type);
    }
}

/// A RexxExitContext (exits and command handlers): { RexxThreadContext
/// *threadContext; ExitContextInterface *functions; ValueDescriptor
/// *arguments; }. Its variables are those of the Rexx code that issued the
/// command.
internal readonly unsafe struct ExitCtx
{
    public readonly nint P;
    public ExitCtx(nint p) { P = p; }
    nint F(int slot) => ((nint*)((nint*)P)[1])[slot];
    public Ctx Thread => new Ctx(((nint*)P)[0]);

    public nint GetVariable(string name)
    {
        var n = Native.Z(name);
        fixed (byte* pn = n) return ((delegate* unmanaged<nint, byte*, nint>)F(ExitContextInterface.GetContextVariable))(P, pn);
    }
    public void SetVariable(string name, nint value)
    {
        var n = Native.Z(name);
        fixed (byte* pn = n) ((delegate* unmanaged<nint, byte*, nint, void>)F(ExitContextInterface.SetContextVariable))(P, pn, value);
    }
    public void DropVariable(string name)
    {
        var n = Native.Z(name);
        fixed (byte* pn = n) ((delegate* unmanaged<nint, byte*, void>)F(ExitContextInterface.DropContextVariable))(P, pn);
    }
    public nint AllVariables() => ((delegate* unmanaged<nint, nint>)F(ExitContextInterface.GetAllContextVariables))(P);

    // (Not ThrowCondition / ThrowException: the exit context's versions
    // unwind with a C++ throw back to the interpreter, which cannot cross
    // managed frames: the process aborts. The thread context's
    // RaiseCondition / RaiseException record the condition and return; the
    // interpreter raises it when the handler returns.)
}

/// A RexxIORedirectorContext (ADDRESS ... WITH): { IORedirectorInterface
/// *functions; }.
internal readonly unsafe struct Redirector
{
    public readonly nint P;
    public Redirector(nint p) { P = p; }
    nint F(int slot) => ((nint*)((nint*)P)[0])[slot];
    bool Test(int slot) => P != 0 && ((delegate* unmanaged<nint, nuint>)F(slot))(P) != 0;

    public bool Requested => Test(IORedirectorInterface.IsRedirectionRequested);
    public bool InputRedirected => Test(IORedirectorInterface.IsInputRedirected);
    public bool OutputRedirected => Test(IORedirectorInterface.IsOutputRedirected);
    public bool ErrorRedirected => Test(IORedirectorInterface.IsErrorRedirected);

    /// A line (ReadInput) or everything (ReadInputBuffer); null at the end.
    public string? Read(bool all)
    {
        byte* data = null; nuint length = 0;
        ((delegate* unmanaged<nint, byte**, nuint*, void>)F(all ? IORedirectorInterface.ReadInputBuffer : IORedirectorInterface.ReadInput))(P, &data, &length);
        return data == null ? null : Encoding.UTF8.GetString(data, (int)length);
    }

    /// A line (WriteOutput / WriteError), or text split into lines at its
    /// line ends (WriteOutputBuffer / WriteErrorBuffer).
    public void Write(bool error, bool buffer, string text)
    {
        int slot = error ? (buffer ? IORedirectorInterface.WriteErrorBuffer : IORedirectorInterface.WriteError)
                         : (buffer ? IORedirectorInterface.WriteOutputBuffer : IORedirectorInterface.WriteOutput);
        var b = Native.Z(text);                             // never a null pointer, even for ""
        fixed (byte* p = b) ((delegate* unmanaged<nint, byte*, nuint, void>)F(slot))(P, p, (nuint)(b.Length - 1));
    }
}

/// A RexxThreadContext: { RexxInstance *instance; RexxThreadInterface *functions; }.
internal readonly unsafe struct Ctx
{
    public readonly nint P;
    public Ctx(nint p) { P = p; }
    nint F(int slot) => ((nint*)((nint*)P)[1])[slot];
    public long Version => (long)((nint*)((nint*)P)[1])[ThreadInterface.interfaceVersion];
    public nint Instance => ((nint*)P)[0];

    public void Detach() => ((delegate* unmanaged<nint, void>)F(ThreadInterface.DetachThread))(P);
    public nint Global(nint o) => ((delegate* unmanaged<nint, nint, nint>)F(ThreadInterface.RequestGlobalReference))(P, o);
    public void ReleaseGlobal(nint o) => ((delegate* unmanaged<nint, nint, void>)F(ThreadInterface.ReleaseGlobalReference))(P, o);
    public void ReleaseLocal(nint o) => ((delegate* unmanaged<nint, nint, void>)F(ThreadInterface.ReleaseLocalReference))(P, o);
    public nint Nil => F(ThreadInterface.RexxNil);
    public nint True => F(ThreadInterface.RexxTrue);
    public nint False => F(ThreadInterface.RexxFalse);

    public nint Str(string s)
    {
        var b = Encoding.UTF8.GetBytes(s);
        fixed (byte* p = b) return ((delegate* unmanaged<nint, byte*, nuint, nint>)F(ThreadInterface.NewString))(P, p, (nuint)b.Length);
    }

    /// o's string value (o~string, or its own value for a String).
    /// ObjectToString's result is a new local reference, even when it is o
    /// itself (a String): released here, or the creating thread's context
    /// leaks and every later release gets slower (measured: a call that
    /// returns its String argument went from 2 to 800 µs in 100 000 calls).
    public string ToStr(nint o)
    {
        nint s = ((delegate* unmanaged<nint, nint, nint>)F(ThreadInterface.ObjectToString))(P, o);
        var v = StrValue(s);
        ReleaseLocal(s);
        return v;
    }

    public string StrValue(nint s)
    {
        var len = ((delegate* unmanaged<nint, nint, nuint>)F(ThreadInterface.StringLength))(P, s);
        var data = ((delegate* unmanaged<nint, nint, byte*>)F(ThreadInterface.StringData))(P, s);
        return Encoding.UTF8.GetString(data, (int)len);
    }

    public nint NewArray(int size) => ((delegate* unmanaged<nint, nuint, nint>)F(ThreadInterface.NewArray))(P, (nuint)size);
    public void ArrayPut(nint a, nint v, int index) => ((delegate* unmanaged<nint, nint, nint, nuint, void>)F(ThreadInterface.ArrayPut))(P, a, v, (nuint)index);
    public nint ArrayAt(nint a, int index) => ((delegate* unmanaged<nint, nint, nuint, nint>)F(ThreadInterface.ArrayAt))(P, a, (nuint)index);
    public int ArraySize(nint a) => (int)((delegate* unmanaged<nint, nint, nuint>)F(ThreadInterface.ArraySize))(P, a);

    public nint Send(nint o, string msg, nint args)
    {
        var n = Native.Z(msg);
        fixed (byte* pn = n) return ((delegate* unmanaged<nint, nint, byte*, nint, nint>)F(ThreadInterface.SendMessage))(P, o, pn, args);
    }

    public nint NewRoutine(string name, string source)
    {
        var n = Native.Z(name); var s = Encoding.UTF8.GetBytes(source);
        fixed (byte* pn = n) fixed (byte* ps = s)
            return ((delegate* unmanaged<nint, byte*, byte*, nuint, nint>)F(ThreadInterface.NewRoutine))(P, pn, ps, (nuint)s.Length);
    }

    public nint CallRoutine(nint routine, nint args) =>
        ((delegate* unmanaged<nint, nint, nint, nint>)F(ThreadInterface.CallRoutine))(P, routine, args);

    public nint CallProgram(string path, nint args)
    {
        var n = Native.Z(path);
        fixed (byte* pn = n) return ((delegate* unmanaged<nint, byte*, nint, nint>)F(ThreadInterface.CallProgram))(P, pn, args);
    }

    public nint LoadPackage(string path)
    {
        var n = Native.Z(path);
        fixed (byte* pn = n) return ((delegate* unmanaged<nint, byte*, nint>)F(ThreadInterface.LoadPackage))(P, pn);
    }

    public nint LoadPackageFromData(string name, string source)
    {
        var n = Native.Z(name); var s = Encoding.UTF8.GetBytes(source);
        fixed (byte* pn = n) fixed (byte* ps = s)
            return ((delegate* unmanaged<nint, byte*, byte*, nuint, nint>)F(ThreadInterface.LoadPackageFromData))(P, pn, ps, (nuint)s.Length);
    }

    public bool RegisterLibrary(string name, nint packageEntry)
    {
        var n = Native.Z(name);
        fixed (byte* pn = n) return ((delegate* unmanaged<nint, byte*, nint, nint>)F(ThreadInterface.RegisterLibrary))(P, pn, packageEntry) != 0;
    }

    public nint FindClass(string name)
    {
        var n = Native.Z(name);
        fixed (byte* pn = n) return ((delegate* unmanaged<nint, byte*, nint>)F(ThreadInterface.FindClass))(P, pn);
    }

    public nint FindPackageClass(nint package, string name)
    {
        var n = Native.Z(name);
        fixed (byte* pn = n) return ((delegate* unmanaged<nint, nint, byte*, nint>)F(ThreadInterface.FindPackageClass))(P, package, pn);
    }

    public nint PackageDirectory(int slot, nint package) => ((delegate* unmanaged<nint, nint, nint>)F(slot))(P, package);
    public nint LocalEnvironment => ((delegate* unmanaged<nint, nint>)F(ThreadInterface.GetLocalEnvironment))(P);
    public nint GlobalEnvironment => ((delegate* unmanaged<nint, nint>)F(ThreadInterface.GetGlobalEnvironment))(P);

    public bool IsString(nint o) => ((delegate* unmanaged<nint, nint, nuint>)F(ThreadInterface.IsString))(P, o) != 0;
    public bool IsRoutine(nint o) => ((delegate* unmanaged<nint, nint, nuint>)F(ThreadInterface.IsRoutine))(P, o) != 0;
    public bool IsInstanceOf(nint o, nint cls) => ((delegate* unmanaged<nint, nint, nint, nuint>)F(ThreadInterface.IsInstanceOf))(P, o, cls) != 0;
    public bool IsOfType(nint o, string cls)
    {
        var n = Native.Z(cls);
        fixed (byte* pn = n) return ((delegate* unmanaged<nint, nint, byte*, nuint>)F(ThreadInterface.IsOfType))(P, o, pn) != 0;
    }
    public bool HasMethod(nint o, string name)
    {
        var n = Native.Z(name);
        fixed (byte* pn = n) return ((delegate* unmanaged<nint, nint, byte*, nuint>)F(ThreadInterface.HasMethod))(P, o, pn) != 0;
    }

    public nint SupplierItem(nint s) => ((delegate* unmanaged<nint, nint, nint>)F(ThreadInterface.SupplierItem))(P, s);
    public nint SupplierIndex(nint s) => ((delegate* unmanaged<nint, nint, nint>)F(ThreadInterface.SupplierIndex))(P, s);
    public bool SupplierAvailable(nint s) => ((delegate* unmanaged<nint, nint, nuint>)F(ThreadInterface.SupplierAvailable))(P, s) != 0;
    public void SupplierNext(nint s) => ((delegate* unmanaged<nint, nint, void>)F(ThreadInterface.SupplierNext))(P, s);

    public nint DirectoryAt(nint d, string index)
    {
        var n = Native.Z(index);
        fixed (byte* pn = n) return ((delegate* unmanaged<nint, nint, byte*, nint>)F(ThreadInterface.DirectoryAt))(P, d, pn);
    }

    public void HaltThread() => ((delegate* unmanaged<nint, void>)F(ThreadInterface.HaltThread))(P);
    public bool CheckCondition() => ((delegate* unmanaged<nint, nuint>)F(ThreadInterface.CheckCondition))(P) != 0;
    public nint ConditionInfo() => ((delegate* unmanaged<nint, nint>)F(ThreadInterface.GetConditionInfo))(P);
    public void Decode(nint info, RexxConditionData* c) =>
        ((delegate* unmanaged<nint, nint, RexxConditionData*, void>)F(ThreadInterface.DecodeConditionInfo))(P, info, c);
    public void ClearCondition() => ((delegate* unmanaged<nint, void>)F(ThreadInterface.ClearCondition))(P);

    /// Raises a condition (ERROR, FAILURE...) in the Rexx code that called
    /// native code (a command handler): recorded, raised when it returns.
    /// Its description, additional object and result (RC for a command).
    public void RaiseCondition(string name, nint description, nint additional, nint result)
    {
        var n = Native.Z(name);
        fixed (byte* pn = n)
            ((delegate* unmanaged<nint, byte*, nint, nint, nint, void>)F(ThreadInterface.RaiseCondition))(P, pn, description, additional, result);
    }

    /// Raises a SYNTAX error (code: major * 1000 + minor; its substitutions), the same way.
    public void RaiseException(long code, nint additional) =>
        ((delegate* unmanaged<nint, nuint, nint, void>)F(ThreadInterface.RaiseException))(P, (nuint)code, additional);
}
