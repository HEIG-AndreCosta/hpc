= Introduction

= Exemple 1 - Boolean Returns

== Version de base - Pas d'optimisations

Source: #link("https://godbolt.org/z/za7YdEab8")[Godbolt - Exemple Boolean Returns]

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
int cprop1(int a) {
	if (a > 10) {
		return true;
	} else {
		return false;
	}
}
```],[
```asm
	push    rbp
	mov     rbp, rsp
	mov     DWORD PTR [rbp-4], edi
	cmp     DWORD PTR [rbp-4], 10
	jle     .L2
	mov     eax, 1
	jmp     .L3
.L2:
	mov     eax, 0
.L3:
	pop     rbp
	ret
```]
)

Ce code est typique de ce que l’on retrouve dans les premiers cours de programmation (cf. PRG1 et PRG2).
On y voit une structure conditionnelle simple avec un `if/else` explicite.
Le compilateur traduit ça littéralement avec des instructions de branchement (`jle`, `jmp`),
ce qui est très lisible, mais pas optimisé.


#line(length:100%)

== Version manuellement optimisée

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
int cprop2(int a) {
	return a > 10;
}
```],[

```asm
        push    rbp
        mov     rbp, rsp
        mov     DWORD PTR [rbp-4], edi
        cmp     DWORD PTR [rbp-4], 10
        setg    al
        movzx   eax, al
        pop     rbp
        ret
```]
)

Ce code est beaucoup plus concis et lisible. En écrivant `return a > 10`, on élimine l’usage
explicite de `if/else` et donc les instructions de branchement.
Le compilateur peut directement utiliser l’instruction `setg` qui place un booléen (`1` ou `0`)
dans un registre selon le résultat de la comparaison. Cela permet d’éviter les branchements
conditionnels, ce qui améliore les performances, notamment en maintenant le pipeline du
processeur plus fluide.

#line(length:100%)

== Version de base - Optimisé par le compilateur (-O1)

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
int cprop1(int a) {
	if (a > 10) {
		return true;
	} else {
		return false;
	}
}
```],[

```asm
        cmp     edi, 10
        setg    al
        movzx   eax, al
        ret
```]
)

Même si le code source est resté dans sa version non optimisée, l’activation de l’optimisation
`-O1` du compilateur GCC permet d’obtenir un résultat très proche de la version manuellement
optimisée. Le compilateur détecte que la structure `if/else` peut être réduite à une expression
booléenne simple, et génère un code plus performant, sans branchement.

L’optimisation ici est automatiquement activée via les options du compilateur,
comme `-O1`, `-O2` ou `-O3`.

= Exemple 2 - Outsmarting

Source: #link("https://godbolt.org/z/887MW959r")[Godbolt - Outsmarting]

== Version de base - Pas d'optimisations

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
void cprop1(int* a, size_t n, int* flag) {
    for(size_t i = 0; i < n; ++i)
    {
        if(*flag)
        {
            a[i] *= 2;
        }
    }

}
```],[

```asm
        push    rbp
        mov     rbp, rsp
        mov     QWORD PTR [rbp-24], rdi
        mov     QWORD PTR [rbp-32], rsi
        mov     QWORD PTR [rbp-40], rdx
        mov     QWORD PTR [rbp-8], 0
        jmp     .L2
.L4:
	// if (!(*flag))
        mov     rax, QWORD PTR [rbp-40]
        mov     eax, DWORD PTR [rax]
        test    eax, eax
        je      .L3
	// else
        mov     rax, QWORD PTR [rbp-8]
        lea     rdx, [0+rax*4]
        mov     rax, QWORD PTR [rbp-24]
        add     rax, rdx
        mov     edx, DWORD PTR [rax]
        mov     rax, QWORD PTR [rbp-8]
        lea     rcx, [0+rax*4]
        mov     rax, QWORD PTR [rbp-24]
        add     rax, rcx
        add     edx, edx
        mov     DWORD PTR [rax], edx
.L3:
	// ++i
        add     QWORD PTR [rbp-8], 1
.L2:
	// i < n
        mov     rax, QWORD PTR [rbp-8]
        cmp     rax, QWORD PTR [rbp-32]
        jb      .L4
        nop
        nop
        pop     rbp
        ret
```]
)

