# Changelog

## [Unreleased]

### Added
- EXPERIMENT docs/INTRODUCTION.md: an introduction to the DSL as it is
  (first question, declarations, verbs, ranking, rule books, writing rules,
  how it works, R references, limits), with real output. docs/build-pdf.sh
  takes the document name (`docs/build-pdf.sh INTRODUCTION`).
- EXPERIMENT package `clds-user` (src/dsl/user.lisp): the Common Lisp
  tidyverse and the DSL in one package, made with
  `tidyverse:define-tidy-package`, so analyses need no package prefixes.
- EXPERIMENT general rule book (src/dsl/general.lisp): the default for
  plain tibbles, including the common core and included by the clinical
  book. Rules: Wilson, exact and Wald intervals with the success-failure
  condition; adjusted pairwise comparisons (Games-Howell, Holm, Tukey);
  clustered rows (mixed model, summary measures; `declare-clustered`);
  missing outcome values (multiple imputation, complete cases as an
  assumption, single imputation against guidance); regression models with
  the m/15 limit, penalisation, linearity as an assumption, splines; data
  reduction instead of stepwise selection; validated predictive
  performance. New verbs `estimate` and `model`; `compare` gains
  `:aim :pairwise`; results fill {predictors} in R code.
- EXPERIMENT docs/GENERAL-RULES.md: seven rules (G1-G7) from Introduction
  to Modern Statistics (2nd ed.), Harrell's Regression Modeling Strategies,
  An Introduction to Statistical Learning (2nd ed.), Regression and Other
  Stories, the EMA guidelines on multiplicity and missing data, and Sterne
  et al. (2009). examples/general/ (own uvr project with mice): proportion
  intervals, ChickWeight repeated measurements, airquality missing values,
  birthwt regression model, pairwise comparisons, with R references.
- EXPERIMENT clinical rule book (src/dsl/clinical.lisp), including the
  common core: baseline and stratification adjustment, change scores,
  within-group tests, baseline tests, subgroups (interaction, exploratory
  label), equivalence with a margin, dichotomisation, time-to-event
  (log-rank, Cox, censoring). Rule books can include others
  (`:includes`); `define-requirement` adds conditions to included
  methods; `define-caveat` adds labels; declaration verbs
  `declare-trial`, `declare-baseline`, `declare-survival`,
  `declare-dichotomized`, `declare-margin`, `declare-prespecified`;
  `compare` takes `:aim` and `:within`; a declared trial selects the
  clinical book (`data-rule-book`). Results print caveat notes and R code
  with the declared covariates.
- EXPERIMENT docs/CLINICAL-RULES.md: ten clinical rules (C1-C10) from the
  EMA guideline on baseline covariates (2015), ICH E9(R1), CONSORT 2010,
  Bland and Altman (2011) and BMJ Statistics Notes, with what each
  recommends, what departs from it, its strength and sources. R references:
  anorexia gains within-group tests, a dichotomised outcome and an
  equivalence interval; new example 02 colon (survival::colon): log-rank,
  Cox, proportional hazards, censoring ignored, subgroup interaction.
- EXPERIMENT CLOS DSL (system `cl-datascience/dsl`, src/dsl/): rule books
  of CLOS rule objects compiled to wouldwork; the common-core rule book
  (Welch and Student t, Wilcoxon, paired t, signed-rank, Welch and
  classical ANOVA, Kruskal-Wallis, chi-square, Fisher's exact test, with
  assumptions and departures and their sources); `statframe` as a
  subclass of `cl-tibble:tbl` with declaration verbs; generic question
  verbs `compare` and `associate` on tibbles, returning an
  `analysis-result`. Works in cl-dplyr's `->` pipeline. tests/run.lisp
  finds the Common Lisp tidyverse in ~/projects/cl (or
  CLDS_TIDYVERSE_DIR).
- EXPERIMENT docs/PRIOR-ART-R.md: how visStatistics, testflow, rstatix and
  AssumpSure choose tests (from their vignettes, help pages and code), the
  rules they share, their own caveats about pre-testing assumptions, and
  what cl-datascience does differently. research/test-selection/ is the
  uvr project (versions pinned) used to read and run them.
- EXPERIMENT clinical tier (examples/clinical/, own uvr project and
  domain): 01 anorexia (MASS), R reference for ANCOVA, change score and
  outcome-only analyses and the baseline test. Guided plans: ANCOVA
  recommended; change score (cost 3, Vickers and Altman 2001, Senn 2006)
  and ignoring the baseline (cost 5, EMA 2015) discouraged; baseline
  tables recommended and baseline significance tests discouraged
  (CONSORT 2010, Altman 1985, Senn 1994); a pre-specified change score is
  a justified departure.
- EXPERIMENT `guided-plans` (src/guidance.lisp): every minimal plan with
  its cost, category (recommended, acceptable, justified departure,
  discouraged, against guidance), assumptions and departures, cheapest
  first. Strengths, rules and sources of every assume-/depart- step are
  in examples/guidance.lisp. Examples can sit in tiers (`:tier`);
  `example-problem` exposes the planning problem of an example question.
- EXPERIMENT.md: branch experiment/guided-rules tests whether rules can
  guide (ranked, labelled plans with costs and sources) instead of forbid.
  The branch is not to be merged.
