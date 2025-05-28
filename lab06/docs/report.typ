#include "title.typ"

#pagebreak()

#outline(title: "Table des matières", depth: 3, indent: 15pt)

#pagebreak()

= Introduction

La consommation énergétique est devenue un facteur déterminant dans l'optimisation des performances des systèmes informatiques modernes.
Dans ce laboratoire, nous explorons différentes méthodes de mesure de consommation énergétique appliquées à l'optimisation d'un algorithme de segmentation d'image.
L'objectif principal est d'évaluer l'impact de la vectorisation SIMD (Single Instruction, Multiple Data) sur l'efficacité énergétique du programme.

= Perf

```bash
sudo perf stat -e power/energy-pkg/ ./build/segmentation ../../docs/media/pexels-christian-heitz-285904-842711.png 10 output.png
Performance counter stats for 'system wide':

        153.34 Joules power/energy-pkg/                                                     

      8.492826126 seconds time elapsed

sudo perf stat -e power/energy-pkg/ ./build/segmentation_simd ../../docs/media/pexels-christian-heitz-285904-842711.png 10 output.png
Performance counter stats for 'system wide':

        120.70 Joules power/energy-pkg/                                                     

      6.228452693 seconds time elapsed
```

Nous constantons que simd est moins gourmand en énérgie.

== Likwid

```bash
likwid-powermeter ./build/segmentation ../../docs/media/pexels-christian-heitz-285904-842711.png 10 output.png
--------------------------------------------------------------------------------
Runtime: 9.54402 s
Measure for socket 0 on CPU 0
Domain CORE:
Energy consumed: 180.989 Joules
Power consumed: 18.9636 Watt
--------------------------------------------------------------------------------
likwid-powermeter ./build/segmentation_simd ../../docs/media/pexels-christian-heitz-285904-842711.png 10 output.png
--------------------------------------------------------------------------------
Runtime: 7.53163 s
Measure for socket 0 on CPU 0
Domain CORE:
Energy consumed: 154.189 Joules
Power consumed: 20.4723 Watt
--------------------------------------------------------------------------------
```

Ici le cpu a canné, il a décidé de travailler et donner un gros burst de puissance ce qui nous a permis de finir en moins longtemps et de consommer moins 
d'énérgie globalement. Même constat qu'avant, SIMD prends moins d'énérgie.

== Powercap
```bash
sudo ./build/segmentation ../../docs/media/pexels-christian-heitz-285904-842711.png 10 output.png
Npackages = 1
 Failed to get energy on package 0
 failed to get energy on package 0
sudo ./build/segmentation_simd ../../docs/media/pexels-christian-heitz-285904-842711.png 10 output.png
Npackages = 1
 Failed to get energy on package 0
 failed to get energy on package 0
```

Malheuresement même avec `sudo`, powercap n'a pas réussi à demander l'énérgie du pacquetage 1 pour la zone `POWERCAP_RAPL_ZONE_PACKAGE`.

= Conclusion

L'implémentation de techniques de vectorisation SIMD représente une stratégie d'optimisation précieuse pour les développeurs soucieux de l'impact environnemental et économique de leurs applications,
confirmant l'importance d'une approche holistique de l'optimisation qui considère à la fois les performances et l'efficacité énergétique.
