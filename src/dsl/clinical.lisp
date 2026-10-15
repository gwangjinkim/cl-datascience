;;;; src/dsl/clinical.lisp - EXPERIMENT (branch experiment/guided-rules)
;;;;
;;;; The clinical rule book: the common core plus rules from clinical
;;;; statistics (docs/CLINICAL-RULES.md, rules C1-C10). A statframe declared
;;;; with DECLARE-TRIAL uses it. Nothing here forbids an analysis: methods
;;;; that go against a rule need a departure step, which carries the rule's
;;;; strength, statement and sources.

(in-package #:cl-datascience)

(define-rule-book clinical
  :includes (general)
  :documentation "Randomised clinical trials: baseline and stratification
adjustment, within-group fallacies, baseline tests, subgroups, equivalence,
dichotomisation, time-to-event outcomes.")

;;; Facts

(define-relation clinical randomized variable)
(define-relation clinical baseline-of> variable variable)           ; (baseline-of> b y)
(define-relation clinical stratified-by> frame variable variable)   ; (stratified-by> f arm s)
(define-relation clinical time-to-event variable)
(define-relation clinical event-of> variable variable)              ; (event-of> event time)
(define-relation clinical noninformative-censoring variable)
(define-relation clinical proportional-hazards> variable variable)
(define-relation clinical nonproportional-hazards> variable variable)  ; observed by a check
(define-relation clinical dichotomized-from> variable variable)     ; (dichotomized-from> v c)
(define-relation clinical equivalence-margin> variable variable)
(define-relation clinical prespecified variable)
;; departures taken and labels given
(define-relation clinical baseline-adjustment-waived variable)
(define-relation clinical stratification-waived variable)
(define-relation clinical unadjusted-change-chosen variable)
(define-relation clinical within-group-chosen variable)
(define-relation clinical baseline-testing-chosen variable)
(define-relation clinical absence-of-evidence-chosen> variable variable)
(define-relation clinical dichotomisation-waived variable)
(define-relation clinical censoring-ignored variable)
(define-relation clinical separate-subgroups-chosen variable)
(define-relation clinical exploratory-labelled variable)
;; answers
(define-relation clinical baseline-compared> variable variable)
(define-relation clinical equivalence-shown> variable variable)
(define-relation clinical survival-difference> variable variable)
(define-relation clinical effect-modification> variable variable variable)

;;; C1, C3: the common core's mean comparisons must adjust for the baseline
;;; value of the outcome and for the stratification factors, or depart.

(define-requirement clinical adjust-for-baseline
  :answers mean-difference>
  :requires ((or (not (exists (?b variable) (baseline-of> ?b ?y)))
                 (baseline-adjustment-waived ?y)))
  :sources ("EMA (2015), Guideline on adjustment for baseline covariates in clinical trials, EMA/CHMP/295050/2013, section 5.6"))

(define-requirement clinical adjust-for-strata
  :answers mean-difference>
  :requires ((or (not (exists (?s variable) (stratified-by> ?f ?g ?s)))
                 (stratification-waived ?g)))
  :sources ("EMA (2015), EMA/CHMP/295050/2013, sections 5.2, 5.3"))

;;; C9: tests on a dichotomised variable need a departure

(define-requirement clinical continuous-not-dichotomised
  :answers association>
  :requires ((or (not (exists (?c variable) (dichotomized-from> ?a ?c))) (dichotomisation-waived ?a))
             (or (not (exists (?c variable) (dichotomized-from> ?b ?c))) (dichotomisation-waived ?b)))
  :sources ("Altman and Royston (2006), BMJ 332:1080"))

;;; Assumptions and caveats

(define-assumption clinical assume-noninformative-censoring
  :parameters (?t variable)
  :requires ((time-to-event ?t))
  :asserts (noninformative-censoring ?t)
  :statement "Patients whose follow-up ends before the event are taken to have the same prospects as those still followed (non-informative censoring)."
  :sources ("Bland and Altman (1998), BMJ 317:1572"))

(define-assumption clinical assume-proportional-hazards
  :parameters (?t variable ?g variable)
  :requires ((time-to-event ?t) (categorical ?g))
  :asserts (proportional-hazards> ?t ?g)
  :unless-known ((nonproportional-hazards> ?t ?g))
  :statement "The hazard ratio between the groups is taken to be constant over time (Cox model)."
  :sources ("Cox (1972), Journal of the Royal Statistical Society B 34:187"
            "Grambsch and Therneau (1994), Biometrika 81:515"))

(define-caveat clinical label-exploratory
  :parameters (?s variable)
  :requires ((categorical ?s) (not (prespecified ?s)))
  :asserts (exploratory-labelled ?s)
  :strength 2
  :statement "The subgroup analysis was not pre-specified: report it as exploratory, needing confirmation."
  :sources ("Moher et al. (2010), CONSORT 2010 explanation and elaboration, BMJ 340:c869, items 12b and 18"
            "EMA (2015), EMA/CHMP/295050/2013, section 6.1"))

;;; Departures

(define-departure clinical depart-baseline-adjustment
  :parameters (?y variable)
  :requires ((exists (?b variable) (baseline-of> ?b ?y)))
  :asserts (baseline-adjustment-waived ?y)
  :strength 5
  :statement "The baseline value of the outcome is available but not adjusted for; adjusting (analysis of covariance) is more precise and protects against chance imbalance."
  :sources ("EMA (2015), Guideline on adjustment for baseline covariates in clinical trials, EMA/CHMP/295050/2013, section 5.6"
            "Vickers and Altman (2001), BMJ 323:1123"))

(define-departure clinical depart-stratification
  :parameters (?f frame ?g variable)
  :requires ((exists (?s variable) (stratified-by> ?f ?g ?s)))
  :asserts (stratification-waived ?g)
  :strength 5
  :statement "The randomisation was stratified, but the analysis ignores the stratification factors; they should normally be in the primary model."
  :sources ("EMA (2015), EMA/CHMP/295050/2013, sections 5.2, 5.3"
            "Moher et al. (2010), CONSORT 2010 explanation and elaboration, BMJ 340:c869, item 12b"))

(define-departure clinical depart-unadjusted-change
  :parameters (?y variable)
  :requires ((exists (?b variable) (baseline-of> ?b ?y)))
  :asserts (unadjusted-change-chosen ?y)
  :strength 3
  :statement "Change from baseline without adjustment for the baseline is less precise than analysis of covariance; with adjustment both give the same treatment effect."
  :sources ("Vickers and Altman (2001), BMJ 323:1123"
            "EMA (2015), EMA/CHMP/295050/2013, section 5.6"))

(define-departure clinical depart-within-group-comparison
  :parameters (?g variable)
  :requires ((randomized ?g))
  :asserts (within-group-chosen ?g)
  :strength 20
  :statement "Testing the change from baseline separately in each randomised group and comparing the verdicts is invalid: with no difference between treatments the false-positive rate can reach 0.50 with two groups and 0.75 with three. Compare the groups directly."
  :sources ("Bland and Altman (2011), Trials 12:264"))

(define-departure clinical depart-baseline-testing
  :parameters (?g variable)
  :requires ((randomized ?g))
  :asserts (baseline-testing-chosen ?g)
  :strength 5
  :statement "Significance tests of baseline differences between randomised groups test a hypothesis known to be true; describe the baseline instead, and do not choose covariates from such tests."
  :sources ("Moher et al. (2010), CONSORT 2010 explanation and elaboration, BMJ 340:c869, items 12b and 15"
            "Bland and Altman (2011), Trials 12:264"
            "EMA (2015), EMA/CHMP/295050/2013, section 5.4"))

(define-departure clinical depart-absence-of-evidence
  :parameters (?y variable ?g variable)
  :asserts (absence-of-evidence-chosen> ?y ?g)
  :strength 20
  :statement "A non-significant test of difference is not evidence of no difference; equivalence needs a pre-specified margin and an interval within it."
  :sources ("Altman and Bland (1995), BMJ 311:485"))

(define-departure clinical depart-dichotomisation
  :parameters (?v variable)
  :requires ((exists (?c variable) (dichotomized-from> ?v ?c)))
  :asserts (dichotomisation-waived ?v)
  :strength 5
  :statement "The variable was made by cutting a continuous measurement in two; this loses information and power and depends on the cut-point. Analyse the continuous measurement."
  :sources ("Altman and Royston (2006), BMJ 332:1080"))

(define-departure clinical depart-ignore-censoring
  :parameters (?t variable)
  :requires ((time-to-event ?t))
  :asserts (censoring-ignored ?t)
  :strength 20
  :statement "Treating censored follow-up times as event times biases the comparison; use survival methods (Kaplan-Meier, log-rank, Cox)."
  :sources ("Bland and Altman (1998), BMJ 317:1572" "Bland and Altman (2004), BMJ 328:1073"))

(define-departure clinical depart-separate-subgroups
  :parameters (?s variable)
  :requires ((categorical ?s))
  :asserts (separate-subgroups-chosen ?s)
  :strength 15
  :statement "A significant effect in one subgroup and a non-significant one in another does not show that the effect differs; test the interaction."
  :sources ("Altman and Bland (2003), BMJ 326:219"
            "Moher et al. (2010), CONSORT 2010 explanation and elaboration, BMJ 340:c869, item 12b"))

;;; C1, C2, C4: treatment effect with a baseline measurement

(define-method clinical adjusted-regression
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (categorical ?g) (rows-independent ?f)
             (or (exists (?b variable) (baseline-of> ?b ?y))
                 (exists (?s variable) (stratified-by> ?f ?g ?s)))
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g)))
  :answers ((mean-difference> ?y ?g))
  :r-code "lm({y} ~ {g} + {covariates}, data = data)"
  :sources ("EMA (2015), EMA/CHMP/295050/2013, sections 5.2, 5.6"
            "Vickers and Altman (2001), BMJ 323:1123"))

