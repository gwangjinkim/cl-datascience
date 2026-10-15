;;;; src/dsl/general.lisp - EXPERIMENT (branch experiment/guided-rules)
;;;;
;;;; The general rule book: the common core plus rules from well-regarded
;;;; textbooks and guidance (docs/GENERAL-RULES.md, rules G1-G7). It is the
;;;; default for plain tibbles; the clinical rule book includes it.

(in-package #:cl-datascience)

(define-rule-book general
  :includes (common-core)
  :documentation "General statistical practice: proportions, pairwise
comparisons, repeated measurements, missing values, regression models and
predictive performance.")

;;; Facts

(define-relation general clustered-by> frame variable)
(define-relation general missing-values variable)
(define-relation general missingness-ignorable variable)
(define-relation general missing-at-random variable)
(define-relation general single-imputation-chosen variable)
(define-relation general few-successes variable)
(define-relation general normal-approximation variable)
(define-relation general success-failure-waived variable)
(define-relation general conservative-noted variable)
(define-relation general multiplicity-ignored variable)
(define-relation general binary-outcome variable)
(define-relation general predictor> variable variable)                ; (predictor> x y)
(define-relation general few-observations-per-parameter variable)
(define-relation general overfitting-accepted variable)
(define-relation general linear-effects variable)
(define-relation general stepwise-chosen variable)
(define-relation general selection-instability-noted variable)
(define-relation general apparent-chosen variable)
(define-relation general holdout-noted variable)
;; answers
(define-relation general proportion-estimated variable)
(define-relation general pairwise-compared> variable variable)
(define-relation general model-fitted variable)
(define-relation general reduced-model variable)
(define-relation general performance-estimated variable)

;;; G3: rows in clusters are not independent - the common core's
;;; assumption is replaced by one that also yields to a declared clustering.

(define-assumption general assume-rows-independent
  :parameters (?f frame)
  :asserts (rows-independent ?f)
  :unless-known ((row-order-time ?f)
                 (exists ((?a ?b) variable) (paired-by> ?f ?a ?b))
                 (exists (?c variable) (clustered-by> ?f ?c)))
  :statement "Rows are taken as independent observations; independence cannot be tested from the data and follows from the design."
  :sources ("testflow 1.0.0 documentation, section Assumption checks"
            "Cetinkaya-Rundel and Hardin, Introduction to Modern Statistics, 2nd ed., section 22.3"))

(define-departure general depart-ignore-clustering
  :parameters (?f frame)
  :requires ((exists (?c variable) (clustered-by> ?f ?c)))
  :asserts (rows-independent ?f)
  :strength 10
  :statement "Rows from the same unit (repeated measurements, patients in one centre) are treated as independent: standard errors are too small and p-values too small. Use a mixed model or one summary value per unit."
  :sources ("Matthews et al. (1990), BMJ 300:230" "Bland and Altman (1994), BMJ 308:896"
            "Moher et al. (2010), CONSORT 2010 explanation and elaboration, BMJ 340:c869, item 12a"))

(define-method general mixed-model
  :parameters (?f frame ?y variable ?g variable ?c variable)
  :requires ((numeric ?y) (categorical ?g) (clustered-by> ?f ?c) (not (eql ?g ?c))
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g)))
  :answers ((mean-difference> ?y ?g))
  :r-code "nlme::lme({y} ~ {g}, random = ~ 1 | {c}, data = data)"
  :sources ("Bland and Altman (1994), BMJ 308:896"))

(define-method general summary-measure-analysis
  :parameters (?f frame ?y variable ?g variable ?c variable)
  :requires ((numeric ?y) (categorical ?g) (clustered-by> ?f ?c) (not (eql ?g ?c)))
  :answers ((mean-difference> ?y ?g))
  :r-code "one summary value of {y} per {c} (final value, slope or area under the curve), then compare by {g}"
  :sources ("Matthews et al. (1990), BMJ 300:230"))

;;; G4: missing outcome values

(define-requirement general missing-outcomes-need-a-strategy
  :answers mean-difference>
  :requires ((or (not (missing-values ?y)) (missingness-ignorable ?y)))
  :sources ("EMA (2010), Guideline on missing data in confirmatory clinical trials, EMA/CPMP/EWP/1776/99 Rev. 1, section 6.2"))

