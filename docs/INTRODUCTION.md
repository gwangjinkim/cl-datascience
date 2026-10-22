---
title: "cl-datascience: An Introduction"
subtitle: "Asking statistical questions in Common Lisp - the DSL as of October 2026"
author: "Gwang-Jin Kim, with A.J. Rossini"
date: "22 October 2026"
---

# In one page {-}

`cl-datascience` is a domain-specific language for data science practice,
written in Common Lisp. Its idea is simple:

- **You ask a question, not for a method.** `compare`, `associate`,
  `estimate` and `model` say what you want to know. You do not say
  "t-test".
- **You may say what you know about the data.** Each patient received both
  drugs; this is a randomised trial; the rows are repeated measurements on
  the same chicks. Declarations are optional.
- **A planner chooses the analysis.** Every statistical method is a rule:
  what it requires and what it delivers. A general problem solver (the
  wouldwork planner) finds every way to answer the question from what is
  known.
- **Rules guide; they do not forbid.** Assumptions a method makes are
  written into the plan. Methods that go against a recommendation stay
  available, ranked lower, labelled, with the rule they break and its
  sources.
- **It works on tibbles.** The data are tibbles from the Common Lisp
  tidyverse (cl-tibble, cl-dplyr, cl-readr); the verbs sit at the end of a
  tidyverse pipeline.
- **It is checked against R.** Every example has an R reference; the rules
  cite textbooks, papers and regulatory guidelines.

A first taste:

```lisp
(in-package :clds-user)

(-> (read-csv "sleep.csv")
    (declare-paired :id :id :within :group)
    (compare :extra :by :group))
;; 1. acceptable (cost 1): assume-normality extra group, paired-t-test ...
;;    R: with(data, t.test(extra[group == second], extra[group == first], paired = TRUE))
```

This document introduces what exists today on the branch
`experiment/guided-rules` of the repository
(github.com/gwangjinkim/cl-datascience). The design behind it is in
`docs/DESIGN.md`.

# Getting started

**What you need**

- SBCL with Quicklisp (`~/quicklisp`), or Roswell. Both are supported
  equally.
- The wouldwork planner (Quicklisp installs it; Roswell finds a local
  checkout).
- The Common Lisp tidyverse packages (cl-tibble, cl-dplyr, cl-readr, ...)
  in `~/projects/cl/`, or in the directory named by `CLDS_TIDYVERSE_DIR`.
- For the R references only: uvr, which pins R 4.6.1 and the packages.

**Loading**

```lisp
(pushnew #p"~/projects/cl/" ql:*local-project-directories* :test #'equal)
(ql:register-local-projects)
(push #p"~/cl-datascience/" asdf:*central-registry*)
(ql:quickload :cl-datascience/dsl)
(in-package :clds-user)        ; the tidyverse and the DSL, no prefixes
```

**Running the tests** (234 checks, both Lisp setups):

```sh
scripts/test.sh            # SBCL + ~/quicklisp, then Roswell
```

# Your first question

The `sleep` data (Student, 1908): extra hours of sleep for 10 patients
under two drugs. Asked plainly, with nothing declared:

```lisp
(defparameter *sleep* (read-csv "examples/stat101/01-sleep/data.csv"))
(compare *sleep* :extra :by :group)
```

```
#<ANALYSIS-RESULT compare extra by group (aim: difference, estimand: mean,
                                          rule book: general)
  known: (numeric extra); (categorical group); (two-levels group)
  1. acceptable (cost 2): (assume-rows-independent data),
       (assume-normality extra group), (welch-t-test data extra group)
       R: t.test(extra ~ group, data = data)
  2. acceptable (cost 3): (assume-rows-independent data),
       (assume-equal-variances extra group), (assume-normality extra group),
       (student-t-test data extra group)
       R: t.test(extra ~ group, data = data, var.equal = TRUE)>
```

How to read it:

- **known** - the facts the planner used. Here they come from the data and
  the question: `extra` is numeric, `group` is the grouping and has two
  levels.
- **the plans** - every minimal way to answer, cheapest first. A plan is a
  list of steps; the last step is the method.
- **assumptions are steps** - `assume-rows-independent` and
  `assume-normality` are what R's `t.test` assumes silently. Here they are
  written down.
- **cost and category** - each assumption costs 1. Welch's test needs one
  assumption less than Student's, so it comes first, as current advice
  recommends (Delacre, Lakens and Leys, 2017).
- **R** - the equivalent R call, to check the result or to run it.

# Saying what you know

Every patient received both drugs. Saying so changes the analysis:

