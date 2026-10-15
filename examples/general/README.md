# General examples

EXPERIMENT (branch experiment/guided-rules). Examples for the general rule
book (src/dsl/general.lisp, rules G1-G7 in docs/GENERAL-RULES.md), each
with an R reference run with uvr (R 4.6.1; mice 3.19.0 for multiple
imputation) and tests in tests/general-dsl-tests.lisp.

| Example | Data | What R shows | What the planner does |
|---|---|---|---|
| 01 proportion (G1) | MASS::birthwt low birth weight 59/189; stanza "B" 3/6 (A.J. Rossini's data) | 3/6: Wald 0.10-0.90, Wilson 0.19-0.81, exact 0.12-0.88 | Wilson recommended; exact with a "conservative" note; Wald acceptable with its assumption, discouraged with fewer than 10 successes or failures |
| 02 chickweight (G3) | datasets::ChickWeight, 578 rows from 50 chicks | rows as independent: p 6e-7 with 264 denominator df; one final weight per chick: p 0.012; mixed model: p 5e-5 | after `declare-clustered :by :chick`: mixed model or summary measure; treating rows as independent against guidance |
| 03 airquality (G4) | datasets::airquality, ozone by month, 37 values missing (21 of 30 in June) | complete cases p 4.8e-6, multiple imputation (20, weather variables in the imputation model) p 4.4e-6, mean imputation p 4.0e-5 | multiple imputation recommended; complete cases with an assumption; single imputation against guidance |
| 04 birthwt (G5-G7) | MASS::birthwt, low birth weight and 8 candidate predictors | m = 3nq(1-q) = 121.7, p = 9 > m/15 = 8.1; stepwise keeps 6; C statistic apparent 0.746, bootstrap-corrected 0.697 | penalised regression recommended; ordinary regression discouraged (overfitting); with `:selection t` data reduction, stepwise against guidance; with `:purpose :prediction` bootstrap or cross-validation, apparent performance against guidance |
| 05 pairwise (G2) | MASS::anorexia, three arms | CBT vs control: unadjusted p 0.015, Holm 0.029, Tukey 0.058; three tests at 0.05: family-wise error up to 0.14 | Games-Howell or Holm recommended; Tukey with equal variances assumed; unadjusted pairwise tests discouraged |

```sh
examples/general/run-references.sh     # R references (uvr)
scripts/test.sh                        # tests, SBCL + ~/quicklisp and Roswell
```
