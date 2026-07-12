# Pipeline des modèles 3D

## État de la version Web

La version actuelle utilise encore des modèles procéduraux construits avec les primitives de Godot. Ce choix garantit un chargement rapide, une physique cohérente et un export Web léger. Les robots, jouets utilitaires, bras industriels et machines possèdent des articulations animées, mais ne reposent pas encore tous sur une bibliothèque de fichiers GLB finalisés.

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

## Pipeline principal : TripoSR local, open source et sans quota

Le dépôt contient maintenant un workflow manuel :

```text
.github/workflows/generate-triposr-asset.yml
```

Il s’appuie sur **TripoSR**, dont le code et les poids sont distribués sous licence MIT. La génération s’exécute sur un runner GPU auto-hébergé : elle ne nécessite ni compte de génération, ni clé API, ni crédits. Le nombre de générations dépend uniquement du matériel local.

Le pipeline :

1. valide un manifeste et l’image source ;
2. exécute TripoSR localement ;
3. produit un maillage GLB ou OBJ ;
4. lance Blender en mode headless ;
5. décime et triangule le modèle ;
6. applique l’échelle métrique et place le pivot au sol ;
7. ajoute une collision boîte Godot facultative ;
8. contrôle la taille du GLB ;
9. crée un rapport de provenance ;
10. publie le résultat comme artifact GitHub pour revue manuelle.

Documentation complète :

```text
docs/TRIPOSR_GITHUB_PIPELINE.md
```

Manifeste préparé pour le premier essai :

```text
assets/concepts/specter_5/triposr.json
```

Il faut ajouter l’image isolée de SPECTER-5 ici :

```text
assets/concepts/specter_5/three_quarter.png
```

Le workflow possède deux modes :

- `validate` : s’exécute sur `ubuntu-latest`, sans GPU ni génération ;
- `generate` : s’exécute sur le runner local portant les labels `gpu` et `triposr`.

TripoSR fournit un blockout 3D détaillé, mais ne remplace pas le travail Blender nécessaire au rig, aux animations et aux UV de production.

## Pipeline Meshy optionnel

Le workflow Meshy existant reste disponible comme solution facultative :

```text
.github/workflows/generate-meshy-asset.yml
```

Il utilise `tools/meshy_generate.py`, produit un artifact pour revue manuelle et ne commite jamais automatiquement un modèle. Son mode `generate` nécessite cependant un compte, une clé `MESHY_API_KEY` et des crédits. Il n’est donc plus le pipeline principal.

Documentation :

```text
docs/MESHY_GITHUB_PIPELINE.md
```

## Choix selon le type d’asset

Utiliser TripoSR pour :

- SPECTER-5 ;
- CRAWLER-7 ;
- KITE-01 ;
- mascotte ToyGuard ;
- accessoires isolés ;
- volumes de référence pour la main et la lampe.

Utiliser Blender ou Blockbench pour :

- couloirs modulaires ;
- bunker S-01 ;
- sas et portes ;
- convoyeurs ;
- bras industriels ;
- décors avec dimensions et collisions précises.

Une salle générée comme un seul maillage serait difficile à optimiser, collisionner et faire évoluer selon le storyboard.
