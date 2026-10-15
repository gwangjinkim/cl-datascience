# General example 05: pairwise comparisons after a three-group comparison.
# MASS::anorexia, weight after treatment in three arms.
source("reference-lib.R")
d <- MASS::anorexia
write_data(d)
section("A. Unadjusted pairwise t-tests (no multiplicity adjustment)")
u <- pairwise.t.test(d$Postwt, d$Treat, p.adjust.method = "none", pool.sd = FALSE)$p.value
report("unadjusted_p", c(CBT_Cont = u["Cont", "CBT"], FT_CBT = u["FT", "CBT"], FT_Cont = u["FT", "Cont"]))
section("B. Holm-adjusted Welch t-tests")
h <- pairwise.t.test(d$Postwt, d$Treat, p.adjust.method = "holm", pool.sd = FALSE)$p.value
report("holm_p", c(CBT_Cont = h["Cont", "CBT"], FT_CBT = h["FT", "CBT"], FT_Cont = h["FT", "Cont"]))
section("C. Tukey HSD after one-way ANOVA")
t <- TukeyHSD(aov(Postwt ~ Treat, data = d))$Treat
report("tukey_p", t[, "p adj"])
section("D. Family-wise error with k unadjusted comparisons at 0.05")
report("fwer_3_independent_tests", 1 - 0.95^3)
finish()
