#include "title.typ"

#pagebreak()

#outline(title: "Table des matières", depth: 3, indent: 15pt)

#pagebreak()

= Introduction

= Familiarisation

Pour analyser les performances du programme fourni, cette étape consiste à utiliser plusieurs outils de profiling.
Cette approche permet d'identifier les goulots d'étranglement et les possibilités d'optimisation sans modifier le code source.

Cela permet d'identifier les problèmes de performance à différents niveaux : instructions CPU, branchements, accès mémoire et cache, ainsi que les fonctions les plus sollicitées.

== Génération de données

Pour avoir assez de données avec lesquelles travailler, j'ai généré 1 million de mesures:

```bash
./code/build/create-sample 1000000
Created 1000000 measurements in 159.335000 ms
```

== Perf

=== Statistiques

Avec la sous-commande `stat`, nous pouvons sortir des informations interessantes de l'éxecution de notre programme.

Perf est un outil de profiling et non d'instrumentation. Cela signifie qu'aucune modification n'est nécessaire pour la recompilation du programme à analyser.
Contrairement aux outils d'instrumentation qui nécessitent d'ajouter du code pour mesurer les performances, Perf s'occupe de lire directement les statistiques
fournies par le CPU via les _hardware performance counters_.


```bash
perf stat ./code/build/analyze measurements.txt

Performance counter stats for './code/build/analyze measurements.txt':

           562.19 msec task-clock:u                     #    0.998 CPUs utilized             
                0      context-switches:u               #    0.000 /sec                      
                0      cpu-migrations:u                 #    0.000 /sec                      
               89      page-faults:u                    #  158.310 /sec                      
    7,101,516,989      instructions:u                   #    2.63  insn per cycle            
                                                 #    0.08  stalled cycles per insn   
    2,701,765,045      cycles:u                         #    4.806 GHz                       
      588,963,871      stalled-cycles-frontend:u        #   21.80% frontend cycles idle      
    1,842,875,664      branches:u                       #    3.278 G/sec                     
        2,265,232      branch-misses:u                  #    0.12% of all branches           

      0.563191320 seconds time elapsed

      0.553085000 seconds user
      0.007922000 seconds sys
```

Ici nous pouvons déjà voir quelques informations comme le temps CPU consommé, le nombre d'instructions, le nombre de cycles, etc...
Les données que perf peut sortir dépendent aussi des _counters_  mises à disposition par le processeur.

=== Record et report

La commande `perf record` permet de collecter des données de profilage pendant l'exécution du programme et de les sauvegarder dans un fichier (par défaut perf.data).
Ces données peuvent ensuite être analysées ultérieurement avec `perf report` sans avoir à réexécuter le programme.

L'option `--call-graph dwarf` est particulièrement utile car elle permet de capturer la pile d'appels complète pour chaque échantillon,
ce qui nous aide à comprendre le contexte dans lequel les fonctions sont appelées. Cette option utilise les informations de débogage DWARF,
ce qui nécessite que l'exécutable ait été compilé avec les symboles de débogage (-g).
Dans notre cas, le Makefile fourni inclut déjà cette option de compilation, donc aucune modification a été effectuée dans ce sens.

```bash
perf record --call-graph dwarf ./code/build/analyze measurements.txt
perf report
```

#image("media/perf_report1.png")

=== Analyse perf

Ici nous remarquons, que l'on prend beaucoup de temps à comparer des strings, notamment dans la fonction `getcity`.
En effet, cette fonction est appellé pour chaque ligne de notre fichier qui contient 1 million de lignes
De plus, la fonction `strcmp` est appellé pour chaque une des villes déjà trouvées. Ceci est une première implémentation d'un algorithme et cela marche très bien
Comme amélioration possible, nous pourrions imaginer une utilisation d'une structure de données différente, un algorithme différent ou une meilleure utilisation
des ressources de notre CPU

== Hotspot

Hotspot est un outil de visualisation de données de profiling qui permet de générer des _flamegraphs_ à partir des données collectées par des outils comme perf.
Contrairement à `perf report` qui présente les données sous forme tabulaire, Hotspot offre une représentation graphique qui facilite l'identification des _hotspots_ du programme.

Un _hotspot_ est une partie du code qui consomme une proportion significative des ressources (CPU, mémoire, etc.) et qui représente donc une cible prioritaire pour l'optimisation.

