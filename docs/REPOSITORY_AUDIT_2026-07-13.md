# Audit du dépôt — 13 juillet 2026

## Périmètre

- pull requests et état de fusion ;
- workflows de construction et de génération 3D ;
- permissions GitHub Actions ;
- secrets et dépendances externes ;
- cohérence des dossiers d’assets.

## Résultats

- aucune pull request ouverte après la fusion de la PR 10 ;
- les PR 2 à 4 et 6 à 10 ont été fusionnées ; les PR 1 et 5 ont été fermées sans fusion
  conformément à leur rôle de validation temporaire ;
- les deux anciens workflows 3D nécessitant un GPU auto-hébergé sont retirés afin d’éviter
  des boutons inutilisables et des files d’attente bloquées ;
- le nouveau workflow fonctionne sans clé API sur un runner GitHub hébergé ;
- les événements issus d’Issues sont limités au propriétaire du dépôt ;
- les permissions du workflow sont limitées à `contents: write` et `issues: write` ;
- les images externes sont filtrées par domaine, taille et validité ;
- TripoSR est épinglé à une révision précise ;
- aucun secret Meshy n’est requis ni enregistré ;
- le GLB est validé par Blender, le lint GDScript et l’import Godot avant commit.

## Limites restantes

- GitHub Actions CPU est plus lent qu’un GPU ;
- TripoSR utilise une image principale et ne fusionne pas géométriquement quatre vues ;
- une inspection artistique dans Blender reste recommandée avant de remplacer définitivement
  un robot de production animé.
