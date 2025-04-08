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

Ce code est typique de ce que l’on retrouve dans les premiers cours de programmation (PRG1 et PRG2).
On y voit une structure conditionnelle simple avec un `if/else` explicite.
Le compilateur traduit ça littéralement avec des instructions de branchement (`jle`, `jmp`),
ce qui est très lisible, mais pas encore optimisé.


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
Ces flags indiquent au compilateur de générer du code plus efficace, avec des optimisations comme
la suppression des branchements inutiles, l'inlining de fonctions, etc.


= Exemple 2 - Outsmarting

Source: #link("https://godbolt.org/z/97b7h9qoc")[Godbolt - Outsmarting]

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

Contrairement à ce que l'on pourrait penser, même avec les options `-O1` et `-fstrict-aliasing`,
le compilateur ne comprend pas que la valeur de `*flag` reste constante pendant l'exécution de
la boucle. Il continue donc à vérifier `*flag` à chaque itération. Autrement dit,
l'optimisation attendue — déplacer la vérification de `*flag` en dehors de la boucle —
n'est pas appliquée automatiquement ici, malgré les indices donnés au compilateur. Cela montre que, dans ce cas, une optimisation manuelle reste nécessaire pour éliminer les vérifications redondantes.

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

Grâce à l’optimisation manuelle combinée à l’optimisation du compilateur, celui-ci peut appliquer des transformations plus agressives. Il supprime toute vérification de `*flag` ou de `i < n` dans le corps de boucle et transforme le tout en un simple parcours de mémoire avec décalage (`sal`). Ce type de code est *beaucoup plus efficace* car il élimine des instructions inutiles et réduit la charge de travail du processeur lors de l’exécution.


= Exemple 3 - Predictive Commoning 

Source: #link("https://godbolt.org/z/8W4njcE7W")[Godbolt - Inline Function]
