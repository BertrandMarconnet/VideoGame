# Blackout Protocol — Night Shift v22

Cette version remplace la progression linéaire du prototype par cinq quarts : surveillance depuis S-01, interventions physiques, retour au poste et rapport. La mission n'est pas validée par la seule présence du joueur au relais.

## Contenu

- Hub avec deux postes, deux shutters physiques, huit feeds et isolation électrique de l'atelier.
- Deux halls, six salles latérales, boucle nord, relais et traversée M-04 destructible et accroupie.
- Missions et archives distinctes par nuit ; mémorisation des caméras, fatigue, perturbations du signal ; trois choix de fin, dont un exige M-04.
- Robots à perception visuelle occultée, bruit, mémoire temporaire et déplacement sur graphe. Les collisions physiques restent actives. Les robots frappent les portes et poussent les objets.
- Animations importées et mouvements supplémentaires : scan de tête, boiterie, rotation, réaction, interaction porte, chute et récupération. Reconstruction visuelle de DELTA entre les nuits.
- Sons industriels générés et spatialisés ; anciens MP3 et ancien générateur global supprimés. Les débris de dégâts localisés sont limités à 24 pour l'ensemble de la scène.
- Mobilier détaillé, transformateurs, rayonnages, consoles CRT, canalisations, affiches ; détails sans collisions supplémentaires.
- HUD tactile masqué pendant la surveillance ; boutons de caméra de 46 px, reflow sans réduction uniforme de toute l'interface.
- WorldForge : sélection par salle, objets éditables, AUDIT LEVEL, AUTO FIX. Audit des routes par capsules, des cadres de porte, de l'échelle et des objets sans support. Réparation des erreurs simples ; les murs porteurs ne sont pas effacés automatiquement.

## Contrôles

Clavier : déplacements WASD/ZQSD selon les actions configurées, souris pour regarder, E pour interagir, V pour les caméras, C pour KITE, Tab pour Sentinel, Ctrl pour s'accroupir. Les commandes tactiles sont visibles sur téléphone. Dans les caméras : Q/E changent de feed, 1/2 commandent les shutters. Échap ferme l'interface ou met en pause.

## Vérification reproductible

Assembler `src_parts/main_*.gdpart` dans `scripts/main.gd`, puis lancer Godot 4.7 sur `tests/test_nightshift.gd`. Le test fait déplacer le CharacterBody sur toutes les liaisons, vérifie M-04 après destruction, le blocage des robots par les shutters, les missions, les clips, la consommation, le HUD mobile et une erreur injectée dans l'audit. Les vues 01 à 15 sont rendues par Godot ; les téléportations servent uniquement aux points de vue des captures.

La CI exporte le Web, ouvre le jeu et WorldForge sous Firefox, déploie Pages puis recommence le test Firefox sur l'URL publique. `build-info.json` contient le commit et les SHA-256 de l'HTML, du moteur, du pack et des deux outils. Le smoke test public vérifie ces empreintes.

## Limites à ne pas confondre avec une validation

- Les profils prudent/explorateur/speedrunner/agressif/paniqué sont couverts par des scénarios automatiques ciblés ; cela ne remplace pas cinq parties humaines complètes.
- Le navigateur Work disponible ne fournit pas WebGL2. La validation interactive 3D dans ce navigateur est bloquée ; le portail et le formulaire sont accessibles.
- Aucun FPS n'est revendiqué sur un smartphone physique. Les profils adaptatifs et les limites de rendu sont des mesures d'optimisation, pas une preuve de 30 FPS.
- Le clip de franchissement est présent ; le graphe n'inclut pas encore de parcours d'escalade à plusieurs niveaux.
- Le générateur existant est conservé. Une génération distante nouvelle exige l'authentification GitHub du développeur ; le formulaire et son lancement sont testés sans transmettre de jeton.
