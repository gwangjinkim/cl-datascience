# General example 04: a logistic regression model. MASS::birthwt: low birth
# weight (59 of 189) and eight candidate predictors.
source("reference-lib.R")
d <- MASS::birthwt
d$race <- c("white", "black", "other")[d$race]
d$low <- ifelse(d$low == 1, "yes", "no")
write_data(d[, c("low", "age", "lwt", "race", "smoke", "ptl", "ht", "ui", "ftv")])
y <- as.integer(d$low == "yes")
section("A. Effective sample size and parameters (Harrell, RMS 4.4)")
q <- min(mean(y), 1 - mean(y)); m <- 3 * length(y) * q * (1 - q)
f <- y ~ age + lwt + race + smoke + ptl + ht + ui + ftv
full <- glm(f, family = binomial, data = cbind(d, y = y))
report("effective_n_m", m)
report("parameters_p", length(coef(full)) - 1)
report("limit_m_over_15", m / 15)
section("B. Stepwise selection (AIC) keeps")
sel <- step(full, trace = 0)
report("stepwise_kept", attr(terms(sel), "term.labels"))
section("C. Apparent vs bootstrap optimism-corrected concordance (C statistic)")
cstat <- function(p, y) { r <- rank(p); (sum(r[y == 1]) - sum(y) * (sum(y) + 1) / 2) / (sum(y) * sum(1 - y)) }
apparent <- cstat(fitted(full), y)
set.seed(1973)
optimism <- replicate(200, {
  i <- sample(length(y), replace = TRUE)
  b <- glm(f, family = binomial, data = cbind(d, y = y)[i, ])
  cstat(fitted(b), y[i]) - cstat(predict(b, newdata = cbind(d, y = y), type = "response"), y)
})
report("c_apparent", apparent)
report("c_optimism", mean(optimism))
report("c_corrected", apparent - mean(optimism))
finish()
