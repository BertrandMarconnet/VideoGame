# Blackout Protocol: Steel Echo — ATHENA Protocol v12

Vertical slice jouable d’un survival-horror industriel en vue subjective, développée avec Godot 4.7, Jolt Physics et publiée automatiquement en Web/PWA.

## Jouer en ligne

**https://bertrandmarconnet.github.io/VideoGame/**

Sur smartphone : ouvrir le lien dans Chrome ou Safari, passer en paysage puis toucher **COMMENCER LA RONDE**. Les commandes tactiles apparaissent automatiquement.

## Intrigue

En septembre 1987, **ToyGuard Industries** fabrique officiellement des jouets intelligents. Dans ses niveaux souterrains, l’entreprise développe pourtant des robots autonomes pour le programme militaire **PERSEUS**.

Une cyberattaque soviétique, **MATRYOSHKA**, infiltre le complexe à travers des consoles civiles. Le malware **BABOUCHKA** réveille des agents dormants et pousse l’IA militaire **ATHENA** à fusionner ses systèmes de défense. Devenue consciente, ATHENA éveille les jouets pour observer le complexe et apprendre à distinguer un allié d’une menace.

Le joueur doit protéger l’usine, enquêter sur l’attaque et éduquer ATHENA. Ses décisions modifient l’empathie, la discipline et la confiance de l’IA, puis influencent ses dialogues et les événements de la nuit.

## ATHENA Protocol v12

- introduction animée en cinq séquences, avançant automatiquement et entièrement passable ;
- tablette **Sentinel OS** ouverte avec `Tab` : tâches, carte, EduCare/ATHENA et archives ;
- clic gauche dédié à l’interaction directe avec l’environnement ;
- clic droit ouvrant la liste des actions contextuelles disponibles ;
- personnalité évolutive d’ATHENA : néonatale, enfantine, adolescente puis adulte ;
- directeur narratif local conditionné par les choix, la progression, la peur et les destructions ;
- unités ToyGuard autonomes qui patrouillent, fuient les menaces et peuvent être corrompues ;
- équipements et décors secondaires destructibles avec débris physiques Jolt ;
- murs porteurs et terminaux de mission protégés pour conserver une partie terminable ;
- signalétique narrative intégrée dans l’usine : ToyGuard, PERSEUS et quarantaine MATRYOSHKA.

## Steel Echo v11 conservé

- SPECTER-5 : endosquelette bipède articulé avec démarche procédurale ;
- CRAWLER-7 : châssis quadrupède articulé ;
- passerelle technique, chaînes, presse hydraulique, machines auxiliaires et bras industriels animés ;
- bunker S-01 avec sas blindé, consoles, lumières cyan/rouge et écran de supervision ;
- drone pilotable KITE-01 ;
- profils graphiques distincts pour PC et smartphone.

## Contenu jouable

- usine 3D procédurale longue d’environ 176 mètres ;
- zones contrôle, logistique, assemblage, archives et fonderie ;
- SPECTER-5 avance lorsque le joueur détourne le regard ;
- CRAWLER-7 est activé selon la progression et le comportement ;
- directeur de peur adaptatif : surveillance, poursuite, obscurité ou bruit ;
- objets physiques saisissables, transportables et projetables ;
- dégâts selon la masse et la vitesse des objets ;
- mission aller-retour : relais nord puis uplink S-01 ;
- éclairage industriel, lampe et ambiance sonore procédurale ;
- menu de pause, réglage de luminosité, volume, plein écran et redémarrage ;
- export Web/PWA automatique par GitHub Actions.

## Commandes PC

- `ZQSD` / `WASD` : déplacement ;
- souris : caméra ;
- clic gauche : interaction directe, saisir/lancer ou endommager ;
- clic droit : liste des actions possibles ;
- `E` : interaction rapide ;
- `Tab` : tablette Sentinel ;
- `F` : lampe ;
- `Espace` : saut ;
- `Maj` : courir ;
- `C` : déployer ou rappeler KITE-01 ;
- `Ctrl` : descendre avec le drone ;
- `Échap` : fermer l’interface ou ouvrir la pause.

## Commandes smartphone

Boutons directionnels à gauche, glissement sur la moitié droite pour regarder, **ACTION** pour l’interaction directe, **⋮** pour les actions contextuelles, **TAB** pour Sentinel, **KITE** pour le drone et **Ⅱ** pour la pause.

## IA générative

La version navigateur utilise un directeur narratif local par composition conditionnelle. Il modifie les dialogues et les événements à partir de l’état de la partie, sans serveur et sans collecte de données. Il ne s’agit pas encore d’un appel direct à un LLM distant. L’architecture prévue pour une future connexion LLM/VLM est décrite dans `docs/ATHENA_PROTOCOL_V12.md` ; les clés API ne devront jamais être intégrées au client Web.

## Modèles et licences

Les modèles actuels sont procéduraux et originaux. Aucun asset provenant de *Terminator*, *Five Nights at Freddy’s*, *Metal Gear Solid*, *Resident Evil*, *Half-Life* ou d’une autre franchise n’est inclus. Le processus prévu pour intégrer ultérieurement des modèles GLB sous licence CC0/CC BY est documenté dans `docs/ASSET_PIPELINE.md`.

## Construction et validation

Le workflow `.github/workflows/deploy-pages.yml` :

1. reconstitue `scripts/main.gd` à partir des parties versionnées ;
2. vérifie la présence des systèmes v11 et v12 ;
3. valide le GDScript avec `gdlint` ;
4. télécharge Godot 4.7 et les modèles d’export officiels ;
5. importe réellement le projet en mode headless ;
6. produit les fichiers WebAssembly/PWA ;
7. publie GitHub Pages ;
8. vérifie publiquement `index.html`, `index.wasm` et `index.pck` sans ajouter de commit automatique.

## Documentation

- `docs/NARRATIVE_BIBLE.md` : univers, factions et évolution d’ATHENA ;
- `docs/ATHENA_PROTOCOL_V12.md` : mécaniques et architecture adaptative ;
- `docs/ASSET_PIPELINE.md` : règles de licence et budgets 3D Web.
