;;;; src/examples.lisp - the Statistics 101 examples as planning problems
;;;;
;;;; Each example folder examples/stat101/NAME/ has a plan.lisp holding one
;;;; plist:
;;;;   :objects    ((type object ...) ...)       what the data contains
;;;;   :facts      (proposition ...)             known in every case
;;;;   :knowledge  ((name proposition ...) ...)  alternative states of
;;;;               knowledge: what is declared (or observed by a check)
;;;;   :questions  ((name goal) ...)             what can be asked
;;;; The method actions shared by all examples are in
;;;; examples/stat101/domain.lisp.

(in-package #:cl-datascience)

(defun examples-directory (&optional (tier "stat101"))
  "examples/TIER/ in this checkout."
  (asdf:system-relative-pathname :cl-datascience (format nil "examples/~a/" tier)))

(defun load-example (name &key (tier "stat101"))
  "The planning specification of example NAME (examples/TIER/NAME/plan.lisp),
symbols read as keywords."
  (let ((forms (read-forms (merge-pathnames (format nil "~a/plan.lisp" name)
                                            (examples-directory tier)))))
    (unless (and (= 1 (length forms)) (listp (first forms)))
      (error "~a/plan.lisp must hold exactly one plist" name))
    (first forms)))

(defun justification-p (fact)
  "Facts (justified <departure>) are read by the guidance layer, not planned."
  (and (consp fact) (eq (first fact) :justified)))

(defun example-problem (name knowledge question &key (tier "stat101"))
  "The planning problem of example NAME when KNOWLEDGE holds and QUESTION is
asked, as a plist (:objects :facts :goal :domain :justified)."
  (let* ((spec (load-example name :tier tier))
         (known (assoc knowledge (getf spec :knowledge)))
         (asked (assoc question (getf spec :questions))))
    (unless known
      (error "Example ~a has no knowledge ~s; it has ~{~s~^, ~}."
             name knowledge (mapcar #'first (getf spec :knowledge))))
    (unless asked
      (error "Example ~a has no question ~s; it has ~{~s~^, ~}."
             name question (mapcar #'first (getf spec :questions))))
    (let ((facts (append (getf spec :facts) (rest known))))
      (list :objects (getf spec :objects)
            :facts (remove-if #'justification-p facts)
            :justified (mapcar #'second (remove-if-not #'justification-p facts))
            :goal (second asked)
            :domain (merge-pathnames "domain.lisp" (examples-directory tier))))))

(defun example-plans (name knowledge question &key (depth-cutoff 6) (tier "stat101"))
  "Every minimal plan for example NAME when KNOWLEDGE (a keyword naming a
:knowledge entry) holds and QUESTION (a keyword naming a :questions entry)
is asked. See FIND-PLANS."
  (let ((problem (example-problem name knowledge question :tier tier)))
    (find-plans :objects (getf problem :objects)
                :facts (getf problem :facts)
                :goal (getf problem :goal)
                :domain (getf problem :domain)
                :depth-cutoff depth-cutoff)))
