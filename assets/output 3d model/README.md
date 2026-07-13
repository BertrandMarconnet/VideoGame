# output 3d model

Les modèles générés par l’action GitHub **Generate 3D model** sont placés ici au format GLB.

Exemple :

```text
assets/Input image/specter_5/
→ assets/output 3d model/specter_5.glb
```

Le workflow ajoute également :

- `catalog.json` : liste des assets, images sources, moteur utilisé et chemins de sortie ;
- `<asset>.metrics.json` : informations de génération ;
- `<asset>.PROVENANCE.md` avec TripoSR lorsqu’il est disponible.

Les GLB restent des candidats de production. Avant intégration définitive dans Godot, vérifier dans Blender : topologie, UV, échelle, origine au sol, rig, animations et collisions.
