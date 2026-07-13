# Input image

Ce dossier alimente l’action GitHub **Generate 3D model**.

## Un seul asset avec plusieurs vues

Créer un sous-dossier par objet :

```text
assets/Input image/
└── specter_5/
    ├── front.png
    ├── right.png
    ├── back.png
    ├── three_quarter.png
    └── asset.json
```

Les images doivent représenter exactement le même objet, sans décor, avec le corps entier visible et un fond simple. Les formats acceptés sont PNG, JPEG et WebP.

Meshy utilise jusqu’à quatre vues du sous-dossier. TripoSR utilise une seule image principale ; les autres vues restent enregistrées dans le catalogue pour le contrôle visuel.

## Un asset avec une seule image

Une image déposée directement dans ce dossier produit un modèle portant le même nom :

```text
assets/Input image/industrial_crate.png
→ assets/output 3d model/industrial_crate.glb
```

Un fichier JSON facultatif portant le même nom peut préciser les réglages :

```text
industrial_crate.png
industrial_crate.json
```

## Configuration `asset.json`

Copier `asset.example.json` dans le sous-dossier de l’asset, puis le renommer `asset.json`.

Pour SPECTER-5 :

```json
{
  "asset_name": "SPECTER-5",
  "primary_image": "three_quarter.png",
  "generation": {
    "target_faces": 12000,
    "target_height_m": 2.45,
    "pose_mode": "a-pose",
    "should_texture": true,
    "enable_pbr": false,
    "image_enhancement": false,
    "remove_lighting": true,
    "auto_size": true,
    "origin_at": "bottom",
    "create_collision": false
  },
  "quality": {
    "max_glb_mb": 25
  }
}
```

## Lancer la génération

1. Fusionner la pull request qui ajoute le workflow.
2. Ajouter les images dans ce dossier sur la branche `main`.
3. Ouvrir **Actions**.
4. Choisir **Generate 3D model**.
5. Cliquer sur **Run workflow**.
6. Choisir le moteur :
   - `meshy` : une à quatre images, runner GitHub standard, clé `MESHY_API_KEY` obligatoire et crédits Meshy consommés ;
   - `triposr` : génération locale gratuite, mais runner GPU auto-hébergé obligatoire.
7. Laisser `commit_output = true` pour enregistrer automatiquement le GLB dans `assets/output 3d model`.

Pour Meshy, créer d’abord le secret du dépôt :

```text
Settings → Secrets and variables → Actions → New repository secret
Name: MESHY_API_KEY
```

Pour TripoSR, le runner doit porter les labels :

```text
self-hosted, linux, x64, gpu, triposr
```
