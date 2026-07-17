# Blackout Protocol: Steel Echo — Storyboard v19

Vertical slice jouable d’un survival-horror industriel en vue subjective, développée avec Godot 4.7, Jolt Physics et publiée automatiquement en Web/PWA.

## Jouer en ligne

**https://bertrandmarconnet.github.io/VideoGame/**

## Générer un asset 3D

**Interface directe avec analyse automatique des images et lancement GitHub Actions :**

**https://bertrandmarconnet.github.io/VideoGame/asset-generator.html**

Le fonctionnement normal ne passe plus par un formulaire GitHub :

1. connecter GitHub une seule fois avec un jeton à granularité fine limité au dépôt `VideoGame` et à la permission `Contents: Read and write` ;
2. charger de une à six images ;
3. laisser le moteur de vision local reconnaître la famille d’asset ;
4. vérifier ou décocher les mouvements, sons, matériaux et parties destructibles proposés ;
5. cliquer sur **Générer le modèle 3D**.

L’interface envoie toutes les images et toute la configuration dans un unique job, puis le commit `Submit asset job …` déclenche automatiquement le workflow. L’utilisateur ne doit rien ressaisir dans Issues ou Actions.

Le formulaire GitHub est conservé uniquement comme solution de secours :

**https://github.com/BertrandMarconnet/VideoGame/issues/new?template=generate-game-asset.yml**

Après un déploiement, utiliser `Ctrl+F5` une seule fois afin d’éviter qu’un ancien export Web reste dans le cache du navigateur.

## Canon du premier chapitre

En septembre 1987, **ToyGuard Industries**, à New Halcyon, fabrique officiellement des jouets intelligents tout en développant clandestinement des plateformes autonomes pour le programme militaire **PERSEUS**.

L’opération soviétique **MATRYOSHKA** et le malware **BABOUCHKA** contaminent le complexe. Pour résister, l’IA militaire **ATHENA** fusionne plusieurs systèmes de sécurité et développe une proto-conscience. Le joueur incarne **Alex Mercer**, analyste en contre-mesures affecté au bunker **S-01**. Ses décisions influencent l’empathie, la discipline, la confiance et le développement cognitif d’ATHENA.

**Project Daedalus**, Blacklake, Paul Merrick, DAEDALUS, DELTA-00 et la salle Hermès restent réservés à une extension ou à un chapitre ultérieur. Ils ne remplacent pas le canon ToyGuard de 1987.

## Storyboard — Acte I

La campagne commence à l’extérieur de ToyGuard Industries, sous la pluie. Le parcours suit l’ordre narratif prévu :

1. arrivée nocturne devant la façade ToyGuard ;
2. progression vers la porte de service latérale ;
3. traversée du sas de décontamination et de la porte blindée S-01 ;
4. arrivée par un vestibule latéral ;
5. consultation de Sentinel OS ;
6. première patrouille dans les secteurs logistique et assemblage ;
7. observation des unités ToyGuard ;
8. déploiement de KITE-01 ;
9. premier contact contrôlé avec ATHENA ;
10. réparation du relais nord.

## Direction artistique PS1 industrial low-poly

- géométrie simple et silhouettes lisibles ;
- matériaux mats, couleurs quantifiées et éclairage cyan/ambre/rouge ;
- pluie optimisée pour smartphone ;
- lampe et main low-poly visibles en vue subjective ;
- filtrage nearest, ombrage par sommet et palette réduite ;
- pixelisation, scanlines, bruit et vignettage subtils appliqués au monde 3D.

## Systèmes conservés

- déplacement ZQSD/WASD et contrôles tactiles ;
- interactions clic gauche, `E` et roue d’actions ;
- tablette Sentinel OS ;
- KITE-01 ;
- SPECTER-5 et CRAWLER-7 ;
- destruction locale et objets physiques Jolt ;
- campagne de cinq rondes ;
- directeur narratif local d’ATHENA ;
- bande-son adaptative.

## Commandes PC

- `ZQSD` / `WASD` : déplacement ;
- souris : caméra ;
- clic gauche : interaction ou scan KITE ;
- clic droit : roue d’actions ou rappel du drone ;
- `E` : interaction rapide ;
- `Tab` : tablette Sentinel ;
- `F` : lampe ;
- `Espace` : saut ou montée avec le drone ;
- `Maj` : course ;
- `Ctrl` : se baisser à pied / descendre avec KITE-01 ;
- `C` : déployer ou rappeler KITE-01 ;
- `Échap` : retour joueur, fermeture d’interface ou pause.

## Générateur unifié d'assets

