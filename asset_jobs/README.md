# Files d'attente du générateur Web

Ce dossier reçoit temporairement les images, sons et `request.json` envoyés par :

`https://bertrandmarconnet.github.io/VideoGame/asset-generator.html`

Le commit de soumission commence par `Submit asset job`. Le workflow `Generate game asset — unified` détecte alors la demande, génère et valide le bundle, publie celui-ci dans `assets/generated/<asset_id>/`, puis supprime le dossier temporaire du job dans le même commit que la sortie.

Le fichier `.gdignore` empêche Godot d'importer ces entrées temporaires.

Ne pas placer manuellement des ressources de production ici.
