#!/usr/bin/env python3
"""Poor-man's static check for GDScript when Godot isn't available.

* every `Autoload.member` / `ClassName.member` reference must exist in the target script
* every scene's script path must exist
* indentation must use tabs only, brackets must balance per file
It does NOT type-check or compile - open the project in Godot for that.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
scripts = {p: open(p).read() for p in glob.glob(os.path.join(ROOT, "scripts/**/*.gd"), recursive=True)}
scripts.update({p: open(p).read() for p in glob.glob(os.path.join(ROOT, "tests/*.gd"))})

# autoloads from project.godot
auto = {}
for m in re.finditer(r'^(\w+)="\*res://(.+?)"', open(os.path.join(ROOT, "project.godot")).read(), re.M):
    auto[m.group(1)] = os.path.join(ROOT, m.group(2))
classes = {}
for p, txt in scripts.items():
    m = re.search(r"^class_name (\w+)", txt, re.M)
    if m:
        classes[m.group(1)] = p
targets = {**{k: v for k, v in auto.items()}, **classes}

BUILTIN_OK = {"new", "call", "bind", "connect", "is_valid", "emit", "get", "set", "size", "keys", "has", "append", "is_empty",
              "free", "queue_free", "duplicate", "erase", "pop_back", "text", "name", "x", "y", "type", "ZERO", "ONE", "UP", "INF"}


def members(txt):
    out = set()
    for pat in (r"^\s*(?:static )?func (\w+)", r"^\s*(?:static )?var (\w+)", r"^\s*const (\w+)", r"^\s*signal (\w+)", r"^\s*enum (\w+)",
                r"^\s*class (\w+)"):
        out.update(re.findall(pat, txt, re.M))
    for m in re.finditer(r"^\s*enum \w*\s*\{([^}]*)\}", txt, re.M):
        out.update(w.strip().split("=")[0].strip() for w in m.group(1).split(","))
    return out


mem = {name: members(open(path).read()) for name, path in targets.items() if os.path.exists(path)}
problems = []
for path, txt in scripts.items():
    rel = os.path.relpath(path, ROOT)
    # tabs / brackets
    for i, line in enumerate(txt.split("\n"), 1):
        if re.match(r"^ +\S", line) and not line.lstrip().startswith("#"):
            problems.append(f"{rel}:{i}: space indentation")
    stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', txt)
    stripped = re.sub(r"#.*", "", stripped)
    for a, b in ("()", "[]", "{}"):
        if stripped.count(a) != stripped.count(b):
            problems.append(f"{rel}: unbalanced {a}{b} ({stripped.count(a)} vs {stripped.count(b)})")
    own = classes and os.path.splitext(os.path.basename(path))[0]
    for m in re.finditer(r"\b([A-Z]\w+)\.(\w+)", stripped):
        cls, member = m.groups()
        if cls in mem and member not in mem[cls] and member not in BUILTIN_OK:
            line = stripped[: m.start()].count("\n") + 1
            problems.append(f"{rel}:{line}: {cls}.{member} not found in {os.path.relpath(targets[cls], ROOT)}")

# scenes
for scn in glob.glob(os.path.join(ROOT, "scenes/**/*.tscn"), recursive=True):
    for m in re.finditer(r'path="res://(.+?)"', open(scn).read()):
        if not os.path.exists(os.path.join(ROOT, m.group(1))):
            problems.append(f"{os.path.relpath(scn, ROOT)}: missing {m.group(1)}")
# resources referenced from scripts
for path, txt in scripts.items():
    for m in re.finditer(r'"res://([\w/\.\-]+\.(?:png|wav|json|tscn|gd|ttf))"', txt):
        if not os.path.exists(os.path.join(ROOT, m.group(1))):
            problems.append(f"{os.path.relpath(path, ROOT)}: missing resource {m.group(1)}")
    for m in re.finditer(r'"res://([\w/\.\-]*%[\w/\.\-]*)"', txt):
        pass
print("\n".join(problems) if problems else "no reference problems found")
print(f"{len(scripts)} scripts, {len(auto)} autoloads, {len(classes)} class_names checked")
sys.exit(1 if problems else 0)
