# Pipeline des modèles 3D

## État de la version Web

La version actuelle utilise encore plusieurs modèles procéduraux construits avec les primitives de Godot. Ce choix garantit un chargement rapide, une physique cohérente et un export Web léger. Les robots, jouets utilitaires, bras industriels et machines possèdent des articulations animées, mais ne reposent pas encore tous sur une bibliothèque de fichiers GLB finalisés.

## Règles pour les futurs assets

Seuls les modèles accompagnés d’une licence explicite peuvent être intégrés :

- **CC0 / domaine public** : intégration autorisée avec conservation de la preuve de licence ;
- **CC BY** : attribution obligatoire dans `THIRD_PARTY_ASSETS.md` et dans les crédits du jeu ;
- **GPL ou licences destinées au code** : à éviter pour les fichiers artistiques sans analyse préalable ;
- **Editorial use**, **non-commercial**, licences ambiguës ou absence de licence : refusés ;
- aucun modèle, logo, personnage ou décor extrait d’une franchise existante.

## Format recommandé

- GLB/glTF 2.0 ;
- textures WebP ou PNG, idéalement 1K maximum pour le profil navigateur ;
- squelette inférieur à 70 os pour les personnages principaux ;
- LOD0, LOD1 et collision simplifiée ;
- animations séparées : idle, marche, course, détection, attaque et panne ;
- pivot, unités métriques et axes vérifiés avant import.

## Budget Web indicatif

| Élément | Triangles LOD0 | Triangles LOD1 | Textures |
|---|---:|---:|---:|
| Ennemi principal | 20 000–35 000 | 8 000–15 000 | 2 × 1K |
| Jouet utilitaire | 4 000–10 000 | 2 000–4 000 | 1 × 1K |
| Machine industrielle | 8 000–20 000 | 3 000–8 000 | 1–2 × 1K |
| Petit accessoire | 300–2 000 | facultatif | atlas partagé |

## Processus d’intégration

1. enregistrer l’URL source, l’auteur, la licence et la date de téléchargement ;
2. contrôler le contenu de l’archive et supprimer les fichiers inutiles ;
3. nettoyer le maillage et les matériaux dans Blender ;
4. créer une collision simplifiée distincte ;
5. exporter en GLB avec les animations ;
6. tester le rendu Godot GL Compatibility ;
7. vérifier la taille du PCK et les performances sur smartphone ;
8. compléter `THIRD_PARTY_ASSETS.md` avant fusion.

Le gameplay doit toujours prévoir un substitut procédural lorsque le modèle externe n’est pas disponible ou dépasse le budget Web.

## Décision après les essais image-vers-3D

Le pipeline TripoSR monoculaire a été retiré. Il produisait un volume statique approximatif, sans segmentation mécanique fiable, sans armature et sans animations. Le fait qu’un GLB puisse être importé ne suffisait pas à en faire un asset exploitable.

Les solutions multivues open source telles que Hunyuan3D-2mv ou les générateurs texturés de la famille TRELLIS restent des options de recherche. Elles exigent toutefois un GPU NVIDIA disposant d’une mémoire importante et ne fournissent pas, à elles seules, un robot mécanique segmenté, riggé et animé.

La comparaison détaillée est conservée dans :

```text
docs/OPEN_SOURCE_3D_DECISION.md
docs/OPEN_SOURCE_3D_TOOLS_MATRIX.md
```

## Pipeline de production actuel : CRAWLER-7 déterministe

Le premier asset de production utilise un générateur Blender hard-surface spécifique au design de CRAWLER-7 :

```text
tools/generate_crawler7_production_v2.py
tools/generate_crawler7_production_v4.py
tools/generate_crawler7_production_v5.py
.github/workflows/generate-production-robot.yml
```

La chaîne garantit :

1. un corps et des blindages séparés ;
2. quatre pattes mécaniques segmentées ;
3. une armature quadrupède de 13 os ;
4. des poids rigides par parentage aux os ;
5. cinq matériaux industriels avec texture d’usure embarquée ;
6. un groupe de capteurs rouges émissifs ;
7. cinq collisions simplifiées ;
8. les clips `Idle-loop`, `Walk-loop`, `Run-loop`, `Attack` et `Shutdown` ;
9. un budget compris entre 3 500 et 12 000 triangles ;
10. un aperçu PNG, des métriques et un rapport de validation ;
11. un réimport Blender puis un import Godot 4.7 avant acceptation.

Le modèle final est écrit ici :

```text
assets/output 3d model/crawler_7_production.glb
```

L’interface utilisateur est :

```text
Issues → New issue → Générer CRAWLER-7 production
```

Aucune image, clé API, installation locale, compte fournisseur ou crédit commercial n’est nécessaire.

## Pipeline Meshy optionnel

Les anciens fichiers de documentation Meshy peuvent rester comme référence d’expérimentation, mais aucun asset généré avec une API commerciale ne doit être intégré automatiquement. Toute réactivation demanderait un compte, une clé, des crédits et une revue de licence.

## Choix selon le type d’asset

Utiliser un générateur Blender déterministe pour :

- CRAWLER-7 ;
- SPECTER-5 lorsque son générateur dédié sera validé ;
- KITE-01 lorsque son générateur dédié sera validé ;
- robots et machines nécessitant des axes articulaires exacts.

Utiliser Blender ou Blockbench pour :

- couloirs modulaires ;
- bunker S-01 ;
- sas et portes ;
- convoyeurs ;
- bras industriels ;
- décors avec dimensions et collisions précises.

Une salle générée comme un seul maillage serait difficile à optimiser, collisionner et faire évoluer selon le storyboard.
