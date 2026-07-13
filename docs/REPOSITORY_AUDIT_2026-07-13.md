# Audit du dépôt — 13 juillet 2026

## Périmètre

- pull requests, issues de test et état de fusion ;
- workflows de construction et de génération 3D ;
- permissions GitHub Actions ;
- secrets, dépendances externes et provenance ;
- cohérence des dossiers d’assets et validation du GLB produit.

## Résultats finaux

- aucune pull request ni issue ouverte à l’issue du nettoyage ;
- les PR 11, 13, 15 et 17 ont été fusionnées par squash après validation ;
- les issues de diagnostic 12, 14 et 16 ont été documentées puis fermées ;
- l’issue 18 constitue le test fonctionnel réussi de bout en bout ;
- les deux anciens workflows 3D nécessitant un GPU auto-hébergé ont été supprimés ;
- le nouveau workflow fonctionne sans clé API sur un runner GitHub hébergé ;
- les déclenchements depuis Issues sont limités au propriétaire du dépôt ;
- les permissions sont limitées à `contents: write` et `issues: write` ;
- les noms, chemins, domaines, dimensions, formats et tailles des images sont contrôlés ;
- TripoSR, PyTorch, ONNX Runtime et les dépendances critiques sont épinglés ;
- aucun secret Meshy, crédit commercial ou compte fournisseur n’est requis ;
- la génération produit un GLB, des métriques et un fichier de provenance ;
- Blender effectue le post-traitement, puis le GDScript et l’import Godot 4.7 sont validés avant commit ;
- le test SPECTER-5 a produit `assets/output 3d model/specter_5.glb` avec 8 999 faces après décimation.

## Corrections révélées par les tests réels

1. ajout d’ONNX Runtime, requis par `rembg` pour la suppression du fond ;
2. ajout de NumPy au Python système de Blender pour l’import glTF ;
3. conservation des journaux complets de génération dans les artefacts GitHub ;
4. correction de la formulation de provenance pour distinguer exécution locale du modèle et hébergement du runner.

## Limites restantes

- GitHub Actions CPU est plus lent qu’un GPU ;
- TripoSR utilise une image principale et ne fusionne pas géométriquement quatre vues ;
- le GLB obtenu est un candidat statique : le rig, les animations, les collisions de gameplay et la validation artistique restent à réaliser avant remplacement d’un robot de production ;
- la forme reconstruite dépend fortement de la qualité et du cadrage de l’image d’entrée.
