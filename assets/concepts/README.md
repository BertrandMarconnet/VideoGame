# Concepts d'assets pour génération 3D

Chaque asset destiné à Meshy possède son propre dossier contenant :

- une à quatre images PNG/JPEG ;
- un fichier `meshy.json` ;
- un README décrivant la forme, les vues et le budget.

## Structure recommandée

```text
assets/concepts/
└── specter_5/
    ├── front.png
    ├── right.png
    ├── back.png
    ├── three_quarter.png
    ├── meshy.json
    └── README.md
```

Les images peuvent également être remplacées dans le manifeste par des URL publiques HTTPS. Les fichiers locaux sont transformés en Data URI par le workflow afin de ne pas nécessiter d'hébergement externe.

## Ordre de production conseillé

1. main gantée + lampe FPS ;
2. SPECTER-5 ;
3. CRAWLER-7 ;
4. KITE-01 ;
5. mascotte ToyGuard ;
6. porte extérieure et sas S-01 ;
7. kit couloir modulaire ;
8. kit bunker S-01 ;
9. bras industriel six axes ;
10. jouets semi-assemblés.

Un modèle généré n'est jamais considéré comme prêt pour le jeu. Il doit être contrôlé dans Blender, optimisé, documenté et validé dans Godot Web avant d'être placé dans `assets/production/validated/`.