Dans cette version, on constate que la valeur de `*flag` est vérifiée à chaque itération de la boucle. Or, l'opération effectuée sur le tableau est une simple multiplication par 2. Même dans le cas où un élément du tableau référencerait la même adresse mémoire que flag, cette opération ne peut pas faire basculer la valeur de `*flag` de 0 à une valeur non nulle, ou inversement, sauf dans un cas très particulier : si `*flag == 0x80000000`, la multiplication entraînerait un dépassement de capacité (overflow) et produirait 0. Toutefois, selon la norme C (ISO/IEC 9899:2018), chapitre 6.5, paragraphe 5, un dépassement lors d'opérations entières signées constitue un comportement indéfini (Undefined Behavior). En se basant sur cela, le compilateur est libre de supposer que `*flag` reste constant pendant toute la boucle. Il peut donc optimiser le code en testant `*flag` une seule fois avant la boucle, ce qui permet d’éliminer des comparaisons et branchements redondants. Cette optimisation est particulièrement bénéfique lorsque n est grand, car elle réduit considérablement le nombre d'instructions exécutées.

#line(width:100%)

== Version manuellement optimisée

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
void cprop2(int* a, size_t n, int* flag) {
    
    if(!(*flag))
    {
        return;
    }
    for(size_t i = 0; i < n; ++i)
    {
        a[i] *= 2;
    }
    
}
```],[

```asm
cprop2:
        push    rbp
        mov     rbp, rsp
        mov     QWORD PTR [rbp-24], rdi
        mov     QWORD PTR [rbp-32], rsi
        mov     QWORD PTR [rbp-40], rdx
	// if(!(*flag))
        mov     rax, QWORD PTR [rbp-40]
        mov     eax, DWORD PTR [rax]
        test    eax, eax
        je      .L10
        mov     QWORD PTR [rbp-8], 0
        jmp     .L8
.L9:
	// a [i] *= 2
        mov     rax, QWORD PTR [rbp-8]
        lea     rdx, [0+rax*4]
        mov     rax, QWORD PTR [rbp-24]
        add     rax, rdx
        mov     edx, DWORD PTR [rax]
        mov     rax, QWORD PTR [rbp-8]
        lea     rcx, [0+rax*4]
        mov     rax, QWORD PTR [rbp-24]
        add     rax, rcx
        add     edx, edx
        mov     DWORD PTR [rax], edx
        add     QWORD PTR [rbp-8], 1
.L8:
	// i < n
        mov     rax, QWORD PTR [rbp-8]
        cmp     rax, QWORD PTR [rbp-32]
        jb      .L9
        jmp     .L5
.L10:
        nop
.L5:
        pop     rbp
        ret
```]
)

Ici, on supprime complètement la vérification de `*flag` dans la boucle. Elle est effectuée *une seule fois* avant le début de la boucle. Si `*flag == 0`, la fonction retourne immédiatement. Cela améliore énormément la performance, notamment dans les cas où `*flag` vaut 0 (le corps de la boucle est alors totalement évité). Même quand `*flag != 0`, cela reste bénéfique car on évite une comparaison et un branchement conditionnel à chaque itération. Sur de très grandes boucles, cela a un impact direct sur le nombre d'instructions exécutées et la pression sur le pipeline du processeur.

#line(length:100%)

== Version de base - Optimisé par le compilateur (-O1 -fstrict-aliasing)

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
void cprop3(int* a, size_t n, int* flag) {
    for(size_t i = 0; i < n; ++i)
    {
        if(*flag)
        {
            a[i] *= 2;
        }
    }
}
```],[
```asm
        test    rsi, rsi
        je      .L11
        mov     eax, 0
        jmp     .L14
.L13:
        add     rax, 1
        cmp     rsi, rax
        je      .L11
.L14:
        cmp     DWORD PTR [rdx], 0
        je      .L13
        sal     DWORD PTR [rdi+rax*4]
        jmp     .L13
.L11:
        ret
```]
)

Contrairement à ce que l'on pourrait penser, même avec les options `-O1`, `-fstrict-aliasing` et `-fmove-all-movables`,
le compilateur ne comprend pas que la valeur de `*flag` reste constante pendant l'exécution de
la boucle. Il continue donc à vérifier `*flag` à chaque itération. Autrement dit,
l'optimisation attendue — déplacer la vérification de `*flag` en dehors de la boucle —
n'est pas appliquée automatiquement ici, malgré les indices donnés au compilateur.
Cela montre que, dans ce cas, une optimisation manuelle reste nécessaire pour éliminer les vérifications redondantes.

Comme quoi l'homme n'est toujours pas dépassé vis-à-vis les machines :).

#line(length:100%)

