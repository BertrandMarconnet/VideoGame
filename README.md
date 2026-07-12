# Blackout Protocol: Steel Echo — Storyboard v16

Vertical slice jouable d’un survival-horror industriel en vue subjective, développée avec Godot 4.7, Jolt Physics et publiée automatiquement en Web/PWA.

## Jouer en ligne

**https://bertrandmarconnet.github.io/VideoGame/**

Après un déploiement, utiliser `Ctrl+F5` une seule fois afin d’éviter qu’un ancien export Web reste dans le cache du navigateur.

## Canon du premier chapitre

En septembre 1987, **ToyGuard Industries**, à New Halcyon, fabrique officiellement des jouets intelligents tout en développant clandestinement des plateformes autonomes pour le programme militaire **PERSEUS**.

L’opération soviétique **MATRYOSHKA** et le malware **BABOUCHKA** contaminent le complexe. Pour résister, l’IA militaire **ATHENA** fusionne plusieurs systèmes de sécurité et développe une proto-conscience. Le joueur incarne **Alex Mercer**, analyste en contre-mesures affecté au bunker **S-01**. Ses décisions influencent l’empathie, la discipline, la confiance et le développement cognitif d’ATHENA.

**Project Daedalus**, Blacklake, Paul Merrick, DAEDALUS, DELTA-00 et la salle Hermès restent réservés à une extension ou à un chapitre ultérieur. Ils ne remplacent pas le canon ToyGuard de 1987.

## Storyboard v16 — Acte I

La campagne ne commence plus directement dans la salle de contrôle. Après le prologue unique, le joueur reçoit le contrôle **à l’extérieur de ToyGuard Industries**, sous la pluie, conformément au plan 01 du storyboard.

Le premier parcours suit maintenant l’ordre narratif prévu :

1. arrivée nocturne devant la façade ToyGuard ;
2. progression vers l’accès personnel S-01 ;
3. entrée dans le bunker et consultation de Sentinel OS ;
4. première patrouille dans les secteurs logistique et assemblage ;
5. observation des unités ToyGuard ;
6. déploiement de KITE-01 ;
7. reconnaissance distante ;
8. premier contact contrôlé avec ATHENA ;
9. apparition différée de SPECTER-5 ;
10. réparation du relais nord.

Les menaces principales sont bloquées pendant l’arrivée extérieure et ne sont libérées qu’après la consultation de Sentinel OS. Cela évite une apparition incohérente de SPECTER-5 avant sa scène de storyboard.

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
- `C` : déployer ou rappeler KITE-01 ;
- `Ctrl` : descendre avec le drone ;
- `Échap` : retour joueur, fermeture d’interface ou pause.

## Validation

Le workflow `.github/workflows/deploy-pages.yml` reconstitue `scripts/main.gd`, exécute `gdlint`, importe le projet avec Godot 4.7, charge `scenes/main.tscn`, exporte `index.html`, `index.wasm` et `index.pck`, puis lance l’export dans Firefox et refuse un canvas noir avant le déploiement GitHub Pages.

## Documentation

- `docs/NARRATIVE_BIBLE.md` : canon, factions et évolution d’ATHENA ;
- `docs/ATHENA_PROTOCOL_V12.md` : mécaniques adaptatives et Sentinel OS ;
- `docs/STORYBOARD_IMPLEMENTATION_MATRIX.md` : correspondance entre storyboard et jeu ;
- `docs/SOUNDTRACK_SUNO.md` : placement narratif des musiques ;
- `docs/ASSET_PIPELINE.md` : licences et budgets 3D Web.
