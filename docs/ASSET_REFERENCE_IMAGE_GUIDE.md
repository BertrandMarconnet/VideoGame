# Guide des images de référence pour générer un asset 3D viable

Ce guide accompagne le formulaire **Issues → Générer un asset de jeu**. Son objectif est d'améliorer la cohérence géométrique, la segmentation, le rig, les textures et l'intégration dans Godot 4.7/Jolt/Web.

## Règles communes à toutes les catégories

Pour maximiser la qualité :

1. montrer un seul asset complet par image ;
2. utiliser le même modèle, les mêmes proportions, les mêmes couleurs et les mêmes accessoires sur toutes les vues ;
3. conserver un fond uni, mat et contrasté avec l'objet ;
4. éviter les ombres dures, les reflets spéculaires brûlés, le brouillard et les effets cinématographiques ;
5. cadrer entièrement l'objet, sans couper les pieds, outils, antennes ou extrémités ;
6. privilégier une focale neutre : pas de grand-angle, fish-eye ou perspective exagérée ;
7. utiliser une résolution d'au moins 1024 × 1024 pixels lorsque possible ;
8. ne pas mélanger plusieurs variantes du même objet dans une même série ;
9. fournir les dimensions réelles en mètres dans le formulaire ;
10. nommer explicitement les parties à séparer, articuler ou rendre destructibles.

Les formats conseillés sont PNG, JPG, JPEG ou WebP. Éviter les captures très compressées, les images floues et les arrière-plans complexes.

## Robot bipède

### Pack recommandé

- vue de face orthographique ;
- vue de droite orthographique ;
- vue arrière orthographique ;
- vue trois-quarts avant ;
- en option : vue de gauche et gros plans des articulations, du capteur et des mains/outils.

### Pose

Utiliser une pose neutre avec les jambes légèrement écartées et les bras décollés du torse. Une A-pose mécanique est préférable à une T-pose stricte pour conserver une lecture claire des épaules et des câbles.

### Points à rendre visibles

- axes de rotation des épaules, coudes, poignets, hanches, genoux et chevilles ;
- séparation entre blindage et articulation ;
- capteurs, lentilles et câbles ;
- pièces détachables ;
- face avant et face arrière du torse.

### À éviter

- jambes ou bras superposés ;
- pose d'attaque ;
- arme cachant le torse ;
- pièces asymétriques absentes des vues opposées ;
- perspective très basse ou contre-plongée.

## Robot quadrupède

### Pack recommandé

- face ;
- profil droit ;
- arrière ;
- trois-quarts légèrement surélevé ;
- en option : vue de dessus et gros plans des pattes.

### Pose

Les quatre pattes doivent être visibles, séparées et en position neutre. Éviter qu'une patte masque celle située derrière.

### Informations importantes

Préciser dans le formulaire :

- l'ordre des pattes : avant gauche, avant droite, arrière gauche, arrière droite ;
- les articulations attendues ;
- la hauteur du corps par rapport au sol ;
- les parties qui peuvent être détruites ou détachées.

## Personnage humanoïde

### Pack recommandé

- face en A-pose ;
- profil droit ;
- dos ;
- trois-quarts avant ;
- en option : visage, mains, chaussures et accessoires séparés.

### Pose et vêtements

- bras légèrement écartés ;
- doigts lisibles ou regroupés proprement selon le style low-poly ;
- jambes droites et non croisées ;
- vêtements sans plis extrêmes ;
- sac, holster, casque ou outil visibles dans plusieurs vues.

### À préciser

- taille réelle ;
- silhouette masculine, féminine ou neutre ;
- tenue ;
- accessoires fixes ou détachables ;
- animations nécessaires : idle, walk, run, crouch, interact, fall, etc.

## Vue FPS : main + objet

### Pack recommandé

- vue principale depuis la caméra du joueur ;
- profil de la main et de l'objet ;
- vue de dessus ;
- vue de dessous ou arrière de la poignée ;
- gros plan de la prise en main ;
- image séparée de l'objet seul si sa forme est complexe.

### Points critiques

- montrer clairement quels doigts entourent la poignée ;
- éviter que la main masque entièrement l'objet ;
- conserver le poignet et une partie de l'avant-bras ;
- indiquer si l'objet est utilisé à droite, à gauche ou à deux mains ;
- préciser les animations : idle, use, bash, inspect, reload, switch, etc.

