"""Combine the BioInnova character and Mixamo FBX clips into one animated GLB.

Usage: blender --background --factory-startup --python tools/export_tigrillo.py -- SOURCE_DIR OUTPUT_GLB [HEART_FBX]
"""

import bpy
import sys
from pathlib import Path


args = sys.argv[sys.argv.index("--") + 1 :]
source_dir, output = Path(args[0]), Path(args[1])
heart_fbx = Path(args[2]) if len(args) > 2 else None
clips = {
    "Walk": "Walking.fbx",
    "Run": "Running.fbx",
    "Wave": "Wave_One_Hand.fbx",
    "Talk": "Talk_with_Right_Hand_Open.fbx",
    "Backflip": "Backflip_Jump.fbx",
    "Cast": "mage_soell_cast_7.fbx",
}
if heart_fbx is not None:
    clips["Heart"] = heart_fbx

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def import_fbx(source):
    path = source if isinstance(source, Path) else next(source_dir.glob(f"*{source}"))
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(path), use_anim=True)
    return set(bpy.data.objects) - before


base_objects = import_fbx("character_meshyrig.fbx")
armature = next(obj for obj in base_objects if obj.type == "ARMATURE")
mesh = next(obj for obj in base_objects if obj.type == "MESH" and obj.name == "char1")
base_bones = {bone.name for bone in armature.data.bones}
for obj in list(base_objects):
    if obj not in (armature, mesh):
        bpy.data.objects.remove(obj, do_unlink=True)

armature.animation_data_create()
armature.animation_data.action = None
for clip_name, source in clips.items():
    imported = import_fbx(source)
    source_armature = next(obj for obj in imported if obj.type == "ARMATURE")
    source_bones = {bone.name for bone in source_armature.data.bones}
    if source_bones != base_bones:
        raise RuntimeError(f"{clip_name}: armature bones do not match base character")
    action = source_armature.animation_data.action
    if action is None:
        raise RuntimeError(f"{clip_name}: FBX contains no action")
    action.name = clip_name
    action.use_fake_user = True
    track = armature.animation_data.nla_tracks.new()
    track.name = clip_name
    strip = track.strips.new(clip_name, int(action.frame_range[0]), action)
    strip.name = clip_name
    for obj in list(imported):
        bpy.data.objects.remove(obj, do_unlink=True)
    print("CLIP", clip_name, tuple(action.frame_range), len(action.slots))

for obj in bpy.data.objects:
    obj.select_set(False)
armature.select_set(True)
mesh.select_set(True)
bpy.context.view_layer.objects.active = armature

output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(output),
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_nla_strips=True,
    export_merge_animation="NLA_TRACK",
    export_apply=False,
)
print("OUTPUT", output, output.stat().st_size)
