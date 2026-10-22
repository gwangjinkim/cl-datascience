;;;; src/dsl/user.lisp - EXPERIMENT (branch experiment/guided-rules)
;;;;
;;;; CLDS-USER: one package for analyses, like TIDYVERSE-USER. It uses the
;;;; Common Lisp tidyverse (read-csv, ->, filter, mutate, ...) and the DSL
;;;; (declare-..., compare, associate, estimate, model), so analyses need no
;;;; package prefixes:
;;;;
;;;;   (in-package :clds-user)
;;;;   (-> (read-csv "sleep.csv")
;;;;       (declare-paired :id :id :within :group)
;;;;       (compare :extra :by :group))

(tidyverse:define-tidy-package #:clds-user
  (:also-use #:cl-datascience))
