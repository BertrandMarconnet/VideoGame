# Générateur 3D simple

Aucune clé API et aucun runner personnel ne sont nécessaires.

## Méthode la plus simple

1. Ouvrir l’onglet **Issues** du dépôt.
2. Cliquer sur **New issue**.
3. Choisir **Générer un modèle 3D**.
4. Donner un nom, puis glisser une image en vue trois-quarts.
5. Cliquer sur **Submit new issue**.

GitHub génère le fichier GLB, le contrôle avec Blender et Godot, le place dans
`assets/output 3d model/`, puis répond dans l’issue avec le lien du modèle.

Pour SPECTER-5, les quatre images sont déjà rangées dans `specter_5/`. Il suffit aussi
d’ouvrir **Actions → Generate 3D model — no key → Run workflow** et de conserver
`asset = specter_5`.

## Limite technique

TripoSR reconstruit la géométrie depuis une image principale. Les autres vues servent de
références de contrôle. Le calcul est réalisé sur le CPU gratuit de GitHub et peut prendre
de 20 minutes à plusieurs heures selon la charge et la qualité choisie.
