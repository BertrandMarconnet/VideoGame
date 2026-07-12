# Storyboard implementation matrix

Cette matrice suit le canon ToyGuard/ATHENA de 1987. Les scènes 01 à 10 correspondent à l’Acte I du storyboard actualisé. Les anciens éléments Blacklake/Project Daedalus restent réservés à une extension ultérieure.

## Acte I — Mise en place

### 01 — Arrivée à ToyGuard
- **Lieu :** façade, route d’accès et clôture du complexe.
- **Objectif joueur :** rejoindre l’accès personnel du bunker S-01.
- **Événement narratif :** panne générale, pluie nocturne et procédure PERSEUS.
- **Gameplay principal :** prise en main FPS, lampe visible et lecture de la signalétique.
- **Menace :** aucune menace directe ; SPECTER-5 et CRAWLER-7 sont verrouillés.
- **Variables ATHENA :** `mission_stage`, `player_fear_profile`.
- **Assets :** façade low-poly, poste de garde, clôtures, lampadaires, flaques, pluie MultiMesh et enseigne ToyGuard.
- **Scripts concernés :** `main_06.gdpart`, `main_15_storyboard_act1.gdpart`.
- **Contraintes physiques :** architecture statique et indestructible ; aucune fracture extérieure.
- **Variante smartphone :** 26 traînées de pluie au lieu de 54 et filtre rétro atténué.
- **Validation :** spawn à l’extérieur, façade visible, objectif lisible et accès S-01 dégagé.
- **Statut :** intégré.

### 02 — Bunker S-01
- **Lieu :** accès extérieur puis salle de contrôle.
- **Objectif joueur :** franchir l’entrée et consulter la supervision.
- **Événement narratif :** découverte du programme PERSEUS et absence du personnel.
- **Gameplay principal :** progression extérieure/intérieure et observation des écrans.
- **Menace :** fausse sécurité ; les menaces restent verrouillées.
- **Variables ATHENA :** `trust`, `mission_stage`.
- **Assets :** sas, signalétique S-01, CRT, consoles et écran principal.
- **Scripts concernés :** `main_11.gdpart`, `main_15_storyboard_act1.gdpart`, modules v13.
- **Contraintes physiques :** terminaux, cadres du sas et murs critiques indestructibles.
- **Variante smartphone :** éclairages et pluie réduits, textes conservés.
- **Validation :** entrée sans obstruction et écran principal hors du passage.
- **Statut :** intégré.

### 03 — Sentinel OS
- **Lieu :** interface tablette dans S-01.
- **Objectif joueur :** consulter l’objectif et la carte avant la patrouille.
- **Événement narratif :** attribution de la réparation du relais nord.
- **Gameplay principal :** navigation Tâches/Carte/ATHENA/Archives.
- **Menace :** informations potentiellement falsifiées plus tard.
- **Variables ATHENA :** `empathy`, `discipline`, `trust`, `archives_discovered`.
- **Assets :** UI CRT/tablette.
- **Scripts concernés :** modules v12 UI et `main_15_storyboard_act1.gdpart`.
- **Contraintes physiques :** monde mis en pause pendant la consultation.
- **Variante smartphone :** boutons plus grands.
- **Validation :** ouverture `Tab`, fermeture `Échap`, objectif vers le relais seulement après consultation.
- **Statut :** intégré.

### 04 — Première sortie
- **Lieu :** secteur logistique et assemblage.
- **Objectif joueur :** progresser vers le nord.
- **Événement narratif :** premières anomalies de production.
- **Gameplay principal :** exploration, lampe, objets physiques et signalétique.
- **Menace :** sons et mouvements indirects.
- **Variables ATHENA :** `light_usage`, `noise_created`, `route_repetition`.
- **Assets :** rayonnages, convoyeurs et bras 6 axes.
- **Scripts concernés :** `main_01.gdpart`, modules v11/v13 et `main_15_storyboard_act1.gdpart`.
- **Contraintes physiques :** maximum de débris contrôlé.
- **Variante smartphone :** quantité de props et mises à jour réduites.
- **Validation :** passage terminable et lisible sans lampe permanente.
- **Statut :** intégré.

### 05 — Jouet observateur
- **Lieu :** couloir d’assemblage.
- **Objectif joueur :** identifier l’anomalie.
- **Événement narratif :** une unité ToyGuard suit le joueur du regard.
- **Gameplay principal :** observation, scan et diagnostic.
- **Menace :** unité potentiellement corrompue.
- **Variables ATHENA :** `utility_units_saved`, `utility_units_destroyed`, `gaze_behavior`.
- **Assets :** jouet industriel low-poly et yeux émissifs.
- **Scripts concernés :** modules v12 population, v13 campagne et jalon v16.
- **Contraintes physiques :** CharacterBody3D simple, collision capsule.
- **Variante smartphone :** animation et fréquence IA réduites.
- **Validation :** regard perceptible sans jumpscare lumineux.
- **Statut :** prototype.

