;;;; src/dsl/common-core.lisp - EXPERIMENT (branch experiment/guided-rules)
;;;;
;;;; The common core of test selection, as a rule book. The rules are those
;;;; that visStatistics, testflow, rstatix and AssumpSure share
;;;; (docs/PRIOR-ART-R.md), re-encoded with three changes:
;;;; - the estimand is part of the question: mean-difference> or
;;;;   location-difference>; a rank test answers the second, never silently
;;;;   the first;
;;;; - there is no gate on the same data: normality and equal variances are
;;;;   assumed (recorded), declared, or observed by a check; large groups
;;;;   make normality unnecessary for mean-based tests;
;;;; - a method against a recommendation stays possible after a departure
;;;;   step with its strength, statement and sources.

(in-package #:cl-datascience)

(define-rule-book common-core
  "Choosing a test for one outcome and one grouping, or two categorical
variables: the rules shared by R packages that choose tests.")

;;; Facts

(define-relation common-core numeric variable)
(define-relation common-core categorical variable)
(define-relation common-core two-levels variable)
(define-relation common-core several-levels variable)
(define-relation common-core rows-independent frame)
(define-relation common-core row-order-time frame)
(define-relation common-core paired-by> frame variable variable)        ; (paired-by> f id within)
(define-relation common-core large-groups> variable variable)           ; every group of (y g) has >= 30 values
(define-relation common-core normal-residuals> variable variable)
(define-relation common-core nonnormal-residuals> variable variable)    ; observed by a check
(define-relation common-core normality-waived> variable variable)
(define-relation common-core equal-variances> variable variable)
(define-relation common-core unequal-variances> variable variable)     ; observed by a check
(define-relation common-core equal-variances-waived> variable variable)
(define-relation common-core low-expected-counts> variable variable)   ; Cochran's rule fails
(define-relation common-core expected-counts-waived> variable variable)
;; answers
(define-relation common-core mean-difference> variable variable)       ; do the means of y differ by g?
(define-relation common-core location-difference> variable variable)   ; do the distributions of y differ in location?
(define-relation common-core association> variable variable)           ; are two categorical variables associated?

;;; Assumptions (cost 1 each; recorded in the plan)

(define-assumption common-core assume-rows-independent
  :parameters (?f frame)
  :asserts (rows-independent ?f)
  :unless-known ((row-order-time ?f) (exists ((?a ?b) variable) (paired-by> ?f ?a ?b)))
  :statement "Rows are taken as independent observations; independence cannot be tested from the data and follows from the design."
  :sources ("testflow 1.0.0 documentation, section Assumption checks"))

(define-assumption common-core assume-normality
  :parameters (?y variable ?g variable)
  :requires ((numeric ?y) (categorical ?g) (not (large-groups> ?y ?g)))
  :asserts (normal-residuals> ?y ?g)
  :unless-known ((nonnormal-residuals> ?y ?g))
  :statement "The values of each group (or the paired differences) are taken to be roughly normal; this matters for small groups only."
  :sources ("Lumley et al. (2002), Annual Review of Public Health 23:151"))

(define-assumption common-core assume-equal-variances
  :parameters (?y variable ?g variable)
  :requires ((numeric ?y) (categorical ?g))
  :asserts (equal-variances> ?y ?g)
  :unless-known ((unequal-variances> ?y ?g))
  :statement "The groups are taken to have the same variance (Student's t-test, classical one-way ANOVA)."
  :sources ("Delacre, Lakens and Leys (2017), International Review of Social Psychology 30:92"))

;;; Departures

(define-departure common-core depart-normality
  :parameters (?y variable ?g variable)
  :requires ((nonnormal-residuals> ?y ?g) (not (large-groups> ?y ?g)))
  :asserts (normality-waived> ?y ?g)
  :strength 5
  :statement "A mean-based test on small groups that a check found clearly non-normal: its error rates and power can be poor. Consider the location question (a rank test) or larger groups."
  :sources ("Fagerland and Sandvik (2009), Contemporary Clinical Trials 30:490"
            "visStatistics 0.3.0 vignette, section 8"))

(define-departure common-core depart-equal-variances
  :parameters (?y variable ?g variable)
  :requires ((unequal-variances> ?y ?g))
  :asserts (equal-variances-waived> ?y ?g)
  :strength 3
  :statement "A test that assumes equal variances, although a check found them unequal; Welch's version does not need them."
  :sources ("Delacre, Lakens and Leys (2017), International Review of Social Psychology 30:92"))

(define-departure common-core depart-expected-counts
  :parameters (?a variable ?b variable)
  :requires ((low-expected-counts> ?a ?b))
  :asserts (expected-counts-waived> ?a ?b)
  :strength 5
  :statement "The chi-square approximation needs enough expected counts (none below 1, at most 20% below 5); Fisher's exact test does not."
  :sources ("Cochran (1954), Biometrics 10:417"
            "visStatistics 0.3.0 vignette, section 5.3.4"))

;;; Two independent groups

(define-method common-core welch-t-test
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (two-levels ?g) (rows-independent ?f)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g)))
  :answers ((mean-difference> ?y ?g))
  :r-code "t.test({y} ~ {g}, data = data)"
  :sources ("Welch (1947), Biometrika 34:28"
            "Delacre, Lakens and Leys (2017), International Review of Social Psychology 30:92"))