== Version manuellement optimisé et optimisé par le compilateur (-O1)

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
void cprop4(int* a, size_t n, int* flag) {
    
    if(!(*flag))
    {
        return;
    }
    for(size_t i = 0; i < n; ++i)
    {
        a[i] *= 2;
    }
    
}
```],[
```asm
        cmp     DWORD PTR [rdx], 0
        je      .L16
        test    rsi, rsi
        je      .L16
        mov     rax, rdi
        lea     rdx, [rdi+rsi*4]
.L18:
        sal     DWORD PTR [rax]
        add     rax, 4
        cmp     rax, rdx
        jne     .L18
.L16:
        ret
```]
)

Grâce à l’optimisation manuelle combinée à l’optimisation du compilateur, celui-ci peut appliquer des transformations plus agressives. Il supprime toute vérification de `*flag`
dans le corps de boucle et transforme le tout en un simple parcours de mémoire avec décalage (`sal`).
Ce type de code est *beaucoup plus efficace* car il élimine des instructions inutiles et réduit la charge de travail du processeur lors de l’exécution.


= Exemple 3 - Propriétés mathématiques

Source: #link("https://godbolt.org/z/6v1Y7GTfr")[Godbolt - Propriétés mathématiques]

== Version de base - Pas d'optimisations

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
int square3(int b)
{
    if(b < 0)
    {
        b = -b;
    }
    return b*b;
}
```],[
```asm
        push    rbp
        mov     rbp, rsp
        mov     DWORD PTR [rbp-4], edi
        cmp     DWORD PTR [rbp-4], 0
        jns     .L2
        neg     DWORD PTR [rbp-4]
.L2:
        mov     eax, DWORD PTR [rbp-4]
        imul    eax, eax
        pop     rbp
        ret
```]
)

Dans cet exemple, on observe que la condition `if (b < 0)` est utilisée pour rendre `b` positif avant de retourner `b * b`. Cependant, cette étape est *inutile*, car l'opération `b * b` renverra toujours le même résultat, qu’on utilise `b` ou `-b` : en effet, le carré d’un entier est toujours positif (ou nul), et `b * b == (-b) * (-b)`.

En ajoutant cette condition, on complique inutilement le code avec une instruction de branchement (`jns`) et une négation (`neg`) qui pourraient être évitées. Ces instructions nuisent à la performance, notamment au niveau de la prédiction de branchement dans le pipeline du processeur.

Cet exemple illustre bien qu'une intuition "logique" en `C` n’est pas toujours synonyme de code optimal en assembleur — parfois, en voulant "corriger" quelque chose qui n'a pas besoin de l'être, on alourdit le programme.

== Version manuellement optimisée

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
int square2(int b)
{
    return b*b;
}
```],[
```asm
        push    rbp
        mov     rbp, rsp
        mov     DWORD PTR [rbp-4], edi
        mov     eax, DWORD PTR [rbp-4]
        imul    eax, eax
        pop     rbp
        ret
```]
)
On constate ici qu’en retirant simplement le if, on obtient une version bien plus concise et directe du code. Le calcul b * b est effectué sans aucun test de signe, car comme expliqué précédemment, le carré d’un entier est le même que celui de sa valeur absolue.

Cette version manuellement optimisée évite toute instruction de branchement ou de négation, ce qui permet un code assembleur plus simple, plus rapide et plus facile à optimiser pour le processeur. En plus, elle réduit la taille du binaire et améliore potentiellement la prédiction dans le pipeline d’exécution.

== Version de base - Optimisé par le compilateur (-O1)

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
int square3(int b)
{
    if(b < 0)
    {
        b = -b;
    }
    return b*b;
}
```],[
```asm
        imul    edi, edi
        mov     eax, edi
        ret
```]
)

On remarque ici qu'avec l’option -O1, le compilateur parvient à optimiser le code de manière très efficace. Il a compris que le test if (b < 0) suivi de b = -b était superflu pour le calcul du carré, et a donc simplifié toute la fonction en une seule instruction de multiplication (imul) suivie d’un mov et d’un ret. Cela donne exactement le même résultat, tout en supprimant les instructions de branchement et de négation.

Cette optimisation revient exactement à ce que nous aurions fait manuellement en supprimant le if dans le code source C, ce qui prouve que le compilateur peut, dans certaines circonstances, appliquer des simplifications mathématiques sûres.

On pourrait penser qu’il est possible de retrouver ce comportement en activant les bonnes optimisations individuellement, mais ce n’est pas si simple.
Par exemple, l’option `-fssa-backprop` que, selon la documentation peut être utilisée pour simplifier des calculs quand le signe d'une valeur n'est pas importante.
#link("https://gcc.gnu.org/onlinedocs/gcc-9.1.0/gcc/Optimize-Options.html")[Source]. Cependant, activée seule, elle n’a aucun effet visible sans `-O1` ou supérieur, car elle dépend d'autres passes déjà actives dans ces niveaux d’optimisation.

