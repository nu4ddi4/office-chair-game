#!/usr/bin/env python3
"""Verify Office Chair Chaos using the pinned engine and real scenes."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--suite', choices=['all', 'rules', 'scene', 'routes', 'handling'], default='all')
    parser.add_argument('--rendered', action='store_true')
    parser.add_argument('--blockout', action='store_true')
    args = parser.parse_args()
    output = ROOT / 'chaos-results'
    output.mkdir(exist_ok=True)

    def run(command, name, timeout=360):
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, encoding='utf-8', timeout=timeout)
        (output / (name + '.log')).write_text(result.stdout, encoding='utf-8')
        print(result.stdout, end='')
        if result.returncode or re.search(r'(SCRIPT ERROR|Parse Error|SHADER ERROR|^ERROR:)', result.stdout, re.M):
            raise RuntimeError(f'{name} failed; inspect chaos-results/{name}.log')
        return result.stdout

    version = run([args.godot, '--version'], 'engine')
    if not version.strip().startswith('4.7.2.stable'):
        raise RuntimeError('Use Godot 4.7.2 stable.')
    run(['node', 'scripts/godot-asset-test.mjs'], 'retained-assets')
    run([sys.executable, 'scripts/check-chaos-assets.py'], 'expanded-assets')
    run([args.godot, '--headless', '--path', 'godot', '--editor', '--import', '--quit'], 'import')
    for suite, marker in [('rules', 'CHAOS_RULES'), ('scene', 'CHAOS_PHYSICS'), ('handling', 'CHAOS_HANDLING'), ('routes', 'CHAOS_ROUTES')]:
        if args.suite not in ['all', suite] and not (args.suite == 'scene' and suite == 'handling'):
            continue
        command = [args.godot, '--path', 'godot', '--audio-driver', 'Dummy', '--fixed-fps', '120']
        if suite in ['rules', 'routes'] or not args.rendered:
            command.append('--headless')
        else:
            command += ['--rendering-method', 'gl_compatibility', '--resolution', '1280x720']
        command += ['--script', f'res://chaos/tests/{dict(scene="physics", rules="rules", routes="drive", handling="handling")[suite]}.gd', '--', '--chaos-test']
        if args.blockout:
            command.append('--blockout')
        if args.rendered:
            command += ['--capture-dir', str(output)]
        raw = run(command, suite, timeout=600)
        reports = [json.loads(line.split(marker+' ', 1)[1]) for line in raw.splitlines() if line.startswith(marker+' ')]
        if len(reports) != 1 or not reports[0].get('passed'):
            raise RuntimeError(f'{suite} did not complete successfully')
        (output / (suite+'.json')).write_text(json.dumps(reports[0], ensure_ascii=False, indent=2), encoding='utf-8')

if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(exc, file=sys.stderr)
        sys.exit(1)
