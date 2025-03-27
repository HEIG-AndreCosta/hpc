#include "title.typ"

#pagebreak()


= Topology CPU

`lstopo` nous permet de voir la topologie de l'ordinateur de façon graphique.

```bash
lstopo
```

#figure(image("media/lstopo.png"), caption: [Topologie CPU])


`likwid` contient aussi un outil permettant de voir la topologie du système.

```bash
likwid-topology
--------------------------------------------------------------------------------
CPU name:	AMD Ryzen 7 PRO 7840U w/ Radeon 780M Graphics  
CPU type:	AMD K19 (Zen4) architecture
CPU stepping:	1
********************************************************************************
Hardware Thread Topology
********************************************************************************
Sockets:		1
CPU dies:		1
Cores per socket:	8
Threads per core:	2
--------------------------------------------------------------------------------
HWThread        Thread        Core        Die        Socket        Available
0               0             0           0          0             *                
1               1             0           0          0             *                
2               0             1           0          0             *                
3               1             1           0          0             *                
4               0             2           0          0             *                
5               1             2           0          0             *                
6               0             3           0          0             *                
7               1             3           0          0             *                
8               0             4           0          0             *                
9               1             4           0          0             *                
10              0             5           0          0             *                
11              1             5           0          0             *                
12              0             6           0          0             *                
13              1             6           0          0             *                
14              0             7           0          0             *                
15              1             7           0          0             *                
--------------------------------------------------------------------------------
Socket 0:		( 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 )
--------------------------------------------------------------------------------
********************************************************************************
Cache Topology
********************************************************************************
Level:			1
Size:			32 kB
Cache groups:		( 0 1 ) ( 2 3 ) ( 4 5 ) ( 6 7 ) ( 8 9 ) ( 10 11 ) ( 12 13 ) ( 14 15 )
--------------------------------------------------------------------------------
Level:			2
Size:			1 MB
Cache groups:		( 0 1 ) ( 2 3 ) ( 4 5 ) ( 6 7 ) ( 8 9 ) ( 10 11 ) ( 12 13 ) ( 14 15 )
--------------------------------------------------------------------------------
Level:			3
Size:			16 MB
Cache groups:		( 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 )
--------------------------------------------------------------------------------
********************************************************************************
NUMA Topology
********************************************************************************
NUMA domains:		1
--------------------------------------------------------------------------------
Domain:			0
Processors:		( 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 )
Distances:		10
Free memory:		1464.93 MB
Total memory:		27691.9 MB
--------------------------------------------------------------------------------
```

= Roofline

Pour pouvoir dessiner notre roofline il nous est demandé de réaliser deux bancs de test:

1. Pour déterminer le maximum d’opérations à virgule flottante que peut exécuter votre processeur
2. Pour déterminer la bande passante mémoire de votre processeur


== Nombre maximum d'opérations à virgule flottante

Pour faire du _benchmark_, on peut utiliser l'outil `likwid-bench`.

En utilisant le flag `-a`, il est possible de lister les benchmarks disponibles

```bash
likwid-bench -a
```

Il existe un groupe de tests nommé `peakfloops` qui nous permet de mesurer le nombre d'opérations
à virgule flottante.


```bash
> likwid-bench -a
peakflops - Double-precision multiplications and additions with a single load, only scalar operations
peakflops_avx - Double-precision multiplications and additions with a single load, optimized for AVX
peakflops_avx512 - Double-precision multiplications and additions with a single load, optimized for AVX-512
peakflops_avx512_fma - Double-precision multiplications and additions with a single load, optimized for AVX-512 FMAs
peakflops_avx_fma - Double-precision multiplications and additions with a single load, optimized for AVX FMAs
peakflops_sp - Single-precision multiplications and additions with a single load, only scalar operations
peakflops_sp_avx - Single-precision multiplications and additions with a single load, optimized for AVX
peakflops_sp_avx512 - Single-precision multiplications and additions with a single load, optimized for AVX-512
peakflops_sp_avx512_fma - Single-precision multiplications and additions with a single load, optimized for AVX-512 FMAs
peakflops_sp_avx_fma - Single-precision multiplications and additions with a single load, optimized for AVX FMAs
peakflops_sp_sse - Single-precision multiplications and additions with a single load, optimised for SSE
peakflops_sse - Double-precision multiplications and additions with a single load, optimised for SSE
```