(define-method clinical change-score-test
  :parameters (?f frame ?y variable ?g variable ?b variable)
  :requires ((numeric ?y) (categorical ?g) (baseline-of> ?b ?y) (rows-independent ?f)
             (unadjusted-change-chosen ?y)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g)))
  :answers ((mean-difference> ?y ?g))
  :r-code "lm(I({y} - {b}) ~ {g}, data = data)"
  :sources ("Vickers and Altman (2001), BMJ 323:1123"))

(define-method clinical within-group-tests
  :parameters (?f frame ?y variable ?g variable ?b variable)
  :requires ((numeric ?y) (categorical ?g) (baseline-of> ?b ?y) (within-group-chosen ?g))
  :answers ((mean-difference> ?y ?g))
  :r-code "by(data, data${g}, function(d) t.test(d${y}, d${b}, paired = TRUE))"
  :sources ("Bland and Altman (2011), Trials 12:264"))

;;; C5: baseline balance

(define-method clinical baseline-table
  :parameters (?b variable ?g variable)
  :requires ((categorical ?g) (not (eql ?b ?g)))
  :answers ((baseline-compared> ?b ?g))
  :r-code "aggregate({b} ~ {g}, data = data, FUN = function(x) c(mean = mean(x), sd = sd(x)))"
  :sources ("Moher et al. (2010), CONSORT 2010 explanation and elaboration, BMJ 340:c869, item 15"))

