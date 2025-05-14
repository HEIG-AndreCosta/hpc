#include "title.typ"

#pagebreak()

#outline(title: "Table des matières", depth: 3, indent: 15pt)

#pagebreak()

= Introduction

L'optimisation des performances est un aspect fondamental du développement logiciel moderne, particulièrement dans les systèmes où les ressources sont limitées ou les attentes
en termes de temps de réponse sont élevées. Ce laboratoire se concentre sur l'utilisation d'outils de profiling pour analyser et améliorer les performances des applications.

Le profiling permet d'identifier avec précision les sections de code qui consomment le plus de ressources (temps CPU, mémoire, accès disque) et constituent donc des goulots d'étranglement potentiels.

Dans ce rapport, j'explore différents outils de profiling disponibles sous Linux.

Ce laboratoire se divise en deux parties principales :

- Une phase de familiarisation avec les outils de profiling, appliquée à un programme d'analyse de températures par ville fourni comme exemple.
- Une phase d'application de ces outils au décodeur DTMF développé lors des laboratoires précédents, suivie de l'implémentation et de l'évaluation d'optimisations ciblées.

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

       562.19 msec task-clock:u              #    0.998 CPUs utilized             
            0      context-switches:u        #    0.000 /sec                      
            0      cpu-migrations:u          #    0.000 /sec                      
           89      page-faults:u             #  158.310 /sec                      
7,101,516,989      instructions:u            #    2.63  insn per cycle            
        #    0.08  stalled cycles per insn   
2,701,765,045      cycles:u                  #    4.806 GHz                       
  588,963,871      stalled-cycles-frontend:u #   21.80% frontend cycles idle      
1,842,875,664      branches:u                #    3.278 G/sec                     
    2,265,232      branch-misses:u           #    0.12% of all branches           

  0.563191320 seconds time elapsed

  0.553085000 seconds user
  0.007922000 seconds sys
```

Ici nous pouvons déjà voir quelques informations comme le temps CPU consommé, le nombre d'instructions, le nombre de cycles, etc...
Les données que perf peut sortir dépendent surtout des _counters_  mises à disposition par le processeur.

=== Record et report

La commande `perf record` permet de collecter des données de profilage pendant l'exécution du programme et de les sauvegarder dans un fichier (par défaut perf.data).
Ces données peuvent ensuite être analysées avec `perf report` sans avoir à réexécuter le programme.

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

Ici nous remarquons que l'on prend beaucoup de temps à comparer des strings, notamment dans la fonction `getcity`.
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


== Pistes d'optimisation

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

Une troisième option pourrait être un Trie qui est particulièrement efficace pour les chaînes de caractères.

Un trie est un arbre qui stocke chaque caractère dans un noeud et donc partage les noeuds entre plusieurs villes qui auraient le préfixe de nom. Lors de la recherche on parcourt l'arbre à la recherche 
de notre ville. Lors que l'on atteint le dernier caractère, le noeud pointe aussi sur la structure de données associé à cette ville:

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

= Profiling

Après m'être familiarisé avec les outils de profiling, j'ai entrepris l'analyse approfondie du décodeur DTMF développé lors du premier laboratoire.
Il convient de noter que certaines optimisations avaient déjà été implémentées depuis, notamment l'utilisation d'instructions SIMD pour accélérer la fonction `is_silence`.
Pour cette raison, le code profilé est celui fourni lors du laboratoire précédent intégrant cette optimisation.

== Compilation et profiling initial

```bash
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
perf record --call-graph=dwarf ./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\!.wav
hotspot perf.data
```
=== Flamegraph initial

#image("./media/hotspot3.png")

Avant d'approfondir l'analyse, j'ai constaté avec satisfaction que la fonction is_silence n'apparaît plus dans le flamegraph, contrairement à la version du laboratoire 1:

#image("./media/hotspot2.png")

Cette absence confirme l'efficacité de l'optimisation SIMD implémentée lors du laboratoire 4, ce qui est particulièrement satisfaisant :)

== Identification des goulots d'étranglement

Comme on pouvait s'y attendre, la majorité des échantillons ont été collectés dans la fonction calculate_correlation,
qui constitue le cœur de notre algorithme.
Une autre piste d'optimisation se situe dans la fonction fft qui, même avec l'algorithme de décodage par corrélation, est utilisée pour déterminer le début du fichier.

== Première optimisation: refactorisation de calculate_correlation

En examinant attentivement cette fonction, j'ai identifié un calcul redondant: la moyenne du signal de référence est recalculée à chaque appel:

```c
	float mean_signal = 0, mean_sine = 0;
	for (size_t i = 0; i < len; i++) {
		mean_signal += signal[i];
		mean_sine += ref_signal[i];
	}
	mean_signal /= len;
	mean_sine /= len;