En regardant la description de ces tests, le plus pertinent me paraît les tests

- `peakflops` - Double-precision multiplications and additions with a single load, only scalar operations
- `peakflops_sp` - Single-precision multiplications and additions with a single load, optimized for AVX

En commençant avec `peakflops`:

```bash
> likwid-bench -t peakflops
Error: At least one workgroup (-w) must be set on commandline
```

Dommage :(.

En retournant sur la documentation, nous pouvons voir qu'un groupe de travail est défini
comme: `<domain>:<size>:<nrThreads>`

```bash
> likwid-bench -h
Threaded Memory Hierarchy Benchmark -- Version 5.4.1 
...
-W/--Workgroup		<thread_domain>:<size>[:<num_threads>[:<chunk size>:<stride>]]
				<size> in kB, MB or GB (mandatory)
...
# Run the copy benchmark on one CPU at CPU socket 0 with a vector size of 100kB
likwid-bench -t copy -w S0:100kB:1
```

Avec:

- `domain` - Défini le domaine à utiliser pour le test.
- `size` - La taille de données.
- `num_threads` - Le numéro de threads.

*Domain* 

En revenant encore sur la topology, en ajoutant l'argument `-g`:

```bash
> likwid-topology -g
...
********************************************************************************
Graphical Topology
********************************************************************************
Socket 0:

+--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+
|  0 1   | |  2 3   | |  4 5   | |  6 7   | |  8 9   | | 10 11  | | 12 13  | | 14 15  |
+--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+
+--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+
|  32 kB | |  32 kB | |  32 kB | |  32 kB | |  32 kB | |  32 kB | |  32 kB | |  32 kB |
+--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+
+--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+
|  1 MB  | |  1 MB  | |  1 MB  | |  1 MB  | |  1 MB  | |  1 MB  | |  1 MB  | |  1 MB  |
+--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+ +--------+
+-------------------------------------------------------------------------------------+
|                                        16 MB                                        |
+-------------------------------------------------------------------------------------+
```

Nous constantons que nous avons seulement un socket - `S0`.

*Size*

Comme ici nous sommes intéressés par le nombre d'opérations de calcul, il est important de limiter cette taille pour pouvoir limiter les accès à la mémoire principale. Plus précisement, il serait important de trouver une quantité de données qui ne dépasse pas la taille de la cache L1.

Comme la taille de la cache L1 est de `32kB`, prennons la moitié (`16kB`) pour garantir que cette contrainte est satisfaite.

*Num Threads*

Comme l'encodeur `dtmf` n'utilise qu'un seul thread, il est important de limiter le workgroup aussi à `1` thread. Sinon, des comparaisons futures avec la performance de ce logiciel ne seraient pas très parlantes.

#line(length: 100%)

En mettant tout ensemble:

```bash
> likwid-bench -t peakflops -s 10 -W S0:16KB:1
Cycles:			3312336588
CPU Clock:		3293751626
Cycle Clock:		3293751626
Time:			1.005642e+00 sec
Iterations:		262144
Iterations per thread:	262144
Inner loop executions:	3000
Size (Byte):		24000
Size per thread:	24000
Number of Flops:	12582912000
MFlops/s:		12512.31
Data volume (Byte):	6291456000
MByte/s:		6256.16
Cycles per update:	4.211854
Cycles per cacheline:	33.694830
Loads per update:	1
Stores per update:	0
Load bytes per element:	8
Store bytes per elem.:	0
Instructions:		15728640032
UOPs:			14942208000
```

Ici, l'information qui nous intéresse est :

```bash
MFlops/s:		12512.31
```

Comme `AMD` ne fournit pas des informations sur le CPU spécifique, il est difficile d'évaluer si cette valeur est bonne ou non.

Nous pouvons par contre comparer avec l'horloge de la CPU qui est à `5.13GHz`, cela veut dire que nous arrivons à calculer

$ 12.512 / 5.13 = 2.439 "opérations par cycle d'horloge" $

Ce qui est très positif. Notons que nous pouvons et nous nous attendons à avoir plus que 1 opération par cycle d'horloge grâce aux microarchitectures modernes qui nous permettent d'effectuer plusieurs opérations en parallèle.

Notons que ce calcul n'est pas très fiable, très probablement ce calcul n'est pas très fiable. Notamment, le cpu n'a probablement pas travaillé à sa vitesse maximale pendant le test. 

== Bande Passante Mémoire

La même procédure peut être effectué que précedemment. Pour la mesure de la mémoire nous avons un groupe de tests de copie :

```bash
> likwid-bench -a
copy - Double-precision vector copy, only scalar operations
copy_avx - Double-precision vector copy, optimized for AVX
copy_avx512 - Double-precision vector copy, optimized for AVX-512
copy_mem - Double-precision vector copy, only scalar operations but with non-temporal stores
copy_mem_avx - Double-precision vector copy, uses AVX and non-temporal stores
copy_mem_avx512 - Double-precision vector copy, uses AVX-512 and non-temporal stores
copy_mem_sse - Double-precision vector copy, uses SSE and non-temporal stores
copy_sse - Double-precision vector copy, optimized for SSE
```

Pour les paramètres du groupe, la même logique peut être suivi pour les paramètres *domain* et *num threads* mais doit être adapté pour le paramètre *size*. En effet, pour calculer la bande passante mémoire, il faut que la taille dépasse la taille des mémoire cache. Pour cela, utilisons une grande valeur, par exemple `512MB`.


```bash
likwid-bench -t copy -w S0:512MB:1
Cycles:			3486906027
CPU Clock:		3291635204
Cycle Clock:		3291635204
Time:			1.059323e+00 sec
Iterations:		64
Iterations per thread:	64
Inner loop executions:	8000000
Size (Byte):		512000000
Size per thread:	512000000
Number of Flops:	0
MFlops/s:		0.00
Data volume (Byte):	32768000000
MByte/s:		30932.95
Cycles per update:	1.702591
Cycles per cacheline:	13.620727
Loads per update:	1
Stores per update:	1
Load bytes per element:	8
Store bytes per elem.:	8
Load/store ratio:	1.00
Instructions:		5632000016
UOPs:			7168000000
```

Ici ce qui nous intéresse c'est la ligne:

```bash
MByte/s:		30932.95
```

Comme `AMD` ne fournit pas des informations sur le CPU spécifique, il est difficile d'évaluer si cette valeur est bonne ou non.

Avec `lshw`, nous pouvons voir la vitesse de la mémoire DDR et voir qu'elle tourne à `6.4GHz`

```bash
sudo lshw -short -C memory
H/W path              Device          Class          Description
================================================================
/0/0                                  memory         512KiB L1 cache
/0/1                                  memory         8MiB L2 cache
/0/2                                  memory         16MiB L3 cache
/0/5                                  memory         32GiB System Memory
/0/5/0                                memory         8GiB Synchronous Unbuffered (Unregistered) 6400 MHz (0.2 ns)
/0/5/1                                memory         8GiB Synchronous Unbuffered (Unregistered) 6400 MHz (0.2 ns)
/0/5/2                                memory         8GiB Synchronous Unbuffered (Unregistered) 6400 MHz (0.2 ns)
/0/5/3                                memory         8GiB Synchronous Unbuffered (Unregistered) 6400 MHz (0.2 ns)
/0/15                                 memory         128KiB BIOS
```

Nous sommes donc à:

$ 30.9 / 6.4 = 4.82 "accès par cycle d'horloge" $

En réalité, les valeurs sont encore biasés par le faite que, même avec une taille de travail plus grande que la mémoire cache, il y aura tout de même des `hit` qui vont survenir ce qui va accèlerer considérablement le nombre d'accès que nous effectuons.

Finalement, en modifiant le taille du groupe de travail, nous pouvons observer les capacités des mémoire L1, L2 et L3.


```bash
likwid-bench -t copy -w S0:4KB:1
likwid-bench -t copy -w S0:512KB:1
likwid-bench -t copy -w S0:12MB:1
```

Ce qui nous donne les résultats suivants:

#table(
  columns: ( 0.25fr, 0.25fr, 0.25fr),
  inset: 10pt,
  align: horizon,
  table.header(
    [*Cible*], [*Taille*], [*MByte/s*],
  ),
  [L1], [`4KB`], [78554.84],
  [L2], [`512KB`],[77244.33],
  [L3], [`12MB`], [69010.02],
  [DDRAM], [`512MB`], [30932.95]
)

