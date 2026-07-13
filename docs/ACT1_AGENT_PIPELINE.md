# Act I — orchestration multi-agent des assets

Le workflow `.github/workflows/act1-agent-orchestrator.yml` coordonne six rôles déterministes. Il ne remplace pas une revue humaine et ne commit jamais automatiquement un modèle généré dans le jeu.

## Agent 1 — orchestration et audit du dépôt

- vérifie le manifeste demandé ;
- fixe l’incrément : interface, arrivée extérieure et sas S-01 ;
- conserve le flux canonique : extérieur → porte de service → sas → porte blindée → vestibule latéral → bunker ;
- interdit l’ouverture directe face à l’écran central.

## Agent 2 — image de concept

- vérifie la présence de l’image source ;
- contrôle le format, la résolution, le poids et le ratio ;
- vérifie le manifeste Tripo ;
- produit un rapport avant tout appel payant.

Le premier concept versionné est :

```text
assets/concepts/act1/service_access/source.jpg
```

## Agent 3 — génération Tripo

- charge l’image sur l’API officielle Tripo ;
- crée une tâche `image_to_model` ;
- suit son état ;
- télécharge le GLB retourné ;
- conserve les identifiants et empreintes dans `generation.json`.

L’appel nécessite le secret GitHub :

```text
TRIPO_API_KEY
```

Aucune clé n’est écrite dans le dépôt ou dans le jeu Web. Sans ce secret, l’agent valide le lot mais marque la génération comme bloquée.

## Agent 4 — contrôle storyboard et qualité

- vérifie la taille du modèle ;
- compte les triangles et sommets ;
- contrôle la présence d’une géométrie exploitable ;
- refuse un modèle au-dessus du budget Web/mobile ;
- conserve un rapport JSON.

## Agent 5 — intégration Godot

- place le modèle validé dans un overlay correspondant à `assets/production/act1/` ;
- laisse le substitut procédural actif lorsque le GLB n’existe pas ;
- assemble `scripts/main.gd` ;
- exécute l’audit du flux d’entrée ;
- exécute `gdlint`.

## Agent 6 — test du jeu

- applique l’overlay sans modifier `main` ;
- importe le projet avec Godot 4.7 ;
- démarre la scène principale en mode headless ;
- recherche les erreurs critiques ;
- produit un export Web avec `index.html`, `index.wasm` et `index.pck`.

## Premier incrément intégré dans le code

Le lot v18 ajoute :

- blocage physique de l’ancienne ouverture centrale ;
- porte de service latérale ;
- couloir de décontamination ;
- double porte coulissante ;
- vestibule imposant un virage avant S-01 ;
- console Sentinel latérale ;
- animation déterministe des portes ;
- chargement conditionnel des futurs GLB ;
- interface d’accueil et panneau d’objectif retravaillés.

Les chemins recherchés par Godot sont :

```text
assets/production/act1/service_access.glb
assets/production/act1/s01_blast_door.glb
assets/production/act1/sentinel_console.glb
assets/production/act1/fps_flashlight.glb
```

Tant qu’un fichier manque, le jeu conserve une version procédurale compatible Web.

## Rig et animations

Les pièces du sas sont des éléments mécaniques : leur animation est pilotée dans Godot par `AnimatableBody3D`. Un squelette n’apporterait rien au gameplay et alourdirait la version Web.

Les rigs squelettiques seront réservés aux assets suivants :

1. main FPS ;
2. SPECTER-5 ;
3. CRAWLER-7 ;
4. KITE-01.

Pour ces assets, le pipeline devra ajouter des tâches postérieures explicitement décrites dans `post_tasks`, après validation de la géométrie statique et des noms de tâches pris en charge par la version courante de l’API Tripo.
