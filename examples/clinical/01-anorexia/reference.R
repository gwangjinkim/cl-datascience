# Clinical example 01: anorexia - weight before and after treatment, three arms.
# Data: MASS::anorexia (Hand, Daly, McConway, Lunn and Ostrowski 1993, A Handbook
# of Small Data Sets, data set 285). 72 young female patients; Treat: CBT
# (cognitive behavioural therapy), FT (family therapy), Cont (control);
# Prewt and Postwt: weight in lb before and after the study period. The R
# documentation does not say how patients were allocated to the arms.
source("reference-lib.R")
d <- MASS::anorexia
d$Treat <- relevel(d$Treat, ref = "Cont")
write_data(d)

section("Data")
report("n_by_arm", c(table(d$Treat)))
report("cor_pre_post", cor(d$Prewt, d$Postwt))

section("Baseline: describe (recommended) or test (discouraged in randomized trials)")
report("baseline_mean_by_arm", tapply(d$Prewt, d$Treat, mean))
report("baseline_sd_by_arm", tapply(d$Prewt, d$Treat, sd))
report("baseline_test_p", anova(lm(Prewt ~ Treat, data = d))[1, "Pr(>F)"])

effects <- function(prefix, fit) {
  co <- summary(fit)$coefficients
  report(paste0(prefix, "_effect_CBT_vs_Cont"), co["TreatCBT", "Estimate"])
  report(paste0(prefix, "_se_CBT_vs_Cont"), co["TreatCBT", "Std. Error"])
  report(paste0(prefix, "_effect_FT_vs_Cont"), co["TreatFT", "Estimate"])
  report(paste0(prefix, "_se_FT_vs_Cont"), co["TreatFT", "Std. Error"])
  report(paste0(prefix, "_residual_sd"), summary(fit)$sigma)
}

section("A. Outcome only, baseline ignored: lm(Postwt ~ Treat)")
post <- lm(Postwt ~ Treat, data = d)
effects("post", post)
report("post_treat_p", anova(post)["Treat", "Pr(>F)"])

section("B. Change score: lm(Postwt - Prewt ~ Treat)")
change <- lm(I(Postwt - Prewt) ~ Treat, data = d)
effects("change", change)
report("change_treat_p", anova(change)["Treat", "Pr(>F)"])

section("C. ANCOVA: lm(Postwt ~ Prewt + Treat)")
ancova <- lm(Postwt ~ Prewt + Treat, data = d)
effects("ancova", ancova)
report("ancova_baseline_slope", coef(ancova)[["Prewt"]])
report("ancova_treat_p", anova(lm(Postwt ~ Prewt, data = d), ancova)[2, "Pr(>F)"])

section("D. Within-group tests against baseline (Bland and Altman 2011: invalid)")
for (arm in levels(d$Treat)) {
  w <- d[d$Treat == arm, ]
  report(paste0("within_", arm, "_mean_change"), mean(w$Postwt - w$Prewt))
  report(paste0("within_", arm, "_paired_p"), t.test(w$Postwt, w$Prewt, paired = TRUE)$p.value)
}

section("E. Dichotomised outcome: gained weight yes/no (Altman and Royston 2006)")
d$gained <- ifelse(d$Postwt > d$Prewt, "yes", "no")
tab <- table(d$Treat, d$gained)
report("gained_by_arm", c(tab[, "yes"]))
report("gained_fisher_p", fisher.test(tab)$p.value)
report("gained_chisq_expected_min", min(suppressWarnings(chisq.test(tab))$expected))

section("F. Equivalence of CBT and control within 2 lb (two one-sided tests, 90% CI)")
two <- droplevels(d[d$Treat %in% c("Cont", "CBT"), ])
ci90 <- t.test(Postwt ~ Treat, data = two, conf.level = 0.90)$conf.int[1:2]
report("cbt_vs_cont_ci90_cont_minus_cbt", ci90)
report("equivalent_within_2lb", all(abs(ci90) < 2))
report("superiority_p_cbt_vs_cont", t.test(Postwt ~ Treat, data = two)$p.value)

finish()