```
Cette opération est non seulement inutile à chaque itération, mais elle peut être entièrement précalculée lors de la génération des signaux de référence.
En poussant plus loin cette logique, j'ai réalisé que je peux directement stocker les différences normalisées entre chaque échantillon et la moyenne, éliminant ainsi un calcul supplémentaire.

```c
	float numerator = 0, denom1 = 0, denom2 = 0;
	for (size_t i = 0; i < len; i++) {
		const float diff_signal = signal[i] - mean_signal;
		const float diff_sine = ref_signal[i] - mean_sine;
		numerator += diff_signal * diff_sine;
		denom1 += diff_signal * diff_signal;
		denom2 += diff_sine * diff_sine;
	}
```

J'ai donc implémenté les modifications suivantes:

```patch
diff --git a/../../lab04/code/part3/src/dtmf_decoder.c b/src/dtmf_decoder_opt_correlation.c
index 629630d..e7bb950 100644
--- a/../../lab04/code/part3/src/dtmf_decoder.c
+++ b/src/dtmf_decoder_opt_correlation.c
@@ -275,21 +275,19 @@ static bool is_valid_frequency(uint32_t freq)
 {
 	return freq > MIN_FREQ && freq < MAX_FREQ;
 }
-static float calculate_correlation(const float *signal, const float *ref_signal,
-				   size_t len)
+static float calculate_correlation(const float *signal,
+				   const float *ref_diff_signal, size_t len)
 {
-	float mean_signal = 0, mean_sine = 0;
+	float mean_signal = 0;
 	for (size_t i = 0; i < len; i++) {
 		mean_signal += signal[i];
-		mean_sine += ref_signal[i];
 	}
 	mean_signal /= len;
-	mean_sine /= len;
 
 	float numerator = 0, denom1 = 0, denom2 = 0;
 	for (size_t i = 0; i < len; i++) {
 		const float diff_signal = signal[i] - mean_signal;
-		const float diff_sine = ref_signal[i] - mean_sine;
+		const float diff_sine = ref_diff_signal[i];
 		numerator += diff_signal * diff_sine;
 		denom1 += diff_signal * diff_signal;
 		denom2 += diff_sine * diff_sine;
@@ -334,10 +332,17 @@ static void generate_reference_signals(size_t len, uint32_t sample_rate)
 			button_reference_signals[index] = malloc(
 				len * sizeof(*button_reference_signals[index]));
 
+			float mean_sine = 0.0f;
+			for (size_t k = 0; k < len; ++k) {
+				const float value = s(1, ROW_FREQUENCIES[i],
+						      COL_FREQUENCIES[j], k,
+						      sample_rate);
+				mean_sine += value;
+				button_reference_signals[index][k] = value;
+			}
+			mean_sine /= len;
 			for (size_t k = 0; k < len; ++k) {
-				button_reference_signals[index][k] =
-					s(1, ROW_FREQUENCIES[i],
-					  COL_FREQUENCIES[j], k, sample_rate);
+				button_reference_signals[index][k] -= mean_sine;
 			}
 		}
 	}