(define-assumption general assume-ignorable-missingness
  :parameters (?y variable)
  :requires ((missing-values ?y))
  :asserts (missingness-ignorable ?y)
  :strength 2
  :statement "Analysing complete cases only: unbiased only if whether a value is missing does not depend on the value itself given the variables in the model; it loses precision, and is not acceptable as the primary analysis of a confirmatory trial."
  :sources ("EMA (2010), EMA/CPMP/EWP/1776/99 Rev. 1, section 6.2"
            "Sterne et al. (2009), BMJ 338:b2393"))

(define-assumption general assume-missing-at-random
  :parameters (?y variable)
  :requires ((missing-values ?y))
  :asserts (missing-at-random ?y)
  :statement "Missing values are taken to be missing at random: any difference between missing and observed values is explained by observed variables, which must be in the imputation model."
  :sources ("Sterne et al. (2009), BMJ 338:b2393"))

(define-departure general depart-single-imputation
  :parameters (?y variable)
  :requires ((missing-values ?y))
  :asserts (single-imputation-chosen ?y)
  :strength 10
  :statement "Single imputation (the mean, the last observation carried forward, a missing-value category) treats guesses as data: standard errors are too small and estimates can be seriously biased."
  :sources ("Sterne et al. (2009), BMJ 338:b2393"
            "EMA (2010), EMA/CPMP/EWP/1776/99 Rev. 1, section 6.3.1"))

(define-method general multiple-imputation
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (categorical ?g) (rows-independent ?f) (missing-values ?y)
             (missing-at-random ?y)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g)))
  :answers ((mean-difference> ?y ?g))
  :r-code "mice::D1(with(imp <- mice::mice(data, m = 20), lm({y} ~ {g})), with(imp, lm({y} ~ 1)))"
  :sources ("Sterne et al. (2009), BMJ 338:b2393"))

(define-method general single-imputation
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (categorical ?g) (missing-values ?y) (single-imputation-chosen ?y))
  :answers ((mean-difference> ?y ?g))
  :r-code "replace each missing {y} by the mean (or the last value), then oneway.test({y} ~ {g}, data = data)"
  :sources ("Sterne et al. (2009), BMJ 338:b2393"))

;;; G1: a proportion

(define-assumption general assume-normal-approximation
  :parameters (?y variable)
  :requires ((categorical ?y))
  :asserts (normal-approximation ?y)
  :statement "The sample proportion is taken to be normally distributed (Wald interval); its coverage is erratic, even in large samples."
  :sources ("Cetinkaya-Rundel and Hardin, Introduction to Modern Statistics, 2nd ed., section 16.2.1"
            "Brown, Cai and DasGupta (2001), Statistical Science 16:101"))

(define-departure general depart-success-failure
  :parameters (?y variable)
  :requires ((few-successes ?y))
  :asserts (success-failure-waived ?y)
  :strength 5
  :statement "Fewer than 10 successes or fewer than 10 failures: the normal approximation does not hold. Use the Wilson or the exact interval."
  :sources ("Cetinkaya-Rundel and Hardin, Introduction to Modern Statistics, 2nd ed., section 16.2.1"))

(define-caveat general note-conservative
  :parameters (?y variable)
  :requires ((categorical ?y))
  :asserts (conservative-noted ?y)
  :strength 1
  :statement "The exact (Clopper-Pearson) interval is conservative: it covers the true share more often than stated, so it is wider than needed."
  :sources ("Brown, Cai and DasGupta (2001), Statistical Science 16:101"))

(define-method general wilson-interval
  :parameters (?y variable)
  :requires ((categorical ?y))
  :answers ((proportion-estimated ?y))
  :r-code "prop.test(x, n, correct = FALSE)$conf.int  # x: count of the level in {y}, n: non-missing {y}"
  :sources ("Wilson (1927), Journal of the American Statistical Association 22:209"
            "Brown, Cai and DasGupta (2001), Statistical Science 16:101"))

(define-method general exact-interval
  :parameters (?y variable)
  :requires ((categorical ?y) (conservative-noted ?y))
  :answers ((proportion-estimated ?y))
  :r-code "binom.test(x, n)$conf.int  # x: count of the level in {y}, n: non-missing {y}"
  :sources ("Clopper and Pearson (1934), Biometrika 26:404"))

(define-method general wald-interval
  :parameters (?y variable)
  :requires ((categorical ?y) (normal-approximation ?y)
             (or (not (few-successes ?y)) (success-failure-waived ?y)))
  :answers ((proportion-estimated ?y))
  :r-code "p + c(-1, 1) * qnorm(0.975) * sqrt(p * (1 - p) / n)  # p: share of the level in {y}"
  :sources ("Cetinkaya-Rundel and Hardin, Introduction to Modern Statistics, 2nd ed., section 16.2"))

