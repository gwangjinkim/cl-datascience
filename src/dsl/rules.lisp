;;;; src/dsl/rules.lisp - EXPERIMENT (branch experiment/guided-rules)
;;;;
;;;; Rule books: statistical knowledge as CLOS objects. A rule book holds
;;;; relations, methods, assumptions, departures and constraints. Each kind
;;;; of rule writes itself as wouldwork (generic functions RULE-PRECONDITION,
;;;; RULE-EFFECTS, RULE->WOULDWORK); COMPILE-RULE-BOOK writes the whole book
;;;; as one planner domain. Assumptions and departures carry their guidance:
;;;; strength (the cost of the step), statement and sources.

(in-package #:cl-datascience)

;;; Classes

(defclass rule ()
  ((name :initarg :name :reader rule-name)
   (sources :initarg :sources :initform nil :reader rule-sources)
   (documentation :initarg :documentation :initform nil :reader rule-documentation))
  (:documentation "A piece of statistical knowledge in a rule book."))

(defclass relation-rule (rule)
  ((argument-types :initarg :argument-types :reader relation-argument-types))
  (:documentation "A kind of fact, e.g. (numeric variable)."))

(defclass action-rule (rule)
  ((parameters :initarg :parameters :reader rule-parameters)
   (requires :initarg :requires :initform nil :reader rule-requires))
  (:documentation "A rule the planner can take as a step."))

(defclass method-rule (action-rule)
  ((answers :initarg :answers :reader rule-answers)
   (r-code :initarg :r-code :initform nil :reader rule-r-code))
  (:documentation "A statistical method: what it requires and what it answers."))

(defclass guidance-rule (action-rule)
  ((asserts :initarg :asserts :reader rule-asserts)
   (unless-known :initarg :unless-known :initform nil :reader rule-unless-known)
   (strength :initarg :strength :reader rule-strength)
   (statement :initarg :statement :reader rule-statement))
  (:documentation "A step that makes an assumption or departs from a rule. Its
strength is its cost in a plan; statement and sources say what and why."))

(defclass assumption-rule (guidance-rule) ()
  (:documentation "Taking a fact as true without declaration (assume-...)."))

(defclass departure-rule (guidance-rule) ()
  (:documentation "Going against a recommendation or principle (depart-...)."))

(defclass constraint-rule (rule)
  ((forbid :initarg :forbid :reader rule-forbid))
  (:documentation "A state no plan may reach."))

(defclass rule-book ()
  ((name :initarg :name :reader book-name)
   (documentation :initarg :documentation :initform nil :reader book-documentation)
   (table :initform (make-hash-table :test 'eq) :reader %book-table)
   (order :initform nil :accessor %book-order))
  (:documentation "A named collection of rules, compiled together into one
planner domain."))

(defvar *rule-books* (make-hash-table :test 'eq))

(defun find-rule-book (name &optional (errorp t))
  (or (gethash (keywordize name) *rule-books*)
      (and errorp (error "No rule book named ~s." name))))

(defun ensure-rule-book (name &key documentation)
  (let ((key (keywordize name)))
    (or (gethash key *rule-books*)
        (setf (gethash key *rule-books*)
              (make-instance 'rule-book :name key :documentation documentation)))))

(defun book-rules (book)
  "The rules of BOOK in definition order."
  (mapcar (lambda (name) (gethash name (%book-table book))) (reverse (%book-order book))))

(defun find-rule (book name)
  (gethash (keywordize name) (%book-table book)))

(defgeneric add-rule (book rule)
  (:documentation "Add RULE to BOOK, replacing a rule of the same name.")
  (:method ((book rule-book) (rule rule))
    (let ((key (keywordize (rule-name rule))))
      (unless (nth-value 1 (gethash key (%book-table book)))
        (push key (%book-order book)))
      (setf (gethash key (%book-table book))
            (reinitialize-instance rule :name key)))))

;;; Defining forms. Rule names and facts are stored as keywords.

(defmacro define-rule-book (name &optional documentation)
  `(ensure-rule-book ',name :documentation ,documentation))

(defmacro define-relation (book name &rest argument-types)
  "A kind of fact: (define-relation core numeric variable)."
  `(add-rule (ensure-rule-book ',book)
             (make-instance 'relation-rule :name ',name
                                           :argument-types ',(keywordize argument-types))))

(defmacro define-method (book name &key parameters requires answers r-code sources documentation)
  "A method. PARAMETERS: (?var type ...). REQUIRES: the facts it needs, as
wouldwork forms. ANSWERS: the facts it delivers. R-CODE: the equivalent R
call, with {var} for each parameter ?var."
  `(add-rule (ensure-rule-book ',book)
             (make-instance 'method-rule :name ',name
                                         :parameters ',(keywordize parameters)
                                         :requires ',(keywordize requires)
                                         :answers ',(keywordize answers)
                                         :r-code ,r-code :sources ',sources
                                         :documentation ,documentation)))

(defmacro define-assumption (book name &key parameters requires asserts unless-known
                                           (strength 1) statement sources)
  "Taking ASSERTS as true, possible when REQUIRES hold and none of
UNLESS-KNOWN is known."
  `(add-rule (ensure-rule-book ',book)
             (make-instance 'assumption-rule :name ',name
                                             :parameters ',(keywordize parameters)
                                             :requires ',(keywordize requires)
                                             :asserts ',(keywordize asserts)
                                             :unless-known ',(keywordize unless-known)
                                             :strength ,strength :statement ,statement
                                             :sources ',sources)))

(defmacro define-departure (book name &key parameters requires asserts strength statement sources)
  "Departing from a rule: possible when REQUIRES hold; asserts ASSERTS,
which the methods that go against the rule need."
  `(add-rule (ensure-rule-book ',book)
             (make-instance 'departure-rule :name ',name
                                            :parameters ',(keywordize parameters)
                                            :requires ',(keywordize requires)
                                            :asserts ',(keywordize asserts)
                                            :strength ,strength :statement ,statement
                                            :sources ',sources)))

(defmacro define-constraint (book name &key forbid sources documentation)
  `(add-rule (ensure-rule-book ',book)
             (make-instance 'constraint-rule :name ',name :forbid ',(keywordize forbid)
                                             :sources ',sources :documentation ,documentation)))

;;; Compilation to wouldwork

(defun parameter-variables (parameters)
  (loop for (var nil) on parameters by #'cddr collect var))

(defun parameter-spec (parameters)
  "Wouldwork parameter list. Several parameters use the product header (see
AGENTS.md: wouldwork's default fails when an example has too few objects)."
  (if (> (length parameters) 2) (cons :product parameters) parameters))

(defun conjunction (forms)
  (if (rest forms) (cons :and forms) (first forms)))

(defgeneric rule-precondition (rule)
  (:documentation "The wouldwork precondition of an action rule.")
  (:method ((rule method-rule))
    (conjunction (append (rule-requires rule)
                         (mapcar (lambda (fact) (list :not fact)) (rule-answers rule)))))
  (:method ((rule guidance-rule))
    (conjunction (append (rule-requires rule)
                         (list (list :not (rule-asserts rule)))
                         (mapcar (lambda (fact) (list :not fact)) (rule-unless-known rule))))))

(defgeneric rule-effects (rule)
  (:documentation "The facts an action rule asserts.")
  (:method ((rule method-rule)) (rule-answers rule))
  (:method ((rule guidance-rule)) (list (rule-asserts rule))))

(defgeneric rule->wouldwork (rule)
  (:documentation "The wouldwork form for RULE, or NIL if it compiles to none
of its own (relations are collected separately).")
  (:method ((rule rule)) nil)
  (:method ((rule action-rule))
    `(:define-action ,(rule-name rule) 1
       ,(parameter-spec (rule-parameters rule))
       ,(rule-precondition rule)
       ,(parameter-variables (rule-parameters rule))
       (:assert ,@(rule-effects rule) (:used ,(rule-name rule)))))
  (:method ((rule constraint-rule))
    `(:define-constraint (:not ,(rule-forbid rule)))))

(defun compile-rule-book (book)
  "Write BOOK as a wouldwork domain file and return its pathname."
  (let* ((book (if (typep book 'rule-book) book (find-rule-book book)))
         (rules (book-rules book))
         (file (merge-pathnames (format nil "domain-~(~a~).lisp" (book-name book))
                                (ensure-directories-exist *problem-directory*))))
    (with-open-file (out file :direction :output :if-exists :supersede)
      (format out ";;;; Generated from rule book ~(~a~) (src/dsl/rules.lisp). Do not edit.~%~%"
              (book-name book))
      (format out "(define-dynamic-relations~%")
      (dolist (rule rules)
        (when (typep rule 'relation-rule)
          (format out "  ~a~%" (term-string (cons (rule-name rule) (relation-argument-types rule))))))
      (format out "  (used method))~%")
      (dolist (rule rules)
        (let ((form (rule->wouldwork rule)))
          (when form (format out "~%~a~%" (term-string form))))))
    file))

(defun book-guidance (book name)
  "Guidance plist (:strength :rule :sources) of the step NAME in BOOK."
  (let ((rule (find-rule book name)))
    (when (typep rule 'guidance-rule)
      (list :strength (rule-strength rule)
            :rule (rule-statement rule)
            :sources (rule-sources rule)))))
