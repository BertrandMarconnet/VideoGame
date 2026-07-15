# Assets générés et intégrables

Chaque asset validé possède son propre dossier :

```text
assets/generated/<slug>/
├── <slug>.glb
├── <slug>.png
├── <slug>.asset.json
├── <slug>.damage.json
├── <slug>.metrics.json
└── <slug>.validation.json
```

Le fichier `catalog.json` est l'unique point d'entrée du jeu. L'autoload `GeneratedAssetBridge` :

1. charge le catalogue ;
2. remplace un modèle procédural lorsque l'entrée demande `replace_procedural` ;
3. conserve le modèle procédural si le GLB manque ou ne peut pas être importé ;
4. attache le profil de dégâts localisés ;
5. expose les assets instanciables aux scènes Godot.

## Règles

- ne pas ajouter manuellement un GLB au catalogue sans rapport de validation ;
- conserver une collision simple et un budget Web/mobile ;
- un robot destructible doit posséder des zones nommées et un rig rigide ;
- un mur destructible doit être segmenté : aucun booléen ne peut créer un vrai trou dans une collision monolithique ;
- les murs en béton porteur restent structurels et non destructibles par les outils improvisés.
