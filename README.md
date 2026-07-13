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

## Générateur 3D clé en main — sans clé API

La génération 3D ne demande plus Meshy, aucune clé API et aucun ordinateur configuré comme runner.

### Interface la plus simple

1. ouvrir **Issues** ;
2. cliquer sur **New issue** ;
3. choisir **Générer un modèle 3D** ;
4. donner un nom et glisser une image ;
5. valider.

GitHub exécute TripoSR sur son runner CPU, optimise le résultat avec Blender, vérifie l’import avec Godot 4.7, puis place automatiquement le fichier dans :

```text
assets/output 3d model/<nom>.glb
```

Pour générer **SPECTER-5** immédiatement, les quatre vues sont déjà présentes dans :

```text
assets/Input image/specter_5/
```

Il est aussi possible d’ouvrir **Actions → Generate 3D model — no key → Run workflow** et de conserver les valeurs proposées.

Le calcul CPU est gratuit mais plus lent qu’un service GPU : le premier essai peut durer de quelques dizaines de minutes à plusieurs heures.

## Validation

Le déploiement reconstruit `scripts/main.gd`, exécute `gdlint`, importe le projet avec Godot 4.7, charge `scenes/main.tscn`, exporte la version Web/PWA et vérifie le rendu dans Firefox avant publication.

## Documentation

- `docs/NARRATIVE_BIBLE.md` : canon, factions et évolution d’ATHENA ;
- `docs/ATHENA_PROTOCOL_V12.md` : mécaniques adaptatives et Sentinel OS ;
- `docs/STORYBOARD_IMPLEMENTATION_MATRIX.md` : correspondance entre storyboard et jeu ;
- `docs/SOUNDTRACK_SUNO.md` : placement narratif des musiques ;
- `docs/ASSET_PIPELINE.md` : licences et budgets 3D Web ;
- `docs/TRIPOSR_GITHUB_PIPELINE.md` : générateur sans clé ;
- `docs/REPOSITORY_AUDIT_2026-07-13.md` : audit des workflows, PR et permissions.
