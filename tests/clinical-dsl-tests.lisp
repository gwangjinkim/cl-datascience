;;;; tests/clinical-dsl-tests.lisp - EXPERIMENT (branch experiment/guided-rules):
;;;; the clinical rule book (docs/CLINICAL-RULES.md, rules C1-C10) in the
;;;; CLOS DSL. A statframe declared as a trial uses the clinical book.

(in-package #:cl-datascience/tests)

(def-suite clinical-dsl :in :cl-datascience)
(in-suite clinical-dsl)

(defun colon-data () (example-csv "clinical" "02-colon"))

(defun anorexia-trial ()
  (cl-dplyr:-> (anorexia-data)
               (declare-trial :arm :treat)
               (declare-baseline :of :postwt :baseline :prewt)))

(defun colon-trial ()
  (cl-dplyr:-> (colon-data)
               (declare-trial :arm :rx)
               (declare-survival :time :time :event :status)))

(defun column-list (data name)
  (cl-vctrs-lite:col->list (cl-tibble:tbl-col data name)))

(defun anorexia-two-arms ()
  "CBT and control only."
  (let* ((d (anorexia-data))
         (rows (loop for arm in (column-list d "Treat") for i from 0
                     when (member arm '("CBT" "Cont") :test #'string=) collect i)))
    (cl-tibble:make-tbl
     (list (cons "Treat" (coerce (mapcar (lambda (i) (nth i (column-list d "Treat"))) rows) 'vector))
           (cons "Postwt" (coerce (mapcar (lambda (i) (nth i (column-list d "Postwt"))) rows) 'vector))))))

(defun anorexia-gained ()
  "Treatment and a dichotomised outcome: weight gained yes or no."
  (let ((d (anorexia-data)))
    (cl-tibble:make-tbl
     (list (cons "Treat" (coerce (column-list d "Treat") 'vector))
           (cons "gained" (coerce (mapcar (lambda (post pre) (if (> post pre) "yes" "no"))
                                          (column-list d "Postwt") (column-list d "Prewt"))
                                  'vector))))))

(defun stratified-trial ()
  "Two arms, randomisation stratified by site."
  (cl-tibble:make-tbl
   (list (cons "y" (coerce (loop for i below 36 collect (float (mod (* i 5) 13) 1d0)) 'vector))
         (cons "arm" (coerce (loop for i below 36 collect (if (evenp i) "A" "B")) 'vector))
         (cons "site" (coerce (loop for i below 36 collect (nth (mod i 3) '("s1" "s2" "s3"))) 'vector)))))

(defun plan-with (method result)
  "The guided plan of RESULT that uses METHOD."
  (find-if (lambda (p) (find method (steps-of p) :key #'first)) (result-plans result)))

(defun departure-sources (plan)
  (format nil "~{~a ~}" (loop for d in (getf plan :departures) append (getf d :sources))))

;;; Rule books

(test clinical-book-includes-the-common-core
  (let ((book (find-rule-book :clinical)))
    (is (find :welch-t-test (book-rules book) :key #'rule-name))
    (is (find :log-rank-test (book-rules book) :key #'rule-name))
    (dolist (rule (book-rules book))
      (when (typep rule '(or assumption-rule departure-rule))
        (is (and (realp (rule-strength rule)) (stringp (rule-statement rule)) (rule-sources rule))
            "~a is incomplete" (rule-name rule))))))

(test a-declared-trial-uses-the-clinical-book
  (is (eq :clinical (data-rule-book (anorexia-trial))))
  (is (eq :common-core (data-rule-book (anorexia-data)))))

;;; C1, C2, C4: baseline

(test c1-trial-with-baseline-recommends-adjusted-regression
  (let* ((result (compare (anorexia-trial) :postwt :by :treat))
         (best (best result)))
    (is (plan-steps-equal (steps-of best)
                          '((assume-normality postwt treat) (adjusted-regression data postwt treat))))
    (is (eq :acceptable (getf best :category)))
    ;; ignoring the baseline stays possible, labelled
    (let ((welch (plan-with :welch-anova result)))
      (is (eq :discouraged (getf welch :category)))
      (is (search "EMA" (departure-sources welch))))))

(test c2-unadjusted-change-score-is-discouraged
  (let ((change (plan-with :change-score-test (compare (anorexia-trial) :postwt :by :treat))))
    (is (eq :discouraged (getf change :category)))
    (is (search "Vickers" (departure-sources change)))))

(test c4-within-group-tests-are-against-guidance
  (let ((within (plan-with :within-group-tests (compare (anorexia-trial) :postwt :by :treat))))
    (is (eq :against-guidance (getf within :category)))
    (is (search "Bland and Altman (2011)" (departure-sources within)))))

;;; C5: baseline balance

(test c5-baseline-is-described-not-tested
  (let ((result (compare (anorexia-trial) :prewt :by :treat :aim :baseline-balance)))
    (is (plan-steps-equal (steps-of (best result)) '((baseline-table prewt treat))))
    (is (eq :recommended (getf (best result) :category)))
    (is (eq :discouraged (getf (plan-with :baseline-significance-test result) :category)))))

;;; C3: stratified randomisation

(test c3-stratification-factors-belong-in-the-model
  (let* ((trial (declare-trial (stratified-trial) :arm :arm :stratified-by :site))
         (result (compare trial :y :by :arm)))
    (is (find :adjusted-regression (steps-of (best result)) :key #'first))
    (let ((welch (plan-with :welch-t-test result)))
      (is (eq :discouraged (getf welch :category)))
      (is (find :depart-stratification (steps-of welch) :key #'first)))))

;;; C8: equivalence

(test c8-equivalence-needs-a-margin-and-an-equivalence-test
  (let* ((trial (declare-trial (anorexia-two-arms) :arm :treat))
         (with-margin (declare-margin trial :outcome :postwt :by :treat :margin 2))
         (best (best (compare with-margin :postwt :by :treat :aim :equivalence))))
    (is (find :equivalence-test (steps-of best) :key #'first))
    (is (eq :acceptable (getf best :category)))
    ;; without a margin, the only plan reads a non-significant test as
    ;; equivalence - offered, against guidance
    (let ((only (best (compare trial :postwt :by :treat :aim :equivalence))))
      (is (find :nonsignificant-test-as-equivalence (steps-of only) :key #'first))
      (is (eq :against-guidance (getf only :category)))
      (is (search "Altman and Bland (1995)" (departure-sources only))))))

;;; C9: dichotomisation

(test c9-a-dichotomised-outcome-is-discouraged
  (let* ((trial (cl-dplyr:-> (anorexia-gained)
                             (declare-trial :arm :treat)
                             (declare-dichotomized :gained :from :postwt)))
         (best (best (associate trial :gained :treat))))
    (is (eq :discouraged (getf best :category)))
    (is (find :depart-dichotomisation (steps-of best) :key #'first))
    (is (search "Royston" (departure-sources best)))))

;;; C10: survival

(test c10-survival-is-compared-with-censoring
  (let ((result (compare (colon-trial) :time :by :rx)))
    (is (plan-steps-equal (steps-of (best result))
                          '((assume-noninformative-censoring time) (log-rank-test data time rx status))))
    (is (plan-with :cox-regression result))
    (let ((naive (plan-with :time-comparison-ignoring-censoring result)))
      (is (eq :against-guidance (getf naive :category))))))

;;; C6, C7: subgroups

(test c6-c7-subgroups-by-interaction-labelled-exploratory-unless-prespecified
  (let* ((result (compare (colon-trial) :time :by :rx :within :sex :aim :effect-modification))
         (best (best result)))
    (is (find :cox-interaction-test (steps-of best) :key #'first))
    (is (find :label-exploratory (steps-of best) :key #'first))
    (is (search "note: The subgroup analysis was not pre-specified" (princ-to-string result)))
    (is (eq :against-guidance
            (getf (plan-with :separate-subgroup-tests result) :category)))
    (let ((prespecified (best (compare (declare-prespecified (colon-trial) :sex)
                                       :time :by :rx :within :sex :aim :effect-modification))))
      (is (not (find :label-exploratory (steps-of prespecified) :key #'first))))))

;;; Relevance: only rules that can contribute to the goal are planned

(test only-relevant-rules-are-compiled-for-a-goal
  ;; A baseline-balance question needs the baseline methods and their
  ;; departure, not the subgroup, censoring or equivalence rules.
  (let* ((domain (uiop:read-file-string
                  (compile-rule-book :clinical :goal '(:baseline-compared> :prewt :treat)))))
    (is (search "baseline-significance-test" domain))
    (is (search "depart-baseline-testing" domain))
    (is (not (search "depart-separate-subgroups" domain)))
    (is (not (search "log-rank-test" domain)))
    (is (not (search "welch-t-test" domain)))))
