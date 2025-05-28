#include "title.typ"

#pagebreak()

#outline(title: "Table des matières", depth: 3, indent: 15pt)

#pagebreak()

= Introduction

Ce laboratoire a pour objectif de nous familiariser avec les techniques et outils de parallélisation des tâches à travers deux activités.
La première activité consite à optimiser et paralléliser un algorithme de calcul de fréquence de k-mers dans des fichiers texte volumineux,
La seconde nous invite à appliquer les techniques de parallélisation à notre implémentation DTMF développée lors du semestre.

= Première partie — Analyse des k-mers

== Analyse des inefficacités du code original et améliorations apportées

Le code original (`main-original.c`) présentait plusieurs problèmes de performance.

=== Multiple ouverture/fermeture de fichier

Le plus gros problème était dans la fonction `read_kmer()` qui ouvrait et fermait le fichier à chaque lecture d'un k-mer.
Pour un fichier de 1 million de caractères avec `k=3`, ça veut dire presque un million d'ouvertures/fermetures de fichier, ce qui ralentit énormément le programme.

=== Double copie des données

Le code original copiait les données deux fois :
1. *Kernel -> User-space* : avec `fgetc()` pour lire caractère par caractère
2. *User-space -> Structure* : avec `strcpy()` pour copier dans l'entrée de la table

=== Allocations dynamiques

La table `Kmer` est initializé avec une capacité nulle. Ceci ralentit le programme car,
même pour un fichier `ABCDABC` il y aura 5 résultats. Ceci avec la stratégie actuelle demande 4 appels d'allocation mémoire: 0 -> 1, 1 -> 2, 2 -> 4, 4 -> 8.

Cet algorithme marche bien de façon générale, mais si l'on sait que l'on va travailler avec de gros fichiers, ceci n'est pas optimale.

=== Modifications

Pour corriger ces problèmes, j'ai d'abord modifié le code pour n'ouvrir qu'une seule fois le fichier et se déplacer dedans après chaque lecture.
Ceci corrige le problème des ouvertures et fermetures multiples mais ne corrige pas le problème de la double copie.
Pour cela, j'ai utilisé `mmap` pour mapper le fichier entier en mémoire. Ceci évite complètement les ouvertures/fermetures répétées et permet un accès direct aux données.
Lors de la copie des caractères dans la structure dédiée, cette copie s'effectue depuis le kernel space directement, on évite donc une copie.

Pour le problème des allocations dynamiques mentionné précedemment, j'ai tout simplement modifié le code pour initialiser un buffer avec `1024` entrées. Cette valeur a été choisie arbitrairement.

== Parallélisation avec OpenMP

=== Approche

Pour paralléliser le programme, j'ai décidé de créer des tables séparées par thread, ceci permet à chaque thread de travailler avec sa propre table.
Ensuite, chaque thread s'occupera lui-même de faire une partie du travail.
Comme le travail est équivalent pour chaque thread, le schedule statique par défaut nous suffit largement.
Une fois que tous les threads ont terminée, une partie sérielle s'occupe de fusionner toutes les tables ensemble.

Le fait de diviser le travail ainsi, nous évite aussi de devoir gérer la synchronisation entre les threads. Chaque thread s'occupe de sa propre partie du fichier et la seule synchronisation
nécessaire est une synchronisation finale lorsque tous les threads auront terminé.

== Autres possibilités d'amélioration

Comme discuté lors d'un laboratoire précedent, nous pourrions encore modifier la structure de données. En effet, l'utilisation d'un tableau nous oblige à parcourir tout le tableau pour vérifier si
une entrée correspondante existe déjà. Ceci implique une recherche en `O(n)` après chaque lecture. Pour améliorer cela, on pourrait utiliser un `trie`, une arbre où chaque noeud 
représente un caractère et le parcours dans l'arbre nous permet de trouver la chaine de caractères souhaitée.

== Compilation

Comme "demandé" dans la donnée, le fichier `CMakeLists.txt` a été modifiée pour générer 3 executables:

- `k-mer-original`: Implémentation original
- `k-mer`: Implémentation optimisé single threaded
- `k-mer-omp`: Implémentation optimisé multi threaded avec OpenMP

== Tests

Une fois ce fichier `CMakeLists.txt` mis en place, il est aussi très simple d'écrire un petit script de test qui compare que l'output des fichiers correspond.
Le script `test.sh` compile correctement le code et génére des tests pour un fichier d'entrée de 1000 caractères.
Ensuite il utilise l'outilitaire `cmp` pour simplement vérifier que les sorties des programmes sont égales.