Le moteur de détection utilise une classification visuelle zéro-shot exécutée localement dans le navigateur, complétée par les noms de fichiers et le nombre de vues. Il propose automatiquement :

- robots bipèdes et quadrupèdes ;
- personnages humanoïdes low-poly ;
- vues FPS avec main et outil ;
- machines et bras industriels articulés ;
- props monoblocs ou segmentés ;
- murs destructibles par cellules ;
- portes et sas animés ;
- modules d'environnement ;
- consoles, écrans et GUI 3D.

Pour chaque famille, l’interface préremplit les dimensions, le matériau, le rig, les animations, les sons, les collisions, la destructibilité, les zones fonctionnelles et l’intégration Godot. L’utilisateur reste décisionnaire et peut tout corriger avant la génération.

Les images servent à la reconnaissance, à l’extraction de palette, à la production d’un atlas PS1 et, pour les interfaces, à la texture de l’écran. La géométrie reste produite par un générateur contrôlé adapté à la catégorie afin de conserver des pivots, des pièces nommées, un rig et des zones de dégâts exploitables.

Les demandes temporaires sont déposées dans `asset_jobs/<job_id>/`, exclues de l’import Godot par `.gdignore`, puis supprimées automatiquement après publication du bundle.

Chaque asset validé est placé dans :

```text
assets/generated/<asset>/
```

Le bundle contient le GLB, l'aperçu, les métriques, le manifeste `.asset.json`, les profils `.damage.json` et `.audio.json`, ainsi qu’un rapport de validation. Le catalogue `assets/generated/catalog.json` est chargé automatiquement par l’autoload `GeneratedAssetBridge`.

La passerelle permet notamment :

```gdscript
var bridge := get_node("/root/GeneratedAssetBridge")
var prop := bridge.spawn_asset("asset_id", self, Transform3D.IDENTITY)
var viewmodel := bridge.spawn_fps_viewmodel("flashlight_right_hand", $Player/Camera3D)
```

## Destruction localisée

- CRAWLER-7 ralentit lorsqu'une patte est détruite ;
- SPECTER-5 peut perdre une jambe, puis ramper si les deux jambes sont coupées ;
- les capteurs, lentilles, batteries, outils et articulations peuvent être neutralisés indépendamment ;
- le placo, la brique, le béton, le verre, le bois, les plastiques, tissus techniques et métaux réagissent différemment ;
- les murs destructibles sont segmentés afin qu'un impact ouvre un trou local plutôt que supprimer toute la paroi ;
- le pied-de-biche est efficace sur le placo, beaucoup moins sur la brique ;
- une charge de SPECTER peut traverser certaines maçonneries non porteuses.

Les modèles procéduraux restent disponibles comme solution de repli lorsque le GLB n'existe pas ou ne passe pas la validation.

## Limite assumée

La détection choisit une famille et des réglages, mais ne peut pas garantir une interprétation parfaite d’une image ambiguë. Le pipeline produit une géométrie structurée et reproductible adaptée au style PS1/Web ; une forme très spécifique peut demander un profil paramétrique dédié.

## Validation

Le déploiement reconstruit `scripts/main.gd`, exécute `gdlint`, importe le projet avec Godot 4.7, exporte la version Web/PWA et vérifie le rendu dans Firefox avant publication. Il vérifie également la publication du configurateur, de son moteur de détection et du module d’envoi direct. Le pipeline d'assets contrôle le GLB, le budget de triangles, les os, les animations, les sons, les textures, les collisions et les zones de dégâts.

## Documentation

- `docs/NARRATIVE_BIBLE.md` : canon, factions et évolution d’ATHENA ;
- `docs/ATHENA_PROTOCOL_V12.md` : mécaniques adaptatives et Sentinel OS ;
- `docs/STORYBOARD_IMPLEMENTATION_MATRIX.md` : correspondance entre storyboard et jeu ;
- `docs/SOUNDTRACK_SUNO.md` : placement narratif des musiques ;
- `docs/ASSET_PIPELINE.md` : licences et budgets 3D Web ;
- `docs/ASSET_REFERENCE_IMAGE_GUIDE.md` : vues, cadrages et poses à fournir ;
- `docs/GENERATED_ASSET_AND_DAMAGE_PIPELINE.md` : génération, catalogue, passerelle et dégâts localisés ;
- `docs/CRAWLER7_PRODUCTION_PIPELINE.md` : génération, rig, animations et contrôles ;
- `docs/OPEN_SOURCE_3D_DECISION.md` : comparaison des solutions open source ;
- `docs/REPOSITORY_AUDIT_2026-07-15.md` : audit ciblé du pipeline 3D.
