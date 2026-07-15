# Décision technique — génération 3D open source

## Constat du test CRAWLER-7

Le premier pipeline TripoSR a produit un maillage statique très éloigné du concept : silhouette
mal reconstruite, aucune segmentation mécanique exploitable, aucune armature, aucune animation et
aucun matériau de production. Ce résultat ne doit pas remplacer un asset de jeu.

## État des solutions open source examinées

- **Hunyuan3D-2mv** : meilleure option open source pour une reconstruction multivue texturée, mais
  elle exige un GPU NVIDIA et une quantité de VRAM incompatible avec un runner GitHub CPU standard.
- **TRELLIS** : génération texturée de bonne qualité, mais nécessite également un GPU NVIDIA important ;
  le multivue est expérimental et ne garantit pas un robot segmenté ou riggé.
- **TripoSG** : reconstruction géométrique plus fidèle que TripoSR, mais reste un générateur de forme
  monoculaire et ne fournit ni texture complète, ni rig, ni clips d'animation.
- **UniRig** : peut créer squelette et skinning sur un maillage existant, mais demande un GPU CUDA et
  ne crée pas les animations de gameplay.

Aucun projet open source disponible ne fournit, sur un runner CPU gratuit, la chaîne complète
`images -> géométrie fidèle -> segmentation mécanique -> matériaux -> rig -> animations -> GLB Godot`.

## Compromis retenu pour Blackout Protocol

Pour les robots mécaniques principaux, le dépôt utilise désormais un générateur Blender déterministe
spécifique au design. Il ne prétend pas reconstruire arbitrairement une image. Il garantit plutôt les
propriétés nécessaires au jeu :

- membres séparés et pivots cohérents ;
- armature quadrupède rigide ;
- matériaux métalliques PS1 industriels ;
- capteurs rouges émissifs ;
- collisions simplifiées ;
- clips `Idle-loop`, `Walk-loop`, `Run-loop`, `Attack` et `Shutdown` ;
- export GLB contrôlé et réimporté avant validation ;
- fonctionnement sans clé API, sans compte fournisseur et sans limite commerciale.

Hunyuan3D-2mv ou TRELLIS pourront être ajoutés ultérieurement comme mode GPU optionnel pour produire
une base visuelle détaillée. Ils ne seront pas activés comme pipeline principal tant qu'un runner GPU
fiable et un test comparatif réussi ne sont pas disponibles.
