# Pipeline des modèles 3D

## État de la version Web

La version v12 utilise actuellement des modèles procéduraux construits avec les primitives de Godot. Ce choix garantit un chargement rapide, une physique cohérente et un export Web léger. Les robots, jouets utilitaires, bras industriels et machines possèdent des articulations animées, mais ne reposent pas encore sur une bibliothèque externe de fichiers GLB.

## Règles pour les futurs assets

Seuls les modèles accompagnés d’une licence explicite peuvent être intégrés :

- **CC0 / domaine public** : intégration autorisée avec conservation de la preuve de licence ;
- **CC BY** : attribution obligatoire dans `THIRD_PARTY_ASSETS.md` et dans les crédits du jeu ;
- **GPL ou licences destinées au code** : à éviter pour les fichiers artistiques sans analyse préalable ;
- **Editorial use**, **non-commercial**, licences ambiguës ou absence de licence : refusés ;
- aucun modèle, logo, personnage ou décor extrait d’une franchise existante.

## Format recommandé

- GLB/glTF 2.0 ;
- textures WebP ou PNG, idéalement 1K maximum pour le profil navigateur ;
- squelette inférieur à 70 os pour les personnages principaux ;
- LOD0, LOD1 et collision simplifiée ;
- animations séparées : idle, marche, course, détection, attaque et panne ;
- pivot, unités métriques et axes vérifiés avant import.

## Budget Web indicatif

| Élément | Triangles LOD0 | Triangles LOD1 | Textures |
|---|---:|---:|---:|
| Ennemi principal | 20 000–35 000 | 8 000–15 000 | 2 × 1K |
| Jouet utilitaire | 4 000–10 000 | 2 000–4 000 | 1 × 1K |
| Machine industrielle | 8 000–20 000 | 3 000–8 000 | 1–2 × 1K |
| Petit accessoire | 300–2 000 | facultatif | atlas partagé |

## Processus d’intégration

1. enregistrer l’URL source, l’auteur, la licence et la date de téléchargement ;
2. contrôler le contenu de l’archive et supprimer les fichiers inutiles ;
3. nettoyer le maillage et les matériaux dans Blender ;
4. créer une collision simplifiée distincte ;
5. exporter en GLB avec les animations ;
6. tester le rendu Godot GL Compatibility ;
7. vérifier la taille du PCK et les performances sur smartphone ;
8. compléter `THIRD_PARTY_ASSETS.md` avant fusion.

Le gameplay doit toujours prévoir un substitut procédural lorsque le modèle externe n’est pas disponible ou dépasse le budget Web.
