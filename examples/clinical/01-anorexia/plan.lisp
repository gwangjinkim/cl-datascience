;;;; examples/clinical/01-anorexia/plan.lisp - see src/examples.lisp

(:objects ((frame anorexia)
           (variable treat prewt postwt))

 :facts ((categorical treat)         ; Cont, CBT, FT
         (continuous prewt)          ; weight before, lb
         (continuous postwt))        ; weight after, lb

 :knowledge ((plain)
             ;; declared as a randomized trial with a baseline measurement
             ;; of the outcome (the R documentation does not say how
             ;; patients were allocated; this is the declaration to test)
             (trial (randomized treat)
                    (baseline-of> prewt postwt)
                    (measured-before> prewt treat)
                    (rows-independent anorexia))
             ;; the same, with change from baseline pre-specified in a protocol
             (trial-change-prespecified (randomized treat)
                                        (baseline-of> prewt postwt)
                                        (measured-before> prewt treat)
                                        (rows-independent anorexia)
                                        (justified depart-prefer-ancova)))

 :questions ((treatment-effect (estimated-treatment-effect> postwt treat))
             (baseline-balance (baseline-compared> prewt treat))))
