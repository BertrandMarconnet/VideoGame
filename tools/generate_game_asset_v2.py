#!/usr/bin/env python3
"""Compatibility entry point for the category-aware asset generator.

The Ubuntu runner can expose different Blender defaults and glTF operator arguments. This wrapper
loads the generator definitions without executing its entry point, then replaces environment
initialization, palette extraction, material creation and GLB export with compatible implementations.
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


def reference_color(request) -> tuple[float, float, float] | None:
    references = request.get("reference_images", [])
    samples: list[tuple[float, float, float]] = []
    for reference in references[:4]:
        path = Path(reference)
        if not path.exists():
            continue
        try:
            image = bpy.data.images.load(str(path), check_existing=True)
            pixel_count = max(1, int(image.size[0]) * int(image.size[1]))
            step = max(1, pixel_count // 1800)
            pixels = image.pixels
            for pixel_index in range(0, pixel_count, step):
                offset = pixel_index * 4
                red = float(pixels[offset])
                green = float(pixels[offset + 1])
                blue = float(pixels[offset + 2])
                alpha = float(pixels[offset + 3])
                brightness = max(red, green, blue)
                saturation = max(red, green, blue) - min(red, green, blue)
                if alpha > 0.45 and 0.035 < brightness < 0.82 and saturation > 0.055:
                    samples.append((red, green, blue))
        except Exception as exc:
            print(f"Reference palette skipped for {path}: {exc}")
    if not samples:
        return None
    return tuple(sum(sample[channel] for sample in samples) / len(samples) for channel in range(3))


def compatible_build_materials(request):
    definitions = namespace["MATERIALS"]
    base = definitions[request["material_id"]]
    sampled = reference_color(request)
    if sampled is not None:
        original = base[0]
        blend = 0.52
        adapted = tuple(max(0.018, min(0.48, original[index] * (1.0 - blend) + sampled[index] * blend)) for index in range(3)) + (original[3],)
        base = (adapted, base[1], base[2])
    return {
        "primary": compatible_material("BP_Primary", base),
        "dark": compatible_material("BP_DarkMetal", ((0.035, 0.038, 0.04, 1.0), 0.85, 0.72)),
        "joint": compatible_material("BP_Joints", ((0.025, 0.022, 0.02, 1.0), 0.9, 0.86)),
        "red": compatible_material("BP_RedSensor", ((0.15, 0.005, 0.005, 1.0), 0.2, 0.25), emission=(1.0, 0.0, 0.02, 1.0)),
    }


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
namespace["build_materials"] = compatible_build_materials
namespace["export_glb"] = compatible_export_glb
namespace["main"]()