```lisp
(-> *sleep*
    (declare-paired :id :id :within :group)
    (compare :extra :by :group))
```

```
  known: ...; (paired-by> data id group)
  1. acceptable (cost 1): (assume-normality extra group),
       (paired-t-test data extra group id)
```

`declare-paired` returns a **statframe**: a tibble (a CLOS subclass of
`cl-tibble:tbl`) that also carries declared facts. `compare` is a generic
function; with a statframe the declared facts take part, and the planner
finds the paired test. Welch's test is gone: it needs independent rows,
and the declaration says they are not.

**The question can change too.** A rank test answers a different question
(does the location differ?) and is chosen only when that is asked:

```lisp
(-> *sleep* (declare-paired :id :id :within :group)
    (compare :extra :by :group :estimand :location))
;; 1. recommended (cost 0): (signed-rank-test data extra group id)
```

**What a check found becomes a fact.** If a check of the residuals found
them clearly non-normal, the mean-based tests are not forbidden; they need
a departure step and are labelled:

```lisp
(-> *sleep*
    (declare-observed '(:nonnormal-residuals> :extra :group))
    (compare :extra :by :group))
```

```
  1. discouraged (cost 6): (assume-rows-independent data),
       (depart-normality extra group), (welch-t-test data extra group)
       departs from: A mean-based test on small groups that a check found
         clearly non-normal: its error rates and power can be poor.
         Consider the location question (a rank test) or larger groups.
       sources: Fagerland and Sandvik (2009), Contemporary Clinical Trials
         30:490; visStatistics 0.3.0 vignette, section 8
```

# The verbs

**Questions** - each takes the data first, so it ends a pipeline:

| Verb | Asks | Example |
|--------|------|-------|
| `compare` | does an outcome differ between groups? | `(compare d :extra :by :group)` |
| `compare ... :aim :pairwise` | which groups differ? | `(compare d :postwt :by :treat :aim :pairwise)` |
| `compare ... :aim :equivalence` | are the groups equivalent within a margin? | after `declare-margin` |
| `compare ... :aim :baseline-balance` | were randomised groups alike at baseline? | in a trial |
| `compare ... :aim :effect-modification :within s` | does the effect differ between subgroups? | `:within :sex` |
| `compare ... :estimand :location` | does the location differ (rank methods)? | |
| `associate` | are two categorical variables associated? | `(associate d :treated :cured)` |
| `estimate` | what share takes a value, how precisely? | `(estimate d :stanza :of "B")` |
| `model` | a regression model | `(model d :low :with '(:age :lwt :smoke))` |
| `model ... :purpose :prediction` | how well does it predict? | |
| `model ... :selection t` | a smaller model | |

**Declarations** - each returns a new statframe:

| Verb | Says |
|-----|-----|
| `declare-paired :id :within` | each unit was measured under every level |
| `declare-clustered :by` | rows come in clusters (repeated measurements, centres) |
| `declare-independent`, `declare-time-ordered` | how the rows relate |
| `declare-trial :arm :stratified-by` | a randomised trial (selects the clinical rules) |
| `declare-baseline :of :baseline` | a column is the outcome measured before treatment |
| `declare-survival :time :event` | a time to an event, with censoring |
| `declare-dichotomized v :from c` | a variable was made by cutting a continuous one |
| `declare-margin :outcome :by :margin` | a pre-specified equivalence margin |
| `declare-prespecified s` | a subgroup analysis was pre-specified |
| `declare-observed fact ...` | what a check found |
| `declare-fact fact` | any fact, for experts |

Some facts need no declaration; they are read from the data: numeric or
categorical, the number of levels, whether all groups have at least 30
values, missing values, too few successes for a proportion, too few
observations per model parameter, small expected counts in a table.

# How answers are ranked

Every step in a plan is one of four kinds:

| Kind | Example | Cost |
|---|---|---|
| method | `welch-t-test` | 0 |
| assumption | `assume-normality` | 1-2 |
| caveat (a label the plan must carry) | `label-exploratory` | 1-2 |
| departure from a rule | `depart-normality` | 3-9 for recommendations, 10 and more for principles |

The cost of a plan is the sum of its steps. Its category:

| Category | Meaning |
|---|---|
| recommended | no assumption, no departure |
| acceptable | assumptions or caveats only |
| discouraged | departs from a recommendation |
| against guidance | departs from a principle |

Nothing is refused. A plan "against guidance" is still shown, with the
rule and its sources, because sometimes one has to go against a rule - but
it should be visible that one does.

# Rule books

Rules live in **rule books**, CLOS objects that can include each other:

```
common-core  <-  general  <-  clinical
```