(define-method clinical baseline-significance-test
  :parameters (?b variable ?g variable)
  :requires ((numeric ?b) (categorical ?g)
             (or (not (randomized ?g)) (baseline-testing-chosen ?g)))
  :answers ((baseline-compared> ?b ?g))
  :r-code "anova(lm({b} ~ {g}, data = data))"
  :sources ("Bland and Altman (2011), Trials 12:264"))

;;; C8: equivalence

(define-method clinical equivalence-test
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (two-levels ?g) (rows-independent ?f) (equivalence-margin> ?y ?g)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g)))
  :answers ((equivalence-shown> ?y ?g))
  :r-code "t.test({y} ~ {g}, data = data, conf.level = 0.90)  # equivalent if the 90% interval lies within the margin"
  :sources ("Schuirmann (1987), Journal of Pharmacokinetics and Biopharmaceutics 15:657"
            "Altman and Bland (1995), BMJ 311:485"))

(define-method clinical nonsignificant-test-as-equivalence
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (categorical ?g) (absence-of-evidence-chosen> ?y ?g))
  :answers ((equivalence-shown> ?y ?g))
  :r-code "t.test({y} ~ {g}, data = data)  # p > 0.05 read as 'no difference'"
  :sources ("Altman and Bland (1995), BMJ 311:485"))

