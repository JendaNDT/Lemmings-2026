"""Author original clay prototype meshes and skeletal actions in Blender.
No external models or textures are used. Output is independent of the game.
"""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.render.fps = 24


def material(name, color, rough=.85, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Roughness'].default_value = rough
    node.inputs['Metallic'].default_value = metallic
    return mat


teal = material('Clay teal clothing', (.005, .19, .20))
dark_teal = material('Clay dark boots', (.013, .055, .064))
amber = material('Clay amber cap', (.95, .43, .018))
skin = material('Clay warm face', (.94, .76, .43))
ivory = material('Clay ivory eyes', (.96, .94, .82), .68)
ink = material('Clay dark eyes', (.012, .025, .03), .6)
wood = material('Clay wood', (.31, .12, .045))
wood_light = material('Clay wood trim', (.51, .26, .095))
steel = material('Steel fittings', (.38, .41, .44), .46, 1)
stone = material('Clay pale stone', (.58, .50, .37))
gold = material('Exit warm interior', (.98, .55, .095), .75)

parts = []


def finish_mesh(obj, name, mat, bone=None):
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if bone:
        group = obj.vertex_groups.new(name=bone)
        group.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    parts.append(obj)
    return obj


def ellipsoid(name, center, scale, mat, bone=None, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=center)
    obj = bpy.context.object
    obj.scale = scale
    return finish_mesh(obj, name, mat, bone)


def box(name, center, scale, mat, bone=None, bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new('Soft clay edges', 'BEVEL')
    mod.width = bevel
    mod.segments = 3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new('Weighted surface normals', 'WEIGHTED_NORMAL')
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish_mesh(obj, name, mat, bone)


def limb(name, a, b, radius, mat, bone):
    delta = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10,
        location=(Vector(a) + Vector(b)) / 2)
    obj = bpy.context.object
    obj.scale = (radius, radius, delta.length / 2 + radius * .5)
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = delta.to_track_quat('Z', 'Y')
    return finish_mesh(obj, name, mat, bone)


def join_parts(name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    parts.clear()
    return result


# Rig coordinates: Blender Z up, face -Y (glTF +Z), soles at Z=0.
armature = bpy.data.armatures.new('ClayWorkerSkeleton')
rig = bpy.data.objects.new('ClayWorkerRig', armature)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bone_defs = {
    'Root': ((0, 0, 0), (0, 0, .10), None),
    'Hips': ((0, 0, .38), (0, 0, .52), 'Root'),
    'Spine': ((0, 0, .52), (0, 0, .76), 'Hips'),
    'Head': ((0, 0, .76), (0, 0, 1.16), 'Spine'),
}
for side, sign in [('L', 1), ('R', -1)]:
    bone_defs[f'Arm.{side}'] = ((sign*.20, 0, .61), (sign*.28, -.015, .51), 'Spine')
    bone_defs[f'Forearm.{side}'] = ((sign*.28, -.015, .51), (sign*.31, -.035, .41), f'Arm.{side}')
    bone_defs[f'Hand.{side}'] = ((sign*.31, -.035, .41), (sign*.31, -.04, .36), f'Forearm.{side}')
    bone_defs[f'Thigh.{side}'] = ((sign*.10, 0, .39), (sign*.10, 0, .25), 'Hips')
    bone_defs[f'Shin.{side}'] = ((sign*.10, 0, .25), (sign*.10, 0, .12), f'Thigh.{side}')
    bone_defs[f'Foot.{side}'] = ((sign*.10, 0, .12), (sign*.10, -.15, .07), f'Shin.{side}')
for name, (head, tail, parent) in bone_defs.items():
    bone = armature.edit_bones.new(name)
    bone.head, bone.tail = head, tail
    if parent:
        bone.parent = armature.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
rig.select_set(False)

ellipsoid('Body', (0, 0, .54), (.255, .205, .215), teal, 'Spine', 32, 20)
ellipsoid('Trousers', (0, 0, .385), (.195, .16, .115), teal, 'Hips')
box('Belt', (0, -.015, .405), (.345, .275, .038), wood, 'Hips', .016)
box('Buckle', (0, -.159, .405), (.055, .025, .045), amber, 'Hips', .009)
ellipsoid('Backpack', (0, .18, .56), (.19, .095, .19), dark_teal, 'Spine', 24, 16)
ellipsoid('Hood', (0, -.005, .965), (.35, .30, .335), teal, 'Head', 40, 24)
ellipsoid('Face', (0, -.244, .975), (.278, .112, .266), skin, 'Head', 40, 24)
ellipsoid('Cap', (0, -.003, 1.195), (.367, .318, .16), amber, 'Head', 40, 20)
ellipsoid('Cap visor', (0, -.252, 1.17), (.354, .14, .041), amber, 'Head', 32, 16)
ellipsoid('Cap button', (0, .002, 1.35), (.047, .047, .038), amber, 'Head', 16, 10)
ellipsoid('Nose', (0, -.351, .955), (.043, .037, .043), skin, 'Head', 20, 12)
for side, sign in [('L', 1), ('R', -1)]:
    ellipsoid('Eye '+side, (sign*.10, -.341, 1.02), (.026, .017, .036), ink, 'Head', 20, 12)
    ellipsoid('Eye glint '+side, (sign*.10-.006, -.355, 1.032), (.007, .006, .009), ivory, 'Head', 12, 8)
    limb('Upper sleeve '+side, bone_defs[f'Arm.{side}'][0], bone_defs[f'Arm.{side}'][1], .09, teal, f'Arm.{side}')
    limb('Lower sleeve '+side, bone_defs[f'Forearm.{side}'][0], bone_defs[f'Forearm.{side}'][1], .075, teal, f'Forearm.{side}')
    ellipsoid('Hand '+side, (sign*.311, -.04, .382), (.075, .067, .072), skin, f'Hand.{side}')
    limb('Thigh '+side, bone_defs[f'Thigh.{side}'][0], bone_defs[f'Thigh.{side}'][1], .09, teal, f'Thigh.{side}')
    limb('Shin '+side, bone_defs[f'Shin.{side}'][0], bone_defs[f'Shin.{side}'][1], .074, teal, f'Shin.{side}')
    ellipsoid('Boot '+side, (sign*.10, -.07, .075), (.113, .172, .085), dark_teal, f'Foot.{side}')
worker = join_parts('ClayWorker')
worker.parent = rig
modifier = worker.modifiers.new('Skeleton', 'ARMATURE')
modifier.object = rig
for bone in rig.pose.bones:
    bone.rotation_mode = 'XYZ'


def pose(name, t):
    phase = t * math.tau
    s = math.sin(phase)
    for bone in rig.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_euler = (0, 0, 0)
        bone.scale = (1, 1, 1)
    bones = rig.pose.bones
    if name == 'idle_loop':
        bones['Spine'].scale.z = 1 + .012 * s
        bones['Head'].rotation_euler.z = .025 * s
    elif name == 'walk_loop':
        bones['Hips'].location.y = .018 * (1 - math.cos(phase * 2))
        for side, sign in [('L', 1), ('R', -1)]:
            bones[f'Thigh.{side}'].rotation_euler.x = .52 * s * sign
            bones[f'Shin.{side}'].rotation_euler.x = -.45 * max(0, -s * sign)
            bones[f'Foot.{side}'].rotation_euler.x = .12 * s * sign
            bones[f'Arm.{side}'].rotation_euler.x = -.40 * s * sign
            bones[f'Forearm.{side}'].rotation_euler.x = -.12
    elif name == 'fall_loop':
        for side, sign in [('L', 1), ('R', -1)]:
            bones[f'Arm.{side}'].rotation_euler.z = -sign * (1.8 + .09 * s)
            bones[f'Forearm.{side}'].rotation_euler.x = -.25
            bones[f'Thigh.{side}'].rotation_euler.x = sign * (.15 + .1 * s)
        bones['Head'].rotation_euler.x = .1
    elif name == 'block_loop':
        for side, sign in [('L', 1), ('R', -1)]:
            bones[f'Arm.{side}'].rotation_euler.z = -sign * 1.0
            bones[f'Forearm.{side}'].rotation_euler.z = -sign * .12
        bones['Head'].rotation_euler.z = .13 * s
    elif name in ('build_loop', 'bash_loop', 'dig_loop', 'mine_loop'):
        lift = (1 - math.cos(phase)) * .5
        bend = {'build_loop': .22, 'bash_loop': .12, 'dig_loop': .45, 'mine_loop': .32}[name]
        bones['Spine'].rotation_euler.x = bend * (.5 + .5 * lift)
        for side in ['L', 'R']:
            bones[f'Arm.{side}'].rotation_euler.x = -.35 - .95 * lift
            bones[f'Forearm.{side}'].rotation_euler.x = -.60 + .40 * lift
            bones[f'Thigh.{side}'].rotation_euler.x = -.14 * lift
            bones[f'Shin.{side}'].rotation_euler.x = .25 * lift
        if name == 'bash_loop':
            bones['Spine'].rotation_euler.z = .18 * s
        if name == 'mine_loop':
            bones['Spine'].rotation_euler.z = .10 * s
    elif name == 'shrug':
        lift = math.sin(math.pi * t)
        for side, sign in [('L', 1), ('R', -1)]:
            bones[f'Arm.{side}'].rotation_euler.z = -sign * .5 * lift
            bones[f'Forearm.{side}'].rotation_euler.x = -.8 * lift
        bones['Head'].rotation_euler.z = .12 * math.sin(2 * phase)
    elif name == 'splat':
        flatten = math.sin(min(t * 2, 1) * math.pi / 2)
        bones['Root'].scale = (1 + .34 * flatten, 1 - .74 * flatten, 1 + .23 * flatten)
    elif name == 'exit':
        factor = max(.02, 1 - t * t)
        bones['Root'].scale = (factor, factor, factor)
        bones['Head'].rotation_euler.z = .12 * s


clips = [
    ('idle_loop', 48), ('walk_loop', 24), ('fall_loop', 24), ('block_loop', 48),
    ('build_loop', 24), ('bash_loop', 24), ('dig_loop', 24), ('mine_loop', 24),
    ('shrug', 20), ('splat', 16), ('exit', 24),
]
rig.animation_data_create()
for name, length in clips:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in range(length + 1):
        pose(name, frame / length)
        # Keep a planted sole on the floor for ground actions; airborne and exit
        # clips retain their authored pose. This is authored motion, not game physics.
        if name not in ['fall_loop', 'exit']:
            bpy.context.view_layer.update()
            evaluated = worker.evaluated_get(bpy.context.evaluated_depsgraph_get())
            geometry = evaluated.to_mesh()
            lowest = min((evaluated.matrix_world @ v.co).z for v in geometry.vertices)
            evaluated.to_mesh_clear()
            rig.pose.bones['Root'].location.y = -lowest
        for bone in rig.pose.bones:
            bone.keyframe_insert('location', frame=frame, group=bone.name)
            bone.keyframe_insert('rotation_euler', frame=frame, group=bone.name)
            bone.keyframe_insert('scale', frame=frame, group=bone.name)
    for curve in action.fcurves:
        for point in curve.keyframe_points:
            point.interpolation = 'LINEAR'
rig.animation_data.action = bpy.data.actions.get('idle_loop')
bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action='DESELECT')
worker.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
ROOT.joinpath('models').mkdir(exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'models/clay_worker.glb'), export_format='GLB',
    use_selection=True, export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_range=False, export_animations=True, export_skins=True, export_yup=True)
(ROOT/'source').mkdir(exist_ok=True)
(ROOT/'source/.gdignore').touch()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/clay_worker.blend'))


metadata = {
    'character': 'clay_worker.glb', 'purpose': 'clay reference v3, derived from project-authored clay kit v1 and art v2',
    'skeleton_bones': len(bone_defs), 'glTF_up': '+Y', 'glTF_forward': '+Z',
    'authored_height_m': 1.388, 'root_motion': False,
    'clips': [{'name': n, 'seconds': frames/24, 'loop': n.endswith('_loop'),
               'contact_phase': .5 if n in ['build_loop','bash_loop','dig_loop','mine_loop'] else None}
              for n, frames in clips],
    'notes': ['Tools are separate socket props.', 'Mine clip anticipates phase 4 diagonal-down skill.',
              'No upward digging.', 'Retiming to simulation events is an integration task.'],
}
(ROOT/'animation_manifest.json').write_text(json.dumps(metadata, indent=2)+'\n')
print('Created original skinned worker, eleven animation clips for the art pass.')
