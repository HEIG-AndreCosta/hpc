
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
TODO Parler que c'est du code standard vu quand les gens commencent à programmer cf cours de prg1 et prg2

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

TODO Parler du code qui devient beaucoup plus clair, et qu'évite une instruction de branchement ce qui permet à la pipeline du processeur de ne pas se casser la figure

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

TODO parler que la version optimisé suit la même logique que celle de la version manuellement optimisé où le compilateur évite des branchements inutiles

TODO trouver le flag gcc qui permet d'ajouter cette optimisation


= Exemple 2 - inline

#figure(image("media/inline.png"), caption: [Exemple Inline])

Source: #link("https://godbolt.org/z/oKTx3T1b3")[Godbolt - Inline Function]

= Exemple 3 - Outsmarting

#figure(image("media/outsmart1.png"), caption: [Exemple Outsmart 1])
#figure(image("media/outsmart2.png"), caption: [Exemple Outsmart 2])

Source: #link("https://godbolt.org/z/3KPqrW4sa")[Godbolt - Outsmarting]
