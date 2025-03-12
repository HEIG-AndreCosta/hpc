#include "title.typ"

#pagebreak()


= Topology CPU

En utilisant l'outil `likwid-topology`, il est possible de voir la topologie du cpu:

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

Comme sur l'exemple de la page help, `S0` indique Core 0, `S1` doit indiquer Core 1