- docs/DESIGN.md: design document for the verbs and the DSL (summary,
  principles, architecture, the verbs in their layers with signatures,
  assumption modes, results, defining forms for method authors,
  compilation to the planner, data representation including unit and
  treatment structures, solver, rule base and sources, execution and
  record, LLM use, prior art, roadmap, decisions). docs/build-pdf.sh and
  docs/pdf-header.tex build DESIGN.pdf with pandoc and xelatex.
- docs/VERBS.md: the verbs in three layers (project verbs from
  1d-analysis.lisp, question verbs as planner goals, method actions chosen
  by the planner), how optional declarations work, plan-run-replan, open
  questions. examples/stat101/README.md: layout, how to run, catalogue,
  findings. README.md: a section on the examples and the test suite.
- Example 05 faithful as a planning problem: after a check finds two
  modes, describe-by-modes replaces describe-continuous; declaring rows as
  time-ordered removes the independence assumption and leaves ols-fit
  with hac-se. Domain: describe-by-modes, hac-se, relations bimodal and
  row-order-time.
- Example 04 UCBAdmissions as a planning problem: without declared counts
  the plan assumes one row per applicant; the estimand is the goal (total
  effect: pooled-odds-ratio; direct effect: mantel-haenszel with
  assume-common-odds-ratio, or logistic-by-stratum), and the direct effect
  has no plan until the order of events places the department between
  gender and admission. Domain: these four methods and
  assume-one-row-per-case.
- Example 03 ToothGrowth as a planning problem, with the first domain
  constraint (design consistency): once dose is declared set by design and
  measured before len, no plan may explain dose by len; prediction in that
  direction stays allowed; the declared design gives two-way-anova.
  Domain: two-way-anova, predictive-fit, relations for origin and timing.
- Example 02 cars as a planning problem: the purpose (trend, inference,
  prediction) is part of the question. A trend needs only ols-fit;
  inference offers robust-se and, with assume-constant-spread,
  classical-se; after a check finds growing spread only robust-se and the
  spread-model prediction interval remain. Domain: ols-fit, classical-se,
  robust-se, normal-prediction-interval, spread-model-prediction-interval,
  assume-constant-spread.
- Example 01 sleep as a planning problem: nothing declared gives
  assume-rows-independent then welch-t-test (R's default, assumption
  shown); declared independence gives welch-t-test; declared pairing gives
  paired-t-test or signed-rank-test. Domain: two-group methods and the
  row-independence assumption.
- Example 00 one variable, as a planning problem: `plan.lisp` (objects,
  facts, states of knowledge, questions), `wish.lisp` and README. The
  shared method actions start in `examples/stat101/domain.lisp`
  (describe, next value). `load-example` and `example-plans`
  (src/examples.lisp) read an example and plan one question under one
  state of knowledge.
- R references for six Statistics 101 examples (examples/stat101/): one
  variable (A.J. Rossini's two datasets from examples/1d-analysis.lisp),
  sleep, cars, ToothGrowth, UCBAdmissions, faithful. Each `reference.R`
  (base R) writes `reference.out`, `expected.json` (the numbers a Lisp
  version must reproduce, names kept) and its data as CSV. R 4.6.1 and
  jsonlite are pinned with uvr; `run-references.sh` reruns all.
- `find-plans` (src/planner.lisp): asks the wouldwork planner for every
  minimal plan that reaches a goal from a set of facts, using a domain file
  of relations and actions. Writes and stages a wouldwork problem, returns
  plans as keyword lists, shortest first; plans that add unneeded steps (an
  assumption they do not use) are dropped. `plan-assumptions` lists the
  `assume-...` steps of a plan; `planning-error` reports wouldwork's output.
  Tested with a toy domain (tests/toy-domain.lisp).

- ASDF systems `cl-datascience` and `cl-datascience/tests` (FiveAM), with
  `tests/run.lisp` and `scripts/test.sh` running the suite under SBCL with
  `~/quicklisp` and under Roswell alike. AGENTS.md records the working rules
  (test first, both Lisp setups, uvr for R, small commits, this changelog).

### Changed
- EXPERIMENT: the design-consistency constraint no longer forbids. Example
  03 with its design declared now gets the plan
  depart-design-consistency, ols-fit dose len, labelled against guidance
  with Fisher (1935) and ICH E9 as sources; with a declared justification
  the departure is labelled justified.

### Fixed
- EXPERIMENT: questions plan only the rules relevant to their goal
  (backward from the goal relation). With the full clinical book, wouldwork
  explored about 21,000 states for a baseline question and failed inside
  its graph search (IDB-IN-OPEN compared NIL with 1).
- `find-plans` no longer changes the caller's `*package*`: staging reloads
  wouldwork, which set it to wouldwork's package, so forms read after a
  call (in a script or at the REPL) were read in the wrong package.
- Actions with several parameters of one type use wouldwork's `product`
  header. With the default, an example with fewer objects than parameters
  (example 00: two variables, a four-parameter action) crashed the planner
  with "too few elements ... to satisfy lambda list".
- A problem that fails to stage no longer breaks the wouldwork
  installation: wouldwork compiles its staged problem on every load, so
  `find-plans` stages wouldwork's own `blocks3` again after a failure, and
  `tests/run.lisp` repairs an installation left broken by a killed process.
- `tests/run.lisp` ends with a failure status on any error; under Roswell
  an error used to wait in the debugger and then exit with status 0.
