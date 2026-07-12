# Blackout Protocol: Steel Echo — Godot/Jolt v11

Vertical slice jouable d’un survival-horror industriel en vue subjective, développée sous Godot 4.7 avec le moteur physique Jolt et publiée automatiquement en Web/PWA.

## Jouer en ligne

**https://bertrandmarconnet.github.io/VideoGame/**

Sur smartphone : ouvrir le lien dans Chrome ou Safari, passer en paysage puis toucher **COMMENCER LA RONDE**. Les commandes tactiles apparaissent automatiquement.

## Steel Echo v11

Cette version renforce la poursuite industrielle et la présence physique des machines avec une direction artistique originale :

- SPECTER-5 devient un endosquelette bipède complet avec bassin, colonne, cage thoracique, mâchoire, optiques, épaules, coudes, hanches et genoux articulés ;
- CRAWLER-7 reçoit un véritable châssis quadrupède avec quatre pattes articulées et une tête mobile ;
- les animations procédurales adaptent la démarche à la vitesse et à la proximité du joueur ;
- l’usine comprend désormais une passerelle technique, des chaînes suspendues, une grande presse hydraulique, des machines auxiliaires et six bras industriels animés ;
- l’abri S-01 possède un sas blindé, des consoles détaillées, des éclairages cyan/rouge et un grand écran de supervision animé ;
- le drone KITE-01 peut être déployé pour explorer et scanner l’usine ;
- les profils PC et smartphone conservent un budget graphique adapté au Web.

## Contenu jouable

- usine 3D procédurale longue d’environ 176 mètres ;
- cinq ambiances industrielles : contrôle, logistique, assemblage, archives et fonderie ;
- SPECTER-5, qui avance lorsque le joueur détourne le regard ;
- CRAWLER-7, activé plus tard selon la progression et le comportement ;
- directeur de peur adaptatif : surveillance, poursuite, obscurité ou bruit ;
- phase initiale de calibration sans attaque immédiate ;
- objets physiques Jolt saisissables, transportables et projetables ;
- dégâts infligés aux robots selon la masse et la vitesse des objets ;
- cloisons destructibles, brèches et débris physiques persistants avec budget limité ;
- objectif aller-retour : activer le relais nord puis restaurer l’uplink S-01 ;
- éclairage industriel, lampe torche et ambiance sonore procédurale ;
- menu de pause avec luminosité, volume, plein écran et redémarrage ;
- commandes PC et smartphone ;
- export Web/PWA automatique par GitHub Actions.

## Commandes PC

ZQSD/WASD : déplacement · souris : caméra · E : saisir/interagir · clic gauche : lancer/frapper · clic droit : interaction · F : lampe · Espace : saut · Maj : courir · C : déployer/reprendre KITE-01 · Ctrl : descendre avec le drone · Échap : pause.

## Commandes smartphone

Boutons directionnels à gauche · glisser sur la moitié droite pour regarder · E : interagir/saisir · LANCER : lancer/frapper · F : lampe · JUMP : sauter/monter avec le drone · RUN : courir/accélérer · KITE : drone · ▼D : descendre · Ⅱ : pause.

Le mode paysage est fortement recommandé. Le profil mobile réduit automatiquement la résolution interne et le nombre de lumières dynamiques.

## Construction et validation

Le workflow `.github/workflows/deploy-pages.yml` :

1. reconstitue `scripts/main.gd` à partir des parties versionnées ;
2. vérifie la présence des principaux systèmes de gameplay ;
3. valide le GDScript avec `gdlint` ;
4. télécharge Godot 4.7 et les modèles d’export officiels ;
5. importe réellement le projet en mode headless ;
6. produit les fichiers WebAssembly et PWA ;
7. publie le résultat sur GitHub Pages.

Projet original. Aucun modèle, son, logo, personnage ou morceau musical provenant de *Terminator*, *FNAF*, *Silent Hill*, *Resident Evil*, *Metal Gear Solid* ou *Vigil* n’est inclus.
