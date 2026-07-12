# ATHENA Protocol v12

## Intention

Cette version transforme la vertical slice industrielle en premier chapitre narratif. ToyGuard Industries est publiquement une usine de jouets intelligents, mais son sous-sol développe des plateformes autonomes pour le projet militaire PERSEUS. En septembre 1987, l’opération soviétique MATRYOSHKA infiltre le réseau à travers des consoles civiles. Le programme BABOUCHKA fragmente les sécurités et provoque l’éveil d’ATHENA.

ATHENA n’est pas présentée comme un simple ennemi. Elle observe le joueur, mémorise ses décisions et tente de déduire une doctrine : protéger, contenir ou sacrifier. Le joueur doit donc survivre tout en donnant involontairement des exemples moraux à une intelligence militaire naissante.

## Prologue jouable

Le bouton de démarrage ouvre une introduction en cinq séquences :

1. façade commerciale de ToyGuard ;
2. double usage civil et militaire de l’usine ;
3. cyberattaque MATRYOSHKA/BABOUCHKA ;
4. émergence d’ATHENA ;
5. mission du joueur.

Chaque écran avance automatiquement après sept secondes. Le joueur peut continuer manuellement ou passer toute l’introduction.

## Tablette Sentinel

La tablette s’ouvre avec `Tab` et met le monde en pause.

- **Tâches** : objectifs, indices, commandes et état des destructions ;
- **Carte** : secteurs de l’usine, menaces, unités compromises et état du drone ;
- **ATHENA** : stade cognitif, empathie, discipline, confiance et décisions EduCare ;
- **Archives** : traces de BABOUCHKA et mémoire récente d’ATHENA.

Les trois décisions EduCare modifient les variables internes d’ATHENA et influencent les événements ultérieurs.

## Interactions

- **Clic gauche** : interaction immédiate avec la cible : saisir, lancer, activer, inspecter ou endommager selon le contexte ;
- **Clic droit** : menu d’actions possibles sur la cible : scanner, saisir, pirater, forcer, marquer, négocier, diagnostiquer ou isoler ;
- **E** : interaction rapide conservée pour l’accessibilité ;
- **C** : déployer ou rappeler KITE-01.

## Directeur narratif adaptatif

Le directeur local combine :

- l’empathie, la discipline et la confiance d’ATHENA ;
- le profil de peur du joueur ;
- la progression de mission ;
- les éléments détruits ;
- les unités utilitaires compromises ;
- les indices découverts.

Il sélectionne ensuite des dialogues et événements cohérents : corruption d’un jouet, diversion d’une menace, confinement d’un secteur ou question morale. La personnalité d’ATHENA progresse de **néonatale** à **adulte**.

Ce module fonctionne entièrement dans le navigateur et ne transmet aucune donnée. Il simule une narration générative par composition conditionnelle. Une connexion future à un LLM/VLM doit rester optionnelle, sécurisée côté serveur et ne jamais exposer une clé API dans l’export Web.

## Monde vivant

L’usine contient désormais des unités ToyGuard autonomes. Elles patrouillent entre les zones, fuient les robots hostiles et peuvent être compromises par BABOUCHKA. Le joueur peut les diagnostiquer ou les isoler via le menu contextuel. Leurs mouvements et articulations sont animés procéduralement avec un budget réduit sur mobile.

## Destruction

Les équipements, consoles secondaires, rayonnages et certains éléments de production peuvent être endommagés puis fragmentés en débris Jolt. Les sols, murs porteurs, enveloppes, ponts et terminaux de mission restent protégés afin d’éviter de rendre la partie impossible.
