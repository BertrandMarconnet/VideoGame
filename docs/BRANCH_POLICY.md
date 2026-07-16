# Politique de branches

Le dépôt de production utilise une seule branche durable : `main`.

## Règles

- les modifications temporaires passent par une pull request courte ;
- la pull request est fusionnée uniquement après réussite des tests Godot, Web et des tests concernés ;
- la branche temporaire est supprimée immédiatement après fusion ;
- aucun développement parallèle durable n'est conservé ;
- les assets générés par Issues sont validés puis poussés directement sur `main` par le bot du dépôt ;
- les anciens travaux non fusionnés peuvent être conservés sous forme de tag d'archive avant suppression de leur branche.

Cette politique réduit les conflits, évite les variantes concurrentes du jeu et maintient une source de vérité unique.
