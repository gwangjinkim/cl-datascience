# Clinical 01 anorexia: baseline and follow-up in a three-arm study

EXPERIMENT (branch experiment/guided-rules).

**Question.** Does cognitive behavioural therapy (CBT) or family therapy
(FT) increase weight compared with control, and were the arms comparable
at the start?

**Data.** `MASS::anorexia`: 72 young female patients; weight (lb) before
(`Prewt`) and after (`Postwt`) the study period; arms Cont (26), CBT (29),
FT (17). From Hand et al. (1993), *A Handbook of Small Data Sets*. The R
documentation does not say how patients were allocated; the `trial`
knowledge declares the study a randomized trial, which is what is tested.

**The guidance.** In a randomized trial with a baseline measurement of the
outcome, the recommended analysis is analysis of covariance; change scores
and ignoring the baseline are possible but less precise. Testing whether
the randomized arms differ at baseline is discouraged; the baseline is
described instead.

## What R says (reference.out)

| Analysis | CBT vs Cont (SE) | FT vs Cont (SE) | p (treatment) |
|---|---|---|---|
| ANCOVA, `lm(Postwt ~ Prewt + Treat)` | 4.10 (1.89) | 8.66 (2.19) | 0.0008 |
| outcome only, `lm(Postwt ~ Treat)` | 4.59 (1.97) | 9.39 (2.27) | 0.0004 |
| change score, `lm(Postwt - Prewt ~ Treat)` | 3.46 (2.03) | 7.71 (2.35) | 0.0065 |

Baseline and follow-up correlate weakly (r = 0.33), so the change score is
the least precise, as Vickers and Altman (2001) explain; ANCOVA has the
smallest standard errors. The baseline test gives p = 0.55, which in a
randomized trial says nothing about whether the comparison is fair.

## What the guided planner says (plan.lisp, tests/clinical-tests.lisp)

| Known | Asked | Plans, in ranking order |
|---|---|---|
| nothing | treatment effect | acceptable: assume-rows-independent, oneway-anova |
| randomized trial, prewt is the baseline of postwt | treatment effect | recommended: ancova; discouraged (cost 3): depart-prefer-ancova, change-score-anova; discouraged (cost 5): depart-adjust-for-baseline, oneway-anova |
| same | baseline balance | recommended: baseline-table; discouraged: depart-no-baseline-tests, baseline-significance-test |
| same, change score pre-specified | treatment effect | the change-score plan becomes a justified departure |

No plan is refused. The analyst sees the recommended analysis first, every
alternative with the rule it departs from and the rule's sources, and can
declare a justification (for example a protocol that pre-specified change
from baseline), which is then recorded.

## Findings for the experiment

- The ranking follows the sources without hand-written ordering: it comes
  from the strengths in `examples/guidance.lisp`.
- Without the baseline declared, ANCOVA is not offered at all: the planner
  cannot know that `prewt` is the same measurement as `postwt`, earlier.
  Recognising such pairs (names, units, timing) would be a validation
  task.
- The strengths (3 for change scores, 5 for ignoring the baseline) are a
  first proposal. The sources agree on the order, not on numbers.