(define-method common-core student-t-test
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (two-levels ?g) (rows-independent ?f)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g))
             (or (equal-variances> ?y ?g) (equal-variances-waived> ?y ?g)))
  :answers ((mean-difference> ?y ?g))
  :r-code "t.test({y} ~ {g}, data = data, var.equal = TRUE)"
  :sources ("Student (1908), Biometrika 6:1"))

(define-method common-core wilcoxon-rank-sum
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (two-levels ?g) (rows-independent ?f))
  :answers ((location-difference> ?y ?g))
  :r-code "wilcox.test({y} ~ {g}, data = data)"
  :sources ("Wilcoxon (1945), Biometrics Bulletin 1:80" "Mann and Whitney (1947), Annals of Mathematical Statistics 18:50"))

;;; Two groups, paired by a unit (id)

(define-method common-core paired-t-test
  :parameters (?f frame ?y variable ?g variable ?id variable)
  :requires ((numeric ?y) (two-levels ?g) (paired-by> ?f ?id ?g)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g)))
  :answers ((mean-difference> ?y ?g))
  :r-code "with(data, t.test({y}[{g} == second], {y}[{g} == first], paired = TRUE))  # rows matched by {id}"
  :sources ("Student (1908), Biometrika 6:1"))

(define-method common-core signed-rank-test
  :parameters (?f frame ?y variable ?g variable ?id variable)
  :requires ((numeric ?y) (two-levels ?g) (paired-by> ?f ?id ?g))
  :answers ((location-difference> ?y ?g))
  :r-code "with(data, wilcox.test({y}[{g} == second], {y}[{g} == first], paired = TRUE))  # rows matched by {id}"
  :sources ("Wilcoxon (1945), Biometrics Bulletin 1:80"))

;;; Three or more independent groups

(define-method common-core welch-anova
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (several-levels ?g) (rows-independent ?f)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g)))
  :answers ((mean-difference> ?y ?g))
  :r-code "oneway.test({y} ~ {g}, data = data)"
  :sources ("Welch (1951), Biometrika 38:330"
            "Delacre et al. (2019), International Review of Social Psychology 32:13"))

(define-method common-core one-way-anova
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (several-levels ?g) (rows-independent ?f)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g))
             (or (equal-variances> ?y ?g) (equal-variances-waived> ?y ?g)))
  :answers ((mean-difference> ?y ?g))
  :r-code "summary(aov({y} ~ {g}, data = data))"
  :sources ("Fisher (1925), Statistical Methods for Research Workers"))

(define-method common-core kruskal-wallis
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (several-levels ?g) (rows-independent ?f))
  :answers ((location-difference> ?y ?g))
  :r-code "kruskal.test({y} ~ {g}, data = data)"
  :sources ("Kruskal and Wallis (1952), Journal of the American Statistical Association 47:583"))

;;; Two categorical variables

(define-method common-core chi-square-test
  :parameters (?f frame ?a variable ?b variable)
  :requires ((categorical ?a) (categorical ?b) (not (eql ?a ?b)) (rows-independent ?f)
             (or (not (low-expected-counts> ?a ?b)) (expected-counts-waived> ?a ?b)))
  :answers ((association> ?a ?b))
  :r-code "chisq.test(table(data${a}, data${b}))"
  :sources ("Pearson (1900), Philosophical Magazine 50:157"))

(define-method common-core fisher-exact-test
  :parameters (?f frame ?a variable ?b variable)
  :requires ((categorical ?a) (categorical ?b) (not (eql ?a ?b)) (rows-independent ?f))
  :answers ((association> ?a ?b))
  :r-code "fisher.test(table(data${a}, data${b}))"
  :sources ("Fisher (1922), Journal of the Royal Statistical Society 85:87"))
