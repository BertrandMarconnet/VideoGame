# Industrial v20

## Intention

Rendre le complexe ToyGuard plus lisible et cohérent, avec une direction de console PS2 adaptée au moteur Compatibility de Godot 4.7. Conserver le parcours de l’Acte I, les interactions, les robots animés et la destruction. La qualité PS3 n’est pas un niveau de fidélité mesuré ou garanti.

## Monde et rendu

- Quatre passages couverts aux coordonnées z = −22,5, −58, −92 et −126 relient logistique, assemblage, archives et fonderie. Les ouvertures conservent les voies principales de circulation.
- Des tuyaux, soubassements, encadrements, marquages au sol et panneaux identifient les secteurs. Neuf groupes de maintenance ajoutent armoires ventilées, pompes à vannes, fûts cerclés et affiches.
- Les consoles qui empiétaient sur le sas ont été déplacées. L’écran de supervision et tous ses éléments sont regroupés sur une paroi libre. Les rayonnages centraux qui gênaient le passage sont retirés ; les bras de production se déploient au-dessus des machines.
- Béton, sol, acier, peinture et caoutchouc utilisent des textures procédurales 256 × 256, avec mipmaps et projection triplanaire. Les matières partagées et géométries sont mises en cache.
- Éclairage par pixel, ambiant plus neutre, brouillard moins dense, lampe chaude et luminosité effective dans le post-traitement Compatibility. Le filtre rétro reste facultatif, désactivé par défaut.
- Les pièces mécaniques procédurales reçoivent des chanfreins et des cylindres plus arrondis. Les détails fixes sont fusionnés par matière et secteur.

## Modèles de campagne

Les GLB réellement sélectionnés par Asset Bridge sont affinés, sans remplacer les noms de pièces, articulations ou animations. Le script Blender `tools/refine_console_assets.py` contrôle ces contrats avant de valider son export.

| Asset | Triangles avant | Triangles après | Taille GLB | Articulations | Clips |
| --- | ---: | ---: | ---: | ---: | ---: |
| SPECTER-5 | 3 636 | 7 572 | 583 292 octets | 14 | 6 |
| CRAWLER-7 | 8 904 | 16 428 | 1 051 628 octets | 13 | 5 |

Comptages effectués sur les primitives du GLB exporté, y compris les aides nommées de collision. Les anciens rapports Blender du CRAWLER indiquaient 8 844 triangles avec un périmètre différent. Les fichiers metrics/validation sont actualisés avec le comptage glTF. Les clips, squelettes, sons et noms de zones de dégâts sont conservés.

## Mobile et menus

Un HUD compact remplace les panneaux superposés. Les commandes disparaissent pendant la tablette, les actions, la pause et l’introduction. Ouvrir un menu libère les actions tactiles maintenues pour éviter un déplacement bloqué. Les tailles visuelles des touches et leurs surfaces de contact sont identiques ; elles restent séparées après rotation.

Les dialogues utilisent une zone de défilement, des lignes de boutons qui reviennent à la ligne et un bouton de fermeture fixe pour la tablette et la pause. Les options d’affichage sont persistantes. Entrée lance la campagne et Échap passe le dossier d’introduction.

## Budgets de rendu

| Réglage | Résolution 3D initiale | Anticrénelage | Ombre de lampe |
| --- | --- | --- | --- |
| Automatique | 78 % mobile / 100 % bureau, adaptation entre 60 % et 85 % / 100 % | Désactivé mobile / MSAA 2× bureau | Désactivée |
| Économie | 65 % | Désactivé | Désactivée |
| Équilibré | 86 % | Désactivé mobile / MSAA 2× bureau | Désactivée |
| Détaillé | 100 % | Désactivé mobile / MSAA 2× bureau | Bureau uniquement |

Les lumières ponctuelles actives sont choisies par proximité : au plus 8 sur mobile/en économie et 12 sur bureau. Les nouveaux petits détails disparaissent à distance. Aucun téléchargement d’asset ni service graphique extérieur n’est nécessaire au démarrage.

## Vérifications

Assembler le script puis utiliser Godot 4.7 :

```sh
cat src_parts/main_*.gdpart > scripts/main.gd
godot --headless --path . --script res://tests/test_visual_mobile.gd -- --touch-ui
godot --headless --path . --script res://tests/test_damage_system.gd
```

Le test d’intégration charge la scène de campagne et vérifie :

- les commandes et le HUD sans recouvrement à 390 × 844, 844 × 390, 360 × 640 et 667 × 375 ;
- les menus de démarrage et leurs textes, la fermeture des dialogues et l’exclusion des autres panneaux ;
- la libération des actions maintenues et l’effet réel du réglage de luminosité ;
- douze positions de capsule de joueur libres au centre des quatre nouveaux couloirs.

Avec un affichage natif, le même test enregistre les vues réelles du sas, des couloirs, des ateliers, des équipements et des robots, ainsi que les menus, dans `build/visual-v20/`. Ces captures ont été examinées pendant la réalisation. L’affichage logiciel de la machine de test ne mesure pas les performances d’un smartphone.

Le workflow de publication exécute la validation GDScript, l’import et le démarrage Godot, les tests d’interface et de dégâts, l’export Web, puis les tests existants du jeu et du portail dans Firefox avec WebGL2 logiciel. Les interactions tactiles de mouvement, lampe, accroupissement et regard sont exercées dans l’export réel avant déploiement.