J’ai également testé en combinant manuellement toutes les options que GCC applique automatiquement avec `-O1`, comme listé sur
#link("https://gcc.gnu.org/onlinedocs/gcc-9.1.0/gcc/Optimize-Options.html")[cette page], mais je n’ai pas réussi à obtenir exactement le même résultat.
Cela montre que le comportement de `-O1` est plus complexe que la simple addition de drapeaux — certaines passes ne sont activées que lorsqu’un certain contexte d’optimisation est présent,
et il peut y avoir des interactions non documentées entre elles.


= Partie 2 - DTMF

Pour cette deuxième partie, je vais me pencher sur l'optimisation du encodeur/décodeur DTMF développé dans le cadre du laboratoire 1.

En lisant le code du décodeur `dtmf_decoder.c`, il y a quelques optimisations qui peuvent être ressorties sans aller trop loin.

== Quick Math

Source: #link("https://godbolt.org/z/1Gv3joacK")[Godbolt - Quick Math]

=== Version Originale

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
        *amplitude = *amplitude - (*amplitude / 10);
```],[
```asm
        mov     rax, QWORD PTR [rbp-8]
        movss   xmm0, DWORD PTR [rax]
        mov     rax, QWORD PTR [rbp-8]
        movss   xmm1, DWORD PTR [rax]
        movss   xmm2, DWORD PTR .LC0[rip]
        divss   xmm1, xmm2
        subss   xmm0, xmm1
        mov     rax, QWORD PTR [rbp-8]
        movss   DWORD PTR [rax], xmm0
```]
)

Ici, on observe que l'expression `*amplitude = *amplitude - (*amplitude / 10);`
est traduite en assembleur par une division suivie d'une soustraction,
ce qui représente deux opérations flottantes séparées.
Pourtant, cette opération est mathématiquement équivalente à une multiplication par `0.9f`.
Ce type de réécriture permet non seulement de simplifier le code source, mais aussi de générer un code assembleur plus efficace.

=== Version Manuellement Optimisée

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
        *amplitude *= 0.9f;
```],[

```asm
        mov     rax, QWORD PTR [rbp-8]
        movss   xmm1, DWORD PTR [rax]
        movss   xmm0, DWORD PTR .LC1[rip]
        mulss   xmm0, xmm1
        mov     rax, QWORD PTR [rbp-8]
        movss   DWORD PTR [rax], xmm0
```]
)

Dans cette version manuellement optimisée, on remplace l'expression par une multiplication directe avec `0.9f`. Le compilateur génère alors un code bien plus concis : une seule multiplication est utilisée, ce qui réduit la complexité des calculs à effectuer. Cela améliore non seulement les performances mais simplifie aussi la lecture du code.

Il est important ici d’utiliser le suffixe `f` (`0.9f`) pour s'assurer que la constante est bien interprétée comme un `float`. Sans ce suffixe, la constante est considérée comme un `double`, ce qui a un impact sur le code généré: 

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
        *amplitude *= 0.9;
```],[
```asm
        mov     rax, QWORD PTR [rbp-8]
        movss   xmm0, DWORD PTR [rax]
        cvtss2sd        xmm1, xmm0
        movsd   xmm0, QWORD PTR .LC2[rip]
        mulsd   xmm0, xmm1
        cvtsd2ss        xmm0, xmm0
        mov     rax, QWORD PTR [rbp-8]
        movss   DWORD PTR [rax], xmm0
```]
)

Ce code est plus lourd car :

- La valeur float est convertie en double (`cvtss2sd`)
- La multiplication est effectuée en double précision (`mulsd`)
- Le résultat est ensuite reconverti en float (`cvtsd2ss`)

En somme, omettre le `f` oblige le processeur à effectuer plusieurs conversions inutiles, 
ce qui nuit à la performance.

=== Version de base - Optimisée par le compilateur (-O3)

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
    *amplitude = *amplitude - (*amplitude / 10);
```],[
```asm
        movss   xmm0, DWORD PTR [rdi]
        movaps  xmm1, xmm0
        divss   xmm1, DWORD PTR .LC0[rip]
        subss   xmm0, xmm1
        movss   DWORD PTR [rdi], xmm0
```]
)

