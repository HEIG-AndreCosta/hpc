#set align(center)

= HPC - Labo 01 - DTMF
== André Costa

#set align(left)

= Introduction

Ce laboratoire a comme objectif la familiarisation avec le langage `C`.

Pour cela, il est demandé d'implémenter un système d'encodage et décodage 
`DTMF` (Dual-Tone Multi-Frequency).

Pour l'implémentation de ce système, il nous est proposé de commencer d'abord 
avec l'encodage avant d'implémenter deux décodeurs différents.

Une fois l'implémentation complète, il nous est demandé de mesurer le temps
d'exécution du système.

= Guide d'utilisation rapide

1. Compilez le code en utilisant le `CMakeLists.txt` à la racine du répertoire

```bash
mkdir -p build
cd build
cmake ..
make -j$(nproc)
cd ..
```

2. Exportez votre message sur un fichier text

```bash
echo "je suis un bg" > je_suis_un_bg.txt
```

3. Encodez votre message

```bash
./build/dtmf_encdec encode je_suis_un_bg.txt je_suis_un_bg.wav
Encoding alone took 0.014179 seconds
```

4. Décodez votre message en utilisant votre décodeur de préférence

	 - Décodeur Fréquentiel

	```bash
	./build/dtmf_encdec decode je_suis_un_bg.wav
		Using 0.539966 as silence amplitude threshold
		Decoding alone took 0.017162 seconds
		Decoded: je suis un bg
	```

	- Décodeur Temporel

	```bash
	./build/dtmf_encdec decode_time_domain je_suis_un_bg.wav
		Using 0.539966 as silence amplitude threshold
		Decoding alone took 0.001462 seconds
		Decoded: je suis un bg
	```

#pagebreak()

= Encodage

L'encodage DTMF consiste à lire un message depuis un fichier texte et à générer un fichier audio au format wave.

L'algorithme fonctionne comme suit :

1. Identifier le bouton correspondant à chaque lettre du message.
2. Déterminer le nombre de pressions nécessaires pour sélectionner la lettre.
3. Générer la séquence de tonalités DTMF correspondante, en insérant une pause 
	de `0.05` secondes entre chaque pression.
4. Ajouter une pause de `0.2` secondes entre les lettres.

== Tonalité

La tonalité est déterminé par la formule suivante :