| Book | Used for | Content | Main sources |
|--|---|------|------|
| common-core | (included) | the test choices shared by R packages that choose tests: Welch, Student, Wilcoxon, paired tests, ANOVA, Welch ANOVA, Kruskal-Wallis, chi-square, Fisher | visStatistics, testflow, rstatix, AssumpSure (re-encoded, no code copied) |
| general | every plain tibble | proportions (Wilson, exact, Wald), adjusted pairwise comparisons, repeated measurements, missing values, regression models (overfitting, penalisation, no stepwise selection), validated prediction | Introduction to Modern Statistics; Harrell, Regression Modeling Strategies; An Introduction to Statistical Learning; Regression and Other Stories; EMA guidance on multiplicity and missing data; Sterne et al. 2009 |
| clinical | statframes declared with `declare-trial` | baseline and stratification adjustment, no within-group tests, no baseline significance tests, subgroups by interaction, equivalence margins, no dichotomising, survival with censoring | EMA guideline on baseline covariates; ICH E9(R1); CONSORT 2010; Bland and Altman; Vickers and Altman; Altman and Royston |

The catalogues are in `docs/PRIOR-ART-R.md`, `docs/GENERAL-RULES.md` and
`docs/CLINICAL-RULES.md`.

**A trial.** The anorexia data (three arms, weight before and after),
declared as a trial with a baseline:

```lisp
(-> (read-csv "examples/clinical/01-anorexia/data.csv")
    (declare-trial :arm :treat)
    (declare-baseline :of :postwt :baseline :prewt)
    (compare :postwt :by :treat))
```

```
  1. acceptable (cost 1): (assume-normality postwt treat),
       (adjusted-regression data postwt treat)
       R: lm(postwt ~ treat + prewt, data = data)
  2. discouraged (cost 4): (depart-unadjusted-change postwt), ...,
       (change-score-test data postwt treat prewt)
  3. discouraged (cost 6): (depart-baseline-adjustment postwt), ...,
       (welch-anova data postwt treat)
  4. discouraged (cost 7): ... (one-way-anova data postwt treat)
  5. against-guidance (cost 20): (depart-within-group-comparison treat),
       (within-group-tests data postwt treat prewt)
       departs from: Testing the change from baseline separately in each
         randomised group and comparing the verdicts is invalid ...
       sources: Bland and Altman (2011), Trials 12:264
```

R agrees with the ranking: analysis of covariance gives the smallest
standard error (1.89 for CBT against control, against 1.97 ignoring the
baseline and 2.03 for the change score), and within-group tests show the
trap (control p = 0.78, CBT p = 0.035 - which says nothing about whether
CBT works better than control).

**Repeated measurements.** ChickWeight has 578 rows from 50 chicks:

```lisp
(-> (read-csv "examples/general/02-chickweight/data.csv")
    (declare-clustered :by :chick)
    (compare :weight :by :diet))
;; 1. recommended: (mixed-model data weight diet chick)
;; 2. recommended: (summary-measure-analysis data weight diet chick)
;; 3. against-guidance (cost 10): (depart-ignore-clustering data),
;;      (welch-anova data weight diet)
```

In R, treating the rows as independent gives p = 6e-7 with 264 degrees of
freedom; one final weight per chick gives p = 0.012.

**A proportion.** Three of six stanzas are "B":

```lisp
(estimate (read-csv "examples/general/01-proportion/stanza.csv") :stanza :of "B")
;; 1. recommended (cost 0): (wilson-interval stanza)
;; 2. acceptable (cost 1): (note-conservative stanza), (exact-interval stanza)
;; 3. discouraged (cost 6): (depart-success-failure stanza), ..., (wald-interval stanza)
```

**A model.** Low birth weight with eight candidate predictors:

```lisp
(model (read-csv "examples/general/04-birthwt/data.csv") :low
       :with '(:age :lwt :race :smoke :ptl :ht :ui :ftv))
;; known: ... (few-observations-per-parameter low)
;; 1. acceptable (cost 2): (assume-linearity low), (assume-rows-independent data),
;;      (penalized-regression data low)
;; 3. discouraged (cost 7): (depart-overfitting low), ..., (regression-model data low)
```

Nine parameters for an effective sample size of 121.7 exceed Harrell's
limit of one parameter per 15 (8.1), so penalisation comes first.

# Writing rules

A rule book is written with defining forms. A method states what it
requires and what it answers; an assumption or departure states its
strength, what it says, and its sources:

