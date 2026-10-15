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
   (estimand :initarg :estimand :initform :mean :reader question-estimand)
   (aim :initarg :aim :initform :difference :reader question-aim)
   (within :initarg :within :initform nil :reader question-within))
  (:documentation "Does OUTCOME differ between the groups of BY? ESTIMAND :mean
asks about means, :location about the location of the distributions. AIM:
:difference (default), :equivalence, :baseline-balance, or
:effect-modification (does the difference depend on the subgroups of
WITHIN?)."))

(defclass association (question)
  ((first :initarg :first :reader question-first)
   (second :initarg :second :reader question-second))
  (:documentation "Are two categorical variables associated?"))

(defclass estimation (question)
  ((variable :initarg :variable :reader question-variable)
   (of :initarg :of :reader question-of))
  (:documentation "What share of VARIABLE takes the value OF, and how precisely is it known?"))

(defclass modelling (question)
  ((outcome :initarg :outcome :reader question-outcome)
   (predictors :initarg :predictors :reader question-predictors)
   (purpose :initarg :purpose :initform :explanation :reader question-purpose)
   (selection :initarg :selection :initform nil :reader question-selection))
  (:documentation "A regression model for OUTCOME with PREDICTORS. PURPOSE
:explanation (default) or :prediction; SELECTION true asks for a smaller model."))

(defun make-estimation (data variable &key of book)
  (make-instance 'estimation :data data :book (or book (data-rule-book data))
                             :variable (keywordize variable) :of of))

(defun make-modelling (data outcome &key with (purpose :explanation) selection book)
  (make-instance 'modelling :data data :book (or book (data-rule-book data))
                            :outcome (keywordize outcome) :predictors (keywordize with)
                            :purpose purpose :selection selection))

(defun make-comparison (data outcome &key by (estimand :mean) (aim :difference) within book)
  (make-instance 'comparison :data data :book (or book (data-rule-book data))
                             :estimand estimand :aim aim :within (keywordize within)
                             :outcome (keywordize outcome) :by (keywordize by)))

(defun make-association (data first second &key book)
  (make-instance 'association :data data :book (or book (data-rule-book data))
                              :first (keywordize first) :second (keywordize second)))

(defun survival-outcome-p (question)
  "Is the outcome declared a time to an event?"
  (member (list :time-to-event (question-outcome question))
          (declared-facts (question-data question)) :test #'equal))

(defgeneric question-goal (question)
  (:documentation "The planner goal that answers QUESTION.")
  (:method ((q comparison))
    (let ((y (question-outcome q))
          (g (question-by q)))
      (ecase (question-aim q)
        (:baseline-balance (list :baseline-compared> y g))
        (:equivalence (list :equivalence-shown> y g))
        (:effect-modification (list :effect-modification> y g (question-within q)))
        (:pairwise (list :pairwise-compared> y g))
        (:difference
         (cond ((survival-outcome-p q) (list :survival-difference> y g))
               ((eq (question-estimand q) :location) (list :location-difference> y g))
               (t (list :mean-difference> y g)))))))
  (:method ((q association))
    (list :association> (question-first q) (question-second q)))
  (:method ((q estimation))
    (list :proportion-estimated (question-variable q)))
  (:method ((q modelling))
    (list (cond ((eq (question-purpose q) :prediction) :performance-estimated)
                ((question-selection q) :reduced-model)
                (t :model-fitted))
          (question-outcome q))))

(defgeneric question-variables (question)
  (:method ((q comparison))
    (remove nil (list (question-outcome q) (question-by q) (question-within q))))
  (:method ((q association)) (list (question-first q) (question-second q)))
  (:method ((q estimation)) (list (question-variable q)))
  (:method ((q modelling)) (cons (question-outcome q) (copy-list (question-predictors q)))))

(defgeneric describe-question (question stream)
  (:method ((q comparison) stream)
    (format stream "compare ~(~a~) by ~(~a~)~@[ within ~(~a~)~] (aim: ~(~a~), estimand: ~(~a~), rule book: ~(~a~))"
            (question-outcome q) (question-by q) (question-within q)
            (question-aim q) (question-estimand q) (question-book q)))
  (:method ((q association) stream)
    (format stream "associate ~(~a~) with ~(~a~)" (question-first q) (question-second q)))
  (:method ((q estimation) stream)
    (format stream "estimate the share of ~a in ~(~a~)" (question-of q) (question-variable q)))
  (:method ((q modelling) stream)
    (format stream "model ~(~a~) with ~{~(~a~)~^, ~} (purpose: ~(~a~)~:[~;, selection~], rule book: ~(~a~))"
            (question-outcome q) (question-predictors q) (question-purpose q)
            (question-selection q) (question-book q))))

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
                (list (list :large-groups> y g)))
              (when (question-within q)
                (list (list :categorical (question-within q))))
              (when (column-missing-p data y)
                (list (list :missing-values y))))))
  (:method ((q estimation) (data cl-tibble:tbl))
    (let* ((v (question-variable q))
           (values (column-values data v))
           (successes (count-if (lambda (x) (string-equal (princ-to-string x)
                                                          (princ-to-string (question-of q))))
                                values))
           (failures (- (length values) successes)))
      (append (list (list :categorical v))
              (when (< (min successes failures) 10)
                (list (list :few-successes v))))))
  (:method ((q modelling) (data cl-tibble:tbl))
    (let* ((y (question-outcome q))
           (values (column-values data y))
           (n (length values))
           (levels (group-counts data y))
           (binary (= (length levels) 2))
           (m (if binary
                  (let ((q-share (/ (reduce #'min (mapcar #'cdr levels)) n)))
                    (* 3 n q-share (- 1 q-share)))
                  n))
           (p (loop for x in (question-predictors q)
                    sum (if (numeric-column-p data x) 1 (1- (length (group-counts data x)))))))
      (append (list (list (if binary :binary-outcome :numeric) y))
              (mapcar (lambda (x) (list :predictor> x y)) (question-predictors q))
              (when (> p (/ m 15))
                (list (list :few-observations-per-parameter y))))))
  (:method ((q association) (data cl-tibble:tbl))
    (let ((a (question-first q))
          (b (question-second q)))
      (append (list (list :categorical a) (list :categorical b))
              (when (low-expected-counts-p data a b)
                (list (list :low-expected-counts> a b)))))))

(defgeneric declared-facts (data)
  (:documentation "Facts declared about DATA or observed by checks.")
  (:method ((data cl-tibble:tbl)) nil)
  (:method ((data statframe))
    (loop for (status proposition) in (frame-facts data)
          unless (eq status :annotation) collect proposition)))

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
                              :domain (compile-rule-book book :goal (question-goal q)))))
      (make-instance 'analysis-result
                     :question q :facts facts
                     :plans (rank-guided-plans
                             (mapcar (lambda (plan)
                                       (guide-plan plan nil (lambda (name) (book-guidance book name))))
                                     plans))))))

