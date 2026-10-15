;;;; src/dsl/frame.lisp - EXPERIMENT (branch experiment/guided-rules)
;;;;
;;;; A statframe is a tibble (a CLOS subclass of cl-tibble:tbl) that also
;;;; carries facts about the study: what was declared, and what checks have
;;;; observed. Every tibble function works on it unchanged. Declaration
;;;; verbs take the data first and return a new statframe, so they chain in
;;;; a tidyverse pipeline:
;;;;
;;;;   (-> (read-csv "sleep.csv")
;;;;       (declare-paired :id :id :within :group)
;;;;       (compare :extra :by :group))

(in-package #:cl-datascience)

(defclass statframe (cl-tibble:tbl)
  ((facts :initarg :facts :initform nil :accessor frame-facts
          :documentation "List of (status proposition): status :declared, :observed
or :annotation (kept for reports, not given to the planner).")
   (book :initarg :book :initform :general :accessor frame-book
         :documentation "The rule book its questions use."))
  (:documentation "A tibble with facts about the study."))

(defgeneric data-rule-book (data)
  (:documentation "The rule book questions about DATA use by default.")
  (:method ((data cl-tibble:tbl)) :general)
  (:method ((data statframe)) (frame-book data)))

(defgeneric as-statframe (data)
  (:documentation "DATA as a new statframe with the same columns and facts.")
  (:method ((data statframe))
    (let ((copy (cl-tibble:new-tibble data :class 'statframe)))
      (setf (frame-facts copy) (copy-list (frame-facts data))
            (frame-book copy) (frame-book data))
      copy))
  (:method ((data cl-tibble:tbl))
    (cl-tibble:new-tibble data :class 'statframe)))

(defgeneric declare-fact (data proposition &key status)
  (:documentation "A new statframe: DATA with PROPOSITION added as a fact.
Column names in propositions are keywords, matched to the tibble's names
without regard to case.")
  (:method ((data cl-tibble:tbl) proposition &key (status :declared))
    (let ((frame (as-statframe data)))
      (push (list status (keywordize proposition)) (frame-facts frame))
      frame)))

(defun declare-paired (data &key id within)
  "Each value of the column ID occurs once under every level of WITHIN."
  (declare-fact data (list :paired-by> :data id within)))

(defun declare-independent (data)
  "The rows are independent observations."
  (declare-fact data (list :rows-independent :data)))

(defun declare-clustered (data &key by)
  "Rows come in clusters of the column BY (repeated measurements on a unit,
patients within centres); rows of a cluster are not independent."
  (declare-fact data (list :clustered-by> :data by)))

(defun declare-time-ordered (data)
  "The rows are in time order (consecutive measurements)."
  (declare-fact data (list :row-order-time :data)))

(defun declare-observed (data &rest propositions)
  "Facts observed by checks, e.g. (:nonnormal-residuals> :extra :group)."
  (let ((frame data))
    (dolist (p propositions frame)
      (setf frame (declare-fact frame p :status :observed)))))

(defun declare-facts (data propositions)
  (let ((frame (as-statframe data)))
    (dolist (p propositions frame)
      (setf frame (declare-fact frame p)))))

;;; Clinical declarations (rule book :clinical, src/dsl/clinical.lisp)

(defun declare-trial (data &key arm stratified-by)
  "DATA come from a randomised trial with one row per patient: ARM was
randomised, stratified by the columns STRATIFIED-BY (one or a list). Its
questions use the clinical rule book."
  (let ((frame (declare-facts data
                              (append (list (list :randomized arm)
                                            (list :rows-independent :data))
                                      (loop for s in (if (listp stratified-by) stratified-by (list stratified-by))
                                            collect (list :stratified-by> :data arm s))))))
    (setf (frame-book frame) :clinical)
    frame))

(defun declare-baseline (data &key of baseline)
  "The column BASELINE is the outcome OF measured before randomisation."
  (declare-fact data (list :baseline-of> baseline of)))

(defun declare-survival (data &key time event)
  "TIME is a time to an event, censored when the column EVENT is 0."
  (declare-facts data (list (list :time-to-event time) (list :event-of> event time))))

(defun declare-dichotomized (data variable &key from)
  "VARIABLE was made by cutting the continuous column FROM into two groups."
  (declare-fact data (list :dichotomized-from> variable from)))

(defun declare-margin (data &key outcome by margin)
  "A pre-specified equivalence margin for OUTCOME between the groups of BY."
  (let ((frame (declare-fact data (list :equivalence-margin> outcome by))))
    (declare-fact frame (list :margin outcome by margin) :status :annotation)))

(defun declare-prespecified (data &rest subgroups)
  "The subgroup analyses by SUBGROUPS were pre-specified in the protocol."
  (declare-facts data (mapcar (lambda (s) (list :prespecified s)) subgroups)))

;;; Columns

(defun column-name (data key)
  "The tibble's column name matching KEY (a keyword or string), any case."
  (or (find (string key) (coerce (cl-tibble:tbl-names data) 'list) :test #'string-equal)
      (error "No column ~s in the data; columns are ~{~a~^, ~}."
             key (coerce (cl-tibble:tbl-names data) 'list))))

(defun column-values (data key)
  "The non-missing values of column KEY, as a list."
  (remove-if #'cl-vctrs-lite:na-p
             (cl-vctrs-lite:col->list (cl-tibble:tbl-col data (column-name data key)))))

(defun column-missing-p (data key)
  "Does column KEY contain missing values?"
  (some #'cl-vctrs-lite:na-p
        (cl-vctrs-lite:col->list (cl-tibble:tbl-col data (column-name data key)))))

(defun numeric-column-p (data key)
  (member (symbol-name (cl-vctrs-lite:col-type (cl-tibble:tbl-col data (column-name data key))))
          '("DOUBLE" "INTEGER" "INT" "FLOAT" "NUMERIC" "NUMBER") :test #'string=))

(defun group-counts (data key)
  "Alist (level . count) for column KEY."
  (let ((counts '()))
    (dolist (v (column-values data key) (nreverse counts))
      (let ((cell (assoc v counts :test #'equal)))
        (if cell (incf (cdr cell)) (push (cons v 1) counts))))))

(defun low-expected-counts-p (data a b)
  "Cochran's rule fails: an expected count below 1, or more than 20% below 5."
  (let* ((rows (group-counts data a))
         (cols (group-counts data b))
         (n (reduce #'+ (mapcar #'cdr rows)))
         (expected (loop for (nil . r) in rows
                         append (loop for (nil . c) in cols collect (/ (* r c) n)))))
    (and expected
         (or (some (lambda (e) (< e 1)) expected)
             (> (count-if (lambda (e) (< e 5)) expected) (* 1/5 (length expected)))))))