#line(length: 100%)

Une fois ces deux valeurs trouvées, nous pouvons trouver notre *roofline*:

```txt
12512.31
30932.95
```

Et lancer le script fourni:

```bash
python roofline_gen.py
```

#figure(image("media/roofline.png"), caption: [Modèle Roofline])


== Profiling

Une fois le `roofline` trouvé, il nous est temps de profiler notre code.

Pour cela je m'intéresse nottament à deux parties du décodage.

- La recherche du début du fichier
- Le décodage des pressions

Pour les détails de ces deux parties, se référer au rapport du laboratoire précedent.

En se basant sur le guide forunit, j'ai commencé par chercher les groupes de mesure disponibles:
```bash
> likwid-perfctr -a
Group name	Description
--------------------------------------------------------------------------------
  BRANCH	Branch prediction miss rate/ratio
   CACHE	Data cache miss rate/ratio
   CLOCK	Cycles per instruction
     CPI	Cycles per instruction
    DATA	Load to store ratio
  DIVIDE	Divide unit information
  ENERGY	Power and Energy consumption
FLOPS_DP	Double Precision MFLOP/s
FLOPS_SP	Single Precision MFLOP/s
  ICACHE	Instruction cache miss rate/ratio
      L2	L2 cache bandwidth in MBytes/s (experimental)
 L2CACHE	L2 cache miss rate/ratio (experimental)
      L3	L3 cache bandwidth in MBytes/s
 L3CACHE	L3 cache miss rate/ratio (experimental)
 MEMREAD	Main memory read bandwidth in MBytes/s
MEMWRITE	Main memory write bandwidth in MBytes/s
    NUMA	Socket interconnect and NUMA traffic
     TLB	TLB miss rate/ratio
```

