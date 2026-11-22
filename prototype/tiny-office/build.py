#!/usr/bin/env python3
"""Build the Tiny Office test clients and headless server with Godot 4.7.2."""

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import zipfile

PROJECT = Path(__file__).resolve().parent
REPO = PROJECT.parent.parent
VERSION = "4.7.2.stable"
DISTRIBUTIONS = {
    "server": ("Linux Server", "tiny-office-server", ".tar.gz"),
    "linux": ("Linux Client", "tiny-office", ".tar.gz"),
    "windows": ("Windows Client", "TinyOffice.exe", ".zip"),
}


def godot(executable, *args, env=None):
    result = subprocess.run(
        [executable, *args],
        text=True, encoding="utf-8", errors="replace",
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        timeout=180, env=env,
    )
    print(result.stdout, end="", flush=True)
    if result.returncode or any(line.lstrip().startswith(("ERROR:", "SCRIPT ERROR:", "Parse Error:"))
                                for line in result.stdout.splitlines()):
        raise RuntimeError("Godot could not complete " + " ".join(str(arg) for arg in args))
    return result.stdout


def template_environment(templates, work):
    if templates is None:
        return os.environ.copy()
    if os.name != "posix":
        raise ValueError("--templates is for a Linux build host. On Windows install the templates in Godot.")
    data = work / "data"
    dest = data / "godot" / "export_templates" / VERSION
    dest.mkdir(parents=True)
    for filename in ("linux_release.x86_64", "windows_release_x86_64.exe"):
        source = templates / filename
        if source.is_file():
            (dest / filename).symlink_to(source.resolve())
    return {**os.environ, "XDG_DATA_HOME": str(data)}


def archive_distribution(kind, executable, work, output):
    _, executable_name, extension = DISTRIBUTIONS[kind]
    folder = {"server": "TinyOffice-Linux-Server", "linux": "TinyOffice-Linux", "windows": "TinyOffice-Windows"}[kind]
    bundle = work / folder
    bundle.mkdir()
    shutil.copy2(executable, bundle / executable_name)
    shutil.copy2(PROJECT / "README.md", bundle / "README.md")
    engine_notice = (REPO / "godot" / "LICENSES.txt").read_bytes()
    notices = engine_notice
    if kind == "server":
        shutil.copy2(PROJECT / "server.example.cfg", bundle / "server.example.cfg")
    else:
        notices += b"\n\n" + (REPO / "godot" / "assets" / "fonts" / "OFL.txt").read_bytes()
    (bundle / "LICENSES.txt").write_bytes(notices)
    target = output / (folder + extension)
    if extension == ".zip":
        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
            for file in sorted(bundle.iterdir()):
                archive.write(file, folder + "/" + file.name)
    else:
        with tarfile.open(target, "w:gz") as archive:
            archive.add(bundle, arcname=folder)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--templates", type=Path, help="Extracted 4.7.2 release templates on Linux")
    parser.add_argument("--target", choices=["all", *DISTRIBUTIONS], default="all")
    args = parser.parse_args()
    if not godot(args.godot, "--version").strip().startswith(VERSION):
        raise RuntimeError("Godot " + VERSION + " is required")

    chosen = list(DISTRIBUTIONS) if args.target == "all" else [args.target]
    output = PROJECT / "dist"
    output.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="pack-", dir=output) as temporary:
        work = Path(temporary)
        stage = work / "source"
        stage.mkdir()
        for filename in ("project.godot", "export_presets.cfg", "main.tscn"):
            shutil.copy2(PROJECT / filename, stage / filename)
        for pattern in ("*.gd", "*.gd.uid"):
            for path in PROJECT.glob(pattern):
                shutil.copy2(path, stage / path.name)
        if any(kind != "server" for kind in chosen):
            generated = stage / "generated"
            generated.mkdir()
            shutil.copy2(REPO / "godot" / "assets" / "fonts" / "NotoSansKR.ttf", generated / "NotoSansKR.ttf")
        env = template_environment(args.templates, work)
        godot(args.godot, "--headless", "--path", str(stage), "--editor", "--import", "--quit", env=env)
        artifacts = []
        for kind in chosen:
            preset, executable_name, _ = DISTRIBUTIONS[kind]
            binaries = work / kind
            binaries.mkdir()
            executable = binaries / executable_name
            godot(args.godot, "--headless", "--path", str(stage), "--export-release", preset, str(executable), env=env)
            artifacts.append(archive_distribution(kind, executable, work, work))
        for artifact in artifacts:
            artifact.replace(output / artifact.name)
    published = sorted(
        path for path in output.iterdir()
        if path.is_file() and any(path.name.endswith(ext) for _, _, ext in DISTRIBUTIONS.values())
    )
    (output / "SHA256SUMS.txt").write_text("".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n" for path in published
    ), encoding="ascii")
    print("Built " + ", ".join(path.name for path in published), flush=True)


if __name__ == "__main__":
    main()