```

=== Mesures

Les mesures avec hyperfine ont révélé une amélioration d'environ 1ms:

```bash
# Version Labo 4
> hyperfine --warmup 10 "./code/part3/build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\\\!.wav"
Benchmark 1: ./code/part3/build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\!.wav
  Time (mean ± σ):      21.1 ms ±   0.8 ms    [User: 4.5 ms, System: 16.4 ms]
  Range (min … max):    19.3 ms …  23.5 ms    143 runs

# Version optimisée
> hyperfine --warmup 10 "./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\\\!.wav"
Benchmark 1: ./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\!.wav
  Time (mean ± σ):      20.1 ms ±   0.7 ms    [User: 4.1 ms, System: 15.7 ms]
  Range (min … max):    19.1 ms …  22.9 ms    134 runs
```

Cette amélioration peut sembler modeste, mais pour un temps d'exécution déjà optimisé d'environ 20ms, chaque milliseconde gagnée représente un progrès significatif.
Un nouveau profiling a montré que cette optimisation avait logiquement augmenté le temps passé dans la fonction `generate_reference_signals`,
ce qui était prévisible puisque nous y avons déplacé une partie des calculs:

#image("./media/hotspot4.png")

== Seconde optimisation: réorganisation de la mémoire

Analysant plus profondément la structure des données, j'ai constaté que les signaux de référence étaient stockés comme une liste de listes,
chaque entrée de button_reference_signals pointant vers une liste d'échantillons. J'ai émis l'hypothèse qu'une réorganisation en un tableau contigu pourrait apporter deux avantages:

- Réduction du nombre d'allocations dynamiques de 13 à 1 lors de l'appel à `generate_reference_signals`
- Amélioration de la cohérence de cache grâce à une disposition contiguë des données

Pour vérifier l'état actuel de l'utilisation du cache, j'ai employé callgrind:

```bash
valgrind --tool=callgrind --simulate-cache=yes ./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\!.wav
==32333== 
==32333== Events    : Ir Dr Dw I1mr D1mr D1mw ILmr DLmr DLmw
==32333== Collected : 26295195 4789614 928033 2429 23238 7150 2172 14911 4017
==32333== 
==32333== I   refs:      26,295,195
==32333== I1  misses:         2,429
==32333== LLi misses:         2,172
==32333== I1  miss rate:       0.01%
==32333== LLi miss rate:       0.01%
==32333== 
==32333== D   refs:       5,717,647  (4,789,614 rd + 928,033 wr)
==32333== D1  misses:        30,388  (   23,238 rd +   7,150 wr)
==32333== LLd misses:        18,928  (   14,911 rd +   4,017 wr)
==32333== D1  miss rate:        0.5% (      0.5%   +     0.8%  )
==32333== LLd miss rate:        0.3% (      0.3%   +     0.4%  )
==32333== 
==32333== LL refs:           32,817  (   25,667 rd +   7,150 wr)
==32333== LL misses:         21,100  (   17,083 rd +   4,017 wr)
==32333== LL miss rate:         0.1% (      0.1%   +     0.4%  )
```

J'ai constaté que le miss rate de la mémoire cache est déjà très faible, ce qui m'a fait douter de l'impact potentiel de cette optimisation.

Après quelques ajustements et la résolution de quelques `segfaults`, voici l'implémentation finale:

```patch
diff --git a/src/dtmf_decoder_opt_correlation.c b/src/dtmf_decoder.c
index e7bb950..6ddb304 100644
--- a/src/dtmf_decoder_opt_correlation.c
+++ b/src/dtmf_decoder.c
@@ -29,7 +29,7 @@ static dtmf_button_t *decode_button_time_domain(const float *signal,
 						uint32_t sample_rate);
 
 /* Used for time domain decoding in order to correlate */
-static float **button_reference_signals = NULL;
+static float *button_reference_signals = NULL;
 static bool generated_references = false;
 
 static const uint16_t ROW_FREQUENCIES[] = { 697, 770, 852, 941 };