;;; C10: time to event

(define-method clinical log-rank-test
  :parameters (?f frame ?t variable ?g variable ?e variable)
  :requires ((time-to-event ?t) (event-of> ?e ?t) (categorical ?g) (rows-independent ?f)
             (noninformative-censoring ?t))
  :answers ((survival-difference> ?t ?g))
  :r-code "survdiff(Surv({t}, {e}) ~ {g}, data = data)"
  :sources ("Bland and Altman (2004), BMJ 328:1073"))

(define-method clinical cox-regression
  :parameters (?f frame ?t variable ?g variable ?e variable)
  :requires ((time-to-event ?t) (event-of> ?e ?t) (categorical ?g) (rows-independent ?f)
             (noninformative-censoring ?t) (proportional-hazards> ?t ?g))
  :answers ((survival-difference> ?t ?g))
  :r-code "coxph(Surv({t}, {e}) ~ {g}, data = data)"
  :sources ("Cox (1972), Journal of the Royal Statistical Society B 34:187"))

(define-method clinical time-comparison-ignoring-censoring
  :parameters (?f frame ?t variable ?g variable)
  :requires ((time-to-event ?t) (categorical ?g) (censoring-ignored ?t))
  :answers ((survival-difference> ?t ?g))
  :r-code "oneway.test({t} ~ {g}, data = data)  # censored times treated as event times"
  :sources ("Bland and Altman (1998), BMJ 317:1572"))

;;; C6, C7: subgroups

(define-method clinical interaction-test
  :parameters (?f frame ?y variable ?g variable ?s variable)
  :requires ((numeric ?y) (not (time-to-event ?y)) (categorical ?g) (categorical ?s)
             (not (eql ?g ?s)) (rows-independent ?f)
             (or (prespecified ?s) (exploratory-labelled ?s)))
  :answers ((effect-modification> ?y ?g ?s))
  :r-code "anova(lm({y} ~ {g} + {s}, data = data), lm({y} ~ {g} * {s}, data = data))"
  :sources ("Altman and Bland (2003), BMJ 326:219"))

(define-method clinical cox-interaction-test
  :parameters (?f frame ?t variable ?g variable ?s variable ?e variable)
  :requires ((time-to-event ?t) (event-of> ?e ?t) (categorical ?g) (categorical ?s)
             (not (eql ?g ?s)) (rows-independent ?f) (noninformative-censoring ?t)
             (proportional-hazards> ?t ?g)
             (or (prespecified ?s) (exploratory-labelled ?s)))
  :answers ((effect-modification> ?t ?g ?s))
  :r-code "anova(coxph(Surv({t}, {e}) ~ {g} + {s}, data = data), coxph(Surv({t}, {e}) ~ {g} * {s}, data = data))"
  :sources ("Altman and Bland (2003), BMJ 326:219" "Cox (1972), Journal of the Royal Statistical Society B 34:187"))

(define-method clinical separate-subgroup-tests
  :parameters (?f frame ?y variable ?g variable ?s variable)
  :requires ((categorical ?g) (categorical ?s) (not (eql ?g ?s)) (separate-subgroups-chosen ?s))
  :answers ((effect-modification> ?y ?g ?s))
  :r-code "the test of {g} repeated within each level of {s}"
  :sources ("Altman and Bland (2003), BMJ 326:219"))
