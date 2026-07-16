# Archives de références 3D

Ce dossier conserve uniquement d'anciens concepts et manifestes de référence.

Il **ne déclenche plus aucun workflow** et ne doit plus être utilisé comme interface de génération. Les anciens scripts TripoSR/Open3D associés ont été supprimés, car ils produisaient des maillages insuffisamment fidèles et non exploitables pour le rig et les dégâts localisés.

## Interface active

Utiliser exclusivement :

```text
GitHub → Issues → New issue → Générer un asset de jeu
```

Le formulaire actif permet de joindre une à six images, puis de choisir :

- la catégorie ;
- les dimensions ;
- les parties à segmenter ;
- le matériau et la texture ;
- le rig et les animations ;
- les collisions ;
- les dégâts localisés ;
- l'intégration Godot.

Les sorties validées sont écrites dans :

```text
assets/generated/<asset_id>/
```

Les SVG et JSON présents sous `assets/asset_inbox/` sont conservés comme documentation visuelle historique. Ils peuvent être joints à une nouvelle issue, mais ils ne sont plus traités automatiquement depuis ce dossier.
