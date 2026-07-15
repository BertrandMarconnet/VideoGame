# CRAWLER-7 — générateur de production

## Interface simple

Ouvrir **Issues -> New issue -> Générer CRAWLER-7 production**, cocher la confirmation et valider.
Aucune image, clé API ou installation locale n'est demandée.

Le workflow crée puis contrôle :

- `assets/output 3d model/crawler_7_production.glb` ;
- `assets/output 3d model/crawler_7_production.png` ;
- `assets/output 3d model/crawler_7_production.metrics.json` ;
- `assets/output 3d model/crawler_7_production.validation.json` ;
- `assets/output 3d model/crawler_7_production.PROVENANCE.md`.

## Critères bloquants

Le modèle n'est ajouté au dépôt que si le GLB réimporté contient :

- au moins un maillage ;
- une armature ;
- au moins 13 os ;
- au moins cinq animations ;
- au moins quatre matériaux ;
- une géométrie triangulée non vide ;
- un import Godot 4.7 sans erreur bloquante.

## Nature du générateur

Il s'agit d'un générateur Blender hard-surface déterministe, spécifique au robot CRAWLER-7. Les
pièces mécaniques sont parentées rigidement aux os : elles pivotent sans déformation organique. Cette
approche est adaptée aux robots PS1 low-poly et permet de reproduire le même asset à chaque exécution.

## Extension

Le même cadre sera décliné pour SPECTER-5 et KITE-01 après validation visuelle du premier GLB CRAWLER-7.
