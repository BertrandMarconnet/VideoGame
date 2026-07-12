# Pipeline 3D local et illimité avec TripoSR

## Choix de l’outil

Le pipeline principal utilise **TripoSR**, le projet open source de VAST-AI-Research, Tripo AI et Stability AI.

- code et poids sous licence MIT ;
- génération locale à partir d’une image ;
- aucun compte de génération ;
- aucune clé API ;
- aucun crédit ni quota imposé par un service distant ;
- sortie GLB ou OBJ ;
- environ 6 Go de VRAM pour le réglage par défaut.

« Illimité » signifie ici que le nombre de générations n’est pas limité par un fournisseur. Les limites réelles sont le temps de calcul, l’électricité, la mémoire GPU et l’espace disque de la machine locale.

Dépôt officiel : `https://github.com/VAST-AI-Research/TripoSR`

## Architecture retenue

```text
image de concept isolée
        ↓
GitHub Actions manuel
        ↓
runner GPU auto-hébergé
        ↓
TripoSR local
        ↓
Blender headless
        ↓
GLB décimé + échelle métrique + collision Godot
        ↓
artifact GitHub pour revue manuelle
```

Le workflow ne commite jamais automatiquement un modèle dans le jeu.

## Fichiers du pipeline

```text
.github/workflows/generate-triposr-asset.yml
tools/triposr_generate.py
tools/triposr_blender_postprocess.py
tools/setup_triposr_runner.sh
tools/testdata/triposr_manifest_smoke.json
assets/concepts/specter_5/triposr.json
```

## Pourquoi un runner auto-hébergé

Les runners GitHub standards n’exposent pas le GPU NVIDIA nécessaire à ce pipeline. La génération se fait donc sur une machine locale reliée au dépôt comme **self-hosted runner**.

Le job de validation reste exécuté gratuitement sur `ubuntu-latest`. Seul le job `generate` attend une machine portant les labels :

```text
self-hosted, linux, x64, gpu, triposr
```

Le workflow ne peut être lancé en génération que :

- manuellement ;
- depuis `main` ;
- par le propriétaire du dépôt.

## Configuration matérielle conseillée

Minimum praticable :

- GPU NVIDIA compatible CUDA ;
- 6 Go de VRAM ;
- 16 Go de RAM ;
- 25 Go d’espace libre ;
- Ubuntu, ou Windows avec WSL2 Ubuntu ;
- Blender disponible dans le `PATH` ;
- Python 3.10 ou 3.11.

8 à 12 Go de VRAM donnent davantage de marge pour les résolutions élevées.

## Installation sous Windows avec WSL2

### 1. Installer WSL2

Dans PowerShell administrateur :

```powershell
wsl --install -d Ubuntu-22.04
```

Redémarrer Windows si demandé. Installer un pilote NVIDIA prenant en charge CUDA dans WSL.

### 2. Installer les outils dans Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y git python3 python3-venv python3-pip blender
nvidia-smi
```

`nvidia-smi` doit afficher la carte graphique.

### 3. Ajouter le runner GitHub

Dans le dépôt :

```text
Settings → Actions → Runners → New self-hosted runner
```

Choisir Linux x64, puis exécuter les commandes indiquées par GitHub dans WSL. Lors de la configuration, ajouter les labels :

```bash
./config.sh \
  --url https://github.com/BertrandMarconnet/VideoGame \
  --token <JETON_TEMPORAIRE_AFFICHE_PAR_GITHUB> \
  --labels gpu,triposr,linux,x64
