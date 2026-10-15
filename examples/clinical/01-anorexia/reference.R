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

finish()
