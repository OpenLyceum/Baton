#!/usr/bin/env python3
"""Read-only Knip inventory: no installs, fixes, commits, or finding suppression."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def capture(command, cwd, timeout=120):
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=timeout, check=False)
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired as error:
        def text(value):
            return value.decode(errors="replace") if isinstance(value, bytes) else value or ""
        return None, text(error.stdout), text(error.stderr) + f"\n{error}"
    except OSError as error:
        return None, "", str(error)


def summarize(stdout):
    """Knip 6 emits {issues: [...]} with unused files inside each issue row."""
    try:
        report = json.loads(stdout)
    except (ValueError, TypeError):
        return None
    if not isinstance(report, dict) or not isinstance(report.get("issues"), list):
        return None
    counts = {}
    for issue in report["issues"]:
        if not isinstance(issue, dict):
            return None
        for key, values in issue.items():
            if key != "owners" and isinstance(values, list):
                counts[key] = counts.get(key, 0) + len(values)
    return {key: count for key, count in counts.items() if count}


def inventory(name, workspace, output, node):
    cwd = workspace / name
    destination = output / name
    destination.mkdir()
    result = {"repo": name, "modes": {}}
    config = cwd / "knip.json"
    binary = cwd / "node_modules/knip/bin/knip.js"
    if not config.is_file() or not binary.is_file():
        result.update(status="unavailable", reason="Missing checkout/config or installed Knip; run npm ci in this repo")
    else:
        result["head"] = capture(["git", "rev-parse", "HEAD"], cwd)[1].strip()
        result["dirty"] = capture(["git", "status", "--porcelain"], cwd)[1].strip()
        for key, path in [("configSha256", config), ("lockSha256", cwd / "package-lock.json")]:
            result[key] = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
        result["knipVersion"] = json.loads((cwd / "node_modules/knip/package.json").read_text())["version"]
        for mode in ["default", "production"]:
            args = ["--production"] if mode == "production" else []
            command = [node, str(binary), *args, "--reporter", "json"]
            code, stdout, stderr = capture(command, cwd)
            (destination / f"{mode}.json").write_text(stdout)
            (destination / f"{mode}.stderr").write_text(stderr)
            counts = summarize(stdout)
            result["modes"][mode] = {"exitCode": code, "validReport": counts is not None, "counts": counts}
        modes = list(result["modes"].values())
        if any(not mode["validReport"] or mode["exitCode"] not in [0, 1] for mode in modes):
            result["status"] = "error"
        elif all(mode["exitCode"] == 0 and not any(mode["counts"].values()) for mode in modes):
            result["status"] = "clean"
        else:
            result["status"] = "findings"
    write_json(destination / "metadata.json", result)
    print(f"{name}: {result['status']}", flush=True)
    return result


def main():
    baton = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=baton.parent)
    parser.add_argument("--output", type=Path, required=True, help="New output directory; existing paths are rejected")
    parser.add_argument("--only", help="One catalog repository (default: simulations plus template)")
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--node", default="node", help="Path to the fleet Node 26 binary")
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    code, version, error = capture([args.node, "--version"], baton)
    if code != 0 or not version.startswith("v26."):
        parser.error(f"Use the fleet Node 26 runtime: {version or error}")
    catalog = json.loads((baton / "structure/repos.json").read_text())
    names = [repo["name"] for repo in catalog["repos"]
             if repo.get("isSimulation") or repo["name"] == "SceneryStackTemplate"]
    if args.only:
        names = [name for name in names if name == args.only]
    if not names:
        parser.error("No catalog repositories matched")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    started = datetime.now(timezone.utc).isoformat()
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(lambda name: inventory(name, args.workspace.resolve(), output, args.node), names))
    write_json(output / "summary.json", {
        "startedAt": started, "finishedAt": datetime.now(timezone.utc).isoformat(),
        "node": version.strip(), "results": sorted(results, key=lambda result: result["repo"]),
    })
    print(f"Reports: {output}")
    return 2 if any(result["status"] in ["error", "unavailable"] for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
