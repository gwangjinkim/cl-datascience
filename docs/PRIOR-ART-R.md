# Prior art in R: packages that choose a statistical test

EXPERIMENT (branch experiment/guided-rules). Notes from the documentation,
vignettes and decision code of four CRAN packages, installed with uvr in
`research/test-selection/` (versions pinned in its `uvr.toml`). The packages
are used as **sources of rules and as references**. No code is copied:
three of them are GPL-licensed, and the rules are re-encoded in our own
format with the package as a cited source.

| Package | Version | Licence | Scope |
|---|---|---|---|
| visStatistics | 0.3.0 | MIT | one function, `visstat()`, chooses and runs a test for a response and one predictor, with plots and diagnostics |
| testflow | 1.0.0 | MIT | about 30 `test_*()` workflows (groups, paired, repeated, categorical, correlation, regression, survival, diagnostic accuracy, agreement) and sample-size planning |
| rstatix | 1.1.0 | GPL-2 | tidy wrappers for tests; `check_test_assumptions()` recommends an omnibus and post-hoc test for one-way designs |
| AssumpSure | 1.1.4 | GPL-3 | Shiny app; assumption checks before tests; written choice rules for users |

## How each decides

### visStatistics (vignette, section 5 "Decision logic")

Routing by the **classes of the two variables** first:

| Route | Response, predictor | Tests |
|---|---|---|
| 1 | numeric, categorical | central-tendency branch (below) |
| 2 | ordered factor, categorical | Wilcoxon rank-sum (2 groups), Kruskal-Wallis (more) |
| 3 | numeric, numeric | simple linear regression; violated assumptions give warnings, no automatic replacement |
| 4 | factor, factor | Pearson chi-square, or Fisher's exact test by Cochran's rule (chi-square if no expected count < 1 and at most 20% below 5); Yates correction for 2x2 |

Route 1 gates: Shapiro-Wilk on the model residuals; if normality is rejected,
the rank tests (Wilcoxon, Kruskal-Wallis with Holm-adjusted pairwise
Wilcoxon). Otherwise Levene's test: equal variances give Student t / Fisher
ANOVA (Tukey HSD), unequal give Welch t / Welch ANOVA (Games-Howell). Users
can override the gates (`group_test = "welch"` or `"rank"`). Rank
correlations (Kendall, Spearman) only on request.

The vignette's own discussion (section 8) is the clearest statement of the
problem with such gates:
- assumption tests have little power in small samples and reject trivial
  departures in large ones; with 100 per group, mild skew already sends 90%
  of analyses to the rank branch, although mean-based tests become more
  tolerant of non-normality as samples grow;
- conditioning on the gates changes the distribution of the final test; the
  nominal level no longer holds exactly (Rochon et al. 2012);
- a gate switch from means to ranks changes the question being answered;
- "visstat() does not know the user's research question", so the residual
  diagnostics decide which estimand is tested.

### testflow (vignette "testflow-complete-reference")

A table of recommended tests, every alternative computed and reported:

| Workflow | normal and equal variances | normal only | neither |
|---|---|---|---|
| one sample | one-sample t | - | Wilcoxon signed-rank |
| two groups | Student t | Welch t | Wilcoxon rank-sum |
| paired | paired t | - | Wilcoxon signed-rank |
| 3+ groups | one-way ANOVA | Welch ANOVA | Kruskal-Wallis |

Further rules: chi-square vs Fisher by expected counts (threshold 5);
correlation `method = "auto"`: Pearson if both variables pass normality and
outlier screens, else Spearman, Kendall always reported; repeated measures:
RM-ANOVA vs Friedman by within-time normality, Mauchly for sphericity;
McNemar for paired binary, Cochran's Q for 3+ repeated binary. Each check
has a status (`acceptable`, `not acceptable`, `warning`, `not applicable`,
`assumed`, `not checked`). Independence of observations "is assumed from the
study design" and always listed explicitly.

### rstatix (`check_test_assumptions()` help page)

Per-group Shapiro-Wilk and Levene: all normal and equal variances give
ANOVA + Tukey; normal, unequal variances give Welch ANOVA + Games-Howell;
any group not normal gives Kruskal-Wallis + Dunn. The help page warns
against its own gate: it is "least reliable exactly when it matters", and
it suggests robust methods without the gate (Welch ANOVA with Games-Howell,
or rank-based tests), treating the recommendation "as guidance, not a
substitute for judgement".

### AssumpSure (app text and server code)

Written rules for users: continuous outcome with two independent groups,
independent t-test; same subjects twice, paired t-test; more than two
groups, one-way ANOVA; binary outcome, logistic regression; more than two
categories, multinomial regression; counts, Poisson regression; two
continuous variables, correlation; two categorical variables, Fisher if any
cell count < 5, else chi-square; several predictors, linear model;
repeated or hierarchical data (patient ID), linear mixed model. Tests are
gated by Shapiro-Wilk and Levene at 0.05; non-parametric tests are always
allowed.

## The common core

Rules the four packages share, with what each needs to know:

| Question | Data | Package recommendation | Needs |
|---|---|---|---|
| two independent groups, means | numeric by 2-level factor | Student t / Welch t / Wilcoxon by gates | normality, equal variances |
| paired | two measurements per subject | paired t / signed-rank | normality of differences |
| 3+ groups | numeric by factor | ANOVA / Welch ANOVA / Kruskal-Wallis, matching post-hoc | normality, equal variances |
| repeated (3+) | long data with subject id | RM-ANOVA (sphericity) / Friedman | normality, sphericity |
| two categorical | contingency table | chi-square / Fisher's exact | expected counts |
| paired binary | | McNemar | |
| two numeric | | regression; Pearson / Spearman / Kendall | linearity, normality, outliers |
| several predictors, binary or count outcome | | linear, logistic, Poisson models | |
| clustered data | subject or site id | mixed model | |

## What our system changes

| Point | R packages | cl-datascience |
|---|---|---|
| What decides | data classes, then p-values of assumption tests on the same data | the **question** (outcome, grouping, estimand, purpose) and **declared design**; checks are optional observations |
| Estimand | changes silently when a gate switches from means to ranks | part of the question: `:estimand :mean` or `:location`; a rank test answers a different question and is labelled so |
| Assumptions | tested, then gate | assumed (recorded), declared, or observed by a check; large groups relax normality instead of a gate rejecting it |
| Non-recommended tests | computed as alternatives (testflow) or overridable (visStatistics) | always planned, ranked, labelled with the rule and its sources; a declared justification is recorded |
| Independence | assumed (testflow lists it) | declared from the design (pairing, clusters, time order) and used to choose the method |
| Design | not represented | origin, timing, baseline, randomization (examples 03, clinical 01) |
| Extensibility | code branches inside each package | rules are CLOS objects compiled to a planner domain; a new method is a new rule |

## Sources cited by the rules

From the packages' documentation: Cochran (1954) on expected counts;
Fagerland and Sandvik (2009) comparing two-sample location tests; Lumley et
al. (2002) on the normality assumption in large samples; Rochon et al. (2012)
on two-stage procedures; Delacre et al. (2019) and Rasch et al. (2011) on
Welch's t-test as default; Bridge and Sawilowsky (1999) on rank tests under
skew; Levene (1960); Shapiro and Wilk (1965).
