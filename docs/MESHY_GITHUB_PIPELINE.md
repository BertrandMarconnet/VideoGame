# Pipeline Meshy dans GitHub Actions

Ce pipeline prépare des modèles 3D GLB à partir d'une à quatre images de référence. Il est manuel, ne se lance jamais lors d'un `push` et ne commite aucun modèle automatiquement.

## 1. Ajouter la clé API

Dans le dépôt GitHub :

1. ouvrir **Settings** ;
2. ouvrir **Secrets and variables** puis **Actions** ;
3. cliquer sur **New repository secret** ;
4. créer le secret `MESHY_API_KEY` ;
5. coller la clé API Meshy dans la valeur.

La clé ne doit apparaître ni dans un fichier, ni dans un commit, ni dans une capture d'écran.

## 2. Préparer les images

Créer un dossier dans `assets/concepts/` et y placer une à quatre images PNG/JPEG du même objet. Pour un robot, préférer :

- face ;
- profil droit ;
- dos ;
- trois-quarts.

Les images doivent montrer un seul objet, dans la même pose, sur fond neutre et sans décor.

## 3. Préparer le manifeste

Le manifeste JSON indique les images, le budget de polygones, la texture, la pose et la limite de taille Web. Exemple :

```json
{
  "asset_name": "SPECTER-5",
  "images": [
    "assets/concepts/specter_5/front.png",
    "assets/concepts/specter_5/right.png",
    "assets/concepts/specter_5/back.png",
    "assets/concepts/specter_5/three_quarter.png"
  ],
  "generation": {
    "ai_model": "latest",
    "should_texture": true,
    "enable_pbr": false,
    "should_remesh": true,
    "topology": "triangle",
    "target_polycount": 12000,
    "pose_mode": "a-pose",
    "target_formats": ["glb"],
    "auto_size": true,
    "origin_at": "bottom"
  },
  "quality": {
    "max_glb_mb": 20,
    "require_glb": true
  }
}
```

Le script accepte un chemin de fichier du dépôt, une URL publique HTTPS ou une Data URI.

## 4. Valider sans consommer de crédits

Dans GitHub :

1. ouvrir **Actions** ;
2. choisir **Generate Meshy 3D asset** ;
3. cliquer sur **Run workflow** ;
4. saisir le chemin du manifeste ;
5. choisir le mode `validate` ;
6. lancer.

Le workflow vérifie le JSON, les images, les options, le budget et le script sans appeler Meshy.

## 5. Générer le modèle

Relancer le même workflow avec le mode `generate`. Le pipeline :

1. transforme les images locales en Data URI ;
2. appelle `image-to-3d` pour une image ou `multi-image-to-3d` pour deux à quatre images ;
3. attend le résultat ;
4. télécharge le GLB et les aperçus ;
5. vérifie l'en-tête GLB ;
6. calcule les SHA-256 ;
7. contrôle la taille maximale ;
8. produit un rapport de provenance.

## 6. Télécharger le résultat

Le résultat est stocké comme **artifact GitHub Actions** pendant 14 jours. Il contient généralement :

```text
<asset>/
├── <asset>.glb
├── preview.png
├── preview_front.png
├── preview_right.png
├── preview_back.png
├── preview_left.png
├── manifest.json
├── validation.json
├── task.json
├── summary.json
└── PROVENANCE.md
```

Le workflow ne dispose que de la permission `contents: read`. Il ne peut donc pas ajouter automatiquement le modèle au dépôt.

## 7. Contrôle Blender obligatoire

Avant l'import dans Godot :

- vérifier l'échelle en mètres ;
- appliquer les transformations ;
- corriger le pivot ;
- supprimer les faces internes et éléments flottants ;
- réduire les matériaux ;
- limiter les textures à 1K pour le Web ;
- créer un LOD1 ;
- préparer une collision simple séparée ;
- contrôler le rig et les noms d'animations ;
- réexporter en GLB.

## 8. Intégration Godot

Le modèle validé peut ensuite être placé dans :

```text
assets/production/validated/<asset>/
```

Il faut conserver le fallback procédural actuel tant que le modèle GLB n'a pas passé :

- import Godot 4.7 ;
- export Web ;
- test Firefox ;
- test smartphone ;
- contrôle du PCK ;
- vérification de licence.

## Sécurité et coût

- aucun appel automatique sur `push` ;
- aucun secret écrit dans les logs ;
- aucun commit automatique ;
- le mode `validate` ne consomme pas de crédits Meshy ;
- le mode `generate` consomme les crédits associés au compte Meshy ;
- les droits des images sources et les conditions du forfait Meshy doivent être vérifiés avant publication commerciale.
