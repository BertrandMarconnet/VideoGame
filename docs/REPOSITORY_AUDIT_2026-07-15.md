# Audit ciblé du pipeline 3D — 15 juillet 2026

## Résultat du pipeline historique

Le test CRAWLER-7 a confirmé que le pipeline TripoSR monoculaire pouvait produire un fichier GLB
techniquement importable, mais sans fidélité, segmentation mécanique, rig, animations ou matériaux
suffisants pour le jeu. Le fichier historique est conservé uniquement pour traçabilité et marqué comme
non destiné à la production.

## Mesures correctives

- ajout d'un générateur Blender déterministe spécifique à CRAWLER-7 ;
- séparation rigide des pièces mécaniques ;
- ajout d'une armature quadrupède ;
- ajout de cinq clips d'animation ;
- ajout de matériaux métalliques et d'une texture procédurale embarquée ;
- ajout de collisions simplifiées ;
- génération d'un aperçu PNG ;
- contrôle par réimport Blender ;
- contrôle des os, animations, matériaux et triangles ;
- contrôle de l'import Godot 4.7 ;
- commit du GLB uniquement après réussite de tous les contrôles.

## Sécurité et reproductibilité

- aucune clé API ;
- aucune commande fournie par l'utilisateur n'est exécutée ;
- déclenchement depuis une issue réservé au propriétaire du dépôt ;
- dépendance principale limitée à Blender installé sur le runner GitHub ;
- sortie déterministe et reproductible ;
- provenance écrite avec chaque asset.

## Limite assumée

Ce pipeline ne transforme pas arbitrairement toute image en modèle 3D. Il génère un robot connu à
partir d'une spécification de design. C'est le compromis retenu pour garantir un asset segmenté,
riggé, animé et utilisable dans un jeu Web low-poly sans infrastructure GPU payante.
