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
hyperfine --warmup 10 './code/build/segmentation ./docs/media/pexels-christian-heitz-285904-842711.png 10 output.png'
Benchmark 1: ./code/build/segmentation ./docs/media/pexels-christian-heitz-285904-842711.png 10 output.png
  Time (mean ± σ):      8.943 s ±  0.103 s    [User: 5.984 s, System: 2.892 s]
  Range (min … max):    8.808 s …  9.118 s    10 runs
```

== Appels fonction distance


Directement, la première chose qui m'a sauté aux yeux est le double appel à la fonction `distance`
pour le calcul de la distance. Par exemple:

```c
distances[i] = distance(src, dest) * distance(src, dest);
```

Finalement, après avoir `objdump`, je remarque que ceci a été optimisé par le compilateur 
avec un seul appel donc finalement l'optimisation de limiter ceci à un seul appel n'apporte rien.

Une autre chose plus inté

= Fonction distance

Ici, pour la fonction distance nous avons 3 soustractions, 3 multiplications et 2 sommes.

Donc j'ai utilisé du simd pour créer un seul vector avec mes 3 valeurs, me permettant ainsi de faire les 3 soustracions et 3 multiplications et finalement mes 2 sommes.


