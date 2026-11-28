"""Exercise the full shift with real local ENet connections and synthetic controls."""

import argparse
from contextlib import ExitStack
import os
from pathlib import Path
import secrets
import socket
import subprocess
import tempfile
import time

PROJECT = Path(__file__).resolve().parents[1]


def launch(stack, command, log):
    home = log.parent / log.stem
    home.mkdir()
    env = dict(os.environ, XDG_DATA_HOME=str(home), XDG_CONFIG_HOME=str(home), XDG_CACHE_HOME=str(home))
    with log.open("w", encoding="utf-8") as output:
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, env=env)
    stack.callback(stop, process)
    return process


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


def wait_for(process, log, marker):
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        if marker in log.read_text():
            return
        if process.poll() is not None:
            break
        time.sleep(0.05)
    raise RuntimeError(f"Missing {marker} in {log.name}")


def scenario(godot, root, role):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    key = secrets.token_hex(18)
    config = root / "server.cfg"
    config.touch(mode=0o600)
    config.write_text(f'[server]\nbind_address="127.0.0.1"\nport={port}\nroom_key="{key}"\n')
    base = [godot, "--headless", "--path", str(PROJECT), "--max-fps", "120"]
    client = base + ["--script", "res://tests/shift_client.gd", "--", str(port), key]
    with ExitStack() as stack:
        server_log = root / "server.log"
        primary_log = root / "primary.log"
        partner_log = root / "partner.log"
        server = launch(stack, base + ["--", "--server", "--config", str(config)], server_log)
        wait_for(server, server_log, "TINY_OFFICE_READY")
        primary = launch(stack, client + [role], primary_log)
        if role != "solo":
            if role == "primary":
                wait_for(primary, primary_log, "SHIFT_TEST solo_round")
            partner_role = "partner" if role == "primary" else "coworker"
            partner = launch(stack, client + [partner_role], partner_log)
            if partner.wait(timeout=55) != 0:
                raise RuntimeError("Partner failed")
        if primary.wait(timeout=55) != 0:
            raise RuntimeError("Primary client failed")
        logs = [path.read_text() for path in root.glob("*.log")]
        if any("ERROR:" in log for log in logs):
            raise RuntimeError("Godot reported an error")
        print(primary_log.read_text().strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    for role in ("solo", "primary", "duo"):
        with tempfile.TemporaryDirectory(prefix="small-business-shift-") as temp:
            root = Path(temp)
            try:
                scenario(args.godot, root, role)
            except BaseException:
                for log in root.glob("*.log"):
                    print(f"--- {log.name} ---\n{log.read_text()}")
                raise


if __name__ == "__main__":
    main()