(defgeneric compare (data outcome &key by estimand aim within book)
  (:documentation "Does OUTCOME differ between the groups of BY? A plain tibble
gets R's defaults with their assumptions named; a statframe's declarations
change the plan, and a declared trial uses the clinical rule book. AIM:
:difference, :equivalence, :baseline-balance, :effect-modification (with
WITHIN).")
  (:method ((data cl-tibble:tbl) outcome &key by (estimand :mean) (aim :difference) within book)
    (answer (make-comparison data outcome :by by :estimand estimand :aim aim
                                          :within within :book book))))

(defgeneric estimate (data variable &key of book)
  (:documentation "The share of VARIABLE taking the value OF, with its interval.")
  (:method ((data cl-tibble:tbl) variable &key of book)
    (answer (make-estimation data variable :of of :book book))))

(defgeneric model (data outcome &key with purpose selection book)
  (:documentation "A regression model of OUTCOME on the predictors WITH.
PURPOSE :explanation (default) or :prediction; SELECTION true asks for a
smaller model.")
  (:method ((data cl-tibble:tbl) outcome &key with (purpose :explanation) selection book)
    (answer (make-modelling data outcome :with with :purpose purpose
                                         :selection selection :book book))))

(defgeneric associate (data first second &key book)
  (:documentation "Are the categorical variables FIRST and SECOND associated?")
  (:method ((data cl-tibble:tbl) first second &key book)
    (answer (make-association data first second :book book))))

;;; Printing

(defun covariates-of (step facts)
  "Declared baseline and stratification covariates for a method STEP whose
arguments start with frame, outcome, grouping."
  (destructuring-bind (&optional frame y g &rest more) (rest step)
    (declare (ignore frame more))
    (append (loop for f in facts when (and (eq (first f) :baseline-of>) (eq (third f) y))
                  collect (second f))
            (loop for f in facts when (and (eq (first f) :stratified-by>) (eq (third f) g))
                  collect (fourth f)))))

(defun replace-all (text placeholder value)
  (loop for at = (search placeholder text)
        while at
        do (setf text (concatenate 'string (subseq text 0 at) value
                                   (subseq text (+ at (length placeholder))))))
  text)

(defun step-r-code (book step &optional facts)
  "The R equivalent of a method STEP, from its rule's R-CODE template;
{covariates} lists the declared baseline and stratification covariates."
  (let ((rule (find-rule book (first step))))
    (when (and (typep rule 'method-rule) (rule-r-code rule))
      (let ((code (replace-all
                   (replace-all (rule-r-code rule) "{covariates}"
                                (format nil "~{~(~a~)~^ + ~}" (covariates-of step facts)))
                   "{predictors}"
                   (format nil "~{~(~a~)~^ + ~}"
                           (loop for f in facts
                                 when (and (eq (first f) :predictor>) (eq (third f) (third step)))
                                   collect (second f))))))
        (loop for var in (parameter-variables (rule-parameters rule))
              for value in (rest step)
              for placeholder = (format nil "{~(~a~)}" (string-left-trim "?" (symbol-name var)))
              do (setf code (replace-all code placeholder (string-downcase (symbol-name value)))))
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
                     (let ((code (step-r-code book step (result-facts result))))
                       (when code (format stream "~%       R: ~a" code))))
                   (dolist (a (getf plan :assumptions))
                     (when (eq (getf a :kind) :caveat)
                       (format stream "~%       note: ~a~%       sources: ~{~a~^; ~}"
                               (getf a :rule) (getf a :sources))))
                   (dolist (d (getf plan :departures))
                     (format stream "~%       departs from: ~a~%       sources: ~{~a~^; ~}"
                             (getf d :rule) (getf d :sources))))))))
