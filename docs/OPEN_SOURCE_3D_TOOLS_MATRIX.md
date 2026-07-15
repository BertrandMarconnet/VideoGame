# Matrice des outils 3D open source évalués

| Outil | Entrée | Géométrie | Texture | Rig | Animations | Besoin matériel | Rôle retenu |
|---|---|---:|---:|---:|---:|---|---|
| TripoSR | 1 image | prototype rapide | limitée | non | non | CPU possible, GPU préférable | abandonné pour les robots finaux |
| TripoSG | 1 image | meilleure forme | non intégrée | non | non | GPU ~8 Go | option géométrie GPU |
| Hunyuan3D-2mv | plusieurs vues | élevée | oui | non | non | GPU, ~6 Go forme / ~16 Go complet | meilleure option multivue future |
| TRELLIS | texte/image, multivue expérimental | élevée | oui | non | non | GPU NVIDIA >=16 Go | option visuelle future |
| UniRig | maillage 3D | n/a | n/a | oui | non | GPU CUDA >=8 Go | rig automatique futur |
| Générateur Blender CRAWLER-7 | spécification de design | contrôlée | oui | oui | oui | runner CPU GitHub | pipeline de production actuel |

La colonne « animations » désigne la présence de clips de gameplay directement livrés. Les outils de
reconstruction génèrent au mieux un maillage statique ; ils ne remplacent pas un pipeline complet de
personnage mécanique.
