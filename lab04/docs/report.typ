#include "title.typ"

#pagebreak()

#outline(title: "Table des matières", depth: 3, indent: 15pt)

#pagebreak()

= Introduction

= Analyse et amélioration

Tout d'abord il faut déjà vérifier la performance de l'application de départ.
Pour cela, je suis allé chercher une vraie image 4k très jolie, histoire de faire rammer cette application :).

#image("./media/pexels-christian-heitz-285904-842711.png")

```bash
hyperfine --warmup 10 './code/part1/build/segmentation ./docs/media/pexels-christian-heitz-285904-842711.png 10 output.png'
Benchmark 1: ./code/part1/build/segmentation ./docs/media/pexels-christian-heitz-285904-842711.png 10 output.png
  Time (mean ± σ):     12.752 s ±  0.026 s    [User: 9.026 s, System: 3.643 s]
  Range (min … max):   12.718 s … 12.792 s    10 runs
```

== Appels fonction distance

Directement, la première chose qui m'a sauté aux yeux est le double appel à la fonction `distance`
pour le calcul de la distance. Par exemple:

```c
distances[i] = distance(src, dest) * distance(src, dest);
```

Finalement, après avoir `objdump`, je remarque que ceci a été optimisé par le compilateur 
avec un seul appel donc finalement l'optimisation de limiter ceci à un seul appel n'apporterait rien directement.

= Calcul distance

Une autre chose que nous pouvons remarquer c'est que la fonction est appellée dans deux contextes:

1. Pour calculer la distance en calculant le carré du résultat de la fonction
2. Pour faire des comparaisons afin de trouver la distance la plus courte

Ceci nous donne deux pistes d'optimisation:

1. La fonction n'a pas besoin d'effectuer une racine carrée
  - Car on utilise toujours le résultat au carrée ou pour comparer.
2. Optimiser cette fonction peut apporter de bons résultats
  - Car elle est appellée très souvent.

= Optmisation SIMD de la fonction distance

== Taille des données

Pour optimiser la fonction distance, je vais utiliser des registres SIMD de 16 octets. Dans le code, la fonction distance fait un calcul sur 12 octets par contre,
pour garantir que nous ne accèdons pas en dehors de l'image, il faudrait ajouter du padding.

Par défaut, l'image telle qu'est chargée en mémoire contient déjà 4 composants (rouge, vert, bleu et alpha) et nous n'effectuons que le calcul entre les 3 premiers composants,
il suffit d'ignorer le dernier composant lors du calcul.

De plus, pour garantir que cela est toujours vrai, il suffit de vérifier au début de la fonction kmeans que `img->components` est égal à 4.

== Modification de la fonction
