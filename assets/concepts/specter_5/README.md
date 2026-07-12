# SPECTER-5 — images à fournir à Meshy

Déposer dans ce dossier quatre images PNG ou JPEG cohérentes du même robot :

- `front.png` : vue de face orthographique ;
- `right.png` : profil droit orthographique ;
- `back.png` : vue arrière orthographique ;
- `three_quarter.png` : vue trois-quarts avant droite.

## Règles d'image

- un seul robot par image ;
- fond uni gris clair ou transparent ;
- aucune ombre portée forte ;
- même pose en A sur les quatre vues ;
- proportions identiques ;
- robot entièrement visible, sans recadrage ;
- aucun décor, texte, logo ou arme tenue ;
- éclairage neutre ;
- définition recommandée : 1024 × 1024 ou 1536 × 1536.

## Description de référence

Endosquelette bipède industriel conçu en 1987 pour la maintenance dangereuse et la poursuite. Silhouette humanoïde mécanique, épaules étroites, bassin compact, membres articulés visibles, plaques d'acier peint usées, câbles protégés, un capteur optique rouge central. Style PS1 industriel low-poly original, sans reprendre un personnage ou robot existant.

## Budget visé

- cible Meshy : environ 12 000 polygones ;
- export : GLB ;
- texture : une base color légère ;
- origine : au sol ;
- pose : A-pose ;
- collision Godot finale : capsule pour le corps et boîtes simples pour les interactions locales.

Le fichier `meshy.json` est déjà configuré. Ne lancer le mode `generate` qu'après avoir ajouté les quatre images et configuré le secret `MESHY_API_KEY`.