```

Le jeton d’enregistrement est temporaire. Il ne doit jamais être commité.

Démarrer ensuite le runner :

```bash
./run.sh
```

### 4. Installer TripoSR sur le runner

Depuis une copie locale du dépôt :

```bash
chmod +x tools/setup_triposr_runner.sh
tools/setup_triposr_runner.sh
```

Le script installe TripoSR par défaut dans :

```text
$HOME/opt/TripoSR
```

Il télécharge les poids publics au premier lancement de génération. Aucun compte Hugging Face n’est requis pour les poids publics de TripoSR.

La variable GitHub facultative `TRIPOSR_HOME` permet d’utiliser un autre dossier.

## Préparer une image source

TripoSR reconstruit un seul objet à partir d’une seule image. L’image doit :

- montrer un seul asset ;
- utiliser un fond uni ou transparent ;
- éviter le décor, le sol complexe et les ombres fortes ;
- présenter l’objet en vue trois-quarts ;
- montrer entièrement les pieds, roues ou pattes ;
- rester cohérente avec le storyboard ;
- ne contenir aucun élément protégé provenant d’une franchise.

Pour SPECTER-5, déposer l’image ici :

```text
assets/concepts/specter_5/three_quarter.png
```

Le manifeste associé existe déjà :

```text
assets/concepts/specter_5/triposr.json
```

## Manifeste

Exemple :

```json
{
  "asset_name": "SPECTER-5",
  "source_image": "assets/concepts/specter_5/three_quarter.png",
  "generation": {
    "foreground_ratio": 0.86,
    "mc_resolution": 256,
    "texture_resolution": 1024,
    "target_faces": 12000,
    "target_height_m": 1.95,
    "bake_texture": false,
    "create_collision": true,
    "device": "cuda:0"
  },
  "quality": {
    "max_glb_mb": 20
  },
  "provenance": {
    "author": "Bertrand Marconnet / Blackout Protocol",
    "source_license": "project-owned concept"
  }
}
```

### Réglages utiles

- `mc_resolution` : qualité géométrique avant décimation ;
- `target_faces` : budget final approximatif ;
- `target_height_m` : hauteur finale en mètres ;
- `bake_texture` : texture 1K au lieu des couleurs de sommets ;
- `create_collision` : ajoute une boîte nommée avec le suffixe Godot `-colonly` ;
- `max_glb_mb` : refuse un résultat trop lourd pour le Web.

Commencer avec `bake_texture: false`. La géométrie doit être approuvée avant de consacrer du temps à la texture.

## Lancer le workflow

### Validation sans GPU

Dans GitHub :

```text
Actions → Generate open-source 3D asset (TripoSR) → Run workflow
```

Choisir :

```text
mode = validate
```

Cette étape vérifie les scripts, le JSON et l’image sans générer de modèle.

### Génération

Laisser le runner local en ligne, puis relancer avec :

```text
mode = generate
bootstrap_runner = false
```

Lors du tout premier lancement, `bootstrap_runner = true` peut installer ou mettre à jour TripoSR. L’installation manuelle préalable reste préférable, car elle permet de diagnostiquer CUDA avant le workflow.

## Résultat

Le workflow crée un artifact contenant :

```text
<asset>/
├── source.png
├── raw/
├── production/<asset>.glb
├── validated-manifest.json
├── metrics.json
├── summary.json
├── PROVENANCE.md
└── github-summary.md
```

Le passage Blender :

- triangule le maillage ;
- réduit le nombre de faces ;
- applique une hauteur métrique ;
- place le pivot au centre du sol ;
- ajoute une collision boîte simple facultative ;
- exporte le résultat en GLB.

## Validation obligatoire avant Godot

TripoSR ne crée pas un asset final riggé. Avant intégration :

1. ouvrir le GLB dans Blender ;
2. supprimer les faces flottantes et intersections ;
3. vérifier l’arrière du modèle, souvent moins fiable ;
4. séparer les pièces qui doivent bouger ;
5. créer ou corriger les UV ;
6. préparer le rig et les animations ;
7. remplacer la collision boîte si nécessaire ;
8. créer LOD0 et LOD1 ;
9. réexporter en GLB ;
10. tester Godot 4.7, Web et smartphone.

Pour un robot : TripoSR fournit un **blockout détaillé**, pas un squelette prêt pour le gameplay.

## Assets adaptés et non adaptés

Adaptés à TripoSR :

- SPECTER-5 ;
- CRAWLER-7 ;
- KITE-01 ;
- mascotte ToyGuard ;
- main et lampe comme référence de volume ;
- accessoires isolés.

À produire plutôt dans Blender ou Blockbench :

- couloirs modulaires ;
- salle S-01 ;
- sas ;
- murs, sols et plafonds ;
- convoyeurs ;
- bras industriels six axes ;
- portes mobiles avec dimensions précises.

Une salle complète générée depuis une image produirait généralement un maillage fusionné, difficile à optimiser, collisionner et modulariser.

## Alternative de qualité supérieure

Hunyuan3D-2mini peut être ajouté ultérieurement. Il est plus lourd et son pipeline texture demande davantage de VRAM. TripoSR reste le choix par défaut pour démarrer avec environ 6 Go de VRAM et une licence MIT simple.

## Sécurité

- aucun secret requis ;
- aucun modèle automatiquement ajouté au jeu ;
- aucun workflow déclenché sur une pull request ;
- génération limitée au propriétaire et à `main` ;
- le runner doit être arrêté lorsqu’il n’est pas utilisé ;
- ne jamais exécuter sur le runner du code non vérifié provenant d’un fork.
