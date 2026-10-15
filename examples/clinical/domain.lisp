;;;; examples/clinical/domain.lisp - EXPERIMENT (branch experiment/guided-rules)
;;;;
;;;; Method actions for the clinical examples, in wouldwork syntax. Same
;;;; conventions as examples/stat101/domain.lisp (types frame, variable,
;;;; method; > marks directional relations; (used <action>) records each
;;;; step; product header for several same-type parameters).
;;;;
;;;; Guidance, not prohibition: a method that goes against a recommendation
;;;; is still possible, after a depart-... step. The step's strength, the
;;;; rule and its sources are in examples/guidance.lisp; guided-plans ranks
;;;; and labels the plans.

(define-dynamic-relations
  ;; what a variable is
  (categorical variable)
  (continuous variable)
  ;; design
  (randomized variable)
  (baseline-of> variable variable)          ; (baseline-of> b y): b is y measured at baseline
  (measured-before> variable variable)
  (rows-independent frame)
  ;; departures taken (EXPERIMENT)
  (baseline-adjustment-waived variable)
  (change-score-chosen variable)
  (baseline-testing-chosen variable)
  ;; answers
  (estimated-treatment-effect> variable variable)  ; (... outcome treatment)
  (baseline-compared> variable variable)            ; (... baseline treatment)
  ;; record
  (used method))

;;; Treatment effect on an outcome with a baseline measurement

(define-action ancova 1                        ; lm(y ~ b + g)
  (product ?f frame ?y variable ?g variable ?b variable)
  (and (continuous ?y) (categorical ?g) (baseline-of> ?b ?y) (rows-independent ?f)
       (not (estimated-treatment-effect> ?y ?g)))
  (?f ?y ?g ?b)
  (assert (estimated-treatment-effect> ?y ?g) (used ancova)))

(define-action change-score-anova 1            ; lm(y - b ~ g)
  (product ?f frame ?y variable ?g variable ?b variable)
  (and (continuous ?y) (categorical ?g) (baseline-of> ?b ?y) (rows-independent ?f)
       (change-score-chosen ?y)
       (not (estimated-treatment-effect> ?y ?g)))
  (?f ?y ?g ?b)
  (assert (estimated-treatment-effect> ?y ?g) (used change-score-anova)))

(define-action oneway-anova 1                  ; lm(y ~ g), baseline not used
  (product ?f frame ?y variable ?g variable)
  (and (continuous ?y) (categorical ?g) (rows-independent ?f)
       (or (not (exists (?b variable) (baseline-of> ?b ?y)))
           (baseline-adjustment-waived ?y))
       (not (estimated-treatment-effect> ?y ?g)))
  (?f ?y ?g)
  (assert (estimated-treatment-effect> ?y ?g) (used oneway-anova)))

;;; Comparability of the arms at baseline

(define-action baseline-table 1                ; describe the baseline by arm
  (product ?b variable ?g variable)
  (and (continuous ?b) (categorical ?g) (not (baseline-compared> ?b ?g)))
  (?b ?g)
  (assert (baseline-compared> ?b ?g) (used baseline-table)))

(define-action baseline-significance-test 1    ; anova(lm(b ~ g))
  (product ?b variable ?g variable)
  (and (continuous ?b) (categorical ?g)
       (or (not (randomized ?g)) (baseline-testing-chosen ?g))
       (not (baseline-compared> ?b ?g)))
  (?b ?g)
  (assert (baseline-compared> ?b ?g) (used baseline-significance-test)))

;;; Departures from recommendations

(define-action depart-adjust-for-baseline 1
  (?y variable)
  (and (exists (?b variable) (baseline-of> ?b ?y))
       (not (baseline-adjustment-waived ?y)))
  (?y)
  (assert (baseline-adjustment-waived ?y) (used depart-adjust-for-baseline)))

(define-action depart-prefer-ancova 1
  (?y variable)
  (and (exists (?b variable) (baseline-of> ?b ?y))
       (not (change-score-chosen ?y)))
  (?y)
  (assert (change-score-chosen ?y) (used depart-prefer-ancova)))

(define-action depart-no-baseline-tests 1
  (?g variable)
  (and (randomized ?g) (not (baseline-testing-chosen ?g)))
  (?g)
  (assert (baseline-testing-chosen ?g) (used depart-no-baseline-tests)))

;;; Assumptions

(define-action assume-rows-independent 1
  (?f frame)
  (not (rows-independent ?f))
  (?f)
  (assert (rows-independent ?f) (used assume-rows-independent)))