```bash
hotspot perf.data
```

#image("media/hotspot1.png")

=== Analyse Hotspot

L'analyse du flamegraph généré par Hotspot confirme nos observations initiales faites avec `perf report`.

La pile d'appels la plus représentée dans le graphique est effectivement celle qui inclut les fonctions `main`, `getcity` et `strcmp`.
Cette visualisation nous apporte cependant des avantages par rapport au rapport textuel de perf :

- Elle montre clairement la proportion du temps d'exécution consacrée à la comparaison de chaînes de caractères par rapport au reste du programme
- Elle met en évidence la structure hiérarchique des appels, montrant que la fonction getcity est le point d'entrée principal qui mène aux nombreux appels à strcmp
- Les différentes couleurs permettent de distinguer visuellement les différentes parties du code et leurs contributions relatives

Le flamegraph confirme notre hypothèse principale : la majorité du temps d'exécution est consacrée à la recherche de villes avec `strcmp`.
Cette représentation visuelle rend immédiatement évident le goulot d'étranglement, même pour quelqu'un qui ne serait pas familier avec le code source.

== Cachegrind & Callgrind

Comme expliqué dans la donnée, Cachegrind et Callgrind sont des outils d'analyse de performance faisant partie de la suite Valgrind.
Contrairement à Perf qui utilise principalement l'échantillonnage des compteurs matériels,
ces outils fonctionnent par instrumentation complète du programme, ce qui les rend plus précis mais aussi plus lents.

Cachegrind se concentre sur la simulation de la hiérarchie de cache, permettant d'analyser en détail les défauts de cache (cache misses) à différents niveaux (L1, LL).
Callgrind étend Cachegrind en ajoutant une analyse détaillée des appels de fonction.

```bash
valgrind --tool=callgrind ./code/build/analyze measurements.txt
callgrind_annotate --auto=yes callgrind.out.137790
kcachegrind
```

Avec callgrind, nous pouvons encore sortir des informations intéressantes comme le fait que le fait qu'il y a `207M` appels à `strcmp`.

#image("./media/kcachegrind.png")

L'option `--simulate-cache=yes` active la simulation complète de cache, ce qui permet d'obtenir des informations détaillées sur les accès mémoire, mais ralentit considérablement l'exécution du programme.
Cette simulation est particulièrement utile pour identifier les problèmes de localité spatiale et temporelle dans les accès mémoire.

```bash
valgrind --tool=callgrind --simulate-cache=yes ./code/build/analyze measurements.txt
==141302== Events    : Ir Dr Dw I1mr D1mr D1mw ILmr DLmr DLmw
==141302== Collected : 7724157915 1416314738 314523730 1773 131746071 1259611 1710 1138 1549
==141302== 
==141302== I   refs:      7,724,157,915
==141302== I1  misses:            1,773
==141302== LLi misses:            1,710
==141302== I1  miss rate:          0.00%
==141302== LLi miss rate:          0.00%
==141302== 
==141302== D   refs:      1,730,838,468  (1,416,314,738 rd + 314,523,730 wr)
==141302== D1  misses:      133,005,682  (  131,746,071 rd +   1,259,611 wr)
==141302== LLd misses:            2,687  (        1,138 rd +       1,549 wr)
==141302== D1  miss rate:           7.7% (          9.3%   +         0.4%  )
==141302== LLd miss rate:           0.0% (          0.0%   +         0.0%  )
==141302== 
==141302== LL refs:         133,007,455  (  131,747,844 rd +   1,259,611 wr)
==141302== LL misses:             4,397  (        2,848 rd +       1,549 wr)
==141302== LL miss rate:            0.0% (          0.0%   +         0.0%  )
```

=== Analyse Valgrind

Ici nous trouvons des informations très intéressantes par rapport à la cache.
Très souvent, le principal frein à la performance ce sont les accès mémoire. Cependant, ici, nous trouvons pas ce problème.
L'algorithme étant très simple avec peu d'instructions permet au cpu d'avoir un miss rate de 0%.
Pour les données, je craignais un pire résultat à cause de la taille de chaque objet result mais non, un miss rate de 7.7% est très acceptable et cela
prouve encore une fois que ce qui ralentit le code ce sont la quantité instructions et non les accès mémoire.


