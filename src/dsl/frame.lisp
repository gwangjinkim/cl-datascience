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
          :documentation "List of (status proposition): status :declared or :observed."))
  (:documentation "A tibble with facts about the study."))

(defgeneric as-statframe (data)
  (:documentation "DATA as a new statframe with the same columns and facts.")
  (:method ((data statframe))
    (let ((copy (cl-tibble:new-tibble data :class 'statframe)))
      (setf (frame-facts copy) (copy-list (frame-facts data)))
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

(defun declare-time-ordered (data)
  "The rows are in time order (consecutive measurements)."
  (declare-fact data (list :row-order-time :data)))

(defun declare-observed (data &rest propositions)
  "Facts observed by checks, e.g. (:nonnormal-residuals> :extra :group)."
  (let ((frame data))
    (dolist (p propositions frame)
      (setf frame (declare-fact frame p :status :observed)))))

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
