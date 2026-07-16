#!/usr/bin/env python3
"""Convert the guided GitHub issue form into a normalized game-asset request.

The parser supports the current compact menu and the previous detailed form. Uploaded references
are accepted only from GitHub-owned hosts. They guide palette, texture and proportions; geometry,
rig, segmentation and localized damage remain category-controlled for predictable Godot assets.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

ALLOWED_IMAGE_HOSTS = {
    "github.com",
    "user-images.githubusercontent.com",
    "private-user-images.githubusercontent.com",
    "raw.githubusercontent.com",
}
MAX_IMAGES = 6
MAX_IMAGE_BYTES = 12 * 1024 * 1024

CATEGORY_MAP = {
    "Robot bipède": "robot_biped",
    "Robot quadrupède": "robot_quadruped",
    "Personnage humanoïde": "character_humanoid",
    "Vue FPS : main + objet": "fps_viewmodel",
    "Machine / bras industriel articulé": "articulated_machine",
    "Prop / objet interactif": "prop",
    "Mur / cloison modulaire": "wall",
    "Porte / sas": "door",
    "Module d'environnement": "environment",
    "Console / écran / GUI 3D": "gui_panel",
}
MATERIAL_MAP = {
    "Métal léger": "metal_light",
    "Métal blindé": "metal_armored",
    "Plastique technique": "technical_plastic",
    "Caoutchouc / tissu technique": "technical_fabric",
    "Verre": "glass",
    "Placo": "drywall",
    "Brique": "brick",
    "Béton": "concrete",
    "Bois": "wood",
}
RIG_MAP = {
    "Aucun": "none",
    "Mécanique bipède": "rigid_biped",
    "Mécanique quadrupède": "rigid_quadruped",
    "Humanoïde": "humanoid",
    "Main FPS articulée": "fps_hand",
    "Machine articulée": "articulated_machine",
    "Charnière simple": "hinge",
    "Pièces rigides segmentées": "rigid_segmented",
}
DESTRUCTION_MAP = {
    "Aucune": "none",
    "Dégâts localisés": "localized",
    "Membres / pièces détachables": "detachable",
    "Mur segmenté avec trous locaux": "segmented_wall",
    "Avancée selon le matériau": "material_advanced",
}
QUALITY_MAP = {
    "Web / mobile PS1 — recommandé": "web",
    "Standard": "standard",
    "Hero asset": "hero",
}
INTEGRATION_MAP = {
    "Ajouter au catalogue seulement": "catalog_only",
    "Remplacer automatiquement le modèle procédural correspondant": "replace_procedural",
    "Générer un module instanciable depuis l'AssetBridge": "bridge_module",
    "Générer une vue FPS instanciable depuis l'AssetBridge": "fps_viewmodel",
}
REFERENCE_MODE_MAP = {
    "Une vue principale / trois-quarts": "single_view",
    "Quatre vues orthographiques cohérentes": "orthographic_four",
    "Plusieurs vues libres du même asset": "multi_view",
    "Storyboard / concept art d'ambiance": "storyboard",
    "Aucune image, génération depuis le profil": "none",
}
GEOMETRY_TEMPLATE_MAP = {
    "Automatique selon la catégorie": "auto",
    "Monobloc simple": "monoblock",
    "Pièces modulaires détachables": "modular_detachable",
    "Outil tenu en main": "held_tool",
    "Console / panneau technique": "technical_panel",
    "Mur cellulaire": "cellular_wall",
    "Porte articulée": "hinged_door",
    "Module environnemental": "environment_module",
    "Bipède articulé": "articulated_biped",
    "Quadrupède articulé": "articulated_quadruped",
    "Machine articulée": "articulated_machine",
}
TEXTURE_MODE_MAP = {
    "Atlas PS1 généré depuis les images": "reference_atlas",
    "Palette PS1 sans texture détaillée": "palette_only",
    "Première image utilisée comme écran / GUI": "screen_image",
    "Matériau plat seulement": "flat",
}
COLLISION_MAP = {
    "Automatique selon la catégorie": "auto",
    "Boîte simple": "box",
    "Capsule personnage / robot": "capsule",
    "Boîtes locales par partie": "local_boxes",
    "Mur segmenté par cellule": "segmented_cells",
    "Aucune collision": "none",
}

DEFAULTS = {
    "robot_biped": ("articulated_biped", "rigid_biped", "capsule", "detachable", ["idle", "walk", "run", "attack", "crawl", "shutdown"]),
    "robot_quadruped": ("articulated_quadruped", "rigid_quadruped", "local_boxes", "detachable", ["idle", "walk", "run", "attack", "shutdown"]),
    "character_humanoid": ("articulated_biped", "humanoid", "capsule", "localized", ["idle", "walk", "run", "interact", "fall"]),
    "fps_viewmodel": ("held_tool", "fps_hand", "none", "localized", ["idle", "use", "bash", "inspect"]),
    "articulated_machine": ("articulated_machine", "articulated_machine", "local_boxes", "detachable", ["idle", "work", "alarm", "shutdown"]),
    "prop": ("monoblock", "none", "box", "localized", ["idle", "use", "break"]),
    "wall": ("cellular_wall", "none", "segmented_cells", "segmented_wall", ["break"]),
    "door": ("hinged_door", "hinge", "local_boxes", "localized", ["open", "close", "lock", "unlock"]),
    "environment": ("environment_module", "none", "local_boxes", "material_advanced", ["idle"]),
    "gui_panel": ("technical_panel", "rigid_segmented", "box", "localized", ["idle", "boot", "alarm", "shutdown"]),
}

PROFILE_OVERRIDES = {
    "Robot ou personnage articulé": (None, None, "capsule", "detachable"),
    "Vue FPS main et objet articulés": ("held_tool", "fps_hand", "none", "localized"),
    "Machine articulée": ("articulated_machine", "articulated_machine", "local_boxes", "detachable"),
    "Prop modulaire segmenté": ("modular_detachable", "rigid_segmented", "local_boxes", "detachable"),
    "Mur destructible cellulaire": ("cellular_wall", "none", "segmented_cells", "segmented_wall"),
    "Porte ou sas articulé": ("hinged_door", "hinge", "local_boxes", "localized"),
    "Environnement modulaire": ("environment_module", "none", "local_boxes", "material_advanced"),
    "Console ou GUI 3D": ("technical_panel", "rigid_segmented", "box", "localized"),
}

DELIVERY_MAP = {
    "Web / mobile PS1 + intégrer au jeu — recommandé": ("web", "bridge_module"),
    "Web / mobile PS1 + catalogue seulement": ("web", "catalog_only"),
    "Standard + intégrer au jeu": ("standard", "bridge_module"),
    "Hero asset + catalogue seulement": ("hero", "catalog_only"),
    "Vue FPS Web + intégrer sous la caméra": ("web", "fps_viewmodel"),
}


def slugify(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    value = re.sub(r"[^a-zA-Z0-9]+", "_", value).strip("_").lower()
    if not value or len(value) > 64:
        raise ValueError("Nom d'asset invalide")
    return value


def parse_sections(body: str) -> dict[str, str]:
    sections: dict[str, str] = {}
    current = ""
    buffer: list[str] = []
    for line in body.splitlines():
        if line.startswith("### "):
            if current:
                sections[current] = "\n".join(buffer).strip()
            current = line[4:].strip()
            buffer = []
        else:
            buffer.append(line)
    if current:
        sections[current] = "\n".join(buffer).strip()
    return sections


def first_any(sections: dict[str, str], *labels: str, default: str = "") -> str:
    for label in labels:
        value = sections.get(label, "").strip()
        value = re.sub(r"^_No response_\s*$", "", value, flags=re.I)
        if value:
            return value
    return default


def parse_float(value: str, label: str) -> float:
    try:
        number = float(value.replace(",", ".").strip())
    except ValueError as exc:
        raise ValueError(f"{label} doit être un nombre") from exc
    if not 0.05 <= number <= 30.0:
        raise ValueError(f"{label} doit être compris entre 0,05 et 30 m")
    return round(number, 4)


def parse_dimensions(sections: dict[str, str]) -> dict[str, float]:
    compact = first_any(sections, "Dimensions cibles L × H × P en mètres")
    if compact:
        numbers = re.findall(r"\d+(?:[.,]\d+)?", compact)
        if len(numbers) != 3:
            raise ValueError("Dimensions : utiliser le format largeur x hauteur x profondeur")
        return {
            "width": parse_float(numbers[0], "Largeur"),
            "height": parse_float(numbers[1], "Hauteur"),
            "depth": parse_float(numbers[2], "Profondeur"),
        }
    return {
        "width": parse_float(first_any(sections, "Largeur cible en mètres", default="1.0"), "Largeur"),
        "height": parse_float(first_any(sections, "Hauteur cible en mètres", default="1.0"), "Hauteur"),
        "depth": parse_float(first_any(sections, "Profondeur cible en mètres", default="1.0"), "Profondeur"),
    }


def extract_urls(text: str) -> list[str]:
    urls = re.findall(r"https://[^\s)\]<>\"]+", text)
    unique: list[str] = []
    for raw in urls:
        url = raw.rstrip(".,;")
        if url not in unique:
            unique.append(url)
    return unique[:MAX_IMAGES]


def download_image(url: str, destination: Path) -> Path:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_IMAGE_HOSTS:
        raise ValueError(f"Hôte d'image non autorisé : {parsed.hostname}")
    request = urllib.request.Request(url, headers={"User-Agent": "BlackoutProtocolAssetBot/3.0"})
    with urllib.request.urlopen(request, timeout=40) as response:
        final_host = urllib.parse.urlparse(response.geturl()).hostname
        if final_host not in ALLOWED_IMAGE_HOSTS:
            raise ValueError(f"Redirection d'image non autorisée : {final_host}")
        content_type = response.headers.get_content_type()
        data = response.read(MAX_IMAGE_BYTES + 1)
    if len(data) > MAX_IMAGE_BYTES:
        raise ValueError("Image trop volumineuse")
    if content_type not in {"image/png", "image/jpeg", "image/webp"}:
        raise ValueError(f"Format d'image refusé : {content_type}")
    extension = {"image/png": ".png", "image/jpeg": ".jpg", "image/webp": ".webp"}[content_type]
    output = destination.with_suffix(extension)
    output.write_bytes(data)
    return output


def map_required(mapping: dict[str, str], value: str, label: str) -> str:
    if value not in mapping:
        raise ValueError(f"Valeur inconnue pour {label}: {value}")
    return mapping[value]


def parse_parts(value: str) -> list[str]:
    parts: list[str] = []
    for raw in re.split(r"[,;\n]+", value):
        raw = raw.strip()
        if not raw:
            continue
        try:
            part = slugify(raw)[:32]
        except ValueError:
            continue
        if part not in parts:
            parts.append(part)
    return parts[:16]


def parse_spec(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in text.splitlines():
        match = re.match(r"^([A-Z_]+)\s*:\s*(.*)$", line.strip())
        if match:
            values[match.group(1)] = match.group(2).strip()
    return values


def parse_animations(value: str, defaults: list[str]) -> list[str]:
    result: list[str] = []
    for item in re.split(r"[,;\n]+", value):
        item = item.strip()
        if not item:
            continue
        animation = slugify(item).replace("_", "-")
        if animation not in result:
            result.append(animation)
    return (result or defaults)[:12]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--event", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--image-dir", type=Path, required=True)
    args = parser.parse_args()

    event = json.loads(args.event.read_text(encoding="utf-8"))
    issue = event.get("issue") or {}
    title = str(issue.get("title", ""))
    body = str(issue.get("body", ""))
    sections = parse_sections(body)
    if not title.startswith("[ASSET]") and "Catégorie" not in sections:
        raise ValueError("Cette issue n'utilise pas le menu de génération d'asset")

    name = first_any(sections, "Nom de l'asset") or title.removeprefix("[ASSET]").strip()
    slug = slugify(name)
    category = map_required(CATEGORY_MAP, first_any(sections, "Catégorie"), "catégorie")
    material = map_required(MATERIAL_MAP, first_any(sections, "Matériau principal"), "matériau")
    reference_mode = map_required(
        REFERENCE_MODE_MAP,
        first_any(sections, "Organisation des images", "Type de références fournies"),
        "références",
    )
    dimensions = parse_dimensions(sections)
    spec_text = first_any(sections, "Spécification gameplay, parties, animations et dégâts")
    spec = parse_spec(spec_text)

    template, rig, collision, destruction, default_animations = DEFAULTS[category]
    profile = first_any(sections, "Profil de génération", default="Automatique selon la catégorie — recommandé")
    if profile in PROFILE_OVERRIDES:
        override_template, override_rig, override_collision, override_destruction = PROFILE_OVERRIDES[profile]
        template = override_template or template
        rig = override_rig or rig
        collision = override_collision or collision
        destruction = override_destruction or destruction

    # Detailed legacy fields and explicit specification keys override category defaults.
    detailed_template = first_any(sections, "Structure géométrique", default=spec.get("GEOMETRY_TEMPLATE", ""))
    if detailed_template in GEOMETRY_TEMPLATE_MAP:
        template = GEOMETRY_TEMPLATE_MAP[detailed_template]
    detailed_rig = first_any(sections, "Rig / articulation", default=spec.get("RIG", ""))
    if detailed_rig in RIG_MAP:
        rig = RIG_MAP[detailed_rig]
    detailed_collision = first_any(sections, "Collision Godot", default=spec.get("COLLISION", ""))
    if detailed_collision in COLLISION_MAP:
        collision = COLLISION_MAP[detailed_collision]
    detailed_destruction = first_any(sections, "Destructibilité", default=spec.get("DESTRUCTION", ""))
    if detailed_destruction in DESTRUCTION_MAP:
        destruction = DESTRUCTION_MAP[detailed_destruction]

    texture_label = first_any(sections, "Texture", default=spec.get("TEXTURE_MODE", "Atlas PS1 généré depuis les images"))
    texture_mode = TEXTURE_MODE_MAP.get(texture_label, "reference_atlas")
    visual_profile = first_any(sections, "Profil visuel", default=spec.get("VISUAL_PROFILE", "PS1 industriel ToyGuard"))[:96]
    animations = parse_animations(
        first_any(sections, "Animations souhaitées", default=spec.get("ANIMATIONS", "")),
        default_animations,
    )
    segmentation_text = first_any(sections, "Parties à séparer / segmenter", default=spec.get("SEGMENTATION", ""))
    segmentation_parts = parse_parts(segmentation_text)

    delivery = first_any(sections, "Qualité et intégration")
    if delivery:
        if delivery not in DELIVERY_MAP:
            raise ValueError(f"Livraison inconnue : {delivery}")
        quality, integration = DELIVERY_MAP[delivery]
    else:
        quality = map_required(QUALITY_MAP, first_any(sections, "Qualité", default="Web / mobile PS1 — recommandé"), "qualité")
        integration = map_required(INTEGRATION_MAP, first_any(sections, "Intégration dans le jeu", default="Générer un module instanciable depuis l'AssetBridge"), "intégration")
    if category == "fps_viewmodel" and delivery == "Web / mobile PS1 + intégrer au jeu — recommandé":
        integration = "fps_viewmodel"

    args.image_dir.mkdir(parents=True, exist_ok=True)
    image_paths: list[str] = []
    image_errors: list[str] = []
    image_section = first_any(sections, "Images de référence")
    image_urls = extract_urls(image_section)
    if not image_urls:
        raise ValueError("Aucune image n'a été jointe au champ Images de référence")
    for index, url in enumerate(image_urls):
        try:
            path = download_image(url, args.image_dir / f"reference_{index + 1}")
            image_paths.append(str(path))
        except Exception as exc:
            image_errors.append(str(exc))
    if not image_paths:
        raise ValueError("Les images jointes n'ont pas pu être téléchargées : " + "; ".join(image_errors))

    generator_profile = {
        "robot_biped": "specter_biped" if "specter" in slug else "generic_biped",
        "robot_quadruped": "crawler7" if "crawler" in slug else "generic_quadruped",
        "character_humanoid": "generic_character",
        "fps_viewmodel": "fps_viewmodel",
        "articulated_machine": "articulated_machine",
        "prop": "generic_prop",
        "wall": "segmented_wall",
        "door": "industrial_door",
        "environment": "environment_module",
        "gui_panel": "gui_panel",
    }[category]

    request_data = {
        "schema_version": 1,
        "asset_name": name[:96],
        "slug": slug,
        "category": category,
        "generator_profile": generator_profile,
        "visual_profile": visual_profile,
        "reference_mode": reference_mode,
        "geometry_template": template,
        "segmentation_parts": segmentation_parts,
        "dimensions_m": dimensions,
        "material_id": material,
        "texture_mode": texture_mode,
        "rig": rig,
        "animations": animations,
        "collision_mode": collision,
        "destruction_mode": destruction,
        "intended_use": first_any(sections, "Rôle du modèle dans le jeu", default=spec.get("ROLE", ""))[:2000],
        "damage_zones_description": first_any(sections, "Zones critiques et conséquences", default=spec.get("DAMAGE_ZONES", ""))[:2000],
        "interactions_description": first_any(sections, "Outils et interactions", default=spec.get("INTERACTIONS", ""))[:2000],
        "quality": quality,
        "integration": integration,
        "reference_images": image_paths,
        "reference_image_errors": image_errors,
        "normalization_warnings": [],
        "issue_number": int(issue.get("number", 0)),
        "issue_url": str(issue.get("html_url", "")),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(request_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(request_data, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"asset request error: {exc}", file=sys.stderr)
        raise
