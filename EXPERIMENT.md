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
