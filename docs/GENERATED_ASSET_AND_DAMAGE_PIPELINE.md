# Pipeline générique d'assets, d'intégration et de destruction locale

## Interface unique

L'unique entrée utilisateur est **Issues → Générer un asset de jeu**.

Le formulaire accepte de une à six images et demande :

- la catégorie technique ;
- le type de références : vue principale, quatre vues orthographiques, vues libres ou storyboard ;
- les dimensions métriques ;
- la structure géométrique ;
- les parties à séparer ;
- le matériau ;
- le mode de texture ;
- le rig et les animations ;
- la collision Godot ;
- la destructibilité et les zones critiques ;
- l'intégration souhaitée.

L'issue est fermée automatiquement uniquement après validation du GLB, du manifeste, du profil de dégâts et de l'import Godot.

## Familles prises en charge

| Catégorie | Géométrie | Rig / animation | Segmentation et dégâts |
|---|---|---|---|
| Robot bipède | générateur bipède ou profil SPECTER-5 | bipède, marche, course, attaque, crawl, arrêt | membres, capteur, torse |
| Robot quadrupède | générateur quadrupède ou profil CRAWLER-7 | quadrupède, marche, course, attaque, arrêt | quatre pattes, capteur, corps |
| Personnage humanoïde | silhouette humanoïde PS1 | squelette humanoïde et clips locomoteurs | tête, torse et membres |
| Vue FPS main + objet | main gantée et outil tenu | avant-bras, main et outil ; idle/use/bash/inspect | corps de l'outil, lentille, batterie |
| Machine articulée | base, colonne, bras, poignet et outil | rig mécanique ; travail, alarme, arrêt | bras, outil et capteur |
| Prop interactif | monobloc ou pièces listées dans le formulaire | rig rigide optionnel | une zone par partie séparée |
| Mur | cellules modulaires | aucun rig | trou local et retrait de collision par cellule |
| Porte / sas | cadre, panneau, verrou | charnière ; open/close | panneau et verrou séparés |
| Environnement | sol, panneaux, parois et accessoires modulaires | éléments mobiles optionnels | matériaux structurels ou destructibles |
| Console / GUI 3D | boîtier et écran | animation facultative | écran en verre indépendant |

## Utilisation des images

Les images sont réellement utilisées pour :

- extraire une palette commune jusqu'à six références ;
- produire un atlas pixelisé PS1 intégré au GLB ;
- utiliser la première image comme texture d'écran lorsqu'un GUI est demandé ;
- harmoniser les matériaux et la lecture visuelle ;
- guider les dimensions et la segmentation saisies dans le formulaire.

Le système ne prétend pas reconstruire automatiquement chaque détail caché. La géométrie est générée par profil contrôlé afin de conserver des pivots, des noms de pièces, un rig et des zones de dégâts utilisables dans le jeu.

## Sorties

Chaque génération validée produit dans `assets/generated/<asset_id>/` :

- `<asset_id>.glb` ;
- `<asset_id>.png` ;
- `<asset_id>.asset.json` ;
- `<asset_id>.damage.json` ;
- `<asset_id>.metrics.json` ;
- `<asset_id>.validation.json`.

Le catalogue central est `assets/generated/catalog.json`.

## Passerelle Godot

`GeneratedAssetBridge` est un autoload déclaré dans `project.godot`.

Il permet :

- le remplacement visuel d'une primitive sans supprimer l'IA ou les collisions de gameplay ;
- l'instanciation de props, portes, machines, environnements et GUI ;
- le montage d'une vue FPS sous une `Camera3D` ;
- l'attachement automatique d'un `DestructibleComponent` ;
- le rechargement et l'interrogation du catalogue.

```gdscript
var bridge := get_node("/root/GeneratedAssetBridge")

var prop := bridge.spawn_asset(
    "industrial_crate",
    self,
    Transform3D(Basis.IDENTITY, Vector3(2.0, 0.0, -4.0))
)

var viewmodel := bridge.spawn_fps_viewmodel(
    "flashlight_right_hand",
    $Player/Camera3D,
    Transform3D(Basis.IDENTITY, Vector3(0.22, -0.22, -0.52))
)

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
- **béton** : structurel et non destructible par les outils courants ;
- **verre** : rupture rapide ;
- **bois** : rupture progressive ;
- **plastique technique** : fissuration et perte de fonction ;
- **caoutchouc / tissu technique** : faible transmission des impacts ;
- **métal léger** : articulations et carrosseries ;
- **métal blindé** : corps principaux et portes renforcées.

## Validation obligatoire

Un asset n'est pas ajouté à `main` lorsque :

- le GLB est invalide ou hors budget ;
- le rig attendu est absent ;
- le nombre de clips est insuffisant ;
- les zones de dégâts sont incohérentes ;
- les métadonnées de texture ou de collision sont invalides ;
- l'import Godot 4.7 échoue.

Les tests de pull request couvrent les robots, personnages, vue FPS, machines, props, murs, portes, modules d'environnement et GUI.

## Limite assumée

Le système vise les besoins récurrents de Blackout Protocol et le style PS1/Web. Il produit des assets structurés, texturés et interactifs. Une forme très spécifique peut encore nécessiter l'ajout d'un profil paramétrique dédié : cette extension doit passer par les mêmes tests avant utilisation dans le jeu.
