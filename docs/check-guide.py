#!/usr/bin/env python3
"""Runs the examples of docs/guide.md and compares their output.

    docs/check-guide.py [build-dir]

Every ```rexx block followed by a ```text block is a program and its output;
the same for the ```csharp block (built as a small console project against
the bridge's Rexx.Net.dll). build-dir: the bridge's build (default
$REXXNET_BUILD/rexxnet, as scripts/platform.sh; bridge/build.sh first).
DOTNET_ROOT: found as scripts/platform.sh does when not set.
"""
import os, re, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
def default_build():   # as scripts/platform.sh
    if os.environ.get("REXXNET_BUILD"): return os.environ["REXXNET_BUILD"]
    if os.path.isdir("/home/claude") and os.access("/home/claude", os.W_OK): return "/home/claude/build"
    return os.path.expanduser("~/build")

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(default_build(), "rexxnet")
if sys.platform == "win32":   # rexxnet.dll: found through the PATH
    LIBVAR, LIBPATH = "PATH", OUT + os.pathsep + os.environ.get("PATH", "")
else:
    LIBVAR, LIBPATH = ("DYLD_LIBRARY_PATH" if sys.platform == "darwin" else "LD_LIBRARY_PATH"), OUT
guide = open(os.path.join(HERE, "guide.md"), encoding="utf-8").read()
blocks = re.findall(r"```(\w+)\n(.*?)```", guide, re.S)
pairs = [(blocks[i][0], blocks[i][1], blocks[i + 1][1]) for i in range(len(blocks) - 1)
         if blocks[i][0] in ("rexx", "csharp") and blocks[i + 1][0] == "text"]

env = dict(os.environ, **{LIBVAR: LIBPATH}, REXX_PATH=OUT, REXXNET_DIR=OUT,
           DOTNET_CLI_TELEMETRY_OPTOUT="1", DOTNET_NOLOGO="1")
def default_dotnet():   # as scripts/platform.sh
    for d in ("/home/claude/dotnet", os.path.expanduser("~/.dotnet")):
        if os.access(os.path.join(d, "dotnet"), os.X_OK): return d
    found = shutil.which("dotnet")
    if found: return os.path.dirname(os.path.realpath(found))
    return "/usr/local/share/dotnet" if sys.platform == "darwin" else "/usr/share/dotnet"

env.setdefault("DOTNET_ROOT", default_dotnet())
dotnet = os.path.join(env["DOTNET_ROOT"], "dotnet")
fails = 0
with tempfile.TemporaryDirectory() as work:
    for n, (lang, code, want) in enumerate(pairs, 1):
        first = code.strip().splitlines()[0]
        if lang == "rexx":
            prog = os.path.join(work, f"ex{n}.rex")
            open(prog, "w").write(code)
            r = subprocess.run(["rexx", prog], cwd=OUT, env=env, capture_output=True, text=True, timeout=120)
        else:
            proj = os.path.join(work, f"cs{n}")
            os.makedirs(proj)
            open(os.path.join(proj, "Program.cs"), "w").write(code)
            open(os.path.join(proj, "Guide.csproj"), "w").write(
                '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType>'
                '<TargetFramework>net8.0</TargetFramework><RollForward>LatestMajor</RollForward>'
                '<Nullable>enable</Nullable><ImplicitUsings>disable</ImplicitUsings></PropertyGroup>'
                f'<ItemGroup><Reference Include="Rexx.Net"><HintPath>{OUT}/Rexx.Net.dll</HintPath></Reference>'
                '</ItemGroup></Project>')
            b = subprocess.run([dotnet, "build", proj, "-c", "Release", "-o", os.path.join(proj, "out"), "-nologo", "-v", "q"],
                               env=env, capture_output=True, text=True)
            if b.returncode != 0:
                fails += 1
                print(f"FAIL example {n} ({lang}: {first}): does not build\n{b.stdout[-2000:]}")
                continue
            r = subprocess.run([dotnet, os.path.join(proj, "out", "Guide.dll")], cwd=work, env=env,
                               capture_output=True, text=True, timeout=120)
        got = (r.stdout + r.stderr).rstrip("\n")
        if got == want.rstrip("\n"):
            print(f"ok   example {n} ({lang}: {first})")
        else:
            fails += 1
            print(f"FAIL example {n} ({lang}: {first})\n--- want\n{want.rstrip()}\n--- got\n{got}")
print(f"guide: all {len(pairs)} examples match" if fails == 0 else f"guide: {fails} of {len(pairs)} examples FAILED")
sys.exit(1 if fails else 0)
