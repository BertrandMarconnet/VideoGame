# Open3D asset inbox

Déposer ici des images isolées d’assets à convertir en GLB avec le pipeline local open source :

```text
assets/asset_inbox/
├── props/
├── modules/
├── characters/
└── robots/
```

Formats acceptés : PNG, JPEG et WebP.

L’image doit montrer un seul objet complet, en vue trois-quarts, sur fond uni. Le pipeline utilise TripoSR local puis Blender pour produire un GLB métrique, décimé et compatible Godot. Il ne contacte aucune API commerciale et ne demande aucune clé.

Un fichier JSON portant le même nom peut préciser les réglages. Exemple :

```json
{
  "asset_name": "Sentinel console",
  "category": "props",
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

Sans JSON, des réglages Web raisonnables sont déduits du dossier et du nom du fichier.

## Validation gratuite sur GitHub

Chaque ajout dans ce dossier déclenche le workflow `Generate Open3D asset inbox` en mode validation. Cette étape vérifie les scripts, les images et les manifestes sans GPU.

## Génération locale sans quota

La génération complète exige un runner GPU auto-hébergé portant les labels :

```text
self-hosted, linux, x64, gpu, triposr
```

Le workflow manuel en mode `generate` :

1. génère les modèles avec TripoSR ;
2. décime et met à l’échelle avec Blender ;
3. place les GLB dans `assets/production/generated/` ;
4. assemble et lint le GDScript ;
5. importe, démarre et exporte le projet avec Godot 4.7 ;
6. ne pousse les GLB sur `main` que si tous les tests réussissent.

Les exemples inclus ont été créés pour Blackout Protocol dans la direction artistique PS1 industrial low-poly du storyboard.
