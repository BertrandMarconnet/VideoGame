# Storyboard implementation matrix

Cette matrice suit le canon ToyGuard/ATHENA de 1987. Les scènes 01 à 10 correspondent à l’Acte I du storyboard actualisé. Les anciens éléments Blacklake/Project Daedalus restent réservés à une extension ultérieure.

## Acte I — Mise en place

### 01 — Arrivée à ToyGuard
- **Lieu :** façade et accès du complexe.
- **Objectif joueur :** rejoindre le bunker S-01.
- **Événement narratif :** panne générale et procédure PERSEUS.
- **Gameplay principal :** prise en main FPS et lecture de la signalétique.
- **Menace :** aucune menace directe.
- **Variables ATHENA :** `mission_stage`, `player_fear_profile`.
- **Assets :** façade low-poly, pluie suggérée, enseigne ToyGuard.
- **Scripts concernés :** `main_01.gdpart`, `main_00.gdpart`.
- **Contraintes physiques :** architecture statique et indestructible.
- **Variante smartphone :** effets météorologiques réduits.
- **Validation :** chargement visible, objectif lisible, accès S-01 dégagé.
- **Statut :** prototype.

### 02 — Bunker S-01
- **Lieu :** salle de contrôle.
- **Objectif joueur :** consulter la supervision et démarrer la campagne.
- **Événement narratif :** découverte du programme PERSEUS.
- **Gameplay principal :** observation des écrans et préparation.
- **Menace :** fausse sécurité.
- **Variables ATHENA :** `trust`, `mission_stage`.
- **Assets :** sas, CRT, consoles, écran principal.
- **Scripts concernés :** `main_05.gdpart`, modules v11/v13.
- **Contraintes physiques :** terminaux et sas critiques indestructibles.
- **Variante smartphone :** textes agrandis et contrôles tactiles.
- **Validation :** écran principal sans obstruction de l’entrée.
- **Statut :** intégré.

### 03 — Sentinel OS
- **Lieu :** interface tablette.
- **Objectif joueur :** consulter l’objectif et la carte.
- **Événement narratif :** attribution de la réparation du relais nord.
- **Gameplay principal :** navigation Tâches/Carte/ATHENA/Archives.
- **Menace :** informations potentiellement falsifiées plus tard.
- **Variables ATHENA :** `empathy`, `discipline`, `trust`, `archives_discovered`.
- **Assets :** UI CRT/tablette.
- **Scripts concernés :** modules v12 UI.
- **Contraintes physiques :** monde mis en pause pendant la consultation.
- **Variante smartphone :** boutons plus grands.
- **Validation :** ouverture `Tab`, fermeture `Échap`, objectif toujours accessible.
- **Statut :** intégré.

### 04 — Première sortie
- **Lieu :** secteur logistique et assemblage.
- **Objectif joueur :** progresser vers le nord.
- **Événement narratif :** premières anomalies de production.
- **Gameplay principal :** exploration, lampe, objets physiques.
- **Menace :** sons et mouvements indirects.
- **Variables ATHENA :** `light_usage`, `noise_created`, `route_repetition`.
- **Assets :** rayonnages, convoyeurs, bras 6 axes.
- **Scripts concernés :** `main_01.gdpart`, modules v11/v13.
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
- **Assets :** jouet industriel low-poly et yeux emissifs.
- **Scripts concernés :** modules v12 population et v13 campagne.
- **Contraintes physiques :** CharacterBody3D simple, collision capsule.
- **Variante smartphone :** animation et fréquence IA réduites.
- **Validation :** regard perceptible sans jumpscare lumineux.
- **Statut :** prototype.

### 06 — Déploiement KITE-01
- **Lieu :** sortie de S-01 ou ligne d’assemblage.
- **Objectif joueur :** déployer le drone.
- **Événement narratif :** ATHENA autorise une reconnaissance distante.
- **Gameplay principal :** bascule caméra, déplacement, scan et rappel.
- **Menace :** future corruption de liaison.
- **Variables ATHENA :** `drone_state`, `trust`.
- **Assets :** KITE-01 procédural et overlay vidéo.
- **Scripts concernés :** modules v11 drone, v13 interface.
- **Contraintes physiques :** locomotion déterministe sans articulation rigide complète.
- **Variante smartphone :** boutons KITE et descente dédiés.
- **Validation :** `C` et clic droit rendent toujours la vue joueur.
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
- **Contraintes physiques :** caméra ne rend pas le châssis du drone.
- **Variante smartphone :** FOV et résolution 3D adaptés.
- **Validation :** image lisible et retour joueur immédiat.
- **Statut :** intégré.

### 08 — Premier contact ATHENA
- **Lieu :** CRT de S-01 ou Sentinel OS.
- **Objectif joueur :** écouter et répondre.
- **Événement narratif :** ATHENA se présente comme intelligence naissante.
- **Gameplay principal :** dialogue EduCare local et déterministe.
- **Menace :** ambiguïté de ses intentions.
- **Variables ATHENA :** `empathy`, `discipline`, `trust`, `cognitive_stage`.
- **Assets :** visage/symbole CRT original.
- **Scripts concernés :** modules v12 narration et UI.
- **Contraintes physiques :** aucune action critique contrôlée par le dialogue.
- **Variante smartphone :** texte court et lisible.
- **Validation :** dialogue cohérent avec le stade néonatal.
- **Statut :** intégré.

### 09 — Première apparition SPECTER-5
- **Lieu :** couloir nord.
- **Objectif joueur :** observer sans déclencher une poursuite injuste.
- **Événement narratif :** silhouette immobile au loin.
- **Gameplay principal :** mécanique de regard.
- **Menace :** SPECTER-5.
- **Variables ATHENA :** `gaze_behavior`, `player_fear_profile`.
- **Assets :** endosquelette industriel articulé.
- **Scripts concernés :** modules robot SPECTER et v11 visuel.
- **Contraintes physiques :** CharacterBody3D, pas de téléportation visible.
- **Variante smartphone :** distance de perception adaptée.
- **Validation :** progression uniquement hors regard et indices sonores présents.
- **Statut :** intégré.

### 10 — Relais nord
- **Lieu :** terminal nord.
- **Objectif joueur :** rétablir le relais.
- **Événement narratif :** confirmation de la contamination BABOUCHKA.
- **Gameplay principal :** interaction terminal et changement de phase.
- **Menace :** déclenchement du retour sous alarme.
- **Variables ATHENA :** `mission_stage`, `trust`, `destruction_count`.
- **Assets :** terminal, signalétique, éclairage d’alerte.
- **Scripts concernés :** fonctions terminal et progression.
- **Contraintes physiques :** terminal indestructible.
- **Variante smartphone :** interaction `E`/ACTION conservée.
- **Validation :** objectif bascule vers l’uplink S-01 et reste terminable.
- **Statut :** intégré.

## Actes II et III

Les scènes 11 à 30 restent **prévues** ou **partiellement prototypées**. Elles seront détaillées au moment de leur intégration afin de conserver des incréments jouables et testables. Le prochain lot recommandé couvre les scènes 11 à 13 : redémarrage des lignes, réponse d’ATHENA et archives MATRYOSHKA.
