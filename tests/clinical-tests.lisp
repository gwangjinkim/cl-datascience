;;;; tests/clinical-tests.lisp - EXPERIMENT (branch experiment/guided-rules):
;;;; clinical examples, planned with guidance. The recommended analysis
;;;; comes first; the others stay available, ranked and labelled.

(in-package #:cl-datascience/tests)

(def-suite clinical :in :cl-datascience)
(in-suite clinical)

(defun clinical-plans (name knowledge question)
  (guided-plans name knowledge question :tier "clinical"))

(defun plan-summary (guided)
  "Category and steps of a guided plan, for readable expectations."
  (list (getf guided :category) (getf guided :plan)))

(defmacro guided-plans-are ((name knowledge question) &body expected)
  "Expected: (category step ...) per plan, in ranking order. Steps within
a plan are compared as a set."
  `(let ((actual (clinical-plans ,name ,knowledge ,question)))
     (is (and (= (length actual) ,(length expected))
              (every (lambda (got want)
                       (and (eq (getf got :category) (first want))
                            (plan-steps-equal (getf got :plan) (rest want))))
                     actual ',expected))
         "~a, knowing ~s, asked ~s:~%  expected ~s~%  got      ~s"
         ,name ,knowledge ,question ',expected (mapcar #'plan-summary actual))))

;;; 01 anorexia (MASS): weight before and after, three arms

(test anorexia-without-a-declared-baseline-compares-outcomes
  ;; Nothing says prewt is the baseline of postwt: a one-way analysis of
  ;; the outcome, with R's assumption of independent rows.
  (guided-plans-are ("01-anorexia" :plain :treatment-effect)
    (:acceptable (assume-rows-independent anorexia) (oneway-anova anorexia postwt treat))))

(test anorexia-trial-recommends-ancova-and-ranks-the-alternatives
  ;; ANCOVA first; the change score departs from "prefer ANCOVA" (cost 3);
  ;; ignoring the baseline departs from "adjust for baseline" (cost 5).
  (guided-plans-are ("01-anorexia" :trial :treatment-effect)
    (:recommended (ancova anorexia postwt treat prewt))
    (:discouraged (depart-prefer-ancova postwt) (change-score-anova anorexia postwt treat prewt))
    (:discouraged (depart-adjust-for-baseline postwt) (oneway-anova anorexia postwt treat))))

(test anorexia-trial-describes-baseline-and-discourages-testing-it
  (guided-plans-are ("01-anorexia" :trial :baseline-balance)
    (:recommended (baseline-table prewt treat))
    (:discouraged (depart-no-baseline-tests treat) (baseline-significance-test prewt treat))))

(test anorexia-departures-carry-their-sources
  (let* ((plans (clinical-plans "01-anorexia" :trial :treatment-effect))
         (sources (loop for p in plans
                        append (loop for d in (getf p :departures)
                                     append (getf d :sources))))
         (text (format nil "~{~a ~}" sources)))
    (is (search "Vickers" text))
    (is (search "EMA" text))))

(test anorexia-justified-change-score-is-a-justified-departure
  ;; e.g. a protocol that pre-specified change from baseline
  (let ((p (find-if (lambda (p) (find :change-score-anova (getf p :plan) :key #'first))
                    (clinical-plans "01-anorexia" :trial-change-prespecified :treatment-effect))))
    (is (eq :justified-departure (getf p :category)))))