Pour une lampe, fournir si possible des vues distinctes de la lentille, de la batterie, de l'interrupteur et du corps principal.

## Machine ou bras industriel articulé

### Pack recommandé

- face ;
- profil ;
- arrière ;
- trois-quarts ;
- vue de dessus ;
- gros plans de la base, des axes, du poignet et de l'outil terminal.

### Informations indispensables

- axes de rotation ;
- limites approximatives de chaque articulation ;
- pièce fixe et pièces mobiles ;
- outil terminal interchangeable ou non ;
- zones de collision ;
- animations attendues : idle, work, alarm, shutdown, maintenance, etc.

Les articulations doivent être visibles et ne pas être confondues avec des pièces décoratives.

## Prop ou objet interactif

### Objet simple

Une vue trois-quarts nette peut suffire, mais deux ou trois vues sont préférables : trois-quarts, profil et arrière.

### Objet complexe ou segmenté

Ajouter :

- face ;
- profil ;
- arrière ;
- dessus ;
- dessous si nécessaire ;
- gros plans des poignées, boutons, charnières et pièces détachables.

Préciser les parties séparées, par exemple : corps, couvercle, poignée, batterie, lentille, verrou, câble ou panneau.

## Mur, cloison ou module d'environnement

### Pack recommandé

- élévation frontale orthographique ;
- face arrière ;
- vue de côté indiquant l'épaisseur ;
- trois-quarts ;
- gros plan de texture ;
- schéma avec dimensions et répétition modulaire.

### Pour la destruction locale

Indiquer :

- matériau principal ;
- présence d'une ossature ;
- épaisseur ;
- taille souhaitée des cellules destructibles ;
- parties structurelles non destructibles ;
- type de rupture : trou local, panneaux détachables, briques, éclats, etc.

Éviter les images de scène trop larges où le mur n'occupe qu'une petite partie du cadre.

## Porte ou sas

### Pack recommandé

- face fermée ;
- arrière ;
- profil avec épaisseur ;
- trois-quarts ouvert si disponible ;
- gros plan du verrou, des charnières et du mécanisme.

### À préciser

- axe et sens d'ouverture ;
- angle maximal ;
- partie fixe et partie mobile ;
- verrou destructible ou non ;
- animation coulissante, battante, verticale ou segmentée ;
- dimensions de passage utiles.

## Console, écran ou GUI 3D

### Pack recommandé

- face orthographique ;
- profil ;
- trois-quarts ;
- arrière si les connexions sont visibles ;
- image séparée et parfaitement frontale du contenu affiché à l'écran.

### Pour l'écran

Fournir de préférence une image sans perspective, sans reflet et sans cadre autour du contenu. Le texte doit rester lisible après réduction en texture 1K ou 512 px.

Préciser si l'écran doit être :

- fixe ;
- animé ;
- interactif ;
- destructible ;
- émissif ;
- remplacé dynamiquement par une interface Godot.

## Véhicule, drone ou objet volant

Utiliser :

- face ;
- profil ;
- arrière ;
- dessus ;
- dessous ;
- trois-quarts ;
- gros plans des rotors, roues, chenilles, capteurs ou armes.

Préciser le centre de masse, les parties mobiles, les surfaces de collision et les animations mécaniques.

## Cohérence entre les vues

Avant de soumettre l'issue, vérifier que :

- le nombre de doigts, roues, capteurs, articulations et panneaux ne change pas ;
- les proportions restent identiques ;
- les couleurs et matériaux sont cohérents ;
- les accessoires sont présents dans toutes les vues pertinentes ;
- les vues ne montrent pas différentes versions du concept ;
- l'avant, l'arrière, la gauche et la droite sont identifiables.

## Niveau de confiance attendu

- **4 à 6 vues cohérentes** : meilleure base pour un asset riggé et segmenté ;
- **2 à 3 vues** : généralement viable pour un prop ou une machine simple ;
- **1 vue** : interprétation plus forte et risque accru d'erreur sur l'arrière, la profondeur et les articulations ;
- **storyboard seul** : utile pour l'ambiance, mais insuffisant pour reproduire précisément une géométrie complexe.

Le pipeline reste orienté vers des assets low-poly PS1/Web structurés. Une forme très spécifique peut nécessiter un profil paramétrique dédié après une première génération de contrôle.
