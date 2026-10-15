;;;; src/dsl/questions.lisp - EXPERIMENT (branch experiment/guided-rules)
;;;;
;;;; Questions are CLOS objects; the verbs that ask them (COMPARE,
;;;; ASSOCIATE) are generic functions that take the data first, so they sit
;;;; at the end of a tidyverse pipeline. ANSWER plans a question with its
;;;; rule book and returns an ANALYSIS-RESULT: every minimal plan, ranked
;;;; and labelled (src/guidance.lisp).
;;;;
;;;; Facts come from two places, chosen by dispatch on the data:
;;;; - ROLE-FACTS: what the question's roles and the values say (a grouping
;;;;   is categorical, how many levels it has, whether all groups are large,
;;;;   whether expected counts are low) - for any tibble;
;;;; - DECLARED-FACTS: what was declared or observed - for statframes only.

(in-package #:cl-datascience)

;;; Questions

(defclass question ()
  ((data :initarg :data :reader question-data)
   (book :initarg :book :initform :common-core :reader question-book))
  (:documentation "Something asked of the data."))

(defclass comparison (question)
  ((outcome :initarg :outcome :reader question-outcome)
   (by :initarg :by :reader question-by)
   (estimand :initarg :estimand :initform :mean :reader question-estimand))
  (:documentation "Does OUTCOME differ between the groups of BY? ESTIMAND :mean
asks about means, :location about the location of the distributions."))

(defclass association (question)
  ((first :initarg :first :reader question-first)
   (second :initarg :second :reader question-second))
  (:documentation "Are two categorical variables associated?"))

(defun make-comparison (data outcome &key by (estimand :mean) (book :common-core))
  (make-instance 'comparison :data data :book book :estimand estimand
                             :outcome (keywordize outcome) :by (keywordize by)))

(defun make-association (data first second &key (book :common-core))
  (make-instance 'association :data data :book book
                              :first (keywordize first) :second (keywordize second)))

(defgeneric question-goal (question)
  (:documentation "The planner goal that answers QUESTION.")
  (:method ((q comparison))
    (list (ecase (question-estimand q)
            (:mean :mean-difference>)
            (:location :location-difference>))
          (question-outcome q) (question-by q)))
  (:method ((q association))
    (list :association> (question-first q) (question-second q))))

(defgeneric question-variables (question)
  (:method ((q comparison)) (list (question-outcome q) (question-by q)))
  (:method ((q association)) (list (question-first q) (question-second q))))

(defgeneric describe-question (question stream)
  (:method ((q comparison) stream)
    (format stream "compare ~(~a~) by ~(~a~) (estimand: ~(~a~))"
            (question-outcome q) (question-by q) (question-estimand q)))
  (:method ((q association) stream)
    (format stream "associate ~(~a~) with ~(~a~)" (question-first q) (question-second q))))

;;; Facts

(defgeneric role-facts (question data)
  (:documentation "Facts given by the roles in QUESTION and the values in DATA.")
  (:method ((q comparison) (data cl-tibble:tbl))
    (let* ((y (question-outcome q))
           (g (question-by q))
           (counts (group-counts data g)))
      (append (list (list (if (numeric-column-p data y) :numeric :categorical) y)
                    (list :categorical g)
                    (list (if (= (length counts) 2) :two-levels :several-levels) g))
              (when (every (lambda (c) (>= (cdr c) 30)) counts)
                (list (list :large-groups> y g))))))
  (:method ((q association) (data cl-tibble:tbl))
    (let ((a (question-first q))
          (b (question-second q)))
      (append (list (list :categorical a) (list :categorical b))
              (when (low-expected-counts-p data a b)
                (list (list :low-expected-counts> a b)))))))

(defgeneric declared-facts (data)
  (:documentation "Facts declared about DATA or observed by checks.")
  (:method ((data cl-tibble:tbl)) nil)
  (:method ((data statframe)) (mapcar #'second (frame-facts data))))

(defgeneric question-facts (question)
  (:documentation "Every fact the planner gets for QUESTION.")
  (:method ((q question))
    (remove-duplicates (append (role-facts q (question-data q))
                               (declared-facts (question-data q)))
                       :test #'equal :from-end t)))

(defun question-objects (question facts)
  "Planner objects: the frame DATA and every variable named in QUESTION or FACTS."
  (let ((variables (copy-list (question-variables question))))
    (dolist (fact facts)
      (dolist (arg (rest fact))
        (unless (eq arg :data) (pushnew arg variables))))
    (list (list :frame :data) (cons :variable (reverse variables)))))

;;; Answers

(defclass analysis-result ()
  ((question :initarg :question :reader result-question)
   (facts :initarg :facts :reader result-facts)
   (plans :initarg :plans :reader result-plans
          :documentation "Guided plans (src/guidance.lisp), cheapest first."))
  (:documentation "The answer to a question: every minimal plan, ranked and labelled."))

(defgeneric answer (question)
  (:documentation "Plan QUESTION with its rule book.")
  (:method ((q question))
    (let* ((book (find-rule-book (question-book q)))
           (facts (question-facts q))
           (plans (find-plans :objects (question-objects q facts)
                              :facts facts
                              :goal (question-goal q)
                              :domain (compile-rule-book book))))
      (make-instance 'analysis-result
                     :question q :facts facts
                     :plans (rank-guided-plans
                             (mapcar (lambda (plan)
                                       (guide-plan plan nil (lambda (name) (book-guidance book name))))
                                     plans))))))

(defgeneric compare (data outcome &key by estimand)
  (:documentation "Does OUTCOME differ between the groups of BY? A plain tibble
gets R's defaults with their assumptions named; a statframe's declarations
change the plan.")
  (:method ((data cl-tibble:tbl) outcome &key by (estimand :mean))
    (answer (make-comparison data outcome :by by :estimand estimand))))

(defgeneric associate (data first second)
  (:documentation "Are the categorical variables FIRST and SECOND associated?")
  (:method ((data cl-tibble:tbl) first second)
    (answer (make-association data first second))))

;;; Printing

(defun step-r-code (book step)
  "The R equivalent of a method STEP, from its rule's R-CODE template."
  (let ((rule (find-rule book (first step))))
    (when (and (typep rule 'method-rule) (rule-r-code rule))
      (let ((code (rule-r-code rule)))
        (loop for var in (parameter-variables (rule-parameters rule))
              for value in (rest step)
              for placeholder = (format nil "{~(~a~)}" (string-left-trim "?" (symbol-name var)))
              do (loop for at = (search placeholder code)
                       while at
                       do (setf code (concatenate 'string (subseq code 0 at)
                                                  (string-downcase (symbol-name value))
                                                  (subseq code (+ at (length placeholder)))))))
        code))))

(defmethod print-object ((result analysis-result) stream)
  (print-unreadable-object (result stream :type t)
    (let ((book (find-rule-book (question-book (result-question result)))))
      (describe-question (result-question result) stream)
      (format stream "~%  known: ~{~(~a~)~^; ~}" (mapcar #'term-string (result-facts result)))
      (if (null (result-plans result))
          (format stream "~%  no plan answers this question with what is known")
          (loop for plan in (result-plans result)
                for i from 1
                do (format stream "~%  ~d. ~(~a~) (cost ~a): ~{~a~^, ~}"
                           i (getf plan :category) (getf plan :cost)
                           (mapcar #'term-string (getf plan :plan)))
                   (dolist (step (getf plan :plan))
                     (let ((code (step-r-code book step)))
                       (when code (format stream "~%       R: ~a" code))))
                   (dolist (d (getf plan :departures))
                     (format stream "~%       departs from: ~a~%       sources: ~{~a~^; ~}"
                             (getf d :rule) (getf d :sources))))))))