Pour mon architecture, `likwid` a déjà les groupes nécessaires pour trouver les valeurs d'intensité opérationelle et le nombre d'opérations à virgule flottante.

=== Efficacité Operationnelle


Pour la suite des mesures, nous cherchons le nombre d'opérations et l'efficacité operationnelle.

L'efficacité operationnelle est donnée par la formule:
$ I = W / Q $

et désigne le nombre d'opérations par octet de trafic mémoire.

Lorsque le travail `W` est exprimé en FLOPs, l'intensité arithmétique `I` qui en résulte est le rapport entre les opérations en virgule flottante et le mouvement total des données (FLOPs/octet). 

=== Profiling FFT

L'algorithme FFT qui avait été démontré comme le moins performant lors du laboratoire précedent peut être lancé avec

```bash
dtmf_encdec decode <sound_file.wav>
```

Pour le profiler nous pouvons le lancer avec:

```bash
likwid-perfctr -C S0:8 -g FLOPS_SP -m ./dtmf_encdec decode ../../../lab01/audio/crashing_is_not_allowed_\!.wav
likwid-perfctr -C S0:8 -g MEMREAD -m ./dtmf_encdec decode ../../../lab01/audio/crashing_is_not_allowed_\!.wav
```

L'utilisation de `S0:8` permet de bloquer l'utilisation sur le thread 8. C'est un choix arbitraire, le seul point important est de ne pas utiliser le core 0 car sur linux est le core qui va recevoir
la plupart des IRQs du système ce qui biasera les résultats du benchmarking.

Et voici les résultats.

#table(
  columns: ( 0.25fr, 0.25fr, 0.25fr, 0.25fr),
  inset: 10pt,
  align: horizon,
  table.header(
    [*Marker*], [*FLOPS_SP [MFLOP/s]*], [*MEMREAD [MByte/s]*], [*Efficacité Operationnelle*],
  ),
  [Find Start Of File], [1202.2479], [772.2337], [1.56],
  [Decode], [1577.2761], [1254.0197], [1.26],
)

=== Profiling Correlation

