# Audit du pipeline d'assets et de destruction — 15 juillet 2026

## Pipeline historique retiré

Le test CRAWLER-7 a confirmé que le pipeline TripoSR monoculaire pouvait produire un fichier GLB techniquement importable, mais sans fidélité, segmentation mécanique, rig, animations ou matériaux suffisants pour le jeu. Le workflow, le formulaire et les sorties trompeuses associés à cette reconstruction ont été retirés du flux de production.

## Pipeline actuel

Le dépôt contient maintenant un générateur contrôlé par catégorie pour :

- robots bipèdes ;
- robots quadrupèdes ;
- props interactifs ;
- murs et cloisons modulaires ;
- portes et sas ;
- modules d'environnement ;
- consoles, écrans et GUI 3D.

Le formulaire **Générer un asset de jeu** accepte une à six images, des dimensions métriques, le matériau, le rig, les animations, le niveau de destructibilité, les zones critiques et la méthode d'intégration. Les images servent à la palette, aux proportions et aux textures d'écran. La géométrie est produite par un générateur paramétrique adapté à la catégorie.

## Assets validés dans `main`

### CRAWLER-7

- générateur hard-surface spécialisé ;
- 13 os ;
- cinq animations ;
- quatre pattes destructibles ;
- capteurs neutralisables ;
- vitesse réduite selon les pattes perdues ;
- GLB remplaçant automatiquement la primitive visuelle, avec repli procédural.

### SPECTER-5

- 3 636 triangles ;
- 14 os ;
- six animations : idle, marche, course, attaque, ramping et shutdown ;
- 59 pièces visuelles ;
- jambes détachables ;
- mode rampant après destruction des deux jambes ;
- capteur et torse traités comme zones indépendantes.

### Cloison placo atelier assemblage

- 1 068 triangles ;
- 24 cellules localement destructibles ;
- collision indépendante par cellule ;
- ouverture d'un vrai trou local après rupture ;
- résistance matérielle distincte de la brique et du béton.

## Passerelle vers Godot

`GeneratedAssetBridge` charge `assets/generated/catalog.json`, instancie les GLB validés, attache les profils `.damage.json` et masque uniquement les primitives visuelles remplacées. Les collisions de gameplay, l'IA et les comportements existants sont conservés. Lorsqu'un GLB manque ou ne peut pas être importé, le substitut procédural reste visible.

## Destruction et matériaux

La base `data/material_response_db.json` différencie :

- placo ;
- brique ;
- béton ;
- verre ;
- bois ;
- plastique technique ;
- métal léger ;
- métal blindé.

Les outils et forces possèdent des multiplicateurs distincts : lampe utilisée comme arme improvisée, planche, pied-de-biche, objet lancé et charge de SPECTER. Le béton porteur reste structurel. Le pied-de-biche est efficace sur le placo, mais peu efficace sur la brique. Une charge de SPECTER peut traverser une maçonnerie non porteuse.

## Contrôles obligatoires

Avant tout commit automatique d'un asset :

1. validation de la requête et des chemins ;
2. génération Blender ;
3. contrôle de l'en-tête GLB ;
4. contrôle du budget de triangles ;
5. contrôle du rig et des animations pour les robots ;
6. contrôle du manifeste `.asset.json` ;
7. contrôle du profil `.damage.json` ;
8. import Godot 4.7 ;
9. mise à jour déterministe du catalogue ;
10. fermeture automatique de l'issue uniquement après réussite.

## Sécurité et reproductibilité

- aucune clé API ;
- aucune commande libre fournie par l'utilisateur n'est exécutée ;
- déclenchement des générations réservé au propriétaire du dépôt ;
- téléchargement d'images limité aux hôtes GitHub autorisés ;
- taille et nombre d'images limités ;
- noms et chemins normalisés ;
- dépendance principale limitée à Blender et Godot sur le runner GitHub ;
- génération reproductible et profils versionnés ;
- conservation d'un modèle procédural de repli.

## Validation réalisée

Les smoke tests SPECTER-5, mur placo et prop ont réussi. Le test Godot de dégâts localisés a confirmé les différences de matériaux, l'ouverture d'un trou physique dans une cellule de mur et le passage de SPECTER en mode rampant. Le pipeline complet a également validé GDScript, l'import Godot 4.7, le démarrage natif, l'export Web/PWA et le rendu Firefox WebGL2 logiciel avant fusion.

## Limite assumée

Le système ne prétend pas reconstruire parfaitement toute géométrie cachée à partir d'une image. Il transforme une demande catégorisée en asset low-poly contrôlé, riggé et interactif. Cette limite est volontaire : elle évite les volumes incohérents et garantit une intégration exploitable dans Blackout Protocol.