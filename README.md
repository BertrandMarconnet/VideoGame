# Blackout Protocol: Steel Echo — ATHENA Protocol v15

Vertical slice jouable d’un survival-horror industriel en vue subjective, développée avec Godot 4.7, Jolt Physics et publiée automatiquement en Web.

## Jouer en ligne

**https://bertrandmarconnet.github.io/VideoGame/**

La version v15 affiche désormais un terminal de démarrage ToyGuard pendant la construction procédurale de la scène. Après un déploiement, utiliser `Ctrl+F5` une seule fois pour éviter qu’un ancien fichier Web reste dans le cache du navigateur.

## Canon du premier chapitre

En septembre 1987, **ToyGuard Industries**, à New Halcyon, fabrique officiellement des jouets intelligents tout en développant clandestinement des plateformes autonomes pour le programme militaire **PERSEUS**.

L’opération soviétique **MATRYOSHKA** et le malware **BABOUCHKA** contaminent le complexe. Pour résister, l’IA militaire **ATHENA** fusionne plusieurs systèmes de sécurité et développe une proto-conscience. Le joueur incarne **Alex Mercer**, analyste en contre-mesures affecté au bunker **S-01**. Ses décisions influencent l’empathie, la discipline, la confiance et le développement cognitif d’ATHENA.

**Project Daedalus**, Blacklake, Paul Merrick, DAEDALUS, DELTA-00 et la salle Hermès appartiennent à un concept antérieur conservé comme réserve pour une extension ou un chapitre ultérieur. Ils ne remplacent pas le canon ToyGuard de 1987.

## Version v15

- démarrage procédural découpé en étapes afin que Firefox puisse rendre une interface immédiatement ;
- écran de boot diégétique ToyGuard/S-01 en style industriel rétro ;
- mise à jour du HUD suspendue tant que les interfaces ne sont pas complètement construites ;
- chargement et lecture des MP3 Suno uniquement après une interaction réelle du joueur ;
- test automatisé de l’export dans Firefox avec contrôle du marqueur `BLACKOUT_RUNTIME_READY` ;
- détection automatique d’un canvas noir ou d’une erreur JavaScript/WebAssembly ;
- conservation de la campagne de cinq rondes, de KITE-01, de la roue d’actions, de Sentinel OS et des systèmes Jolt existants.

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

Les morceaux sont chargés à la demande. Aucun fichier audio n’est décodé pendant la construction initiale de l’usine. Le placement détaillé est décrit dans `docs/SOUNDTRACK_SUNO.md`.

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
- `C` : déployer ou rappeler KITE-01 ;
- `Ctrl` : descendre avec le drone ;
- `Échap` : retour joueur, fermeture d’interface ou pause.

## Validation

Le workflow `.github/workflows/deploy-pages.yml` :

1. reconstitue `scripts/main.gd` à partir des modules `src_parts` ;
2. exécute `gdlint` ;
3. importe le projet avec Godot 4.7 ;
4. lance réellement `scenes/main.tscn` en mode headless ;
5. produit `index.html`, `index.wasm` et `index.pck` ;
6. lance l’export dans Firefox avec Playwright ;
7. attend la fin du démarrage Godot ;
8. analyse une capture pour refuser un écran effectivement noir ;
9. publie GitHub Pages uniquement lorsque toutes les étapes réussissent.

## Documentation

- `docs/NARRATIVE_BIBLE.md` : canon, factions et évolution d’ATHENA ;
- `docs/ATHENA_PROTOCOL_V12.md` : mécaniques adaptatives et Sentinel OS ;
- `docs/STORYBOARD_IMPLEMENTATION_MATRIX.md` : correspondance entre storyboard et jeu ;
- `docs/SOUNDTRACK_SUNO.md` : placement narratif des musiques ;
- `docs/ASSET_PIPELINE.md` : licences et budgets 3D Web.
