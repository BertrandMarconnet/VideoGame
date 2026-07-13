# Matrice d’implémentation du storyboard

Cette matrice relie les plans validés aux éléments réellement intégrés dans le jeu. Le lot courant **Act I v18** corrige l’entrée : le joueur ne traverse plus une ouverture centrale donnant directement sur le cœur du bunker. Le flux est désormais :

```text
extérieur ToyGuard → porte de service → sas de décontamination → porte blindée S-01 → vestibule latéral → bunker
```

Statuts : `prévu`, `prototype`, `intégré`, `validé`.

## Acte I — mise en place

| ID | Lieu | Objectif joueur | Événement narratif | Gameplay | Menace | Variables ATHENA | Assets / scripts | Contraintes physiques | Variante smartphone | Critères de validation | Statut |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 01 | Extérieur ToyGuard | Identifier l’accès S-01 | Arrivée sous la pluie à New Halcyon | Orientation, lampe, lecture de la signalétique | Aucune | `mission_stage`, `light_usage` | Façade, clôtures, pluie ; `main_15_storyboard_act1.gdpart` | Architecture statique, pluie sans collision | Moins de pluie et de lumières | Spawn extérieur, façade visible, aucune menace active | intégré |
| 01B | Façade / accès latéral | Suivre l’indication `SERVICE ACCESS` | L’accès principal est condamné | Déplacement, repérage | Aucune | `mission_stage` | Concept `assets/concepts/act1/service_access/source.jpg` ; `main_17_act1_startup_v18.gdpart` | L’ancien passage central possède une collision statique | Signalétique agrandie | Impossible de traverser l’entrée centrale ; porte latérale visible | intégré |
| 02 | Porte de service | Entrer dans le sas | Contrôle d’accès du personnel | Approche, ouverture automatique télégraphiée | Aucune | `mission_stage`, `trust` | `ServiceDoorOuterV18`, manifeste Tripo `service_access/tripo_api.json` | `AnimatableBody3D`, collision boîte | Ouverture identique, effets lumineux réduits | La porte s’ouvre sans téléportation et ne supprime pas la collision | intégré |
| 02B | Sas de décontamination | Traverser le couloir pressurisé | Première fermeture derrière le joueur | Progression séquencée, ambiance | Aucune | `mission_stage`, `player_fear_profile` | Couloir, conduites, éclairages cyan/rouge ; `main_17_act1_startup_v18.gdpart` | Sol, murs et plafond en boîtes simples | Trois éclairages maximum | La porte extérieure se ferme avant l’ouverture intérieure | intégré |
| 02C | Porte blindée S-01 | Attendre le déverrouillage | Le bunker impose une deuxième barrière | Temporisation courte, franchissement | Aucune | `mission_stage`, `trust` | `BlastDoorInnerV18`, manifeste `s01_blast_door/tripo_api.json` | `AnimatableBody3D`, collision boîte | Même logique à fréquence réduite | L’ouverture intervient après le délai du sas | intégré |
| 02D | Vestibule latéral | Tourner vers la salle de contrôle | L’arrivée ne révèle pas immédiatement le cœur du bunker | Virage imposé, lecture d’une console secondaire | Aucune | `mission_stage`, `archives_discovered` | `VestibuleLateralV18`, console Sentinel, chargeur GLB conditionnel | Architecture statique, largeur de circulation conservée | Console procédurale si GLB absent | Le joueur n’apparaît jamais face au grand écran central | intégré |
| 03 | Bunker S-01 | Ouvrir Sentinel OS | Présentation du relais nord | Tablette, objectif, carte | Aucune | `mission_stage`, `trust` | Sentinel OS ; scripts v12/v13 | Aucun corps rigide requis | Interface adaptée au paysage | `Tab` ouvre la tablette et l’objectif est lisible | intégré |
| 04 | Logistique / assemblage | Commencer la ronde | Premiers indices d’une usine clandestine | Exploration, observation | Unités dormantes | `route_repetition`, `noise_created` | Usine procédurale, bras industriels | Machines statiques ou animées | Moins de props visibles | Le joueur atteint l’assemblage sans blocage | intégré |
| 05 | Couloir des mascottes | Observer sans s’approcher | Une mascotte semble suivre le joueur | Observation, peur | Présence ambiguë | `gaze_behavior`, `player_fear_profile` | Jouets et yeux rouges | Aucun dégât direct | Effet réduit | Apparition brève, aucune mort injuste | prototype |
| 06 | Station KITE-01 | Déployer le drone | Le compagnon est présenté | Déploiement et rappel | Aucune | `drone_state`, `trust` | KITE-01 procédural / futur GLB | Locomotion contrôlée | Commandes tactiles | `C` et bouton tactile fonctionnent | intégré |
| 07 | Passerelles | Reconnaître les machines | Observation distante | Pilotage, scan | Aucune | `drone_state`, `archives_discovered` | Vue KITE, HUD drone | Pas de physique articulée complète | FOV et effets réduits | Retour joueur toujours disponible | intégré |
| 08 | Terminal CRT | Établir le contact avec ATHENA | Premier dialogue néonatal | Dialogue et observation | Aucune | `trust`, `empathy`, `discipline`, `cognitive_stage` | CRT ATHENA | Aucun blocage de progression | Texte plus grand | Dialogue cohérent avec le canon ToyGuard | intégré |
| 09 | Secteur technique | Repérer SPECTER-5 | Première apparition immobile | Regard, visibilité | SPECTER-5 | `gaze_behavior`, `player_fear_profile` | Endosquelette procédural / futur GLB | `CharacterBody3D`, collision capsule | Décisions IA espacées | Il n’avance pas tant que le joueur le regarde | prototype |
| 10 | Relais nord | Rétablir l’alimentation | Fin du premier incrément | Interaction, réparation | Menace différée | `mission_stage`, `trust`, `discipline` | Relais et terminal | Objectif indestructible | Effets réduits | Mission toujours terminable | intégré |

## Interface et pipeline d’assets — lot v18

| Élément | Implémentation | Fallback | Validation |
|---|---|---|---|
| Menu d’accueil | panneau semi-transparent, boutons alignés à gauche, palette cyan/ambre | interface antérieure conservée dans les fonctions de base | `main_17_act1_startup_v18.gdpart` |
| HUD d’objectif | panneau technique en haut à gauche et légende de commandes | labels existants réutilisés | lisibilité PC/Web/mobile |
| Porte de service | chargement conditionnel de `assets/production/act1/service_access.glb` | porte low-poly procédurale | collision et animation indépendantes du mesh |
| Porte blindée | chargement conditionnel de `s01_blast_door.glb` | porte procédurale | séquence du sas non bloquante |
| Console latérale | chargement conditionnel de `sentinel_console.glb` | console CRT procédurale | aucune obstruction du passage |
| Lampe FPS | chargement conditionnel de `fps_flashlight.glb` | rig procédural v17 | visible uniquement en vue joueur |
| Orchestration | six jobs GitHub Actions | validation sans appel API | `.github/workflows/act1-agent-orchestrator.yml` |

## Règles pour les actes II et III

- aucune poursuite majeure ne commence dans le sas ;
- l’entrée S-01 et les terminaux critiques restent indestructibles ;
- les changements de ronde modifient lumières, état des machines, signalétique et événements, pas la géométrie critique du flux d’entrée ;
- les futurs GLB ne remplacent les fallbacks qu’après contrôle de licence, taille, triangles, import Godot et export Web ;
- les rigs squelettiques sont réservés à la main FPS, SPECTER-5, CRAWLER-7 et KITE-01 ; les portes restent animées par `AnimatableBody3D`.
