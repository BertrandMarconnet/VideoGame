# SPECTER-5 — pack de références image-vers-3D

Contenu prévu dans ce dossier :

- `front.png` : face orthographique ;
- `right.png` : profil droit orthographique ;
- `back.png` : vue arrière orthographique ;
- `three_quarter.png` : trois-quarts avant droit ;
- `specter_5.json` : cible d'intégration et budget ;
- `meshy_prompt.txt` : prompt et exclusions.

## Paramètres visés

- GLB ;
- environ 12 000 polygones ;
- hauteur : 2,45 m ;
- texture base color 1K ;
- origine au sol ;
- rig bipède ;
- collision Godot : capsule principale et boîtes locales.

## Remarque importante

Les vues ont été extraites et nettoyées à partir du storyboard fourni. La pose source reste proche d'une pose neutre, avec les bras relativement bas. Dans Meshy, demander explicitement `A-pose`. Pour TripoSR, Stable Fast 3D, InstantMesh ou Hunyuan3D, générer d'abord la géométrie, puis corriger la pose et le rig dans Blender avant l'export GLB final.
