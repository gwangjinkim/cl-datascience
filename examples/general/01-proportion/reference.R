# General example 01: a confidence interval for a proportion.
# (a) MASS::birthwt, share of low birth weight (59 of 189): the success-failure
#     condition holds; (b) A.J. Rossini's stanzas (examples/1d-analysis.lisp),
#     share of "B" (3 of 6): it fails.
source("reference-lib.R")
low <- MASS::birthwt$low
write_data(data.frame(low = ifelse(low == 1, "yes", "no")), "birthwt-low.csv")
stanza <- c("A", "B", "A", "B", "C", "B")
write_data(data.frame(stanza = stanza), "stanza.csv")

wald <- function(x, n) { p <- x / n; p + c(-1, 1) * qnorm(0.975) * sqrt(p * (1 - p) / n) }
interval_report <- function(prefix, x, n) {
  report(paste0(prefix, "_successes_failures"), c(successes = x, failures = n - x))
  report(paste0(prefix, "_wald"), wald(x, n))
  report(paste0(prefix, "_wilson"), prop.test(x, n, correct = FALSE)$conf.int[1:2])
  report(paste0(prefix, "_exact"), binom.test(x, n)$conf.int[1:2])
}
section("A. Low birth weight: 59 of 189 (condition holds)")
interval_report("birthwt", sum(low), length(low))
section("B. Stanza B: 3 of 6 (condition fails)")
interval_report("stanza", sum(stanza == "B"), length(stanza))
finish()
