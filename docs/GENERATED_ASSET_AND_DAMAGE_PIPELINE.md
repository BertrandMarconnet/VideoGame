# Pipeline générique d'assets et de destruction locale

## Entrée utilisateur

L'interface **Issues → Générer un asset de jeu** demande :

- la catégorie technique de l'asset ;
- une à six images de référence facultatives ;
- les dimensions métriques ;
- le matériau ;
- le rig et les animations ;
- le mode de destructibilité ;
- les zones critiques et les conséquences ;
- l'intégration souhaitée dans le jeu.

Le pipeline n'affirme pas reconstruire fidèlement toute géométrie cachée à partir d'une image. Les images guident la palette, les proportions et les textures d'écran. Un générateur contrôlé est sélectionné selon la catégorie : bipède, quadrupède, prop, mur, porte, environnement ou GUI 3D.

## Sorties

Chaque génération produit :

- un GLB ;
- un aperçu PNG ;
- un manifeste `.asset.json` ;
- un profil `.damage.json` ;
- des métriques ;
- un rapport de validation.

La génération est refusée lorsque le GLB est invalide, dépasse le budget, ne contient pas le rig attendu ou lorsque le profil de dégâts est incohérent.

## Passerelle Godot

`GeneratedAssetBridge` est un autoload déclaré dans `project.godot`. Il charge `assets/generated/catalog.json`, puis :

- attache automatiquement les GLB aux personnages existants ;
- masque uniquement les primitives visuelles, sans supprimer l'IA ni la collision de gameplay ;
- conserve la primitive comme solution de repli si le GLB manque ;
- attache un `DestructibleComponent` à chaque asset répertorié ;
- permet l'instanciation de props, portes et modules depuis n'importe quelle scène.

API principale :

```gdscript
var bridge := get_node("/root/GeneratedAssetBridge")
var instance := bridge.spawn_asset("asset_id", self, Transform3D.IDENTITY)
var result := bridge.apply_damage(target, {
    "amount": 20.0,
    "hit_position": hit_position,
    "tool_id": "crowbar",
    "damage_type": "impact",
    "impulse": Vector3.UP * 2.0
})
```

## Destruction selon le matériau

Les coefficients sont centralisés dans `data/material_response_db.json`.

- **placo** : sensible au pied-de-biche et aux impacts ;
- **brique** : résiste aux outils improvisés, mais cède à une charge de SPECTER ;
- **béton** : structurel ;
- **verre** : se brise facilement ;
- **bois** : rupture progressive ;
- **métal léger** : articulations et carrosseries ;
- **métal blindé** : corps principaux des robots.

## Robots

CRAWLER-7 possède quatre zones de pattes, un capteur et un corps. Chaque patte détruite réduit la vitesse. Le capteur détruit réduit la capacité de poursuite.

SPECTER-5 possède deux zones de jambes, un capteur et un torse. Une jambe détruite provoque une démarche dégradée ; deux jambes détruites activent le mode `crawl` et l'animation `Crawl-loop` lorsque le GLB généré est disponible.

## Murs

Les cloisons destructibles sont construites sous forme de cellules avec une collision propre. La rupture d'une cellule masque seulement sa géométrie et retire sa collision, ce qui ouvre un trou local. Les cloisons en placo et en brique utilisent des résistances différentes. Les murs porteurs restent monolithiques et non destructibles.

## Limites

Le système est conçu pour le style PS1/Web de Blackout Protocol. Il produit des assets cohérents et interactifs, mais il ne remplace pas une validation artistique. Une image complexe peut nécessiter un nouveau profil paramétrique plutôt qu'une reconstruction automatique incontrôlée.