### 06 — Déploiement KITE-01
- **Lieu :** ligne d’assemblage après la première patrouille.
- **Objectif joueur :** déployer le drone.
- **Événement narratif :** ATHENA autorise une reconnaissance distante.
- **Gameplay principal :** bascule caméra, déplacement, scan et rappel.
- **Menace :** future corruption de liaison.
- **Variables ATHENA :** `drone_state`, `trust`.
- **Assets :** KITE-01 procédural et overlay vidéo.
- **Scripts concernés :** modules v11 drone, v13 interface et jalon v16.
- **Contraintes physiques :** locomotion déterministe sans articulation rigide complète.
- **Variante smartphone :** boutons KITE et descente dédiés.
- **Validation :** `C`, clic droit et `Échap` rendent toujours la vue joueur.
- **Statut :** intégré.

### 07 — Reconnaissance KITE
- **Lieu :** passerelles et cellules industrielles.
- **Objectif joueur :** localiser un chemin et marquer une anomalie.
- **Événement narratif :** découverte de machines en attente.
- **Gameplay principal :** caméra distante et scan.
- **Menace :** perte progressive de qualité du signal.
- **Variables ATHENA :** `drone_state`, `archives_discovered`.
- **Assets :** overlay KITE, passerelles, lignes de production.
- **Scripts concernés :** modules v11/v13.
- **Contraintes physiques :** caméra ne rendant pas le châssis du drone.
- **Variante smartphone :** FOV et résolution 3D adaptés.
- **Validation :** image lisible et retour joueur immédiat.
- **Statut :** intégré.

### 08 — Premier contact ATHENA
- **Lieu :** Sentinel OS et écrans CRT de S-01.
- **Objectif joueur :** écouter et répondre après avoir consulté la mission.
- **Événement narratif :** ATHENA se présente comme intelligence naissante.
- **Gameplay principal :** dialogue EduCare local et déterministe.
- **Menace :** ambiguïté de ses intentions.
- **Variables ATHENA :** `empathy`, `discipline`, `trust`, `cognitive_stage`.
- **Assets :** visage/symbole CRT original.
- **Scripts concernés :** modules v12 narration/UI et séquence v16.
- **Contraintes physiques :** aucune action critique contrôlée par le dialogue.
- **Variante smartphone :** texte court et lisible.
- **Validation :** aucun dialogue ATHENA avant l’entrée S-01 et la consultation de Sentinel.
- **Statut :** intégré.

### 09 — Première apparition SPECTER-5
- **Lieu :** couloir nord.
- **Objectif joueur :** observer sans déclencher une poursuite injuste.
- **Événement narratif :** silhouette immobile au loin.
- **Gameplay principal :** mécanique de regard.
- **Menace :** SPECTER-5.
- **Variables ATHENA :** `gaze_behavior`, `player_fear_profile`.
- **Assets :** endosquelette industriel articulé.
- **Scripts concernés :** modules robot SPECTER, v11 visuel et verrouillage v16.
- **Contraintes physiques :** CharacterBody3D, pas de téléportation visible.
- **Variante smartphone :** distance de perception adaptée.
- **Validation :** SPECTER invisible et immobilisé avant Sentinel, puis progression uniquement hors regard.
- **Statut :** intégré.

### 10 — Relais nord
- **Lieu :** terminal nord.
- **Objectif joueur :** rétablir le relais.
- **Événement narratif :** confirmation de la contamination BABOUCHKA.
- **Gameplay principal :** interaction terminal et changement de phase.
- **Menace :** déclenchement du retour sous alarme.
- **Variables ATHENA :** `mission_stage`, `trust`, `destruction_count`.
- **Assets :** terminal, signalétique et éclairage d’alerte.
- **Scripts concernés :** fonctions terminal et progression.
- **Contraintes physiques :** terminal indestructible.
- **Variante smartphone :** interaction `E`/ACTION conservée.
- **Validation :** objectif bascule vers l’uplink S-01 et reste terminable.
- **Statut :** intégré.

## Direction artistique transversale

- **Style :** PS1 industrial low-poly, matériaux mats, palette quantifiée, textures nearest et ombrage par sommet.
- **Post-traitement :** pixelisation, scanlines, bruit et vignettage appliqués au monde 3D, sans dégrader le HUD.
- **Accessibilité :** curseur `Filtre rétro` de 0 à 100 %, intensité mobile réduite.
- **Performance :** géométrie procédurale, pluie MultiMesh et aucune nouvelle texture externe.

## Actes II et III

Les scènes 11 à 30 restent **prévues** ou **partiellement prototypées**. Elles seront détaillées au moment de leur intégration afin de conserver des incréments jouables et testables. Le prochain lot recommandé couvre les scènes 11 à 13 : redémarrage des lignes, réponse d’ATHENA et archives MATRYOSHKA.