Malgré l’activation des optimisations agressives via l’option `-O3`, le compilateur choisit de ne pas réécrire l’opération `*amplitude = *amplitude - (*amplitude / 10);` en une simple multiplication par `0.9f`. Il effectue toujours la division suivie de la soustraction, comme dans la version non optimisée.

Cela peut paraître surprenant, mais cette décision du compilateur est probablement liée aux problèmes de précision liés aux opérations en virgule flottante. En effet, une division par 10 suivie d’une soustraction peut donner un résultat légèrement différent d’une multiplication directe par `0.9f` à cause des arrondis introduits à chaque étape.

Comme le standard C impose que les optimisations ne doivent pas modifier le résultat visible d’un programme (sauf en présence d’`-ffast-math` ou autres options flottantes spécifiques), le compilateur joue la prudence et préserve l’ordre exact des opérations.

En applicant le flag `-ffast-math`, nous arrivons à faire le compilateur remplacer notre calcul par une multiplication:

```asm
        movss   xmm0, DWORD PTR .LC1[rip]
        mulss   xmm0, DWORD PTR [rdi]
        movss   DWORD PTR [rdi], xmm0
```

Une autre façon de forcer la simplification, est d’écrire directement `*amplitude *= 0.9f;` dans le code source.
Dans ce cas, le compilateur utilise bien une seule instruction `mulss`,
ce qui réduit les cycles CPU et améliore les performances sans risque de comportement inattendu -
du moment que l'erreur d'arrondi est tolérable dans le contexte de l'application.

== Optimisation des branchements

Source: #link("https://godbolt.org/z/h5dsM385W")[Godbolt - Optimisation des branchements]

La fonction `is_valid_frequency` détermine si la fréquence passé en paramère appartient à la plage des fréquences possibles pour le dtmf.

=== Version Originale

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
bool is_valid_frequency(uint32_t freq)
{
	return freq > MIN_FREQ && freq < MAX_FREQ;
}
```],[
```asm
        push    rbp
        mov     rbp, rsp
        mov     DWORD PTR [rbp-4], edi
        cmp     DWORD PTR [rbp-4], 650
        jbe     .L2
        cmp     DWORD PTR [rbp-4], 1499
        ja      .L2
        mov     eax, 1
        jmp     .L3
.L2:
        mov     eax, 0
.L3:
        and     eax, 1
        pop     rbp
        ret
```]
)

Dans cette version du code, nous observons que le compilateur fait usage de plusieurs instructions
de branchements conditionnels pour vérifier si la fréquence (`freq`) est supérieure à `MIN_FREQ` et
inférieure à `MAX_FREQ`. Comme discuté précedemment, éviter des branchements conditionnels,
améliore les performances, notamment en maintenant le pipeline du processeur plus fluide.

Nous pouvons remplacer ces vérifications conditionnelles par des opérations mathématiques.

=== Version Manuellement Optimisée

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
bool is_valid_frequency(uint32_t freq)
{
        return (freq - MIN_FREQ - 1) <= (MAX_FREQ - MIN_FREQ - 2);
}
```],[
```asm
        mov     eax, DWORD PTR [rbp-4]
        sub     eax, 651
        cmp     eax, 848
        setbe   al
```]
)

Avec cette optimisation, les branchements conditionnels sont supprimés, ce qui améliore les performances en évitant des sauts dans la pipeline du processeur. Le code devient plus rapide, notamment lorsque la fonction est appelée fréquemment. Cependant, cette approche rend le code moins lisible et plus difficile à comprendre, car la logique est condensée en une seule opération mathématique, ce qui peut déstabiliser un lecteur moins familier avec ces optimisations.

Pour cette raison, nous allons préférer la version originale, lisible et laisser le compilateur
faire le travail d'optimisations lui-même.

=== Version Originale - Optimisée par le compilateur (-O1)

#table(
columns: (.5fr, 1fr),
align:horizon,
[*Code C*],
[*Code Assembleur*],
[```c
bool is_valid_frequency(uint32_t freq)
{
	return freq > MIN_FREQ && freq < MAX_FREQ;
}
```],[
```asm
        sub     edi, 651
        cmp     edi, 848
        setbe   al
```]
)

Ce type d'optimisation est assez simple à réaliser pour le compilateur,
qui peut transformer une comparaison avec des bornes en une soustraction et une comparaison
plus simples. L’avantage de cette approche est qu'elle conserve un code lisible et clair,
tout en offrant de bonnes performances. C’est précisément ce pour quoi nous utilisons des
outils de compilation : pour maintenir un code propre et compréhensible sans sacrifier
l’efficacité d’exécution.


