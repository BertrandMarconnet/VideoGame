# Blackout Protocol: Steel Echo — Godot/Jolt v10

Vertical slice jouable d’un survival-horror industriel en vue subjective, développé sous Godot 4.7 avec le moteur physique Jolt.

## Jouer en ligne

**https://bertrandmarconnet.github.io/VideoGame/**

Sur smartphone : ouvrir le lien dans Chrome ou Safari, passer en paysage puis toucher **COMMENCER LA RONDE**. Les commandes tactiles apparaissent automatiquement.

## Contenu

- usine procédurale longue avec cinq secteurs ;
- SPECTER-5, CRAWLER-7, MIMIC-3 et RAM-9 ;
- directeur de peur adaptatif ;
- phase initiale d’observation sans attaque immédiate ;
- objets Jolt saisissables et projetables ;
- panneaux destructibles et brèches réparables ;
- contrôles PC et smartphone ;
- menu de pause, luminosité, qualité et volumes ;
- audio industriel généré procéduralement ;
- export Web/PWA automatique par GitHub Actions.

## Commandes PC

ZQSD/WASD : déplacement · Souris : caméra · E : saisir/interagir · clic gauche : lancer · F : lampe · Espace : saut · Maj : courir · B : barricader · Tab : tablette · Échap : pause.

## Développement

Le workflow `.github/workflows/deploy-pages.yml` valide le projet, télécharge Godot 4.7 et ses modèles d’export officiels, produit l’export Web/PWA puis le publie sur GitHub Pages.

Projet original. Aucun modèle, son, musique, logo ou personnage provenant de Terminator, FNAF, Silent Hill, Resident Evil ou Metal Gear Solid n’est inclus.
