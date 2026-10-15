# Clinical rules: from the literature to the rule book

EXPERIMENT (branch experiment/guided-rules). The clinical rule book
(`src/dsl/clinical.lisp`) extends the common core with rules from openly
available clinical-statistics sources. Each rule below names its sources,
says what is recommended and what departs from it, and how it is encoded.
Rules are paraphrased; nothing is quoted at length. Textbooks behind
paywalls were not read; these sources were:

| Source | Read through |
|---|---|
| EMA, Guideline on adjustment for baseline covariates in clinical trials, EMA/CHMP/295050/2013 (adopted 26 February 2015, in effect 1 September 2015) | the PDF, full text |
| ICH E9(R1), Addendum on estimands and sensitivity analysis (Step 4, 20 November 2019) | the PDF, sections A.3 and A.5 |
| Moher et al. (2010), CONSORT 2010 explanation and elaboration, BMJ 340:c869 (doi 10.1136/bmj.c869) | PubMed Central, items 12a, 12b and checklist items 15-18 |
| Bland and Altman (2011), Comparisons against baseline within randomised groups are often used and can be highly misleading, Trials 12:264 (doi 10.1186/1745-6215-12-264) | PubMed Central, full text |
| Vickers and Altman (2001), BMJ 323:1123; Altman and Royston (2006), BMJ 332:1080; Altman and Bland (1995), BMJ 311:485; Altman and Bland (2003), BMJ 326:219; Bland and Altman (1995), BMJ 310:170; Bland and Altman (1994), BMJ 308:1499 | BMJ Statistics Notes; located in PubMed Central, full text not machine-readable (scanned); content as widely cited |
| Bland and Altman (1998), Survival probabilities (the Kaplan-Meier method), BMJ 317:1572; Bland and Altman (2004), The logrank test, BMJ 328:1073 | as above |

## The rules

| # | Rule | Recommended | Departure (strength) | Sources | Example |
|---|---|---|---|---|---|
| C1 | Adjust for the baseline value of a continuous outcome | `adjusted-regression` (ANCOVA) | methods that ignore the baseline: `depart-baseline-adjustment` (5) | EMA 2015 section 5.6; Vickers and Altman 2001 | anorexia |
| C2 | Change from baseline without adjustment is less precise | `adjusted-regression` | `change-score-test` after `depart-unadjusted-change` (3) | EMA 2015 section 5.6; Vickers and Altman 2001 | anorexia |
| C3 | Adjust for the factors used to stratify the randomisation | `adjusted-regression` | methods that ignore the strata: `depart-stratification` (5) | EMA 2015 sections 5.2, 5.3; CONSORT 2010 item 12b | constructed |
| C4 | Compare randomised groups directly, never by separate tests against baseline in each group | between-group methods | `within-group-tests` after `depart-within-group-comparison` (20: the false-positive rate can reach 0.50 with two groups, 0.75 with three) | Bland and Altman 2011 | anorexia |
| C5 | Describe baseline characteristics; do not test randomised groups for baseline differences | `baseline-table` | `baseline-significance-test` after `depart-baseline-testing` (5) | CONSORT 2010 items 12b, 15; Bland and Altman 2011; EMA 2015 section 5.4 | anorexia |
| C6 | Effect modification by a subgroup is shown by a test of interaction, not by separate tests in each subgroup | `interaction-test`, `cox-interaction-test` | `separate-subgroup-tests` after `depart-separate-subgroups` (15) | Altman and Bland 2003; CONSORT 2010 item 12b; EMA 2015 section 6.4 | colon |
| C7 | Subgroup analyses not pre-specified are exploratory | an interaction plan with the step `label-exploratory` (2) unless the subgroup is declared pre-specified | - | CONSORT 2010 items 12b, 18; EMA 2015 section 6.1 | colon |
| C8 | Absence of evidence is not evidence of absence: equivalence needs a pre-specified margin and an equivalence test | `equivalence-test` (two one-sided tests) with a declared margin | `nonsignificant-test-as-equivalence` after `depart-absence-of-evidence` (20) | Altman and Bland 1995 | anorexia |
| C9 | Do not dichotomise a continuous outcome | analysing the continuous variable | tests on the dichotomised variable after `depart-dichotomisation` (5) | Altman and Royston 2006 | anorexia |
| C10 | Time-to-event outcomes with censoring: Kaplan-Meier, log-rank, Cox | `log-rank-test`; `cox-regression` (assumes proportional hazards) | `time-comparison-ignoring-censoring` after `depart-ignore-censoring` (20) | Bland and Altman 1998, 2004 | colon |

Assumptions added: `assume-noninformative-censoring` (1),
`assume-proportional-hazards` (1).

## Encoding

- The clinical rule book **includes** the common core (`:includes`); its
  rules are added to the common core's in one planner domain.
- **Requirement rules** (`define-requirement`) add conditions to the
  included methods that answer a given question, without redefining them.
  C1 and C3 are written this way: every common-core method that answers a
  mean difference gains "no baseline declared, or the baseline adjustment
  waived" and "no stratification declared, or it was waived".
- A statframe **selects its rule book**: `declare-trial` makes it a
  clinical trial and its questions use the clinical book; a plain tibble
  uses the common core.
- The `:aim` of `compare` is part of the question: `:difference` (default),
  `:equivalence`, `:baseline-balance`, `:effect-modification` (with
  `:within`). A declared time-to-event outcome turns a difference into a
  survival comparison.

## Not yet encoded (next)

- Covariates measured after randomisation must not be adjusted for (EMA
  2015 section 5.5; ICH E9): needs `:adjust-for` in `compare`.
- Intercurrent events and estimand strategies (ICH E9(R1) A.3.2): treatment
  policy, hypothetical, composite, while on treatment, principal stratum;
  subsets by actual post-randomisation events are confounded (A.3.2).
- Multiplicity across endpoints (Bland and Altman 1995; EMA points to
  consider on multiplicity, CPMP/EWP/908/99).
- Regression to the mean in single-arm before-after comparisons (Bland and
  Altman 1994).
- Absolute and relative effects for binary outcomes (CONSORT 17b).
