#!/usr/bin/env python3
"""Compatibility entry point for the category-aware asset generator.

The Ubuntu runner can expose different Blender defaults and glTF operator arguments. This wrapper
loads the generator definitions without executing its entry point, then replaces only environment
initialization, material creation and GLB export with version-tolerant implementations.
"""
from __future__ import annotations

from pathlib import Path

import bpy

SOURCE = Path(__file__).with_name("generate_game_asset.py")
text = SOURCE.read_text(encoding="utf-8")
marker = 'if __name__=="__main__":\n    main()'
if marker not in text:
    raise RuntimeError(f"Missing entry-point marker in {SOURCE}")
text = text.rsplit(marker, 1)[0]
namespace: dict[str, object] = {"__file__": str(SOURCE), "__name__": "generic_asset_module"}
exec(compile(text, str(SOURCE), "exec"), namespace)


def compatible_reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("BlackoutAssetWorld")
    scene.world.color = (0.025, 0.03, 0.036)
    scene.frame_start = 1
    scene.frame_end = 48


def compatible_material(name, definition, emission=None, texture=None):
    color, metallic, roughness = definition
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if color[3] < 1.0:
        bsdf.inputs["Alpha"].default_value = color[3]
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "DITHERED"
        elif hasattr(mat, "blend_method"):
            mat.blend_method = "BLEND"
    if texture is not None and Path(texture).exists():
        image_node = nodes.new("ShaderNodeTexImage")
        image_node.image = bpy.data.images.load(str(texture), check_existing=True)
        image_node.interpolation = "Closest"
        links.new(image_node.outputs["Color"], bsdf.inputs["Base Color"])
        alpha_output = image_node.outputs.get("Alpha")
        if alpha_output is not None and bsdf.inputs.get("Alpha") is not None:
            links.new(alpha_output, bsdf.inputs["Alpha"])
    if emission is not None:
        socket = bsdf.inputs.get("Emission Color")
        if socket is None:
            socket = bsdf.inputs.get("Emission")
        if socket is not None:
            socket.default_value = emission
        strength = bsdf.inputs.get("Emission Strength")
        if strength is not None:
            strength.default_value = 4.0
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def compatible_export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE"}:
            obj.select_set(True)
    wanted = {
        "filepath": str(path),
        "export_format": "GLB",
        "use_selection": True,
        "export_apply": True,
        "export_yup": True,
        "export_animations": True,
        "export_nla_strips": True,
        "export_force_sampling": True,
        "export_materials": "EXPORT",
    }
    supported = {item.identifier for item in bpy.ops.export_scene.gltf.get_rna_type().properties}
    options = {key: value for key, value in wanted.items() if key in supported}
    bpy.ops.export_scene.gltf(**options)


namespace["reset"] = compatible_reset
namespace["material"] = compatible_material
namespace["export_glb"] = compatible_export_glb
namespace["main"]()
