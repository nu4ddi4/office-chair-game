#!/usr/bin/env python3
"""Check the expanded GLB and authored route clearances independently of Godot."""
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'godot/assets/models/Office_Chaos.glb'
with path.open('rb') as stream:
    header = stream.read(12)
    assert header[:4] == b'glTF', 'Fetch the LFS runtime assets first'
    size, kind = struct.unpack('<II', stream.read(8))
    assert kind == 0x4e4f534a
    document = json.loads(stream.read(size))
names = [node.get('name', '') for node in document['nodes']]
assert sum(name.startswith('Chaos_DeskGroup_') for name in names) == 20
assert 'STATIC_Chaos_Floor' in names
assert 'STATIC_Chaos_Ceiling' in names
assert sum(name.startswith('COLLIDER_Chaos_') for name in names) >= 40
layout = json.loads((ROOT / 'godot/chaos/data/office_layout.json').read_text())
assert (layout['width'], layout['depth']) == (60, 42)
missions = json.loads((ROOT / 'godot/chaos/data/missions.json').read_text())
assert [mission['id'] for mission in missions] == list(range(1, 7))
for mission in missions:
    assert 2 <= 1 + sum(point.get('checkpoint', False) for point in mission['route']) <= 3
    for point in [mission['start']] + [waypoint['at'] for waypoint in mission['route']]:
        x, z = point
        assert abs(x) < 29 and abs(z) < 20
        for wall in layout['walls']:
            wx, _, wz = wall['at']
            sx, _, sz = wall['size']
            assert not (abs(x-wx) < sx/2+.4 and abs(z-wz) < sz/2+.4), (mission['id'], point, 'wall overlap')



for mission in missions:
    route = [mission["start"]] + [point["at"] for point in mission["route"]]
    for begin, end in zip(route, route[1:]):
        steps = max(1, int(((begin[0]-end[0])**2+(begin[1]-end[1])**2)**.5*5))
        for step in range(steps+1):
            x = begin[0]+(end[0]-begin[0])*step/steps
            z = begin[1]+(end[1]-begin[1])*step/steps
            for wall in layout["walls"]:
                wx, _, wz = wall["at"]; sx, _, sz = wall["size"]
                assert not (abs(x-wx)<sx/2+.36 and abs(z-wz)<sz/2+.36), (mission["id"], begin, end, "blocked route")

print(f"Expanded office: 60x42m, 20 retained desk groups, {len(missions)} clear authored routes.")