;;; G2: pairwise comparisons

(define-departure general depart-multiplicity
  :parameters (?g variable)
  :requires ((several-levels ?g))
  :asserts (multiplicity-ignored ?g)
  :strength 8
  :statement "Several pairwise tests without adjustment: the chance of at least one false positive grows with the number of tests (three tests at 0.05: up to 0.14). Adjust (Holm, Tukey, Games-Howell) or pre-specify the comparisons."
  :sources ("Bland and Altman (1995), BMJ 310:170"
            "Cetinkaya-Rundel and Hardin, Introduction to Modern Statistics, 2nd ed., chapter 22"
            "EMA (2002), Points to consider on multiplicity issues in clinical trials, CPMP/EWP/908/99, section 2"))

(define-method general games-howell
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (several-levels ?g) (rows-independent ?f)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g)))
  :answers ((pairwise-compared> ?y ?g))
  :r-code "rstatix::games_howell_test(data, {y} ~ {g})"
  :sources ("Games and Howell (1976), Journal of Educational Statistics 1:113"))

(define-method general pairwise-holm
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (several-levels ?g) (rows-independent ?f)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g)))
  :answers ((pairwise-compared> ?y ?g))
  :r-code "pairwise.t.test(data${y}, data${g}, p.adjust.method = \"holm\", pool.sd = FALSE)"
  :sources ("Holm (1979), Scandinavian Journal of Statistics 6:65"))

(define-method general tukey-hsd
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (several-levels ?g) (rows-independent ?f)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g) (normality-waived> ?y ?g))
             (or (equal-variances> ?y ?g) (equal-variances-waived> ?y ?g)))
  :answers ((pairwise-compared> ?y ?g))
  :r-code "TukeyHSD(aov({y} ~ {g}, data = data))"
  :sources ("Tukey (1949), Biometrics 5:99"))

(define-method general unadjusted-pairwise-tests
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (several-levels ?g) (multiplicity-ignored ?g))
  :answers ((pairwise-compared> ?y ?g))
  :r-code "pairwise.t.test(data${y}, data${g}, p.adjust.method = \"none\")"
  :sources ("Bland and Altman (1995), BMJ 310:170"))

;;; G5: regression models

(define-assumption general assume-linearity
  :parameters (?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)))
  :asserts (linear-effects ?y)
  :statement "Each continuous predictor is taken to act linearly; unless linearity is known, splines are safer."
  :sources ("Harrell, Regression Modeling Strategies, course notes, sections 4.1 and 4.12.1"
            "Gelman, Hill and Vehtari (2020), Regression and Other Stories, section 11.1"))

(define-departure general depart-overfitting
  :parameters (?y variable)
  :requires ((few-observations-per-parameter ?y))
  :asserts (overfitting-accepted ?y)
  :strength 5
  :statement "More parameters than about one per 15 effective observations (for a binary outcome m = 3nq(1-q), for survival the number of events): the model will be overfitted. Penalise, or reduce the predictors without looking at the outcome."
  :sources ("Harrell, Regression Modeling Strategies, course notes, section 4.4"))

(define-method general regression-model
  :parameters (?f frame ?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)) (rows-independent ?f) (linear-effects ?y)
             (or (not (few-observations-per-parameter ?y)) (overfitting-accepted ?y)))
  :answers ((model-fitted ?y))
  :r-code "glm({y} ~ {predictors}, data = data)  # family for the outcome type"
  :sources ("Gelman, Hill and Vehtari (2020), Regression and Other Stories"))

(define-method general spline-regression
  :parameters (?f frame ?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)) (rows-independent ?f)
             (or (not (few-observations-per-parameter ?y)) (overfitting-accepted ?y)))
  :answers ((model-fitted ?y))
  :r-code "rms::lrm({y} ~ {predictors}, data = data)  # with rcs(x, 3) for each continuous predictor"
  :sources ("Harrell, Regression Modeling Strategies, course notes, sections 4.1 and 4.12.1"))

(define-method general penalized-regression
  :parameters (?f frame ?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)) (rows-independent ?f) (linear-effects ?y))
  :answers ((model-fitted ?y))
  :r-code "glmnet::cv.glmnet(model.matrix(~ {predictors}, data)[, -1], data${y}, alpha = 0)  # ridge"
  :sources ("Harrell, Regression Modeling Strategies, course notes, sections 4.5-4.7"))

