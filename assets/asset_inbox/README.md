# Open3D asset inbox

Déposer ici des images isolées d’assets à convertir en GLB avec le pipeline local open source :

```text
assets/asset_inbox/
├── props/
├── modules/
├── characters/
└── robots/
```

Formats acceptés : PNG, JPEG, WebP et SVG. Les SVG sont rasterisés localement en 1024 × 1024 avant l’inférence.

L’image doit montrer un seul objet complet, en vue trois-quarts, sur fond uni. Le pipeline utilise TripoSR local puis Blender pour produire un GLB métrique, décimé et compatible Godot. Il ne contacte aucune API commerciale et ne demande aucune clé.

Un fichier JSON portant le même nom peut préciser les réglages et le chemin d’intégration Godot. Exemple :

```json
{
  "asset_name": "Sentinel Console",
  "category": "props",
  "integration_path": "assets/production/act1/sentinel_console.glb",
  "generation": {
    "target_faces": 7000,
    "target_height_m": 1.35,
    "create_collision": true
  },
  "quality": {
    "max_glb_mb": 16
  }
}
```

`integration_path` doit rester sous `assets/production/` et se terminer par `.glb`. Sans ce champ, le résultat est placé sous `assets/production/generated/<catégorie>/`.

Sans JSON, des réglages Web raisonnables sont déduits du dossier et du nom du fichier.

## Concepts Acte I déjà préparés

- `props/service_access_door.svg` → `assets/production/act1/service_access.glb` ;
- `props/s01_blast_door.svg` → `assets/production/act1/s01_blast_door.glb` ;
- `props/sentinel_console.svg` → `assets/production/act1/sentinel_console.glb` ;
- `props/fps_flashlight.svg` → `assets/production/act1/fps_flashlight.glb` ;
- `modules/industrial_wall_module_a.svg` → `assets/production/environment/industrial_wall_module_a.glb`.

Les quatre premiers chemins sont déjà recherchés par le code de l’Acte I. Le jeu conserve ses fallbacks procéduraux tant que les GLB ne sont pas présents.

## Validation gratuite sur GitHub

Chaque ajout dans ce dossier déclenche le workflow `Generate Open3D asset inbox` en mode validation. Cette étape vérifie les scripts, rasterise les SVG, contrôle les images et construit les manifestes sans GPU.

## Génération locale sans quota

La génération complète exige un runner GPU auto-hébergé portant les labels :

```text
self-hosted, linux, x64, gpu, triposr
```

Le workflow manuel en mode `generate` :

1. génère les modèles avec TripoSR ;
2. décime et met à l’échelle avec Blender ;
3. place chaque GLB directement dans son chemin d’intégration ;
4. assemble et lint le GDScript ;
5. importe, démarre et exporte le projet avec Godot 4.7 ;
6. ne pousse les GLB sur `main` que si tous les tests réussissent.

Les exemples inclus sont des concepts originaux créés pour Blackout Protocol dans la direction artistique PS1 industrial low-poly du storyboard.
