;;;; src/guidance.lisp - EXPERIMENT (branch experiment/guided-rules)
;;;;
;;;; Rules guide instead of forbid. Every assumption (assume-...) and every
;;;; departure from a rule (depart-...) is a step a plan may contain. Its
;;;; strength, the rule in words and the rule's sources are in
;;;; examples/guidance.lisp. GUIDED-PLANS returns every minimal plan with
;;;; its cost and category, cheapest first:
;;;;   :recommended          no assumption, no departure
;;;;   :acceptable           assumptions only
;;;;   :justified-departure  departures, each with a declared justification
;;;;   :discouraged          an unjustified departure below *principle-strength*
;;;;   :against-guidance     an unjustified departure at or above it

(in-package #:cl-datascience)

(defparameter *principle-strength* 10
  "Departures at least this strong break a principle, not a recommendation.")

(defparameter *justified-cost* 1
  "Cost of a departure whose justification has been declared.")

(defun guidance-file ()
  (asdf:system-relative-pathname :cl-datascience "examples/guidance.lisp"))

(defun guidance-entry (name)
  "The guidance plist (:strength :rule :sources) of the step named NAME."
  (let ((key (keywordize name)))
    (rest (find key (read-forms (guidance-file)) :key #'first))))

(defun step-kind (step)
  (let ((name (symbol-name (first step))))
    (cond ((eql 0 (search "ASSUME-" name)) :assumption)
          ((eql 0 (search "DEPART-" name)) :departure))))

(defun describe-step (step justified)
  "STEP with its guidance, as a plist."
  (let ((entry (guidance-entry (first step))))
    (unless entry
      (error "No guidance for ~s in ~a" (first step) (guidance-file)))
    (list :step step
          :strength (getf entry :strength)
          :rule (getf entry :rule)
          :sources (getf entry :sources)
          :justified (and (member (first step) justified) t))))

(defun step-cost (described)
  (if (getf described :justified) *justified-cost* (getf described :strength)))

(defun plan-category (assumptions departures)
  (let ((open (remove-if (lambda (d) (getf d :justified)) departures)))
    (cond ((some (lambda (d) (>= (getf d :strength) *principle-strength*)) open)
           :against-guidance)
          (open :discouraged)
          (departures :justified-departure)
          (assumptions :acceptable)
          (t :recommended))))

(defun guide-plan (plan justified)
  "PLAN as a plist (:plan :cost :category :assumptions :departures)."
  (let ((assumptions (loop for step in plan
                           when (eq (step-kind step) :assumption)
                             collect (describe-step step justified)))
        (departures (loop for step in plan
                          when (eq (step-kind step) :departure)
                            collect (describe-step step justified))))
    (list :plan plan
          :cost (reduce #'+ (mapcar #'step-cost (append assumptions departures)))
          :category (plan-category assumptions departures)
          :assumptions assumptions
          :departures departures)))

(defun guided-plans (name knowledge question &key (tier "stat101") (depth-cutoff 6))
  "Every minimal plan for an example question, guided: each with cost,
category, assumptions and departures; cheapest first, then shortest."
  (let* ((problem (example-problem name knowledge question :tier tier))
         (plans (find-plans :objects (getf problem :objects)
                            :facts (getf problem :facts)
                            :goal (getf problem :goal)
                            :domain (getf problem :domain)
                            :depth-cutoff depth-cutoff)))
    (stable-sort (mapcar (lambda (plan) (guide-plan plan (getf problem :justified))) plans)
                 (lambda (a b)
                   (or (< (getf a :cost) (getf b :cost))
                       (and (= (getf a :cost) (getf b :cost))
                            (< (length (getf a :plan)) (length (getf b :plan)))))))))