@@ -321,16 +321,15 @@ static dtmf_button_t *decode_button_frequency_domain(const float *signal,
 static void generate_reference_signals(size_t len, uint32_t sample_rate)
 {
 	const size_t nb_buttons =
-		ARRAY_LEN(ROW_FREQUENCIES) + ARRAY_LEN(COL_FREQUENCIES);
+		ARRAY_LEN(ROW_FREQUENCIES) * ARRAY_LEN(COL_FREQUENCIES);
 
 	button_reference_signals =
-		calloc(nb_buttons, sizeof(*button_reference_signals));
+		malloc(nb_buttons * len * sizeof(*button_reference_signals));
 
 	for (size_t i = 0; i < ARRAY_LEN(ROW_FREQUENCIES); ++i) {
 		for (size_t j = 0; j < ARRAY_LEN(COL_FREQUENCIES); ++j) {
-			const size_t index = i * ARRAY_LEN(COL_FREQUENCIES) + j;
-			button_reference_signals[index] = malloc(
-				len * sizeof(*button_reference_signals[index]));
+			const size_t window_index =
+				(i * ARRAY_LEN(COL_FREQUENCIES) + j) * len;
 
 			float mean_sine = 0.0f;
 			for (size_t k = 0; k < len; ++k) {
@@ -338,11 +337,13 @@ static void generate_reference_signals(size_t len, uint32_t sample_rate)
 						      COL_FREQUENCIES[j], k,
 						      sample_rate);
 				mean_sine += value;
-				button_reference_signals[index][k] = value;
+				button_reference_signals[window_index + k] =
+					value;
 			}
 			mean_sine /= len;
 			for (size_t k = 0; k < len; ++k) {
-				button_reference_signals[index][k] -= mean_sine;
+				button_reference_signals[window_index + k] -=
+					mean_sine;
 			}
 		}
 	}
@@ -369,9 +370,12 @@ static dtmf_button_t *decode_button_time_domain(const float *signal,
 		const uint16_t row_freq = ROW_FREQUENCIES[i];
 		for (size_t j = 0; j < ARRAY_LEN(COL_FREQUENCIES); ++j) {
 			const uint16_t col_freq = COL_FREQUENCIES[j];
-			const size_t index = i * ARRAY_LEN(COL_FREQUENCIES) + j;
+			const size_t index =
+				(i * ARRAY_LEN(COL_FREQUENCIES) + j) *
+				nb_samples;
+
 			const float corr = calculate_correlation(
-				signal, button_reference_signals[index],
+				signal, &button_reference_signals[index],
 				nb_samples);
 
 			if (corr > best_corr) {
```


=== Mesures

La mesure avec `hyperfine` montrent une légère amélioration supplémentaire:

```bash
> hyperfine --warmup 10 "./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\\\!.wav"
Benchmark 1: ./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\!.wav
  Time (mean ± σ):      19.8 ms ±   0.4 ms    [User: 4.2 ms, System: 15.4 ms]
  Range (min … max):    19.0 ms …  21.7 ms    141 runs
```

L'impact limité sur les performances s'explique par les résultats de callgrind après optimisation - Spoiler Alert - ce sont les mêmes résultats:

```bash
==33544== Events    : Ir Dr Dw I1mr D1mr D1mw ILmr DLmr DLmw
==33544== Collected : 26329909 4783324 929378 2421 23205 7167 2175 14912 4017
==33544== 
==33544== I   refs:      26,329,909
==33544== I1  misses:         2,421
==33544== LLi misses:         2,175
==33544== I1  miss rate:       0.01%
==33544== LLi miss rate:       0.01%
==33544== 
==33544== D   refs:       5,712,702  (4,783,324 rd + 929,378 wr)
==33544== D1  misses:        30,372  (   23,205 rd +   7,167 wr)
==33544== LLd misses:        18,929  (   14,912 rd +   4,017 wr)
==33544== D1  miss rate:        0.5% (      0.5%   +     0.8%  )
==33544== LLd miss rate:        0.3% (      0.3%   +     0.4%  )
==33544== 
==33544== LL refs:           32,793  (   25,626 rd +   7,167 wr)
==33544== LL misses:         21,104  (   17,087 rd +   4,017 wr)
==33544== LL miss rate:         0.1% (      0.1%   +     0.4%  )
```

=== Analyse
Le gain modeste obtenu s'explique par plusieurs facteurs:

- La taille réduite des échantillons de référence (entre 57 et 316 pour des fréquences d'échantillonnage de 8kHz à 44.1kHz)
  fait qu'ils sont déjà probablement présents dans le cache, même lorsqu'ils ne sont pas stockés de manière contiguë.
- La fonction `generate_reference_signals` a été accélérée, mais comme elle n'est appelée qu'une seule fois pendant l'exécution du programme, son impact sur les performances globales reste limité.



== Analyse des performances

Les optimisations réalisées ont collectivement permis un gain d'environ 1.5ms par rapport au code du laboratoire précédent et de 9ms par rapport à la version initiale du laboratoire 1, ce qui représente une amélioration substantielle de 31%.

=== Evolution des performances

==== Laboratoire 1

```bash
> hyperfine "./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\\\!.wav" --shell=none --warmup 10
Benchmark 1: ./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\!.wav
  Time (mean ± σ):      28.9 ms ±   0.3 ms    [User: 14.0 ms, System: 14.7 ms]
  Range (min … max):    28.1 ms …  29.7 ms    102 runs
```

==== Laboratoire 4

```bash
> hyperfine --warmup 10 "./code/part3/build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\\\!.wav"
Benchmark 1: ./code/part3/build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\!.wav
  Time (mean ± σ):      21.1 ms ±   0.8 ms    [User: 4.5 ms, System: 16.4 ms]
  Range (min … max):    19.3 ms …  23.5 ms    143 runs
```

==== Laboratoire 5

```bash
> hyperfine --warmup 10 "./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\\\!.wav"
Benchmark 1: ./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\!.wav
  Time (mean ± σ):      19.8 ms ±   0.4 ms    [User: 4.2 ms, System: 15.4 ms]
  Range (min … max):    19.0 ms …  21.7 ms    141 runs
```

Ces résultats démontrent l'efficacité cumulative des différentes optimisations apportées au code, depuis l'implémentation SIMD pour is_silence jusqu'aux améliorations de la fonction de corrélation et de l'organisation en mémoire des signaux de référence.

#pagebreak()
= Conclusion

Ce laboratoire m'a permis d'explorer en profondeur l'utilisation des outils de profiling pour l'analyse et l'optimisation des performances logicielles.
En appliquant ces outils à deux cas d'études distincts - un programme d'analyse de températures et un décodeur DTMF - j'ai pu constater leur efficacité
pour identifier les goulots d'étranglement et guider les efforts d'optimisation.

Dans la première partie, l'analyse du programme de calcul de températures a révélé que la fonction getcity constituait un point critique,
en raison de son algorithme de recherche linéaire avec une complexité de O(N²). Ce constat m'a conduit à proposer plusieurs stratégies d'optimisation potentielles,
notamment l'utilisation de structures de données plus efficaces comme les tables de hachage ou les arbres binaires de recherche.

Pour le décodeur DTMF, j'ai pu mettre en oeuvre deux optimisations significatives :

- L'élimination de calculs redondants dans la fonction calculate_correlation, en précalculant les moyennes des signaux de référence.
- La réorganisation de la mémoire pour stocker les signaux de référence de manière contiguë.

Ces optimisations ont permis une amélioration globale des performances d'environ 31% par rapport à la version initiale du laboratoire 1.
La démarche progressive d'optimisation a confirmé l'importance d'une approche méthodique basée sur le profiling, permettant d'identifier et de cibler précisément les points critiques du code.

Ce laboratoire démontre l'intérêt d'intégrer le profiling comme une étape systématique du processus de développement, particulièrement pour les applications où les performances sont critiques.
L'optimisation guidée par les données de profiling permet d'éviter les pièges de l'optimisation prématurée et d'obtenir des gains de performance significatifs avec un effort ciblé et mesuré.

Pour finir, j'aimerais juste dire que je suis convaincu que l'utilisation de ces outils feront partie de mon quotidien en tant que développeur dans le futur. Merci beaucoup pour ce laboratoire :)
