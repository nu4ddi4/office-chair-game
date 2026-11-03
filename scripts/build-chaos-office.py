"""Blender: build the expanded office from the retained, credited furniture.

blender -b --python scripts/build-chaos-office.py
The retained GLB and authoring master are never modified.
"""
import json
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'godot/assets/models/Interior_07_Godot.glb'))
originals = list(bpy.data.objects)
template = bpy.data.objects.get('CORP_Staff_Seat_13')
if template is None:
    raise RuntimeError('Retained office furniture template is missing')
layout = json.loads((ROOT / 'godot/chaos/data/office_layout.json').read_text())
collection = bpy.data.collections.new('Chaos_Office')
bpy.context.scene.collection.children.link(collection)

def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .78
    return mat

wall = material('Chaos warm plaster', (.72, .75, .72))
floor = bpy.data.materials.get('CORP_Office_Carpet_2K') or material('Chaos carpet', (.20, .25, .27))
ceiling = material('Chaos matte acoustic ceiling', (.80, .82, .78))
glass = material('Chaos window glass', (.48, .65, .70))
glass.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value = .18
glass.surface_render_method = 'DITHERED'
trim = material('Chaos oak trim', (.49, .35, .22))

def box(name, at, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(at[0], -at[2], at[1]))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for col in list(obj.users_collection): col.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj

ground = box('STATIC_Chaos_Floor', (0, -.12, 0), (60, .24, 42), floor)
for poly in ground.data.polygons:
    for index in poly.loop_indices:
        co = ground.data.vertices[ground.data.loops[index].vertex_index].co
        ground.data.uv_layers.active.data[index].uv = (co.x / 2, co.y / 2)
box('STATIC_Chaos_Ceiling', (0, 3.55, 0), (60, .15, 42), ceiling)
for i in range(51):
    box(f'DECOR_CeilingGridX_{i}', (-30+i*1.2, 3.469, 0), (.018, .012, 42), wall)
for i in range(36):
    box(f'DECOR_CeilingGridZ_{i}', (0, 3.469, -21+i*1.2), (60, .012, .018), wall)
for i, item in enumerate(layout['walls']):
    if item['size'][0] == 60:
        z = item['at'][2]
        box(f'STATIC_Chaos_Sill_{i:02}', (0, .5, z), (60, 1, .2), wall)
        box(f'STATIC_Chaos_Lintel_{i:02}', (0, 3.25, z), (60, .5, .2), wall)
        box(f'STATIC_Chaos_Glass_{i:02}', (0, 1.95, z), (60, 1.9, .04), glass)
        for x in range(-30, 31, 3):
            box(f'DECOR_Chaos_Mullion_{i}_{x}', (x, 1.95, z), (.055, 1.9, .08), trim)
    else:
        box(f'STATIC_Chaos_Wall_{i:02}', item['at'], item['size'], wall)
    p = list(item['at']); p[1] = .06
    s = list(item['size']); s[1] = .12
    box(f'DECOR_Chaos_Skirting_{i:02}', p, s, trim)

def clone_tree(source, parent=None):
    clone = source.copy()
    clone.name = 'CHAOS_' + source.name
    collection.objects.link(clone)
    clone.parent = parent
    clone.matrix_parent_inverse = source.matrix_parent_inverse.copy()
    clone.matrix_basis = source.matrix_basis.copy()
    # Runtime authors collision boxes from copied source collider meshes.
    if source.name.startswith('COLLIDER_'):
        clone.name = 'COLLIDER_Chaos_' + source.name
    for child in source.children: clone_tree(child, clone)
    return clone

for i, (x, z) in enumerate(layout['desks']):
    root = clone_tree(template)
    root.name = f'Chaos_DeskGroup_{i:02}'
    root.parent = None
    root.matrix_world = template.matrix_world.copy()
    root.location = (x, -z, 0)

# Server racks reuse the original authored mesh/materials at their original size.
rack = bpy.data.objects.get('ServerRack_01')
if rack is not None:
    for i, x in enumerate([20.5, 22.3, 24.1, 25.9]):
        root = clone_tree(rack)
        root.name = f'Chaos_ServerRack_{i:02}'
        root.parent = None
        root.matrix_world = rack.matrix_world.copy()
        root.location = (x, 19.2, 0)
        box(f'COLLIDER_Chaos_ServerRack_{i:02}', (x, 1.05, -19.2), (.8, 2.1, .9), floor)

for obj in originals:
    bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'assets/authoring/Office_Chaos.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in collection.all_objects: obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT / 'godot/assets/models/Office_Chaos.glb'),
    export_format='GLB', use_selection=True, export_extras=True,
    export_cameras=False, export_lights=False, export_animations=False)
print('CHAOS_OFFICE_EXPORTED')
