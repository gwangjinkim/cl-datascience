;;;; src/package.lisp

(defpackage #:cl-datascience
  (:nicknames #:clds)
  (:use #:cl)
  (:export
   ;; planner bridge (src/planner.lisp)
   #:find-plans #:plan-assumptions #:planning-error #:keywordize
   ;; examples (src/examples.lisp)
   #:examples-directory #:load-example #:example-problem #:example-plans
   ;; EXPERIMENT guided rules (src/guidance.lisp)
   #:guidance-entry #:guided-plans
   ;; EXPERIMENT the CLOS DSL (src/dsl/)
   ;; rule books
   #:rule-book #:find-rule-book #:book-rules #:define-rule-book
   #:rule #:rule-name #:rule-strength #:rule-statement #:rule-sources
   #:relation-rule #:method-rule #:assumption-rule #:departure-rule #:constraint-rule
   #:define-relation #:define-method #:define-assumption #:define-departure
   #:define-constraint #:compile-rule-book
   ;; data
   #:statframe #:frame-facts #:declare-paired #:declare-independent
   #:declare-time-ordered #:declare-observed #:declare-fact
   ;; questions and answers
   #:question #:comparison #:association #:make-comparison #:make-association
   #:question-facts #:question-goal #:answer
   #:compare #:associate
   #:analysis-result #:result-question #:result-plans #:result-facts
   ;; clinical rule book
   #:requirement-rule #:caveat-rule #:define-requirement #:define-caveat
   #:data-rule-book #:declare-trial #:declare-baseline #:declare-survival
   #:declare-dichotomized #:declare-margin #:declare-prespecified
   ;; general rule book
   #:declare-clustered #:estimation #:modelling #:estimate #:model))