== Analyse

En analysant les résultats du profiling, nous observons que la fonction `getcity` est un point critique pour les performances du programme.
Cette fonction est appelée pour chaque ligne de notre fichier d'entrée, soit 1 million de fois dans notre cas.

Pour chaque appel, la fonction `strcmp` est exécutée en comparant la ville courante avec chacune des villes déjà identifiées.
Cette approche implémente une recherche linéaire avec une complexité algorithmique de $O(N ^ 2)$ dans le pire des cas, où $N$ est le nombre de lignes du fichier.

Plus spécifiquement, le profiling révèle que :

- La fonction getcity consomme la majorité du temps d'exécution
- L'appel à strcmp est exécuté plus de 207 millions de fois selon les données de Callgrind
- Cette fonction représente un goulot d'étranglement évident pour les performances du programme

Bien que cette implémentation soit fonctionnelle et correcte, elle n'est pas optimale pour le traitement de grandes quantités de données.
L'algorithme actuel vérifie séquentiellement si une ville existe déjà dans la liste des villes connues, ce qui devient inefficace à mesure que le nombre de villes uniques augmente.

Pour pallier à ces limitations, je propose trois approches d'amélioration possibles, une approche structure de données, une approche algorithmique et une approche utilisation de ressources.

=== Structure de Données

Une Hash Map (table de hachage) serait particulièrement adaptée pour remplacer la recherche linéaire actuelle.

Cette structure de données permettrait de :

- Réduire la complexité de recherche de O(N) à O(1) en moyenne, où N est le nombre de villes déjà trouvées
- Utiliser une fonction de hachage pour calculer directement l'emplacement d'une ville dans la table
- Éviter les comparaisons multiples de chaînes de caractères pour chaque nouvelle ville

Une autre alternative serait d'utiliser un Arbre Binaire de Recherche qui offrirait :

- Une complexité de recherche de O(log n)
- Un maintien automatique de l'ordre des éléments
- Une utilisation efficace de la mémoire

Une troisième option pourrait être un Trie (arbre préfixe), particulièrement efficace pour les chaînes de caractères :

- Complexité de recherche proportionnelle à la longueur de la chaîne, et non au nombre de chaînes stockées
- Partage des préfixes communs entre les différentes chaînes
- Particulièrement adapté pour les noms de villes qui peuvent partager des préfixes communs

=== Algorithme

Une autre approche pour améliorer les performances serait de maintenir une liste triée de villes, ce qui permettrait d'utiliser une recherche dichotomique au lieu d'une recherche linéaire.
Cet algorithme fonctionnerait comme suit :

- Maintenir une liste triée de toutes les villes déjà rencontrées
- Pour chaque nouvelle ville, utiliser une recherche dichotomique pour vérifier si elle existe déjà
- Si la ville n'existe pas, l'insérer à la position correcte pour maintenir le tri

La recherche dichotomique a une complexité de O(log n) par recherche, ce qui est nettement plus efficace que la recherche linéaire actuelle (O(n)).
Même en considérant le coût d'insertion dans une liste triée (O(n) dans le pire des cas à cause du décalage des éléments), cette approche resterait avantageuse car:

- Le nombre de villes uniques est probablement bien inférieur au nombre total de lignes
- L'insertion peut être optimisée avec des structures de données appropriées
- La réduction du nombre d'appels à `strcmp` compenserait largement le coût supplémentaire des insertions

Cette approche pourrait être encore améliorée en utilisant des algorithmes de tri efficaces comme le quicksort ou le mergesort pour la maintenance de la liste triée.

=== Ressources
La parallélisation représente une autre stratégie d'optimisation pour ce programme, comme approche simple, nous pourrions imaginer dispatcher la recherche sur plusieurs threads,
permettant ainsi de parcourir toute la liste très rapidement.

Cependant, il faudrait également tenir compte du coût de création et de gestion des threads, ainsi que du surcoût lié à la synchronisation,
qui pourrait réduire les gains de performance sur des petits jeux de données.

Cela est clairement l'approche la moins idéale pour l'état actuel de l'algorithme vu que nous avons encore beaucoup à gagner en faisant des petites modifications comme le changement de la structure
de données qui stocke les villes.