L'algorithme de corrélation linéaire qui avait été démontré comme le moins performant lors du laboratoire précedent peut être lancé avec


```bash
dtmf_encdec decode <sound_file.wav>
```

Pour le profiler nous pouvons le lancer avec:

```bash
likwid-perfctr -C S0:8 -g FLOPS_SP -m ./dtmf_encdec decode_time_domain ../../../lab01/audio/crashing_is_not_allowed_\!.wav
likwid-perfctr -C S0:8 -g MEMREAD -m ./dtmf_encdec decode_time_domain ../../../lab01/audio/crashing_is_not_allowed_\!.wav
```

#table(
  columns: ( 0.25fr, 0.25fr, 0.25fr, 0.25fr),
  inset: 10pt,
  align: horizon,
  table.header(
    [*Marker*], [*FLOPS_SP [MFLOP/s]*], [*MEMREAD [MByte/s]*], [*Efficacité Operationnelle*],
  ),
  [Find Start Of File], [1448.3669], [631.8976], [2.29],
  [Decode], [844.8329], [5541.2554], [0.15],
)


#line(length: 100%)


Une fois ces valeurs mesurés, il est possible de trouver notre `baseline` pour les deux algorithmes:

```
12512.31
30932.95
1.26 1577.2761 fft
0.15 844.8329 correlation
```

#figure(image("media/baseline.png"), caption: [Baseline])

Dans ces mesures, l'algorithme de corrélation présente une efficacité opérationnelle inférieure à celle de l'algorithme FFT. Cela peut sembler contre-intuitif au premier abord, mais une explication simple existe.

Puisque les accès mémoire restent similaires – en raison de la nécessité de parcourir l'intégralité du fichier audio – la bande passante demeure inchangée, tandis que le nombre d'opérations réalisées par l'algorithme de corrélation diminue. Paradoxalement, cet algorithme s'avère pourtant 12 fois plus rapide que la FFT, ce qui met en évidence les limites de cette métrique pour évaluer correctement la performance.

En poussant l'analyse plus loin, on comprend la véritable signification de l’efficacité opérationnelle et la raison de sa valeur relativement basse pour un algorithme pourtant performant. En effet, bien que la quantité de données accessibles soit la même pour les deux algorithmes, la corrélation effectue moins de calculs. Cela engendre des accès mémoire sous-exploités, réduisant ainsi artificiellement l’efficacité mesurée.

== Améliorations Possibles
Voici quelques pistes d’amélioration possibles :  

- *Optimisation du compilateur* : Le code a été compilé avec l’option `-O0`, car il a été fourni ainsi par l’assistant. Activer un niveau d’optimisation plus élevé permettrait d’améliorer significativement les performances.  
- *Réduction de la taille des fenêtres de calcul* : L’algorithme effectue un grand nombre d’opérations sur les données. En diminuant la taille des fenêtres de calcul, il serait possible d’accélérer son exécution.  
- *Vectorisation* : Certains calculs pourraient être optimisés en utilisant des techniques de vectorisation comme `SIMD`, permettant d’exploiter plus efficacement les ressources du processeur.  
- *Parallélisation* : L’exploitation du calcul parallèle pourrait considérablement accélérer les algorithmes.  
  - Pour l’algorithme de corrélation, le calcul de la corrélation avec chaque bouton pourrait être parallélisé.  
  - Pour l’algorithme FFT, l’analyse de certaines fenêtres en parallèle permettrait de parcourir le fichier plus rapidement.


= Conclusion

Ce laboratoire a permis d’analyser la performance du processeur en combinant *modèle Roofline, profiling détaillé et outils LIKWID*.

`likwid-bench` a permis de mesurer le nombre possible les FLOPs, l’utilisation du cache et la bande passante de mon cpu alors que avec `likwid-perctr` et les _markers_ `likwid` m'ont permis de facilement profiler le code développé précedemment.

Pour améliorer la performance, plusieurs optimisations sont envisageables : *vectorisation SIMD, parallélisation multi-thread, optimisation de la localité des données et compilation avancée*.  

En conclusion, cette approche a permis de mieux comprendre les limites matérielles et d’identifier des stratégies pour optimiser les performances des applications exécutées sur ce processeur.
