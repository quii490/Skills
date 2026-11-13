#!/usr/bin/env python3
"""Adapt a shared pipeline skill to the current maintainer code.

Commands:
  refresh   capture code hashes + live --help + capability flags; update snapshot
  check     compare current code/flags with the snapshot; exit 1 on drift
  flags     print the flags captured for each entrypoint
  plan      build a command for a logical action using current flag names
  run       plan + execute on the pod (short commands / dry-runs)

The spec lives at references/adapt_spec.json. Role aliases make `plan`
survive flag renames; the agent can always use `--extra` for new flags.
"""
from __future__ import annotations

import argparse
import contextlib
import io
import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
SPEC = SKILL_DIR / "references/adapt_spec.json"
SNAP = SKILL_DIR / "references/code_snapshot.json"
GEN = SKILL_DIR / "references/generated"


def die(msg: str, code: int = 2):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def load_config() -> dict:
    cfg = Path(os.environ.get("LAB_CONFIG", Path.home() / ".config/med-lab/config.env"))
    if not cfg.exists():
        die(f"lab config not found: {cfg}")
    env = {}
    for line in cfg.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    user = env.get("LAB_CLUSTER_USER")
    if not user:
        die("LAB_CLUSTER_USER missing in config")
    env.setdefault("LAB_NAMESPACE", f"zhaoslab-{user}")
    env.setdefault("LAB_MAINTAINER", "machicheng")
    root = env.setdefault("LAB_CODE_ROOT", f"/home/{env['LAB_MAINTAINER']}")
    env.setdefault("LAB_CODE_RNA", f"{root}/RNA-seq/Pipeline/rnaseq")
    env.setdefault("LAB_CODE_CUT", f"{root}/CUTnRUN")
    env.setdefault("LAB_CODE_ATAC", f"{root}/ATAC-seq/pipeline_final")
    env.setdefault("LAB_KUBECTL", "kubectl")
    return env


def load_spec() -> dict:
    if not SPEC.exists():
        die(f"adapt spec missing: {SPEC}")
    return json.loads(SPEC.read_text())


def pod(cfg: dict) -> str:
    if cfg.get("LAB_POD"):
        return cfg["LAB_POD"]
    for _ in range(3):
        p = subprocess.run(
            [cfg["LAB_KUBECTL"], "get", "pods", "-n", cfg["LAB_NAMESPACE"],
             "--request-timeout=15s", "-o",
             'jsonpath={range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\\n"}{end}'],
            capture_output=True, text=True)
        name = (p.stdout or "").strip().splitlines()
        if name:
            return name[0]
    die(f"no Running pod in {cfg['LAB_NAMESPACE']}")


