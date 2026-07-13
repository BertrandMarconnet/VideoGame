# Blackout Protocol: Steel Echo — Storyboard v19

Vertical slice jouable d’un survival-horror industriel en vue subjective, développée avec Godot 4.7, Jolt Physics et publiée automatiquement en Web/PWA.

## Jouer en ligne

**https://bertrandmarconnet.github.io/VideoGame/**

Après un déploiement, utiliser `Ctrl+F5` une seule fois afin d’éviter qu’un ancien export Web reste dans le cache du navigateur.

## Canon du premier chapitre

En septembre 1987, **ToyGuard Industries**, à New Halcyon, fabrique officiellement des jouets intelligents tout en développant clandestinement des plateformes autonomes pour le programme militaire **PERSEUS**.

L’opération soviétique **MATRYOSHKA** et le malware **BABOUCHKA** contaminent le complexe. Pour résister, l’IA militaire **ATHENA** fusionne plusieurs systèmes de sécurité et développe une proto-conscience. Le joueur incarne **Alex Mercer**, analyste en contre-mesures affecté au bunker **S-01**. Ses décisions influencent l’empathie, la discipline, la confiance et le développement cognitif d’ATHENA.

**Project Daedalus**, Blacklake, Paul Merrick, DAEDALUS, DELTA-00 et la salle Hermès restent réservés à une extension ou à un chapitre ultérieur. Ils ne remplacent pas le canon ToyGuard de 1987.

## Storyboard — Acte I

La campagne ne commence plus directement dans la salle de contrôle. Après le prologue unique, le joueur reçoit le contrôle **à l’extérieur de ToyGuard Industries**, sous la pluie, conformément au plan 01 du storyboard.

Le premier parcours suit maintenant l’ordre narratif prévu :

1. arrivée nocturne devant la façade ToyGuard ;
2. progression vers la porte de service latérale ;
3. traversée du sas de décontamination et de la porte blindée S-01 ;
4. arrivée par un vestibule latéral, sans apparition face à l’écran central ;
5. consultation de Sentinel OS ;
6. première patrouille dans les secteurs logistique et assemblage ;
7. observation des unités ToyGuard ;
8. déploiement de KITE-01 ;
9. premier contact contrôlé avec ATHENA ;
10. réparation du relais nord.

L’écran principal du bunker reste visible mais sa structure n’est plus une collision de navigation. Les menaces principales sont bloquées pendant l’arrivée extérieure et ne sont libérées qu’après la consultation de Sentinel OS.

## Direction artistique PS1 industrial low-poly

- façade, clôtures, poste de garde, lampadaires, flaques et signalétique procédurale low-poly ;
- géométrie volontairement simple et silhouettes lisibles ;
- matériaux mats, couleurs quantifiées et éclairage cyan/ambre/rouge ;
- pluie construite avec `MultiMeshInstance3D`, limitée sur smartphone ;
- lampe et main low-poly visibles en vue subjective ;
- filtrage nearest, ombrage par sommet et palette réduite ;
- pixelisation, scanlines, bruit et vignettage subtils appliqués uniquement au monde 3D ;
- réglage **Filtre rétro** dans le menu de pause, permettant de réduire ou désactiver l’effet.

Le filtre ne modifie pas la lisibilité du HUD et utilise une intensité plus faible sur smartphone.

## Systèmes conservés

- déplacement ZQSD/WASD et contrôles tactiles ;
- position basse avec vérification du plafond ;
- interactions clic gauche, `E` et roue d’actions au clic droit ;
- tablette Sentinel OS ;
- KITE-01 et retour immédiat à la vue joueur ;
- SPECTER-5 et CRAWLER-7 ;
- unités ToyGuard et bras industriels ;
- destruction locale et objets physiques Jolt ;
- campagne de cinq rondes ;
- directeur narratif local d’ATHENA ;
- bande-son Suno déclenchée après interaction utilisateur.

## Bande-son adaptative

