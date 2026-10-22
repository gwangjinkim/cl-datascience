;;;; cl-datascience.asd

(defsystem "cl-datascience"
  :description "Common Lisp Data Science: a DSL for data science practice.
Examples first: textbook analyses, planned by the wouldwork planner from
what is declared about the data and what is asked."
  :author "AJ Rossini, Gwang-Jin Kim"
  :license "MIT"
  :depends-on ("wouldwork")
  :serial t
  :components ((:module "src"
                :components ((:file "package")
                             (:file "planner")
                             (:file "examples")
                             (:file "guidance"))))
  :in-order-to ((test-op (test-op "cl-datascience/tests"))))

(defsystem "cl-datascience/dsl"
  :description "EXPERIMENT (experiment/guided-rules): the CLOS DSL on tibbles
from the Common Lisp tidyverse - rule books, statframes, question verbs."
  :depends-on ("cl-datascience" "cl-tidyverse")
  :serial t
  :components ((:module "src/dsl"
                :components ((:file "rules")
                             (:file "common-core")
                             (:file "frame")
                             (:file "questions")
                             (:file "general")
                             (:file "clinical")
                             (:file "user")))))

(defsystem "cl-datascience/tests"
  :depends-on ("cl-datascience" "cl-datascience/dsl" "fiveam")
  :serial t
  :components ((:module "tests"
                :components ((:file "package")
                             (:file "planner-tests")
                             (:file "stat101-tests")
                             (:file "guidance-tests")
                             (:file "clinical-tests")
                             (:file "dsl-tests")
                             (:file "clinical-dsl-tests")
                             (:file "general-dsl-tests"))))
  :perform (test-op (o c) (symbol-call :cl-datascience/tests :run-all)))
