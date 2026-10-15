;;;; tests/general-dsl-tests.lisp - EXPERIMENT (branch experiment/guided-rules):
;;;; the general rule book (docs/GENERAL-RULES.md, rules G1-G7), the default
;;;; for plain tibbles.

(in-package #:cl-datascience/tests)

(def-suite general-dsl :in :cl-datascience)
(in-suite general-dsl)

(defun general-csv (name &optional (file "data.csv"))
  (cl-readr:read-csv
   (namestring (asdf:system-relative-pathname
                :cl-datascience (format nil "examples/general/~a/~a" name file)))))

(test plain-tibbles-use-the-general-book
  (is (eq :general (data-rule-book (sleep-data))))
  (let ((book (find-rule-book :general)))
    (is (find :welch-t-test (book-rules book) :key #'rule-name))
    (dolist (rule (book-rules book))
      (when (typep rule '(or assumption-rule departure-rule caveat-rule))
        (is (and (realp (rule-strength rule)) (stringp (rule-statement rule)) (rule-sources rule))
            "~a is incomplete" (rule-name rule))))))

;;; G1: a proportion

(test g1-wilson-for-a-proportion-wald-with-an-assumption
  (let ((result (estimate (general-csv "01-proportion" "birthwt-low.csv") :low :of "yes")))
    (is (find :wilson-interval (steps-of (best result)) :key #'first))
    (is (eq :recommended (getf (best result) :category)))
    (is (eq :acceptable (getf (plan-with :wald-interval result) :category)))))

(test g1-too-few-successes-make-wald-discouraged
  (let ((wald (plan-with :wald-interval
                         (estimate (general-csv "01-proportion" "stanza.csv") :stanza :of "B"))))
    (is (eq :discouraged (getf wald :category)))
    (is (search "Introduction to Modern Statistics" (departure-sources wald)))))

;;; G2: pairwise comparisons

(test g2-pairwise-comparisons-are-adjusted
  (let ((result (compare (anorexia-data) :postwt :by :treat :aim :pairwise)))
    (is (member (first (car (last (steps-of (best result))))) '(:games-howell :pairwise-holm)))
    (is (plan-with :tukey-hsd result))
    (let ((unadjusted (plan-with :unadjusted-pairwise-tests result)))
      (is (eq :discouraged (getf unadjusted :category)))
      (is (search "Bland and Altman (1995)" (departure-sources unadjusted))))))

;;; G3: repeated measurements

(test g3-clustered-rows-need-a-mixed-model-or-summary-measures
  (let* ((chicks (declare-clustered (general-csv "02-chickweight") :by :chick))
         (result (compare chicks :weight :by :diet)))
    (is (member (first (car (last (steps-of (best result))))) '(:mixed-model :summary-measure-analysis)))
    (let ((naive (plan-with :welch-anova result)))
      (is (eq :against-guidance (getf naive :category)))
      (is (find :depart-ignore-clustering (steps-of naive) :key #'first)))))

;;; G4: missing outcome values

(test g4-missing-outcomes-recommend-multiple-imputation
  (let ((result (compare (general-csv "03-airquality") :ozone :by :month)))
    (is (member '(:missing-values :ozone) (result-facts result) :test #'equal))
    (is (find :multiple-imputation (steps-of (best result)) :key #'first))
    (is (find :assume-ignorable-missingness (steps-of (plan-with :welch-anova result)) :key #'first))
    (is (eq :against-guidance (getf (plan-with :single-imputation result) :category)))))

;;; G5, G6, G7: models

(defparameter *birthwt-predictors* '(:age :lwt :race :smoke :ptl :ht :ui :ftv))

(test g5-too-many-parameters-recommend-penalisation
  (let ((result (model (general-csv "04-birthwt") :low :with *birthwt-predictors*)))
    ;; m = 3nq(1-q) = 121.7, p = 9 > m/15 = 8.1
    (is (member '(:few-observations-per-parameter :low) (result-facts result) :test #'equal))
    (is (find :penalized-regression (steps-of (best result)) :key #'first))
    (is (eq :discouraged (getf (plan-with :regression-model result) :category)))))

(test g5-within-the-limit-ordinary-regression-is-fine
  (let ((result (model (general-csv "04-birthwt") :low :with '(:lwt :smoke :ht))))
    (is (not (member '(:few-observations-per-parameter :low) (result-facts result) :test #'equal)))
    (is (not (eq :discouraged (getf (plan-with :regression-model result) :category))))))

(test g6-stepwise-selection-is-against-guidance
  (let ((result (model (general-csv "04-birthwt") :low :with *birthwt-predictors* :selection t)))
    (is (find :data-reduction (steps-of (best result)) :key #'first))
    (is (eq :against-guidance (getf (plan-with :stepwise-selection result) :category)))
    (is (search "Harrell" (departure-sources (plan-with :stepwise-selection result))))))

(test g7-predictive-performance-on-data-not-used-for-fitting
  (let ((result (model (general-csv "04-birthwt") :low :with *birthwt-predictors* :purpose :prediction)))
    (is (member (first (car (last (steps-of (best result))))) '(:bootstrap-validation :cross-validation)))
    (is (eq :against-guidance (getf (plan-with :apparent-performance result) :category)))
    (is (search "Statistical Learning" (departure-sources (plan-with :apparent-performance result))))))
