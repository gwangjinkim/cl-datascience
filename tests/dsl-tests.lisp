;;;; tests/dsl-tests.lisp - EXPERIMENT (branch experiment/guided-rules):
;;;; the CLOS DSL on tibbles from the Common Lisp tidyverse.
;;;;
;;;; Rules are CLOS objects in a rule book (the common core of the R
;;;; packages that choose tests, docs/PRIOR-ART-R.md); question verbs are
;;;; generic functions on tibbles and statframes; answers are ranked,
;;;; labelled plans.

(in-package #:cl-datascience/tests)

(def-suite dsl :in :cl-datascience)
(in-suite dsl)

(defun example-csv (tier name)
  (cl-readr:read-csv
   (namestring (asdf:system-relative-pathname
                :cl-datascience (format nil "examples/~a/~a/data.csv" tier name)))))

(defun sleep-data () (example-csv "stat101" "01-sleep"))
(defun anorexia-data () (example-csv "clinical" "01-anorexia"))

(defun two-groups (n)
  "A tibble with N values in each of two groups."
  (cl-tibble:make-tbl
   (list (cons "y" (coerce (loop for i below (* 2 n) collect (float (mod (* i 7) 11) 1d0)) 'vector))
         (cons "g" (coerce (loop for i below (* 2 n) collect (if (< i n) "a" "b")) 'vector)))))

(defun small-table ()
  "Two categorical variables with small expected counts (a 2x2 table, n = 12)."
  (cl-tibble:make-tbl
   (list (cons "treated" (coerce '("yes" "yes" "yes" "yes" "yes" "yes" "no" "no" "no" "no" "no" "no") 'vector))
         (cons "cured" (coerce '("yes" "yes" "yes" "yes" "yes" "no" "no" "no" "no" "no" "no" "yes") 'vector)))))

(defun steps-of (guided) (getf guided :plan))

(defun best (result) (first (result-plans result)))

;;; Rules are objects

(test common-core-rule-book-is-complete
  ;; every assumption and departure says how strong it is, what it states,
  ;; and where the rule comes from
  (let ((book (find-rule-book :common-core)))
    (is (typep book 'rule-book))
    (dolist (rule (book-rules book))
      (when (typep rule '(or assumption-rule departure-rule))
        (is (and (realp (rule-strength rule)) (stringp (rule-statement rule)) (rule-sources rule))
            "~a is incomplete" (rule-name rule))))
    (is (find :welch-t-test (book-rules book) :key #'rule-name))))

;;; Facts come from the tibble and the question

(test facts-are-inferred-from-the-tibble-and-the-roles
  (let ((facts (question-facts (make-comparison (sleep-data) :extra :by :group))))
    (is (member '(:numeric :extra) facts :test #'equal))
    (is (member '(:two-levels :group) facts :test #'equal))
    (is (not (member '(:large-groups> :extra :group) facts :test #'equal)))))

(test large-groups-are-recognised
  (is (member '(:large-groups> :y :g)
              (question-facts (make-comparison (two-groups 40) :y :by :g)) :test #'equal)))

(test low-expected-counts-are-recognised
  ;; Cochran's rule: expected counts of 3 in a 2x2 table with n = 12
  (is (member '(:low-expected-counts> :treated :cured)
              (question-facts (make-association (small-table) :treated :cured)) :test #'equal)))

;;; compare: a generic function on tibbles

(test plain-tibble-gets-welch-with-its-assumptions-named
  ;; No gate on the same data: Welch by default (Delacre et al.), its
  ;; assumptions as plan steps; Student's t needs one assumption more.
  (let ((result (compare (sleep-data) :extra :by :group)))
    (is (typep result 'analysis-result))
    (is (plan-steps-equal (steps-of (best result))
                          '((assume-rows-independent data) (assume-normality extra group)
                            (welch-t-test data extra group))))
    (is (eq :acceptable (getf (best result) :category)))
    (is (find :student-t-test (result-plans result)
              :key (lambda (p) (first (car (last (steps-of p)))))))))

(test location-estimand-asks-a-different-question
  (let ((result (compare (sleep-data) :extra :by :group :estimand :location)))
    (is (plan-steps-equal (steps-of (best result))
                          '((assume-rows-independent data) (wilcoxon-rank-sum data extra group))))))

(test declared-pairing-dispatches-to-paired-methods
  ;; DECLARE-PAIRED returns a statframe; COMPARE dispatches on it
  (let* ((frame (declare-paired (sleep-data) :id :id :within :group))
         (result (compare frame :extra :by :group)))
    (is (typep frame 'statframe))
    (is (typep frame 'cl-tibble:tbl))
    (is (plan-steps-equal (steps-of (best result))
                          '((assume-normality extra group) (paired-t-test data extra group id))))
    (is (plan-steps-equal (steps-of (best (compare frame :extra :by :group :estimand :location)))
                          '((signed-rank-test data extra group id))))))

(test large-groups-need-no-normality-assumption
  (is (plan-steps-equal (steps-of (best (compare (two-groups 40) :y :by :g)))
                        '((assume-rows-independent data) (welch-t-test data y g)))))

(test three-groups-get-welch-anova
  (let ((result (compare (anorexia-data) :postwt :by :treat)))
    (is (plan-steps-equal (steps-of (best result))
                          '((assume-rows-independent data) (assume-normality postwt treat)
                            (welch-anova data postwt treat))))))

(test observed-non-normality-makes-mean-tests-discouraged-not-forbidden
  (let* ((frame (declare-observed (sleep-data) '(:nonnormal-residuals> :extra :group)))
         (best (best (compare frame :extra :by :group))))
    (is (eq :discouraged (getf best :category)))
    (is (find :depart-normality (steps-of best) :key #'first))
    (is (search "Fagerland" (format nil "~{~a ~}" (getf (first (getf best :departures)) :sources))))))

;;; associate: two categorical variables

(test small-expected-counts-recommend-fisher-and-discourage-chi-square
  (let* ((result (associate (small-table) :treated :cured))
         (plans (result-plans result)))
    (is (find :fisher-exact-test (steps-of (best result)) :key #'first))
    (let ((chi (find-if (lambda (p) (find :chi-square-test (steps-of p) :key #'first)) plans)))
      (is (eq :discouraged (getf chi :category)))
      (is (search "Cochran" (format nil "~{~a ~}" (getf (first (getf chi :departures)) :sources)))))))

;;; Results read like a short report

(test results-print-the-plan-and-the-alternatives
  (let ((text (princ-to-string (compare (sleep-data) :extra :by :group))))
    (is (search "welch-t-test" text))
    (is (search "student-t-test" text))
    (is (search "t.test(extra ~ group" text))))

(test verbs-work-in-a-tidyverse-pipeline
  (let ((result (cl-dplyr:-> (sleep-data)
                             (declare-paired :id :id :within :group)
                             (compare :extra :by :group))))
    (is (find :paired-t-test (steps-of (best result)) :key #'first))))

(test clds-user-reads-like-the-tidyverse
  ;; One package for analyses: the tidyverse (read-csv, ->, filter, ...)
  ;; and the DSL (declare-..., compare, ...), without prefixes.
  (let* ((package (find-package :clds-user))
         (file (namestring (asdf:system-relative-pathname
                            :cl-datascience "examples/stat101/01-sleep/data.csv")))
         (form (let ((*package* package))
                 (read-from-string
                  (format nil "(-> (read-csv ~s) (declare-paired :id :id :within :group) (compare :extra :by :group))"
                          file)))))
    (is (not (null package)))
    (is (find :paired-t-test (steps-of (best (eval form))) :key #'first))))
