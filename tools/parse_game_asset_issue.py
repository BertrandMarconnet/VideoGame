#!/usr/bin/env python3
"""Convert the GitHub issue form into a normalized asset-generation request.

The parser deliberately validates every user-controlled value. Reference images are optional;
when supplied they are downloaded only from GitHub-owned attachment hosts and are used for
palette/aspect guidance or GUI textures, not as an unverified promise of exact 3D reconstruction.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
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


def first_value(sections: dict[str, str], label: str, default: str = "") -> str:
    value = sections.get(label, default).strip()
    value = re.sub(r"^_No response_\s*$", "", value, flags=re.I)
    return value


def parse_float(value: str, label: str) -> float:
    try:
        number = float(value.replace(",", ".").strip())
    except ValueError as exc:
        raise ValueError(f"{label} doit être un nombre") from exc
    if not 0.05 <= number <= 30.0:
        raise ValueError(f"{label} doit être compris entre 0,05 et 30 m")
    return round(number, 4)


def extract_urls(text: str) -> list[str]:
    urls = re.findall(r"https://[^\s)\]\">]+", text)
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
    request = urllib.request.Request(url, headers={"User-Agent": "BlackoutProtocolAssetBot/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--event", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--image-dir", type=Path, required=True)
    args = parser.parse_args()

    event = json.loads(args.event.read_text(encoding="utf-8"))
    issue = event.get("issue") or {}
    title = str(issue.get("title", ""))
    if not title.startswith("[ASSET]"):
        raise ValueError("L'issue ne correspond pas au formulaire [ASSET]")
    body = str(issue.get("body", ""))
    sections = parse_sections(body)

    name = first_value(sections, "Nom de l'asset") or title.removeprefix("[ASSET]").strip()
    slug = slugify(name)
    category = map_required(CATEGORY_MAP, first_value(sections, "Catégorie"), "catégorie")
    material = map_required(MATERIAL_MAP, first_value(sections, "Matériau principal"), "matériau")
    rig = map_required(RIG_MAP, first_value(sections, "Rig / articulation"), "rig")
    destruction = map_required(DESTRUCTION_MAP, first_value(sections, "Destructibilité"), "destructibilité")
    quality = map_required(QUALITY_MAP, first_value(sections, "Qualité"), "qualité")
    integration = map_required(INTEGRATION_MAP, first_value(sections, "Intégration dans le jeu"), "intégration")

    dimensions = {
        "width": parse_float(first_value(sections, "Largeur cible en mètres", "1.0"), "Largeur"),
        "height": parse_float(first_value(sections, "Hauteur cible en mètres", "1.0"), "Hauteur"),
        "depth": parse_float(first_value(sections, "Profondeur cible en mètres", "1.0"), "Profondeur"),
    }
    animations = [
        slugify(item).replace("_", "-")
        for item in first_value(sections, "Animations souhaitées", "idle").split(",")
        if item.strip()
    ][:12]
    if not animations:
        animations = ["idle"]

    args.image_dir.mkdir(parents=True, exist_ok=True)
    image_paths: list[str] = []
    image_errors: list[str] = []
    for index, url in enumerate(extract_urls(first_value(sections, "Images de référence"))):
        try:
            path = download_image(url, args.image_dir / f"reference_{index + 1}")
            image_paths.append(str(path))
        except Exception as exc:  # report bad attachments without hiding the rest of the request
            image_errors.append(str(exc))

    generator_profile = {
        "robot_biped": "specter_biped" if "specter" in slug else "generic_biped",
        "robot_quadruped": "crawler7" if "crawler" in slug else "generic_quadruped",
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
        "visual_profile": first_value(sections, "Profil visuel", "PS1 industriel ToyGuard")[:96],
        "dimensions_m": dimensions,
        "material_id": material,
        "rig": rig,
        "animations": animations,
        "destruction_mode": destruction,
        "damage_zones_description": first_value(sections, "Zones critiques et conséquences")[:2000],
        "interactions_description": first_value(sections, "Outils et interactions")[:2000],
        "quality": quality,
        "integration": integration,
        "reference_images": image_paths,
        "reference_image_errors": image_errors,
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
