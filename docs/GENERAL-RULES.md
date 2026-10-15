# General rules: from textbooks to the rule book

EXPERIMENT (branch experiment/guided-rules). The general rule book
(`src/dsl/general.lisp`) includes the common core and is the default for
plain tibbles; the clinical rule book includes it. Sources were chosen for
quality and readability: textbooks widely used and highly rated by
students, an authoritative modelling text, and regulatory guidance. Rules
are paraphrased and cited, never quoted at length.

| Source | Read |
|---|---|
| Cetinkaya-Rundel and Hardin, *Introduction to Modern Statistics*, 2nd ed. (OpenIntro, free online) | chapters 16 (one proportion) and 22 (many means) |
| Harrell, *Regression Modeling Strategies*, course notes (hbiostat.org/rmsc, free) | chapter 4 (multivariable modelling strategies) |
| James, Witten, Hastie and Tibshirani, *An Introduction to Statistical Learning*, 2nd ed. (free from statlearning.com) | not re-read here; chapter 2.2 (training vs test error) and chapter 5 (cross-validation, bootstrap) as widely taught |
| Gelman, Hill and Vehtari, *Regression and Other Stories* (free PDF from the authors) | not re-read here (the PDF exceeds the fetch limit); section 11.1 (assumptions in order of importance) as widely taught |
| EMA, Points to consider on multiplicity issues in clinical trials, CPMP/EWP/908/99 (2002) | full text |
| EMA, Guideline on missing data in confirmatory clinical trials, EMA/CPMP/EWP/1776/99 Rev. 1 (2010) | executive summary, sections 6.2 and 6.3 |
| Sterne et al. (2009), Multiple imputation for missing data in epidemiological and clinical research: potential and pitfalls, BMJ 338:b2393 | full text via PubMed Central |
| Bland and Altman (1995), Multiple significance tests: the Bonferroni method, BMJ 310:170; Matthews et al. (1990), Analysis of serial measurements in medical research, BMJ 300:230; Bland and Altman (1994), Correlation, regression, and repeated data, BMJ 308:896 | located in PubMed Central (scanned); content as widely cited |
| Brown, Cai and DasGupta (2001), Interval estimation for a binomial proportion, Statistical Science 16:101 | not re-read; its main finding as widely cited |

## The rules

| # | Rule | Recommended | Labelled | Sources | Example |
|---|---|---|---|---|---|
| G1 | The normal-approximation interval for a proportion needs at least 10 successes and 10 failures; even then it is erratic | Wilson interval; exact (Clopper-Pearson) interval, noted as conservative | Wald interval: an assumption; with fewer than 10 successes or failures `depart-success-failure` (5) | IMS 2e 16.2; Brown et al. 2001 | general/01 |
| G2 | Pairwise comparisons after a comparison of several groups need a multiplicity adjustment | Games-Howell, Holm-adjusted Welch tests; Tukey HSD (equal variances) | unadjusted pairwise tests after `depart-multiplicity` (8) | IMS 2e 22 (data snooping); Bland and Altman 1995; EMA 2002 section 2 | general/05 |
| G3 | Repeated measurements on the same unit are not independent rows | mixed model; summary measure per unit (final value, slope, area) | any method treating the rows as independent after `depart-ignore-clustering` (10) | Matthews et al. 1990; Bland and Altman 1994; CONSORT 2010 12a | general/02 |
| G4 | Missing outcome values: complete cases rely on an assumption; single imputation is invalid | multiple imputation (assumes missing at random) | complete cases after `assume-ignorable-missingness` (2); mean imputation, last value carried forward after `depart-single-imputation` (10) | EMA 2010 6.2, 6.3.1; Sterne et al. 2009 | general/03 |
| G5 | A regression model should have at most one parameter per 15 effective observations (binary outcome: m = 3nq(1-q)); otherwise penalise or reduce the data without using the outcome | penalised regression; regression with linearity assumed when within the limit | ordinary regression beyond the limit after `depart-overfitting` (5) | Harrell RMS 4.4, 4.5-4.7 | general/04 |
| G6 | Do not select predictors stepwise | data reduction without the outcome; penalised selection | stepwise selection after `depart-stepwise` (10) | Harrell RMS 4.3 | general/04 |
| G7 | Judge predictive performance on data not used to fit the model | bootstrap validation, cross-validation; a held-out set, noted as wasteful unless n is large | apparent (training) performance after `depart-apparent-performance` (10) | ISLR 2e 2.2, 5.1-5.2; Harrell RMS 4.12 | general/04 |

## New verbs and declarations

- `(estimate data :variable :of "level")` - a proportion and its interval.
- `(compare data :y :by :g :aim :pairwise)` - which groups differ.
- `(declare-clustered data :by :unit)` - rows come in clusters (repeated
  measurements, patients in centres).
- `(model data :y :with '(:x1 :x2 ...) :purpose :prediction :selection t)` -
  a regression model; the purpose decides the goal (fitted model, reduced
  model, or estimated predictive performance).
- Missing outcome values are found in the data; no declaration is needed.
