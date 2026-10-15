# Experiment: guided rules (branch experiment/guided-rules)

**This branch is an experiment. Do not merge it into `main` or into
`examples/stat101`.** It tests an idea; what works is later rebuilt on a
normal branch, test first, with its own review.

## Question

Statistics books, guidelines and regulators give many rules for which
analysis is allowed. A system that enforces them strictly is wrong in
practice: "one sometimes has to go over them" (A.J. Rossini). Can the
planner *guide* towards the recommended analysis while still offering
every other analysis, ranked, labelled and with its reasons?

## Idea

Every rule is a cost with a source, never a wall:

| Rule kind | In the planner | Cost | Plan category |
|---|---|---|---|
| mathematical requirement (a two-group test needs two groups) | precondition | cannot be planned (a direct method call is still possible) | - |
| assumption (rows independent) | `assume-...` step | low | acceptable |
| guidance (adjust for baseline; no tests of baseline balance) | `depart-...` step | medium | discouraged |
| principle (nothing explains a randomized or designed variable) | `depart-...` step | high | against guidance |
| a departure with a declared justification | `depart-...` step, fact `(justified depart-...)` | low | justified departure |

The strengths, the wording of each rule and its sources live in one file,
`examples/guidance.lisp`. `guided-plans` returns every minimal plan with
its cost, category, assumptions and departures, cheapest first.

## What changed compared with examples/stat101

- The design-consistency constraint in `examples/stat101/domain.lisp` is
  softened: explaining a variable set by design is possible after the step
  `depart-design-consistency`. Example 03 therefore gets a plan where it
  had none, labelled "against guidance".
- A clinical tier, `examples/clinical/`, starts with the `anorexia` trial
  (MASS): baseline and follow-up weights in three arms.

## How to judge the experiment

- Does the ranking match what the sources recommend?
- Are the labels and reasons understandable to an analyst?
- Does the search stay fast as departures multiply the plans?
- Which costs had to be invented, and are they defensible?

## Part 2: a CLOS DSL on tidyverse tibbles

The common core of four R packages that choose tests (docs/PRIOR-ART-R.md)
re-encoded as a **rule book** of CLOS objects (src/dsl/), used from tibbles
of the Common Lisp tidyverse:

```lisp
(-> (read-csv "sleep.csv")
    (declare-paired :id :id :within :group)
    (compare :extra :by :group))
;; => #<ANALYSIS-RESULT compare extra by group (estimand: mean)
;;      1. acceptable (cost 1): assume-normality, paired-t-test ...
;;         R: with(data, t.test(..., paired = TRUE))>
```

- Rules: `rule` with subclasses `relation-rule`, `method-rule`,
  `assumption-rule`, `departure-rule`, `constraint-rule`, collected in a
  `rule-book`; defining macros `define-method`, `define-assumption`,
  `define-departure`, ...; generic functions `rule-precondition`,
  `rule-effects`, `rule->wouldwork` compile a book into a planner domain.
- Data: `statframe`, a CLOS subclass of `cl-tibble:tbl`, carries declared
  and observed facts; declaration verbs (`declare-paired`,
  `declare-observed`, ...) take the data first and return a new statframe.
- Questions: `comparison` and `association` objects; `compare` and
  `associate` are generic functions on tibbles; facts come from
  `role-facts` (roles and values, any tibble) and `declared-facts`
  (statframes only), chosen by dispatch.
- Answers: `analysis-result` with every minimal plan ranked and labelled,
  printed with the R equivalent of each method and the rule and sources of
  each departure.

Differences from the R packages: the estimand is part of the question; no
assumption test gates the choice on the same data; large groups make
normality unnecessary for mean-based tests; non-recommended methods stay
available after a recorded departure.

## Part 3: a clinical rule book from the literature

`docs/CLINICAL-RULES.md` lists ten rules (C1-C10) taken from openly
available sources: the EMA guideline on baseline covariates (2015), ICH
E9(R1), CONSORT 2010, Bland and Altman (2011) and the BMJ Statistics Notes.
`src/dsl/clinical.lisp` encodes them as a rule book that **includes** the
common core:

- `define-requirement` adds conditions to the included methods without
  redefining them (every mean comparison must adjust for a declared
  baseline and for stratification factors, or depart);
- `define-caveat` adds labels a plan must carry (exploratory subgroups);
- a statframe declared with `declare-trial` uses the clinical book;
  `declare-baseline`, `declare-survival`, `declare-dichotomized`,
  `declare-margin`, `declare-prespecified` add the facts;
- `compare` takes `:aim` (`:difference`, `:equivalence`,
  `:baseline-balance`, `:effect-modification` with `:within`).

Planning only the rules relevant to the question (backward from the goal)
keeps the search small; without it, the clinical book made wouldwork
explore 21,000 states and fail inside its graph search.

Examples: `examples/clinical/01-anorexia` and `02-colon` (survival::colon),
with R references.

## Part 4: rules from textbooks

`docs/GENERAL-RULES.md` lists seven rules (G1-G7) from high-quality,
readable sources: Introduction to Modern Statistics (OpenIntro, 2nd ed.),
Harrell's Regression Modeling Strategies (chapter 4), An Introduction to
Statistical Learning (2nd ed.), Regression and Other Stories, the EMA
guidelines on multiplicity (2002) and missing data (2010), and Sterne et
al. (2009) on multiple imputation. `src/dsl/general.lisp` encodes them as
the general rule book: it includes the common core, is the default for
plain tibbles, and is included by the clinical book.

New in the DSL: `estimate` (a proportion), `model` (a regression model,
with `:purpose :prediction` or `:selection t`), `compare ... :aim
:pairwise`, `declare-clustered`; missing outcome values and the number of
observations per model parameter are found in the data. Examples in
`examples/general/` with R references (uvr, with mice).
