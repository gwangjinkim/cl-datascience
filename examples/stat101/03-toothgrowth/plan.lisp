;;;; examples/stat101/03-toothgrowth/plan.lisp - see src/examples.lisp

(:objects ((frame toothgrowth)
           (variable len supp dose))

 :facts ((continuous len)            ; odontoblast length
         (two-levels supp)           ; OJ or VC
         (continuous dose))          ; 0.5, 1, 2 mg/day, stored as numbers

 :knowledge ((plain)
             ;; How the columns came about. Partial: how animals were
             ;; assigned to the six groups is not documented.
             (design (set-by-design supp)
                     (set-by-design dose)
                     (observed len)
                     (measured-before> supp len)
                     (measured-before> dose len)
                     (rows-independent toothgrowth))    ; one animal per row
             ;; EXPERIMENT: the same, with a declared justification for
             ;; departing from design consistency (read by src/guidance.lisp)
             (design-justified (set-by-design supp)
                               (set-by-design dose)
                               (observed len)
                               (measured-before> supp len)
                               (measured-before> dose len)
                               (rows-independent toothgrowth)
                               (justified depart-design-consistency)))

 :questions ((effects (and (explained-by-design> len supp)
                           (explained-by-design> len dose)))
             (dose-from-len (estimated-trend> dose len))
             (predict-dose (predicted-from> dose len))))