```lisp
(define-method common-core welch-t-test
  :parameters (?f frame ?y variable ?g variable)
  :requires ((numeric ?y) (two-levels ?g) (rows-independent ?f)
             (or (normal-residuals> ?y ?g) (large-groups> ?y ?g)
                 (normality-waived> ?y ?g)))
  :answers ((mean-difference> ?y ?g))
  :r-code "t.test({y} ~ {g}, data = data)"
  :sources ("Welch (1947), Biometrika 34:28"))

(define-departure clinical depart-within-group-comparison
  :parameters (?g variable)
  :requires ((randomized ?g))
  :asserts (within-group-chosen ?g)
  :strength 20
  :statement "Separate tests against baseline in each arm are invalid ..."
  :sources ("Bland and Altman (2011), Trials 12:264"))
```

A book can add conditions to the methods it includes without rewriting
them. In the clinical book, every mean comparison must adjust for a
declared baseline, or depart:

```lisp
(define-requirement clinical adjust-for-baseline
  :answers mean-difference>
  :requires ((or (not (exists (?b variable) (baseline-of> ?b ?y)))
                 (baseline-adjustment-waived ?y))))
```

The kinds of rule are CLOS classes (`method-rule`, `assumption-rule`,
`departure-rule`, `caveat-rule`, `requirement-rule`, `constraint-rule`,
`relation-rule`). Generic functions turn each into planner input, so a new
kind of rule is a new class with its methods.

# Under the hood

```
 tibble / statframe --role-facts, declared-facts--> facts
 question (compare, ...) --question-goal-----------> goal
 rule book --relevant rules, compiled--------------> planner domain
                                                        |
                                      wouldwork: every minimal plan
                                                        |
                       guidance: cost, category, rules, sources, R code
                                                        |
                                                analysis-result
```

1. **Facts** come from the question's roles and the values (any tibble),
   and from declarations (statframes only) - chosen by CLOS dispatch.
2. **The goal** comes from the question: `(mean-difference> extra group)`,
   `(survival-difference> time rx)`, `(proportion-estimated stanza)`, ...
3. **The domain**: the rule book's rules relevant to the goal, found
   backwards from the goal, written as a wouldwork problem.
4. **The planner** (wouldwork, a classical planner in Common Lisp in the
   tradition of GPS and STRIPS) returns every plan; plans containing all
   steps of another plan are dropped, so an assumption appears only when a
   plan needs it.
5. **Guidance** gives each plan its cost and category, the rules it
   departs from, and the R code of its methods.

# Checked against R

Every example has an R reference, run with uvr (R 4.6.1), whose output and
expected numbers are committed:

| Tier | Examples |
|---|---|
| `examples/stat101/` | one variable (Rossini's datasets), sleep, cars, ToothGrowth, UCBAdmissions, faithful |
| `examples/general/` | a proportion, ChickWeight, airquality (missing values, with mice), birthwt (model), pairwise comparisons |
| `examples/clinical/` | anorexia (baseline, within-group tests, dichotomising, equivalence), colon cancer trial (survival, subgroups) |

234 tests check that each question gives the expected plans, under SBCL
with Quicklisp and under Roswell.

# What it does not do yet

- **It plans; it does not compute.** Results list the plans and their R
  code; executing them (in Lisp or through R) is the next step.
- **Declarations do not survive every tidyverse verb.** `filter` or
  `mutate` on a statframe return a plain tibble; the facts must be
  carried along by methods on those verbs.
- **Checks are not run.** "Non-normal residuals" is declared with
  `declare-observed`; a `check` verb should compute it.
- **Facts from rows can mislead.** "Large groups" counts rows, also when
  rows are repeated measurements on fewer units.
- **The costs are proposals.** The sources agree on which analysis to
  prefer, not on numbers.
- **It is an experiment.** The branch `experiment/guided-rules` is not
  meant to be merged as it is; what proves itself is to be rebuilt on a
  normal branch.

# Where to find things {-}

| Path | Content |
|-----|-----|
| `src/planner.lisp` | the bridge to wouldwork (`find-plans`) |
| `src/guidance.lisp` | costs and categories of plans |
| `src/dsl/rules.lisp` | rule classes, rule books, compilation |
| `src/dsl/common-core.lisp`, `general.lisp`, `clinical.lisp` | the three rule books |
| `src/dsl/frame.lisp` | statframes and declaration verbs |
| `src/dsl/questions.lisp` | questions, verbs, results |
| `src/dsl/user.lisp` | the `clds-user` package |
| `docs/DESIGN.md` | the design document |
| `docs/*-RULES.md`, `docs/PRIOR-ART-R.md` | rule catalogues and their sources |
| `EXPERIMENT.md` | what the experiment tests and how to judge it |
