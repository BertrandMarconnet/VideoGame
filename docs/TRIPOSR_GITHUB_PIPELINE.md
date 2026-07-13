# Générateur 3D GitHub sans clé

## Interface utilisateur

Le point d’entrée recommandé est le formulaire GitHub :

`Issues → New issue → Générer un modèle 3D`

L’utilisateur renseigne le nom, glisse une image et valide. Aucun dossier, secret, compte
Meshy ou runner GPU n’est demandé.

## Pipeline

1. le formulaire est accepté uniquement si son auteur est le propriétaire du dépôt ;
2. les noms et chemins sont normalisés ;
3. les pièces jointes sont limitées à quatre images et 12 Mo par image ;
4. seuls les domaines d’images GitHub sont téléchargés ;
5. TripoSR est installé à la révision épinglée
   `107cefdc244c39106fa830359024f6a2f1c78871` ;
6. PyTorch utilise les roues CPU officielles ;
7. Blender réduit le maillage, règle l’échelle métrique et exporte le GLB ;
8. le GDScript est assemblé et linté ;
9. Godot 4.7 importe le projet et le modèle ;
10. le GLB n’est poussé sur `main` qu’après validation.

## Sortie

```text
assets/output 3d model/<nom_normalisé>.glb
assets/output 3d model/<nom_normalisé>.metrics.json
assets/output 3d model/<nom_normalisé>.PROVENANCE.md
```

## Sécurité

- aucun secret externe ;
- aucune API commerciale ;
- exécution autorisée uniquement pour le propriétaire ;
- aucune commande issue du texte de l’utilisateur n’est exécutée ;
- restrictions de domaine, taille et format sur les images ;
- dépendance TripoSR épinglée sur un commit précis.
