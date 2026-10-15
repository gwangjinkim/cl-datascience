# Clinical example 02: colon - adjuvant chemotherapy for colon cancer.
# Data: survival::colon (Moertel et al. 1990; Laurie et al. 1989), rows with
# etype == 2 (death). rx: Obs (observation), Lev (levamisole), Lev+5FU
# (levamisole plus fluorouracil); time: days to death or last follow-up;
# status: 1 = died, 0 = censored.
source("reference-lib.R")
library(survival)
d <- survival::colon[survival::colon$etype == 2,
                     c("id", "rx", "sex", "age", "nodes", "time", "status")]
d$sex <- ifelse(d$sex == 1, "male", "female")
write_data(d)

section("Data")
report("n_by_arm", c(table(d$rx)))
report("deaths_by_arm", tapply(d$status, d$rx, sum))
report("censored_share", mean(d$status == 0))

section("A. Log-rank test (recommended comparison of survival)")
lr <- survdiff(Surv(time, status) ~ rx, data = d)
report("logrank_chisq", lr$chisq)
report("logrank_p", pchisq(lr$chisq, df = length(lr$n) - 1, lower.tail = FALSE))

section("B. Cox regression and the proportional-hazards check")
cox <- coxph(Surv(time, status) ~ rx, data = d)
report("cox_hr", exp(coef(cox)))
report("cox_hr_ci_lev5fu", exp(confint(cox)["rxLev+5FU", ]))
report("ph_test_global_p", cox.zph(cox)$table["GLOBAL", "p"])

section("C. Ignoring censoring: t-test on follow-up times (invalid)")
lev5 <- droplevels(d[d$rx %in% c("Obs", "Lev+5FU"), ])
report("naive_mean_time_by_arm", tapply(lev5$time, lev5$rx, mean))
report("naive_time_ttest_p", t.test(time ~ rx, data = lev5)$p.value)

section("D. Subgroups by sex: interaction test vs separate tests")
inter <- coxph(Surv(time, status) ~ rx * sex, data = d)
main  <- coxph(Surv(time, status) ~ rx + sex, data = d)
report("interaction_p", anova(main, inter)[2, "Pr(>|Chi|)"])
for (s in c("female", "male")) {
  sub <- d[d$sex == s, ]
  t <- survdiff(Surv(time, status) ~ rx, data = sub)
  report(paste0("separate_logrank_p_", s), pchisq(t$chisq, df = 2, lower.tail = FALSE))
}

finish()
