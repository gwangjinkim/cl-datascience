# Clinical 02 colon: adjuvant chemotherapy, time to death

EXPERIMENT (branch experiment/guided-rules).

**Question.** Does levamisole, alone or with fluorouracil, prolong survival
after surgery for colon cancer, and does the effect differ between women and
men?

**Data.** `survival::colon` (Moertel et al. 1990), the rows for death
(`etype == 2`): 929 patients in three arms (Obs 315, Lev 310, Lev+5FU 304);
`time` in days to death or last follow-up, `status` 1 for death. 51% of
the times are censored.

**The traps.** Censored times are not event times. And an effect that is
significant in one subgroup but not in another does not show that the
effect differs between subgroups.

## What R says (reference.out)

| Analysis | Result |
|---|---|
| log-rank test, 3 arms | chi-square 11.7, p = 0.0029 |
| Cox, hazard ratio Lev+5FU vs Obs | 0.69 (95% CI 0.55 to 0.87); proportional hazards p = 0.48 |
| t-test on follow-up times, ignoring censoring (invalid) | p = 0.0041 |
| interaction rx by sex (Cox) | p = 0.021 |
| separate log-rank tests by sex | women p = 0.62, men p = 0.0001 |

## What the guided planner says (tests/clinical-dsl-tests.lisp)

```lisp
(-> (read-csv "data.csv")
    (declare-trial :arm :rx)
    (declare-survival :time :time :event :status)
    (compare :time :by :rx))
;; 1. acceptable: assume-noninformative-censoring, log-rank-test
;;    then cox-regression (assumes proportional hazards);
;;    against guidance: depart-ignore-censoring, time-comparison-ignoring-censoring

(compare colon :time :by :rx :within :sex :aim :effect-modification)
;; 1. acceptable (cost 4): label-exploratory, assume-proportional-hazards,
;;    assume-noninformative-censoring, cox-interaction-test
;;    note: the subgroup analysis was not pre-specified ...
;; 2. against guidance: depart-separate-subgroups, separate-subgroup-tests
```

With `(declare-prespecified data :sex)` the exploratory label disappears.

Rules applied: C6, C7, C10 in docs/CLINICAL-RULES.md.
