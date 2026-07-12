# Concepts d'assets pour génération 3D

Chaque dossier représente un asset isolé. Les images doivent être originales ou accompagnées d'une licence compatible avec le projet.

## Pipeline principal : TripoSR

TripoSR utilise une image principale :

- un seul objet ;
- fond uni ou transparent ;
- vue trois-quarts recommandée ;
- objet entièrement visible ;
- pas de décor ;
- pas de texte, logo ou élément provenant d'une franchise ;
- silhouette cohérente avec le storyboard ;
- PNG, JPEG ou WebP.

Structure minimale :

```text
assets/concepts/
└── specter_5/
    ├── three_quarter.png
    ├── triposr.json
    ├── meshy.json
    └── README.md
```

Le manifeste TripoSR préparé se trouve ici :

```text
assets/concepts/specter_5/triposr.json
```

Le workflow local et sans quota produit uniquement un artifact de revue. Aucun GLB n'est ajouté automatiquement au jeu.

## Pipeline Meshy optionnel

Meshy peut utiliser une à quatre images :

```text
front.png
right.png
back.png
three_quarter.png
```

Le fichier `meshy.json` reste disponible, mais la génération nécessite un compte, une clé API et des crédits.

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

TripoSR convient surtout aux objets isolés et aux robots. Les kits de couloirs, sas, portes, convoyeurs et salles doivent être construits dans Blender ou Blockbench pour conserver leurs dimensions, leur modularité et leurs collisions.

Un modèle généré n'est jamais considéré comme prêt pour le jeu. Il doit être contrôlé dans Blender, optimisé, documenté et validé dans Godot Web avant d'être placé dans `assets/production/validated/`.
