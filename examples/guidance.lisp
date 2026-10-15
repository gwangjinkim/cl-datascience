;;;; examples/guidance.lisp - EXPERIMENT (branch experiment/guided-rules)
;;;;
;;;; For every assumption (assume-...) and departure (depart-...) step of
;;;; the domains: its strength (the cost of taking the step), the rule in
;;;; words, and the sources of the rule. Read by src/guidance.lisp.
;;;; Strengths: assumptions 1; recommendations 3-9; principles 10 and
;;;; above (see *principle-strength*). The numbers are a first proposal.
;;;; Rules are paraphrased; sources are cited, not quoted.

;;; Assumptions

(assume-rows-independent
 :strength 1
 :rule "Rows are taken as independent observations (the default of R's t.test, lm and chisq.test)."
 :sources ("assumption of the method"))

(assume-random-process
 :strength 1
 :rule "The values are taken to arise by chance, not from a known pattern."
 :sources ("A.J. Rossini, examples/1d-analysis.lisp"))

(assume-constant-spread
 :strength 1
 :rule "The spread of the outcome around the trend is taken to be the same for all values of the predictor."
 :sources ("assumption of ordinary least squares inference"))

(assume-common-odds-ratio
 :strength 1
 :rule "The odds ratio is taken to be the same in every stratum."
 :sources ("assumption of the Mantel-Haenszel estimator"))

(assume-one-row-per-case
 :strength 1
 :rule "Each row is taken to be one case (no count column)."
 :sources ("default of R's data frames"))

;;; Departures from principles

(depart-design-consistency
 :strength 20
 :rule "A variable set by design or randomized, or measured before another, is not explained by that other variable; doing so reverses the design."
 :sources ("Fisher (1935), The Design of Experiments"
           "ICH E9 (1998), Statistical principles for clinical trials"))
