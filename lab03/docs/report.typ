= Introduction

= Exemple 1 - return

== Version de base - Pas d'optimisations

Source: #link("https://godbolt.org/z/za7YdEab8")[Godbolt - Exemple Return]

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


= Exemple 2 - inline

#figure(image("media/inline.png"), caption: [Exemple Inline])

Source: #link("https://godbolt.org/z/oKTx3T1b3")[Godbolt - Inline Function]

= Exemple 3 - Outsmarting

#figure(image("media/outsmart1.png"), caption: [Exemple Outsmart 1])
#figure(image("media/outsmart2.png"), caption: [Exemple Outsmart 2])

Source: #link("https://godbolt.org/z/3KPqrW4sa")[Godbolt - Outsmarting]