$ s(t) = A × (sin(2#sym.pi f_("row") t) + sin(2#sym.pi f_("col") t)) $

où :
- $A$ est l’amplitude du signal,
- $f_("row")$ et $f_("col")$ sont les fréquences DTMF associées au caractère,
- $t$ est le temps.

Comme le traitement est effectué avec des échantillons, $t$ peut être determiné avec

$ t = "sample_number" / "sample_rate" $

== Fréquence d'échantillonage (Sample Rate)

Pour l'encodage la fréquence d'échantillonage est fixée à `44.1 kHz`, ce
qui est un habituel pour des application audio.

La fréquence minimale est tout de fois plus basse. En effet, selon le théorème
de Nyquist, la fréquence minimale doit être au moins deux fois plus élevé que 
la fréquence maximale que nous allons utiliser ce qui donne la relation suivante:

$ "fs" >= 2 * 1477 = 2954 "Hz" $

Avec la fréquence choisie de `44.1 kHz` nous respectons largement cette contrainte.

Notons qu'une autre fréquence qui est très utilisé pour la téléphonie est la fréquence de `8kHz`.

== Autres paramètres

Vu le challenge de partager des fichier encodés entre la classe les paramètres suivants 
peuvent être modifiés pour générer des fichiers plus ou moins difficiles à décoder.

```c
#define SILENCE_F1    0 
#define SILENCE_F2    0
```

Les paramètres `SILENCE_FX` permettent d'indiquer les deux fréquences utilisés
lors de la génération du silence. Par défaut à `0`, ces valeurs peuvent être modifiées
pour générer du bruit lorsqu'il devrait y avoir du silence

```c
#define EXTRA_PRESSES    0
```

Le paramètre `EXTRA_PRESSES` permet d'indiquer combien de tours supplémentaires il faudra
encoder pour chaque lettre. Par exemple, la valeur de 1 encodera la valeur `2` avec `5` 
pressions sur le deuxième bouton à la place de `1` pression.

#pagebreak()

= Decodage

Les différentes contraintes du système permettent de simplifier énormément le décodeur.

Pour rappel, les 3 contraintes du système sont:

1. Une durée d’un son de 0.2 secondes par caractère.
2. Une pause de 0.2 secondes entre deux caractères.
3. Une pause de 0.05 secondes entre plusieurs pressions pour un même caractère.

En profitant de ces contraintes il est possible de déterminer que, une fois trouvé une pression
de touche, la prochaine touche viendra soit :

1. 0.25 secondes plus tard
	- Il sera donc la même touche qui aurait été pressée
2. 0.40 secondes
	- Pour une nouvelle lettre

De plus, la période maximale des signaux générés par notre système correspond à l'envers de 
fréquence minimale:

$ T_{min} = 1 / F_("min") = 1 / 697 ~= 1.56 "ms" $

Cela veut dire qu'en prenant une fenêtre de `0.05s` il est possible de capturer 
n'importe quel signal généré par notre système.

Ici, l'utilisation de `0.05s` correspond au temps de pause minimale entre chaque touche
et permet de facilement rester alignés avec le signal à décoder.
Avec cette analyse, des optimisations additionneles seraient possibles mais elles n'ont
pas été exploités dans le cadre de ce laboratoire.


== Algorithme Général

=== Alignement avec première touche

Tout d'abord, il faut s'aligner avec le début du signal.
Pour cela, la transformé de fourier a été utilisé, l'algorithme est le suivant:

1. Sélectionner une fenêtre de `0.05s`.
2. Identifier les deux fréquences dominantes dans cette fenêtre.
3. Si ces fréquences appartiennent à l'intervalle $[650"Hz";1500"Hz"]$, considérer
	cette fenêtre comme le début de l'appui sur une touche.
4. Sinon, avancer de `0.05s` et répéter l'opération.


Cet alignement est important car le fichier `wave` pourrait démarrer avec du silence.

=== Décodage - Algorithme Général

Une fois aligné avec le signal, les contraintes du système garantissent que l’alignement
est maintenu. L’algorithme fonctionne comme suit :

1. Sélectionner une fenêtre de `0.05 secondes`.
2. Vérifier la présence de silence :
	- Une fenêtre est considérée comme silencieuse si son amplitude est inférieure à $90 %$
		de celle détectée lors de la première touche.
	- Si du silence est détecté, avancer de `0.15 secondes` et revenir à l’étape `1`.
3. Décoder le bouton pressé :
        - Si l’identification du bouton n’est pas possible, considérer cette fenêtre comme invalide, avancer de `0.15` secondes, puis retourner à l’étape `1`.
	- Si le bouton a été identifié, comptabiliser la pression, avancer de `0.25` secondes, puis retourner à l'étape `1`.

En cas de détection d’une fenêtre invalide ou silencieuse, on retient le dernier
bouton pressé ainsi que le nombre d’appuis consécutifs pour déterminer la lettre correcte.

Cet algorithme général est utilisé pour deux méthodes de décodage distinctes :

- Une analyse fréquentielle via la Transformée de Fourier.
- Une analyse temporelle par corrélation.

== Analyse Fréquentielle  

L'analyse fréquentielle repose sur l'utilisation de la Transformée de Fourier
sur une fenêtre de `0.05 secondes`. On en extrait les deux fréquences dominantes et,
si celles-ci appartiennent à l'intervalle $[650"Hz";1500"Hz"]$,
elles sont considérées comme valides. On identifie alors les fréquences les plus proches parmi les fréquences DTMF afin de déterminer le bouton correspondant.  

== Analyse Temporelle  

L'analyse temporelle consiste à générer des signaux de référence pour chaque touche,
puis à calculer la corrélation entre la fenêtre de `0.05 secondes` et ces signaux de référence.
Le bouton associé au signal de référence présentant la meilleure corrélation est alors considéré comme celui ayant été pressé.  


#pagebreak()

= Résultats


== Should Be Easy To Decode

- Contient un peu de bruit

#image("./media/should_be_easy_to_decode.png")

```bash
Decoding audio/should_be_easy_to_decode.wav
-- Frequency Domain --
Using 0.899973 as silence amplitude threshold
Decoding alone took 0.003061 seconds
Decoded: should be easy to decode
-- Time Domain --
Using 0.899973 as silence amplitude threshold
Decoding alone took 0.000439 seconds
Decoded: should be easy to decode
```

== Hard To Decode

- Contient plus du bruit

#image("./media/hard_to_decode.png")

```bash
Decoding audio/hard_to_decode.wav
-- Frequency Domain --
Using 0.899973 as silence amplitude threshold
Decoding alone took 0.001612 seconds
Decoded: hard to decode
-- Time Domain --
Using 0.899973 as silence amplitude threshold
Decoding alone took 0.000341 seconds
Decoded: hard to decode
```

== You Are Amazing

- Contient du bruit seulement dans les moments de silence 
 avec une amplitude égale au moments de pression.

#image("./media/you_are_amazing.png")

```bash
Decoding audio/you_are_amazing.wav
-- Frequency Domain --
Using 0.359953 as silence amplitude threshold
Decoding alone took 0.027844 seconds
Decoded: you are amazing
-- Time Domain --
Using 0.359953 as silence amplitude threshold
Decoding alone took 0.00188 seconds
Decoded: you are amazing
```

== Unrealistic Noise

- Contient du bruit seulement dans les moments de silence 
 avec une amplitude égale au moments de pression.

#image("./media/unrealistic_noise.png")
```bash
Decoding audio/unrealistic_noise.wav
-- Frequency Domain --
Using 0.89976 as silence amplitude threshold
Decoding alone took 0.030596 seconds
Decoded: unrealistic noise
-- Time Domain --
Using 0.89976 as silence amplitude threshold
Decoding alone took 0.001835 seconds
Decoded: unrealistic noise
```

== Bien Joue Bg

- Amplitude est infiniment petite 

#image("./media/bien_joue_bg.png")

```bash
Decoding audio/bien_joue_bg.wav
-- Frequency Domain --
Using 0.00179916 as silence amplitude threshold
Decoding alone took 0.023035 seconds
Decoded: bien joue bg !!!
-- Time Domain --
Using 0.00179916 as silence amplitude threshold
Decoding alone took 0.001768 seconds
Decoded: bien joue bg !!!
```

#pagebreak()

== Crashing Is Not Allowed

- Encodé avec un nombre de `EXTRA_PRESSES` élevé

#image("./media/crashing_is_not_allowed.png")

```bash
Decoding audio/crashing_is_not_allowed_!.wav
-- Frequency Domain --
Using 0.359832 as silence amplitude threshold
Decoding alone took 0.34178 seconds
Decoded: crashing is not allowed !
-- Time Domain --
Using 0.359832 as silence amplitude threshold
Decoding alone took 0.013804 seconds
Decoded: crashing is not allowed !
```


= Analyse

De manière surprenante, le décodage basé sur l’analyse
temporelle par corrélation parvient à identifier correctement
les touches, même en présence d’un bruit important ou
d’un bruit artificiel peu réaliste.  

Cette robustesse s’explique par le fait que la corrélation
exploite directement la forme du signal dans le temps, ce
qui permet de détecter des motifs caractéristiques même
lorsqu’ils sont partiellement masqués par du bruit.

Cependant, le décodeur fréquentiel reste supérieur en toutes
circonstances. Grâce à l’utilisation de la Transformée
de Fourier, il identifie avec précision les fréquences
dominantes, offrant un décodage stable et fiable,
y compris en présence de bruit. Son efficacité est due à sa
capacité à isoler les composantes fréquentielles du signal,
ce qui le rend plus robuste face aux variations
d’intensité ou aux déformations temporelles du signal d’entrée.  
Il est surtout plus fiable lorsqu'il n'est pas possible de
s'aligner parfaitement avec le signal.
Dans de telles situations, l'analyse fréquentielle
permet de retrouver les fréquences des touches même si
le signal est légèrement décalé ou perturbé.


#pagebreak()
= Performance


En utilisant l'outil `hyperfine` il est possible de facilement 
déterminer le temps pris par notre application.

De plus, pour pouvoir savoir le temps qui prend la partie de
décodage, cette fonction est _wrappé_ sur deux appels de
`clock`.

```c
clock_t t;
t = clock();
char *value = decode_fn(&decoder);
t = clock() - t;
const double time_taken = ((double)t) / CLOCKS_PER_SEC;
printf("Decoding alone took %g seconds\n", time_taken);
```

*Hard To Decode*

```bash
> hyperfine "./build/dtmf_encdec decode audio/hard_to_decode.wav" --shell=none --warmup 10
Benchmark 1: ./build/dtmf_encdec decode audio/hard_to_decode.wav
  Time (mean ± σ):       2.9 ms ±   0.1 ms    [User: 1.9 ms, System: 1.0 ms]
  Range (min … max):     2.8 ms …   4.0 ms    975 runs
 
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet system without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
> hyperfine "./build/dtmf_encdec decode_time_domain audio/hard_to_decode.wav" --shell=none --warmup 10
Benchmark 1: ./build/dtmf_encdec decode_time_domain audio/hard_to_decode.wav
  Time (mean ± σ):       1.6 ms ±   0.1 ms    [User: 0.5 ms, System: 1.0 ms]
  Range (min … max):     1.4 ms …   2.0 ms    1844 runs
 
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet system without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
```


Mesurer la performance de notre décodeur avec un signal si
court n'est pas la meilleure idée, car il est difficile d'avoir
des résultats consistents.
De plus, la partie plus intéressant - le décodage - est surpassé
par des autres tâches comme la lecture du fichier `wave`. ce qui peut être vu lors que la sortie `stdout` n'est pas consommé:


```bash
> time ./build/dtmf_encdec decode audio/hard_to_decode.wav
Using 0.899973 as silence amplitude threshold
Decoding alone took 0.001628 seconds
Decoded: hard to decode
./build/dtmf_encdec decode audio/hard_to_decode.wav  0.00s user 0.00s system 88% cpu 0.004 total
> time ./build/dtmf_encdec decode_time_domain audio/hard_to_decode.wav
Using 0.899973 as silence amplitude threshold
Decoding alone took 0.000246 seconds
Decoded: hard to decode
./build/dtmf_encdec decode_time_domain audio/hard_to_decode.wav  0.00s user 0.00s system 85% cpu 0.003 total
```

Avec ces deux outils il est possible d'estimer que le décodage avec l'analyse linéaire est environ `6.58` fois plus rapide que le décodage avec l'analyse fréquentielle.

Le programme en soit tourne `1.8` fois plus rapidement.

#pagebreak()

*Crashing is not allowed*

Vu la longeur du signal `crashing_is_not_allowed` il est 
possible d'avoir des résultats plus fiables pour nos décodeurs.


```bash
> hyperfine "./build/dtmf_encdec decode audio/crashing_is_not_allowed_\\\!.wav" --shell=none --warmup 10
Benchmark 1: ./build/dtmf_encdec decode audio/crashing_is_not_allowed_\!.wav
  Time (mean ± σ):     364.9 ms ±   7.8 ms    [User: 348.0 ms, System: 15.3 ms]
  Range (min … max):   357.3 ms … 379.7 ms    10 runs
 
> hyperfine "./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\\\!.wav" --shell=none --warmup 10
Benchmark 1: ./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\!.wav
  Time (mean ± σ):      28.9 ms ±   0.3 ms    [User: 14.0 ms, System: 14.7 ms]
  Range (min … max):    28.1 ms …  29.7 ms    102 runs
```

```bash
> time ./build/dtmf_encdec decode audio/crashing_is_not_allowed_\!.wav
Using 0.359832 as silence amplitude threshold
Decoding alone took 0.341306 seconds
Decoded: crashing is not allowed !
./build/dtmf_encdec decode audio/crashing_is_not_allowed_!.wav  0.34s user 0.02s system 99% cpu 0.360 total
> time ./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_\!.wav
Using 0.359832 as silence amplitude threshold
Decoding alone took 0.013742 seconds
Decoded: crashing is not allowed !
./build/dtmf_encdec decode_time_domain audio/crashing_is_not_allowed_!.wav  0.01s user 0.01s system 98% cpu 0.030 total
```

Ici lanalyse linéaire est environ `25` fois plus rapide que le décodage avec l'analyse fréquentielle.

Le programme en soit tourne `12.6` fois plus rapidement.
