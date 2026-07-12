# Blackout Protocol: Steel Echo — ATHENA Protocol v14

Vertical slice jouable d’un survival-horror industriel en vue subjective, développée avec Godot 4.7, Jolt Physics et publiée automatiquement en Web/PWA.

## Jouer en ligne

**https://bertrandmarconnet.github.io/VideoGame/**

Après une mise à jour, utiliser `Ctrl+F5` afin de vider l’ancien cache Web. Sur smartphone : ouvrir le lien dans Chrome ou Safari, passer en paysage puis toucher **COMMENCER LA RONDE**.

## Intrigue

ToyGuard Industries fabrique officiellement des jouets intelligents mais développe, dans ses niveaux souterrains, des robots autonomes pour un programme militaire. Une cyberattaque réveille des agents dormants et pousse l’IA militaire ATHENA/DAEDALUS à relier les systèmes du complexe. Le joueur protège l’usine, enquête sur l’attaque et influence la personnalité de l’IA, tandis que DELTA-00 évolue progressivement vers un prototype autonome.

## Version v14

- correction de l’écran noir causé par des erreurs de typage GDScript au chargement de la scène ;
- test de démarrage réel : la CI lance le jeu et exige l’atteinte de `BLACKOUT_RUNTIME_READY` ;
- campagne de cinq rondes avec environnement, jouets, éclairages et bras industriels évolutifs ;
- caméra KITE-01 corrigée, retour immédiat à la vue joueur et interface drone dédiée ;
- HUD avec barres Santé, liaison ATHENA et batterie KITE ;
- roue d’actions contextuelles ;
- introduction jouée une seule fois par campagne ;
- écran de contrôle déplacé et alimenté par des alertes dynamiques ;
- bande-son Suno adaptative, différente selon la ronde et renforcée par une couche de poursuite.

## Bande-son Suno intégrée

- menu : `01_main_theme.mp3` ;
- introduction : `02_introduction.mp3` ;
- poursuite dynamique : `03_factory_hunts.mp3` ;
- ronde 1 : `05_daedalus_entity.mp3` ;
- ronde 2 : `04_surveillance_loop.mp3` ;
- ronde 3 : `07_crawler.mp3` ;
- ronde 4 : `08_first_skin.mp3` ;
- ronde 5 : `09_delta00_final.mp3` ;
- crédits : `10_credits.mp3`.

Les fichiers actuels sont des boucles Web compactes issues des masters fournis. Les masters optimisés pourront les remplacer progressivement sans modifier le directeur musical. Voir `docs/SOUNDTRACK_SUNO.md`.

## Commandes PC

- `ZQSD` / `WASD` : déplacement ;
- souris : caméra ;
- clic gauche : interaction ou scan KITE ;
- clic droit : roue d’actions, ou rappel immédiat du drone ;
- `E` : interaction rapide ;
- `Tab` : tablette Sentinel ;
- `F` : lampe ;
- `Espace` : saut/monter avec le drone ;
- `Maj` : courir ;
- `C` : déployer ou rappeler KITE-01 ;
- `Ctrl` : descendre avec le drone ;
- `Échap` : retour joueur, fermeture d’interface ou pause.

## Construction et validation

Le workflow `.github/workflows/deploy-pages.yml` :

1. reconstitue `scripts/main.gd` à partir des modules versionnés ;
2. exécute `gdlint` et conserve son journal ;
3. télécharge Godot 4.7 et les modèles d’export officiels ;
4. importe réellement le projet en mode headless ;
5. lance le jeu et contrôle l’absence d’erreur d’exécution ;
6. produit l’export WebAssembly/PWA ;
7. publie GitHub Pages ;
8. vérifie publiquement `index.html`, `index.wasm` et `index.pck`.

## Documentation

- `docs/NARRATIVE_BIBLE.md` : univers, factions et évolution d’ATHENA ;
- `docs/ATHENA_PROTOCOL_V12.md` : mécaniques et architecture adaptative ;
- `docs/SOUNDTRACK_SUNO.md` : placement narratif et ajout progressif des musiques ;
- `docs/ASSET_PIPELINE.md` : règles de licence et budgets 3D Web.
