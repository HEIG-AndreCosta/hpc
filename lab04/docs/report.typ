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

== Calcul distance

Une autre chose que nous pouvons remarquer c'est que la fonction est appellée dans deux contextes:

1. Pour calculer la distance en calculant le carré du résultat de la fonction
2. Pour faire des comparaisons afin de trouver la distance la plus courte

Ceci nous donne deux pistes d'optimisation:

1. La fonction n'a pas besoin d'effectuer une racine carrée
  - Car on utilise toujours le résultat au carrée ou pour comparer.
2. Optimiser cette fonction peut apporter de bons résultats
  - Car elle est appellée très souvent.

En raison des observations précédentes, la fonction de calcul de distance et le code associé ont été modifiés afin d'améliorer les performances :

- La fonction retourne désormais la distance euclidienne au carré plutôt que la distance euclidienne elle-même. Cela permet d’éviter le calcul
  coûteux de la racine carrée, qui était inutile dans les cas d’usage observés (comparaisons ou multiplication par elle-même).

- Le type de retour a été modifié de float à int, ce qui garantit une meilleure précision dans les calculs, tout en évitant les imprécisions liées à
  l'arithmétique flottante.

- Les endroits du code où la distance était multipliée par elle-même ont été modifiés, car cette opération est désormais superflue :
  la fonction retourne directement la distance au carré.

À noter que, en raison des limites de la précision flottante, les résultats peuvent différer légèrement par rapport à ceux de la version originale.
Cependant, après validation auprès du professeur, ces écarts ont été considérés comme acceptables, et cette version du code est désormais considérée
comme la référence. Pour la suite du projet, toutes les optimisations, y compris celles utilisant SIMD, seront validées en s’assurant qu’elles produisent
les mêmes résultats que cette version.


== Optimisation de la fonction de distance avec SIMD

Pour améliorer les performances de la fonction de distance, j’ai utilisé des registres SIMD de 16 octets. Étant donné qu’un pixel en format RGBA occupe 4 octets (1 par composant R, G, B, A), cela permet de traiter 4 pixels simultanément.

Cela implique de modifier toutes les parties du code qui appellent cette fonction. En effet, il devient nécessaire de former des groupes (ou batchs) de 4 pixels pour pouvoir calculer les distances par 4.

Dans l’algorithme k-means, on calcule la distance entre un pixel donné et un centre (pixel central). Pour pouvoir appliquer le calcul SIMD à 4 pixels en parallèle, la solution la plus simple consiste à copier le pixel central 4 fois dans un buffer temporaire, afin de le comparer aux 4 autres pixels en une seule opération SIMD.

Afin que cette approche fonctionne sans erreur, l’image doit avoir un nombre de pixels multiple de 4. Sinon, on risquerait de dépasser les limites du buffer lors des derniers calculs.

Pour simplifier, l’image est convertie en format RGBA (avec un canal alpha mis à zéro) avant le traitement k-means, puis reconvertie en format RGB à l’export.

== Modification de la fonction


```c
void distance_simd(const uint8_t *p1, const uint8_t *p2, uint32_t *result)
{
	__m128i v1 = _mm_loadu_si128((__m128i const *)p1);
	__m128i v2 = _mm_loadu_si128((__m128i const *)p2);

	const __m128i mask = _mm_set_epi8(0x00, 0xFF, 0xFF, 0xFF, 0x00, 0xFF,
					  0xFF, 0xFF, 0x00, 0xFF, 0xFF, 0xFF,
					  0x00, 0xFF, 0xFF, 0xFF);

	v1 = _mm_and_si128(v1, mask);
	v2 = _mm_and_si128(v2, mask);

	__m128i zero = _mm_setzero_si128();

	__m128i v1lo = _mm_unpacklo_epi8(v1, zero);
	__m128i v1hi = _mm_unpackhi_epi8(v1, zero);
	__m128i v2lo = _mm_unpacklo_epi8(v2, zero);
	__m128i v2hi = _mm_unpackhi_epi8(v2, zero);

	__m128i diff_lo = _mm_sub_epi16(v1lo, v2lo);
	__m128i diff_hi = _mm_sub_epi16(v1hi, v2hi);

	__m128i sq_lo = _mm_mullo_epi16(diff_lo, diff_lo);
	__m128i sq_hi = _mm_mullo_epi16(diff_hi, diff_hi);

	uint16_t tmp[16];
	_mm_storeu_si128((__m128i *)tmp, sq_lo);
	_mm_storeu_si128((__m128i *)(tmp + 8), sq_hi);

	for (size_t i = 0; i < 4; ++i) {
		size_t j = i * 4;
		result[i] = tmp[j] + tmp[j + 1] + tmp[j + 2];
	}
}
```

=== 1. Masquage (Mask)

Le calcul de la distance ne doit pas prendre en compte le canal alpha. On utilise donc un masque pour mettre à zéro cette composante dans chaque pixel.
Cela dit, cette opération est optionnelle, car l’alpha a déjà été mis à zéro lors de la conversion initiale de l’image, ce qui rend ce masque inutile dans notre cas.

=== 2. Soustraction et multiplication

On convertit les octets en entiers de 16 bits (au lieu de 8 bits) pour éviter tout dépassement de capacité pendant les opérations de soustraction
et de multiplication. Une fois les pixels convertis en 16 bits, on peut faire la soustraction entre chaque composant correspondant des deux vecteurs
(R1 avec R2, G1 avec G2, etc.) sans risque d'erreur. Ensuite, on élève chaque différence au carré avec `_mm_mullo_epi16` pour obtenir les carrés des écarts,
comme dans une distance euclidienne classique.

=== 3. Addition

Une fois les carrés des différences calculés, on les récupère dans un tableau temporaire, puis on additionne les composantes 
R, G et B de chaque pixel pour obtenir la distance finale, le tout en utilisant des opérations classiques.


== Benchmarking

```bash
hyperfine --warmup 10 './code/part1/build/segmentation_simd ./docs/media/pexels-christian-heitz-285904-842711.png 10 simd.png'
Benchmark 1: ./code/part1/build/segmentation_simd ./docs/media/pexels-christian-heitz-285904-842711.png 10 simd.png
  Time (mean ± σ):      3.707 s ±  0.028 s    [User: 3.426 s, System: 0.246 s]
  Range (min … max):    3.672 s …  3.764 s    10 runs
```

Nous observons une amélioration considérable par rapport à la première version du code, avec un temps d'exécution passant de 12.7 secondes à 3.7 secondes.

Cette optimisation n’est pas uniquement due à l’utilisation de SIMD. Elle est fortement soutenue par plusieurs autres modifications apportées au code, notamment :

- La suppression des calculs en valeurs flottantes, remplacés par des entiers pour gagner en rapidité et en précision,
- L’élimination de certaines allocations dynamiques inutiles, qui ralentissaient l'exécution,
- Ainsi que d’autres petites optimisations structurelles dans les fonctions critiques.

L'ensemble de ces changements contribue à un gain de performance global très significatif.