== Performance

=== Résultats
```bash
❯ hyperfine --warmup 10 "./build/k-mer-original ./inputs/pi_dec_1m.txt 3"
Benchmark 1: ./build/k-mer-original ./inputs/pi_dec_1m.txt 3
  Time (mean ± σ):      7.769 s ±  0.197 s    [User: 2.993 s, System: 4.739 s]
  Range (min … max):    7.621 s …  8.197 s    10 runs

❯ hyperfine --warmup 10 "./build/k-mer ./inputs/pi_dec_1m.txt 3"
Benchmark 1: ./build/k-mer ./inputs/pi_dec_1m.txt 3
  Time (mean ± σ):      2.336 s ±  0.096 s    [User: 2.316 s, System: 0.001 s]
  Range (min … max):    2.289 s …  2.605 s    10 runs

❯ hyperfine --warmup 10 "./build/k-mer-omp ./inputs/pi_dec_1m.txt 3"
Benchmark 1: ./build/k-mer-omp ./inputs/pi_dec_1m.txt 3
  Time (mean ± σ):     380.3 ms ±  15.5 ms    [User: 3659.2 ms, System: 16.2 ms]
  Range (min … max):   348.8 ms … 405.1 ms    10 runs
```

=== Analyse

Nous pouvons voir des énormes différences entre les différentes versions mais les résultats sont ceux attendus. La version originale est la plus lente,
suivie de la version single threaded et pour finir la version openmp est la plus rapide.

Pour les deux premières versions, il est intéressant de voir que la différence est surtout dans le temps passé dans le kernel, tous les appels à `fopen`, `fclose`, `fgetc` ont un vrai poids sur 
la performance de l'application. Même si le temps `user` est très similaire entre les deux versions, le temps `system` passe de `4.739s` à `0.001s`.

Il est aussi intéressant de voir le ratio entre la version single threaded et la version multi threaded, nous notons une amélioration de 6x sur un CPU à 12 cores.
Ceci est attendu, même si nous arrivons à bien paralléliser une grande partie du calcul, le overhead pour la création des threads ainsi que la partie fusion de l'algorithme ne nous permet pas d'atteindre
une amélioration de 12x.

= Deuxième partie — Activité DTMF

== Description de la partie parallélisée

Pour la parallélisation du décodeur DTMF, j'ai complètement modifié l'algorithme original. L'approche initiale (décrite dans le premier rapport)
consistait à itérer séquentiellement dans le fichier audio pour déterminer si une fenêtre devait être analysée ou ignorée selon la présence de silence,
puis l'algorithme décode immédiatement chaque fenêtre identifiée et génére le caractère lors de la détéction d'une fin de séquence.

La nouvelle approche divise le processus en trois phases:

1. Détection et indexation des fenêtres: Parcours du fichier audio pour identifier toutes les fenêtres d'intérêt et sauvegarde de leurs informations 
(offset dans les données et un flag pour savoir si c'est une fin de séquence)
2. Décodage parallèle: Traitement simultané de toutes les fenêtres identifiées précédemment - cette phase est facilement parallélisable puisque nous connaissons déjà exactement quelles parties analyser
3. Reconstitution du texte: Assemblage du message final en utilisant les résultats de décodage obtenus lors de la phase précédente

Cette séparation permet d'isoler la partie computationnellement intensive (le décodage des fenêtres) et de la paralléliser efficacement avec OpenMP.
Ceci nous permet aussi de paralléliser les deux algorithmes de décodage - `fft` et `correlation` vu que la seule différence est la fonction de décodage individuelle d'une fenêtre.

Même si cette version peut paraître plus coûteuse, vu les plusieurs itérations sur les même données (surtout pour la phase 2 et 3), un premier test de performance - sans parallélisation - montrait un
résultat similaire entre cette version et la version précédente.

== Stratégie de parallélisation

La parallélisation s'applique uniquement à la phase 2 (décodage des fenêtres).
Une fois que toutes les fenêtres d'intérêt sont identifiées et indexées, chaque thread OpenMP peut traiter indépendamment un sous-ensemble de ces fenêtres.

Pour cette partie, nous nous retrouvons avec un cas similaire à la première partie:
- Pas de synchronisation nécessaire : Chaque thread travaille sur des fenêtres distinctes et écrit dans des emplacements mémoire séparés
- Répartition équitable du travail : Le nombre de fenêtres à décoder est connu à l'avance, permettant une distribution optimale entre les threads
- Préservation de l'ordre: Les résultats sont stockés dans un tableau indexé, cela maintien l'ordre original nécessaire pour la reconstitution du texte

L'implémentation utilise une directive OpenMP avec un ordonnancement statique par défaut, ce qui convient parfaitement puisque chaque fenêtre nécessite approximativement le même temps de traitement.

== Algorithmes disponibles

Avec ceci ajouté, le programme permet maintenant de choisir entre quatre modes de décodage au lancement :
- `decode` : Décodage fréquentiel séquentiel (FFT)
- `decode_time_domain` : Décodage temporel séquentiel (corrélation)
- `decode_parallel` : Décodage fréquentiel parallèle (FFT + OpenMP)
- `decode_parallel_time_domain` : Décodage temporel parallèle (corrélation + OpenMP)

== Évaluation de l'efficacité

=== Résultats de performance

```bash
# Décodage temporel
❯ hyperfine --warmup 10 "./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\!.wav"
Time (mean ± σ):      20.7 ms ±   0.3 ms    [User: 4.1 ms, System: 16.3 ms]

❯ hyperfine --warmup 10 "./build/dtmf_encdec decode_parallel_time_domain audio/crashing_is_not_allowed_\!.wav"
Time (mean ± σ):      20.2 ms ±   3.7 ms    [User: 47.6 ms, System: 17.4 ms]

# Décodage fréquentiel
❯ hyperfine --warmup 10 "./build/dtmf_encdec decode audio/crashing_is_not_allowed_\!.wav"
Time (mean ± σ):     283.0 ms ±   2.3 ms    [User: 265.2 ms, System: 16.3 ms]

❯ hyperfine --warmup 10 "./build/dtmf_encdec decode_parallel audio/crashing_is_not_allowed_\!.wav"
Time (mean ± σ):      61.5 ms ±   9.1 ms    [User: 470.9 ms, System: 20.0 ms]
```

=== Analyse des résultats

Le décodage temporel présentait déjà une performance très optimisée dans sa version séquentielle, ce qui explique l'amélioration marginale observée avec la parallélisation (20.7ms → 20.2ms).
L'overhead introduit par la création et la gestion des threads OpenMP compense presque entièrement le gain obtenu par la parallélisation..

Le décodage fréquentiel bénéficie d'une amélioration substantielle avec la parallélisation, passant de 283.0ms à 61.5ms, soit une accélération de 4.6x sur un processeur 12 coeurs.
L'efficacité de parallélisation atteint environ 38% (4.6/12), un résultat satisfaisant compte tenu de l'existence de phases séquentielles incompressibles dans l'algorithme global.

La parallélisation s'avère particulièrement bénéfique pour le décodage fréquentiel qui implique des calculs de FFT coûteux.
Pour le décodage temporel, déjà très optimisé grâce à l'utilisation d'un nombre réduit d'échantillons pour la corrélation,
les gains sont négligeables et peuvent même être contre-productifs sur de petits fichiers à cause de l'overhead des threads.

Cette différence illustre l'importance d'analyser le profil de performance avant d'appliquer la parallélisation : tous les algorithmes ne bénéficient pas équitablement de cette optimisation.

#pagebreak()

= Conclusion

Ce laboratoire m'a a permis d'expérimenter concrètement avec différentes approches de parallélisation et d'observer leurs impacts sur des problèmes aux caractéristiques distinctes.
Pour l'analyse des k-mers, j'ai constaté des gains de performance spectaculaires grâce à l'optimisation du code séquentiel (élimination des ouvertures/fermetures répétées de fichiers, utilisation de mmap)
et à la parallélisation efficace avec OpenMP. L'amélioration de 6x obtenue sur un processeur 12 cœurs démontre que cette approche est particulièrement adaptée aux problèmes de traitement de données massives où le travail peut être naturellement réparti.
L'activité DTMF a révélé une réalité plus nuancée de la parallélisation. Alors que le décodage fréquentiel a bénéficié d'une accélération significative (4.6x), le décodage temporel, déjà très optimisé,
n'a montré que des gains marginaux. Cette observation souligne un principe fondamental : la parallélisation n'est bénéfique que lorsque le coût computationnel du travail à paralléliser
dépasse l'overhead de création et coordination des threads.
Pour conclure, ce laboratoire illustre que la parallélisation efficace nécessite une compréhension approfondie des caractéristiques algorithmiques du problème traité
et une évaluation rigoureuse du rapport coût/bénéfice de cette optimisation.
