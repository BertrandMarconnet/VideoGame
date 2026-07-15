# Pipeline des modèles 3D

## État de la version Web

La version actuelle conserve plusieurs substituts procéduraux Godot afin de garantir un démarrage rapide, une physique stable et une solution de repli. Les GLB validés peuvent désormais remplacer uniquement leur représentation visuelle sans supprimer l'IA, les collisions ni les interactions existantes.

## Règles pour les futurs assets

Seuls les modèles accompagnés d’une licence explicite peuvent être intégrés :

- **CC0 / domaine public** : intégration autorisée avec conservation de la preuve de licence ;
- **CC BY** : attribution obligatoire dans `THIRD_PARTY_ASSETS.md` et dans les crédits du jeu ;
- **GPL ou licences destinées au code** : à éviter pour les fichiers artistiques sans analyse préalable ;
- **Editorial use**, **non-commercial**, licences ambiguës ou absence de licence : refusés ;
- aucun modèle, logo, personnage ou décor extrait d'une franchise existante.

## Format recommandé

- GLB/glTF 2.0 ;
- textures WebP ou PNG, idéalement 1K maximum pour le profil navigateur ;
- squelette inférieur à 70 os ;
- collisions simplifiées distinctes ;
- animations nommées et séparées ;
- origine au sol, unités métriques et axes vérifiés ;
- manifeste `.asset.json` ;
- profil d'interaction `.damage.json`.

## Budget Web indicatif

| Élément | Triangles LOD0 | Triangles LOD1 | Textures |
|---|---:|---:|---:|
| Ennemi principal | 12 000–25 000 | 6 000–12 000 | 1–2 × 1K |
| Jouet utilitaire | 4 000–10 000 | 2 000–4 000 | 1 × 1K |
| Machine industrielle | 8 000–20 000 | 3 000–8 000 | 1–2 × 1K |
| Petit accessoire | 300–2 000 | facultatif | atlas partagé |
| Cellule de mur | 12–300 | facultatif | atlas partagé |

## Décision après les essais image-vers-3D

Le pipeline TripoSR monoculaire a été retiré : un volume importable ne garantissait ni fidélité, ni segmentation mécanique, ni rig, ni animations. Les solutions multivues open source restent documentées comme options de recherche, mais elles demandent une infrastructure GPU et ne produisent pas seules un asset de gameplay final.

Le dépôt utilise donc une génération **contrôlée par catégorie**. Les images jointes servent à guider les proportions, la palette et les textures d'écran ; la géométrie est fabriquée par un générateur paramétrique adapté à l'asset.

## Pipeline principal : bundle générique validé

Interface :

```text
Issues → New issue → Générer un asset de jeu
```

Catégories disponibles :

- robot bipède ;
- robot quadrupède ;
- prop interactif ;
- mur ou cloison modulaire ;
- porte ou sas ;
- module d'environnement ;
- console, écran ou GUI 3D.

Workflow :

```text
.github/workflows/generate-game-asset.yml
```

Générateurs et contrôles :

```text
tools/parse_game_asset_issue.py
tools/generate_game_asset.py
tools/generate_game_asset_v2.py
tools/validate_game_asset_bundle.py
tools/update_generated_asset_catalog.py
```

Chaque asset validé est écrit dans :

```text
assets/generated/<slug>/
```

Le bundle comprend :

1. `<slug>.glb` ;
2. `<slug>.png` ;
3. `<slug>.asset.json` ;
4. `<slug>.damage.json` ;
5. `<slug>.metrics.json` ;
6. `<slug>.validation.json`.

Le workflow refuse un robot sans rig ou sans animations, un GLB invalide, un budget excessif et un profil de dégâts incohérent. L'import Godot 4.7 est exécuté avant tout commit automatique.

## Passerelle vers le jeu

Le catalogue :

```text
assets/generated/catalog.json
```

est chargé par l'autoload :

```text
scripts/generated_assets/asset_bridge_autoload.gd
scripts/generated_assets/asset_bridge.gd
```

La passerelle :

- instancie les GLB validés ;
- masque les primitives visuelles seulement lorsque le remplacement est demandé ;
- conserve toujours un substitut procédural ;
- attache les profils de dégâts ;
- expose une API d'instanciation pour les scènes ;
- relie les états de destruction à l'IA et aux animations.

## Destruction localisée et matériaux

Les réponses physiques sont centralisées dans :

```text
data/material_response_db.json
scripts/destruction/material_response_db.gd
scripts/destruction/destructible_component.gd
```

Les murs destructibles utilisent plusieurs cellules avec des collisions indépendantes. La destruction d'une cellule ouvre un trou local. Les murs porteurs en béton restent structurels.

Les robots utilisent des zones nommées. La perte d'une patte de CRAWLER-7 réduit sa vitesse. La perte des jambes de SPECTER-5 déclenche un mode de locomotion rampant. Les capteurs peuvent être neutralisés indépendamment du corps.

## CRAWLER-7 spécialisé

Le générateur CRAWLER-7 v5 reste utilisé lorsque le profil `crawler7` est sélectionné :

```text
tools/generate_crawler7_production_v2.py
tools/generate_crawler7_production_v4.py
tools/generate_crawler7_production_v5.py
```

Son GLB de production actuel est enregistré dans :

```text
assets/output 3d model/crawler_7_production.glb
```

Le catalogue le rend immédiatement disponible dans le jeu avec un profil localisé à six zones.

## Modules d'environnement

Les couloirs, sas, portes et salles doivent rester modulaires. Une salle générée comme un seul maillage est refusée, car elle serait difficile à collisionner, optimiser et faire évoluer selon le storyboard.

Documentation détaillée :

```text
docs/GENERATED_ASSET_AND_DAMAGE_PIPELINE.md
assets/generated/README.md
```