def remote(cfg: dict, cmd: str, check: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(
        [cfg["LAB_KUBECTL"], "exec", pod(cfg), "-n", cfg["LAB_NAMESPACE"],
         "--request-timeout=120s", "--",
         "su", "-", cfg["LAB_CLUSTER_USER"], "-c", cmd],
        capture_output=True, text=True, check=check)


def code_root(cfg: dict, spec: dict) -> str:
    var = spec.get("code_var", "LAB_CODE_RNA")
    return cfg.get(var) or die(f"{var} missing in config")


def remote_capture(cfg: dict, code: str, cmd: str) -> str:
    p = remote(cfg, f"cd {shlex.quote(code)} && {cmd}")
    return (p.stdout or "") + (p.stderr or "")


def parse_flags(text: str) -> list[str]:
    return sorted(set(re.findall(r"--[A-Za-z0-9][A-Za-z0-9-]*", text)))


def hashes(cfg: dict, spec: dict, code: str) -> tuple[str, dict[str, str]]:
    files = spec.get("files", [])
    q = " ".join(shlex.quote(f) for f in files)
    p = remote(cfg, f"cd {shlex.quote(code)} && {{ git rev-parse HEAD 2>/dev/null || echo none; }} && sha256sum {q}")
    if p.returncode != 0:
        die(f"cannot read {code}: {(p.stderr or p.stdout).strip()[:300]}")
    lines = (p.stdout or "").splitlines()
    head = lines[0].strip() if lines else "none"
    out = {}
    for line in lines[1:]:
        parts = line.split()
        if len(parts) == 2:
            out[parts[1]] = parts[0]
    return head, out


def do_refresh(cfg: dict, spec: dict) -> None:
    code = code_root(cfg, spec)
    GEN.mkdir(parents=True, exist_ok=True)
    old_caps = {}
    if SNAP.exists():
        try:
            old_caps = json.loads(SNAP.read_text()).get("capabilities", {})
        except Exception:
            pass
    head, hs = hashes(cfg, spec, code)
    caps, help_all = {}, []
    for name, cmd in spec.get("entrypoints", {}).items():
        text = remote_capture(cfg, code, cmd + " --help")
        (GEN / f"help_{name}.txt").write_text(text)
        help_all.append(f"===== {name} =====\n{text}\n")
        caps[name] = parse_flags(text)
    (GEN / "help.txt").write_text("".join(help_all))
    all_flags = sorted({f for v in caps.values() for f in v})
    (GEN / "params.txt").write_text("\n".join(all_flags) + "\n")
    # diffs
    old_all = sorted({f for v in old_caps.values() for f in v}) if old_caps else []
    (GEN / "params_added.txt").write_text("\n".join(sorted(set(all_flags) - set(old_all))) + "\n")
    (GEN / "params_removed.txt").write_text("\n".join(sorted(set(old_all) - set(all_flags))) + "\n")
    obj = {
        "pipeline": spec.get("pipeline", SKILL_DIR.name),
        "code_root": code,
        "git_head": head,
        "captured_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "files": hs,
        "capabilities": caps,
    }
    SNAP.write_text(json.dumps(obj, indent=2, sort_keys=True) + "\n")
    print(f"refreshed {obj['pipeline']} -> {SNAP}")
    print(f"flags: {len(all_flags)}; help: {GEN/'help.txt'}")
    added = [x for x in (GEN / "params_added.txt").read_text().splitlines() if x]
    removed = [x for x in (GEN / "params_removed.txt").read_text().splitlines() if x]
    if added:
        print("new flags: " + " ".join(added))
    if removed:
        print("removed flags: " + " ".join(removed))


def cmd_refresh(args: argparse.Namespace) -> None:
    do_refresh(load_config(), load_spec())


def ensure_fresh(cfg: dict, spec: dict) -> None:
    """Auto-refresh capabilities if the maintainer code changed."""
    if not SNAP.exists():
        print("[adapt] no snapshot; refreshing capabilities", file=sys.stderr)
        do_refresh(cfg, spec)
        return
    try:
        with contextlib.redirect_stderr(io.StringIO()):
            head, hs = hashes(cfg, spec, code_root(cfg, spec))
    except SystemExit:
        print("[adapt] WARN: cannot check code drift; using cached capabilities", file=sys.stderr)
        return
    snap = json.loads(SNAP.read_text())
    changed = head != snap.get("git_head") or any(
        hs.get(f) != h for f, h in snap.get("files", {}).items()
    )
    if changed:
        print("[adapt] pipeline code changed; refreshing capabilities", file=sys.stderr)
        do_refresh(cfg, spec)


def current_caps(cfg: dict, spec: dict, code: str) -> dict[str, list[str]]:
    out = {}
    for name, cmd in spec.get("entrypoints", {}).items():
        out[name] = parse_flags(remote_capture(cfg, code, cmd + " --help"))
    return out


def cmd_check(args: argparse.Namespace) -> None:
    cfg, spec = load_config(), load_spec()
    if not SNAP.exists():
        die("no snapshot; run: pipeline_adapt.py refresh")
    snap = json.loads(SNAP.read_text())
    code = code_root(cfg, spec)
    head, hs = hashes(cfg, spec, code)
    drift = []
    if head != snap.get("git_head"):
        drift.append(f"git_head {snap.get('git_head')} -> {head}")
    for f, h in snap.get("files", {}).items():
        if hs.get(f) != h:
            drift.append(f"file {f}")
    if getattr(args, "deep", False):
        caps = current_caps(cfg, spec, code)
        old = snap.get("capabilities", {})
        for name in sorted(set(caps) | set(old)):
            added = sorted(set(caps.get(name, [])) - set(old.get(name, [])))
            removed = sorted(set(old.get(name, [])) - set(caps.get(name, [])))
            if added:
                drift.append(f"{name} new flags: {' '.join(added)}")
            if removed:
                drift.append(f"{name} removed flags: {' '.join(removed)}")
    if not drift:
        print(f"OK: matches snapshot ({spec.get('pipeline')} @ {head})")
        return
    for d in drift:
        print("DRIFT " + d)
    print("run: pipeline_adapt.py refresh, then review references/generated/help.txt")
    sys.exit(1)


def cmd_flags(args: argparse.Namespace) -> None:
    snap = json.loads(SNAP.read_text()) if SNAP.exists() else {}
    caps = snap.get("capabilities", {})
    for name, flags in caps.items():
        print(f"== {name}")
        for f in flags:
            print(f)


def resolve(caps: dict, entry: str, role: str, aliases: list[str]) -> str:
    have = set(caps.get(entry, []))
    for a in aliases:
        if a in have:
            return a
    die(f"role '{role}' not found in {entry}; tried {aliases}. "
        f"Current flags: {' '.join(sorted(have))}")


def build_command(cfg: dict, spec: dict, snap: dict, action: str, pairs: dict[str, str], extra: str) -> str:
    actions = spec.get("actions", {})
    if action not in actions:
        die(f"unknown action '{action}'; choose from {', '.join(actions)}")
    a = actions[action]
    entry = a["entry"]
    caps = snap.get("capabilities", {})
    roles = spec.get("roles", {})
    bools = set(spec.get("booleans", []))
    for r in a.get("force", []):
        pairs.setdefault(r, "1")
    allowed = set(a.get("required", [])) | set(a.get("optional", [])) | set(a.get("force", []))
    for r in pairs:
        if r not in allowed:
            die(f"--{r.replace('_','-')} is not valid for action '{action}'; allowed: {', '.join(sorted(allowed))}")
    for r in a.get("required", []):
        if r not in pairs:
            die(f"missing --{r.replace('_','-')} (required for {action})")
    flags = []
    for role, aliases in roles.items():
        if role not in pairs:
            continue
        flag = resolve(caps, entry, role, aliases)
        if role in bools:
            flags.append(flag)
        else:
            flags.extend([flag, shlex.quote(str(pairs[role]))])
    if extra:
        flags.append(extra)
    base = spec["entrypoints"][entry]
    return f"cd {shlex.quote(code_root(cfg, spec))} && {base} " + " ".join(flags)


def parse_pairs(argv: list[str], spec: dict) -> tuple[dict[str, str], str]:
    bools = set(spec.get("booleans", []))
    roles = set(spec.get("roles", {}))
    pairs, extra, i = {}, "", 0
    while i < len(argv):
        k = argv[i]
        if not k.startswith("--"):
            die(f"unexpected argument: {k}")
        key = k[2:].replace("-", "_")
        if key == "extra":
            i += 1
            extra = argv[i] if i < len(argv) else ""
        elif key in bools:
            pairs[key] = "1"
        elif key in roles:
            i += 1
            if i >= len(argv):
                die(f"--{k} needs a value")
            pairs[key] = argv[i]
        else:
            die(f"unknown option {k}; roles: {', '.join(sorted(roles))}; or use --extra")
        i += 1
    return pairs, extra


def cmd_plan(args: argparse.Namespace) -> None:
    cfg, spec = load_config(), load_spec()
    ensure_fresh(cfg, spec)
    snap = json.loads(SNAP.read_text()) if SNAP.exists() else die("no snapshot; run refresh")
    pairs, extra = parse_pairs(args.rest, spec)
    print(build_command(cfg, spec, snap, args.action, pairs, extra))


def cmd_run(args: argparse.Namespace) -> None:
    cfg, spec = load_config(), load_spec()
    ensure_fresh(cfg, spec)
    snap = json.loads(SNAP.read_text()) if SNAP.exists() else die("no snapshot; run refresh")
    pairs, extra = parse_pairs(args.rest, spec)
    cmd = build_command(cfg, spec, snap, args.action, pairs, extra)
    print(f"[adapt] {cmd}", file=sys.stderr)
    p = remote(cfg, cmd)
    sys.stdout.write(p.stdout or "")
    sys.stderr.write(p.stderr or "")
    sys.exit(p.returncode)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("refresh")
    chk = sub.add_parser("check")
    chk.add_argument("--deep", action="store_true", help="also re-read --help and compare flags")
    sub.add_parser("flags")
    for name in ("plan", "run"):
        p = sub.add_parser(name)
        p.add_argument("action")
        p.add_argument("rest", nargs=argparse.REMAINDER)
    args = ap.parse_args()
    {"refresh": cmd_refresh, "check": cmd_check, "flags": cmd_flags,
     "plan": cmd_plan, "run": cmd_run}[args.cmd](args)


if __name__ == "__main__":
    main()