- menu et amorçage : `01_main_theme.mp3` après interaction utilisateur ;
- introduction : `02_introduction.mp3` ;
- poursuite dynamique : `03_factory_hunts.mp3` ;
- ronde 1 : `05_daedalus_entity.mp3` ;
- ronde 2 : `04_surveillance_loop.mp3` ;
- ronde 3 : `07_crawler.mp3` ;
- ronde 4 : `08_first_skin.mp3` ;
- ronde 5 : `09_delta00_final.mp3` ;
- crédits : `10_credits.mp3`.

Les noms historiques des fichiers sont conservés pour éviter les références cassées. Leur usage narratif actuel reste rattaché à ATHENA/ToyGuard.

## Commandes PC

- `ZQSD` / `WASD` : déplacement ;
- souris : caméra ;
- clic gauche : interaction ou scan KITE ;
- clic droit : roue d’actions ou rappel immédiat du drone ;
- `E` : interaction rapide ;
- `Tab` : tablette Sentinel ;
- `F` : lampe ;
- `Espace` : saut ou montée avec le drone ;
- `Maj` : course ;
- `Ctrl` : se baisser à pied / descendre avec KITE-01 ;
- `C` : déployer ou rappeler KITE-01 ;
- `Échap` : retour joueur, fermeture d’interface ou pause.

Sur smartphone, le bouton `CROUCH` maintient la position basse. Le personnage ne peut pas se relever lorsqu’un obstacle est détecté au-dessus de lui.

## Génération 3D open source sans clé

Le dépôt contient désormais deux niveaux de pipeline local :

```text
.github/workflows/generate-open3d-inbox.yml
.github/workflows/generate-triposr-asset.yml
```

Le pipeline recommandé est **Open3D asset inbox** :

```text
assets/asset_inbox/
├── props/
├── modules/
├── characters/
└── robots/
```

Il accepte PNG, JPEG, WebP et SVG, rasterise localement les SVG, exécute TripoSR sur un runner GPU auto-hébergé, puis Blender produit un GLB décimé, métrique et compatible Godot. Aucune API commerciale, aucun compte, aucune clé et aucun quota fournisseur ne sont utilisés.

Avant tout commit automatique d’un GLB, le workflow :

1. valide l’image et le manifeste ;
2. génère et optimise le modèle ;
3. assemble et lint `scripts/main.gd` ;
4. importe le projet avec Godot 4.7 ;
5. démarre la scène principale ;
6. exporte la version Web ;
7. pousse l’asset sur `main` uniquement si tous les contrôles réussissent.

Les concepts Acte I déjà préparés couvrent la porte de service, la porte blindée S-01, la console Sentinel, la lampe FPS et un premier module mural industriel.

Documentation :

```text
assets/asset_inbox/README.md
docs/TRIPOSR_GITHUB_PIPELINE.md
```

## Validation

Le workflow `.github/workflows/deploy-pages.yml` reconstitue `scripts/main.gd`, exécute `gdlint`, importe le projet avec Godot 4.7, charge `scenes/main.tscn`, exporte `index.html`, `index.wasm` et `index.pck`, puis lance l’export dans Firefox et refuse un canvas noir avant le déploiement GitHub Pages.

## Documentation

- `docs/NARRATIVE_BIBLE.md` : canon, factions et évolution d’ATHENA ;
- `docs/ATHENA_PROTOCOL_V12.md` : mécaniques adaptatives et Sentinel OS ;
- `docs/STORYBOARD_IMPLEMENTATION_MATRIX.md` : correspondance entre storyboard et jeu ;
- `docs/SOUNDTRACK_SUNO.md` : placement narratif des musiques ;
- `docs/ASSET_PIPELINE.md` : licences, budgets 3D Web et choix des pipelines ;
- `docs/TRIPOSR_GITHUB_PIPELINE.md` : génération 3D locale, gratuite et sans quota ;
- `assets/asset_inbox/README.md` : dossier image-vers-GLB et intégration automatisée.
