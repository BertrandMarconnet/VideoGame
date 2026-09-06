#!/usr/bin/env python3
"""Bevel existing robot assets in Blender, preserving skins, clips and part names.

Run: blender -b --python tools/refine_console_assets.py -- input.glb output.glb
The output is validated before it can replace the existing asset.
"""
from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

import bmesh
import bpy


def glb_info(path: Path) -> dict:
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    return {
        "triangles": sum(doc["accessors"][primitive["indices"]]["count"] // 3
                         for mesh in doc["meshes"] for primitive in mesh["primitives"]),
        "mesh_names": {node["name"] for node in doc["nodes"] if "mesh" in node},
        "joints": {doc["nodes"][joint]["name"] for skin in doc.get("skins", []) for joint in skin["joints"]},
        "animations": {clip["name"] for clip in doc.get("animations", [])},
        "bytes": len(data),
    }


def main() -> None:
    source, destination = map(Path, sys.argv[sys.argv.index("--") + 1:])
    before = glb_info(source)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source.resolve()), merge_vertices=True)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    refined = 0
    for obj in meshes:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        # Only manufactured casings: cylindrical bearings and thin sensor lenses
        # keep their authored contours, UVs and damage alignment.
        shortest = min(obj.dimensions)
        if shortest < 0.025 or len(obj.data.vertices) > 100:
            continue
        backup = obj.data.copy()
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.00001)
        bm.to_mesh(obj.data)
        bm.free()
        bevel = obj.modifiers.new("Manufactured edge radius", "BEVEL")
        bevel.width = min(0.018, shortest * 0.075)
        bevel.segments = 2
        bevel.limit_method = "ANGLE"
        bevel.angle_limit = math.radians(36)
        bevel.harden_normals = True
        # Evaluate the bevel ahead of the existing Armature modifier so the
        # bind pose, deform weights and skeletal animation remain intact.
        bpy.ops.object.modifier_move_to_index(modifier=bevel.name, index=0)
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        if len(obj.data.polygons) > 850:
            obj.data = backup
            continue
        for face in obj.data.polygons:
            face.use_smooth = True
        normal = obj.modifiers.new("Weighted casing normals", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
        normal.weight = 50
        bpy.ops.object.modifier_move_to_index(modifier=normal.name, index=0)
        bpy.ops.object.modifier_apply(modifier=normal.name)
        refined += 1
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        for node in mat.node_tree.nodes:
            if node.type == "TEX_IMAGE":
                node.interpolation = "Linear"
            elif node.type == "BSDF_PRINCIPLED":
                node.inputs["Metallic"].default_value = min(node.inputs["Metallic"].default_value, 0.68)
                node.inputs["Roughness"].default_value = max(node.inputs["Roughness"].default_value, 0.3)
    destination.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(destination.resolve()), export_format="GLB", export_yup=True,
        export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True,
        export_morph=False, export_cameras=False, export_lights=False,
        export_apply=False, export_optimize_animation_size=False,
    )
    after = glb_info(destination)
    for key in ("mesh_names", "joints", "animations"):
        if before[key] != after[key]:
            raise RuntimeError(f"Asset contract changed ({key}): missing={before[key]-after[key]}, added={after[key]-before[key]}")
    if after["triangles"] > 32000 or after["bytes"] > 4_000_000:
        raise RuntimeError(f"Web asset budget exceeded: {after['triangles']} triangles, {after['bytes']} bytes")
    print("CONSOLE_ASSET_VALIDATED", json.dumps({"source": str(source), "refined_meshes": refined,
          "triangles_before": before["triangles"], "triangles_after": after["triangles"],
          "bytes": after["bytes"], "clips": sorted(after["animations"]), "joints": len(after["joints"])}))


if __name__ == "__main__":
    main()
