;;;; tests/guidance-tests.lisp - EXPERIMENT (branch experiment/guided-rules):
;;;; rules guide instead of forbid. Every plan is offered, with a cost, a
;;;; category and the rules it departs from.

(in-package #:cl-datascience/tests)

(def-suite guidance :in :cl-datascience)
(in-suite guidance)

(defun domain-files ()
  (directory (merge-pathnames "*/domain.lisp"
                              (asdf:system-relative-pathname :cl-datascience "examples/"))))

(defun guidance-step-names (domain)
  "Names of the assume-... and depart-... actions of DOMAIN."
  (remove-if-not (lambda (name)
                   (let ((s (symbol-name name)))
                     (or (eql 0 (search "ASSUME-" s)) (eql 0 (search "DEPART-" s)))))
                 (cl-datascience::domain-action-names domain)))

(defun plan-steps-equal (actual expected)
  (plans-equal (list actual) (list expected)))

(test every-assumption-and-departure-has-guidance
  ;; strength, the rule in words, and at least one source
  (dolist (domain (domain-files))
    (dolist (name (guidance-step-names domain))
      (let ((entry (guidance-entry name)))
        (is (and entry (realp (getf entry :strength))
                 (stringp (getf entry :rule)) (getf entry :sources))
            "~a in ~a has no complete guidance entry" name (pathname-directory domain))))))

(test sleep-plain-plan-is-acceptable-with-one-assumption
  (let ((p (first (guided-plans "01-sleep" :plain :difference))))
    (is (eq :acceptable (getf p :category)))
    (is (= 1 (getf p :cost)))
    (is (= 1 (length (getf p :assumptions))))
    (is (null (getf p :departures)))))

(test designed-analysis-is-recommended
  (let ((p (first (guided-plans "03-toothgrowth" :design :effects))))
    (is (eq :recommended (getf p :category)))
    (is (= 0 (getf p :cost)))))

(test reversed-design-is-offered-against-guidance
  ;; examples/stat101 refuses this plan; here it is offered, labelled, with
  ;; the rule it breaks and its sources.
  (let ((plans (guided-plans "03-toothgrowth" :design :dose-from-len)))
    (is (= 1 (length plans)))
    (let* ((p (first plans))
           (departure (first (getf p :departures))))
      (is (plan-steps-equal (getf p :plan)
                            '((depart-design-consistency dose) (ols-fit dose len))))
      (is (eq :against-guidance (getf p :category)))
      (is (equal '(:depart-design-consistency :dose) (getf departure :step)))
      (is (search "Fisher" (format nil "~{~a ~}" (getf departure :sources))))
      (is (not (getf departure :justified))))))

(test a-declared-justification-makes-a-justified-departure
  (let ((p (first (guided-plans "03-toothgrowth" :design-justified :dose-from-len))))
    (is (eq :justified-departure (getf p :category)))
    (is (getf (first (getf p :departures)) :justified))
    (is (< (getf p :cost)
           (getf (first (guided-plans "03-toothgrowth" :design :dose-from-len)) :cost)))))