;;; G6: choosing predictors

(define-departure general depart-stepwise
  :parameters (?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)))
  :asserts (stepwise-chosen ?y)
  :strength 10
  :statement "Stepwise selection gives biased coefficients, too-small standard errors and p-values, and often keeps noise variables while dropping true predictors."
  :sources ("Harrell, Regression Modeling Strategies, course notes, section 4.3"))

(define-caveat general note-selection-instability
  :parameters (?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)))
  :asserts (selection-instability-noted ?y)
  :strength 2
  :statement "Penalised selection (the lasso) chooses predictors unstably between samples; report the selection with that caveat."
  :sources ("Harrell, Regression Modeling Strategies, course notes, section 4.5"))

(define-method general data-reduction
  :parameters (?f frame ?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)))
  :answers ((reduced-model ?y))
  :r-code "summarise correlated predictors without {y} (Hmisc::varclus, principal components), then fit {y} on the summaries"
  :sources ("Harrell, Regression Modeling Strategies, course notes, section 4.7"))

(define-method general lasso-selection
  :parameters (?f frame ?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)) (rows-independent ?f)
             (selection-instability-noted ?y))
  :answers ((reduced-model ?y))
  :r-code "glmnet::cv.glmnet(model.matrix(~ {predictors}, data)[, -1], data${y}, alpha = 1)"
  :sources ("Harrell, Regression Modeling Strategies, course notes, section 4.5"))

(define-method general stepwise-selection
  :parameters (?f frame ?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)) (stepwise-chosen ?y))
  :answers ((reduced-model ?y))
  :r-code "step(glm({y} ~ {predictors}, data = data))"
  :sources ("Harrell, Regression Modeling Strategies, course notes, section 4.3"))

;;; G7: predictive performance

(define-departure general depart-apparent-performance
  :parameters (?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)))
  :asserts (apparent-chosen ?y)
  :strength 10
  :statement "Performance measured on the data used to fit the model (training error) is optimistic; estimate it on data not used for fitting (bootstrap, cross-validation)."
  :sources ("James, Witten, Hastie and Tibshirani, An Introduction to Statistical Learning, 2nd ed., sections 2.2 and 5.1"
            "Harrell, Regression Modeling Strategies, course notes, section 4.12"))

(define-caveat general note-holdout
  :parameters (?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)))
  :asserts (holdout-noted ?y)
  :strength 2
  :statement "A single train/test split uses part of the data only and varies from split to split; it is reasonable only for very large samples."
  :sources ("Harrell, Regression Modeling Strategies, course notes, chapter 4"
            "James, Witten, Hastie and Tibshirani, An Introduction to Statistical Learning, 2nd ed., section 5.1.1"))

(define-method general bootstrap-validation
  :parameters (?f frame ?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)) (rows-independent ?f))
  :answers ((performance-estimated ?y))
  :r-code "rms::validate(rms::lrm({y} ~ {predictors}, data = data, x = TRUE, y = TRUE), B = 200)"
  :sources ("Harrell, Regression Modeling Strategies, course notes, section 4.12"))

(define-method general cross-validation
  :parameters (?f frame ?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)) (rows-independent ?f))
  :answers ((performance-estimated ?y))
  :r-code "10-fold cross-validation of glm({y} ~ {predictors}), e.g. boot::cv.glm(data, fit, K = 10)"
  :sources ("James, Witten, Hastie and Tibshirani, An Introduction to Statistical Learning, 2nd ed., section 5.1"))

(define-method general holdout-validation
  :parameters (?f frame ?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)) (rows-independent ?f) (holdout-noted ?y))
  :answers ((performance-estimated ?y))
  :r-code "fit on a random part of the rows, measure performance on the rest"
  :sources ("James, Witten, Hastie and Tibshirani, An Introduction to Statistical Learning, 2nd ed., section 5.1.1"))

(define-method general apparent-performance
  :parameters (?f frame ?y variable)
  :requires ((exists (?x variable) (predictor> ?x ?y)) (apparent-chosen ?y))
  :answers ((performance-estimated ?y))
  :r-code "performance of glm({y} ~ {predictors}) measured on the same rows it was fitted to"
  :sources ("James, Witten, Hastie and Tibshirani, An Introduction to Statistical Learning, 2nd ed., section 2.2"))
