#columns(2, [
    #image("media/logo_heig-vd-2020.svg", width: 40%)
    #colbreak()
    #par(justify: false)[
        #align(right, [
            Département des Technologies de l'information et de la communication (TIC)
        ])
    ] 
    #v(1%)
    #par(justify:false)[
        #align(right, [
            Informatique et systèmes de communication
        ])
    ]
    #v(1%)
    #par(justify:false)[
        #align(right, [
            High Performance Coding
        ])
    ]
  ])
  
#v(20%)

#align(center, [#text(size: 14pt, [*HPC*])])
#v(4%)
#align(center, [#text(size: 20pt, [*Laboratoire 4*])])
#v(1%)
#align(center, [#text(size: 16pt, [*SIMD*])])

#v(8%)

#align(left, [#block(width: 70%, [
    #table(
      stroke: none,
      columns: (25%, 75%),
      [*Etudiant*], [André Costa],
      [*Professeur*], [Alberto Dassatti],
      [*Assistant*], [Bruno Da Rocha Carvalho],
      [*Année*], [2025]
    )
  ])])

#align(bottom + right, [
    Yverdon-les-Bains, #datetime.today().display("[day].[month].[year]")
  ])
