#!/usr/bin/env python3
"""Check the retained office geometry and exercise the actual map scene."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--rendered", action="store_true")
    parser.add_argument("--captures", type=Path, default=ROOT / "map-results")
    args = parser.parse_args()
    directory = args.captures.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    logs = []

    def run(command, timeout=240):
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=timeout)
        logs.append(result.stdout)
        (directory / "smoke.log").write_text("\n".join(logs), encoding="utf-8")
        print(result.stdout, end="")
        if result.returncode or re.search(r"(SCRIPT ERROR|Parse Error|SHADER ERROR|^ERROR:)", result.stdout, re.M):
            raise RuntimeError(f"Map check failed: {command[0]}")
        return result.stdout

    version = run([args.godot, "--version"])
    if not version.strip().startswith("4.7.2.stable"):
        raise RuntimeError("Use Godot 4.7.2 stable.")
    run(["node", "scripts/godot-asset-test.mjs"])
    run([args.godot, "--headless", "--path", str(ROOT / "godot"), "--editor", "--import"])
    command = [args.godot, "--path", str(ROOT / "godot"), "--rendering-method", "gl_compatibility",
               "--audio-driver", "Dummy", "--resolution", "960x540"]
    if not args.rendered:
        command.append("--headless")
    command += ["--script", "res://tests/map_smoke.gd", "--", "--capture-dir", str(directory)]
    if args.rendered:
        command.append("--rendered")
    output = run(command, timeout=360)
    reports = [json.loads(line.split("MAP_SMOKE ", 1)[1]) for line in output.splitlines() if line.startswith("MAP_SMOKE ")]
    if len(reports) != 1 or reports[0].get("passed") is not True:
        raise RuntimeError("The map smoke test did not finish successfully.")
    (directory / "smoke.json").write_text(json.dumps(reports[0], indent=2), encoding="utf-8")
    print("Office map checks passed.")

if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
