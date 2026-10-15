# General example 03: missing outcome values. datasets::airquality, ozone by
# month (May-September 1973, New York); Ozone has missing values.
source("reference-lib.R")
library(mice)
d <- airquality
d$Month <- month.abb[d$Month]
write_data(d)
section("Data")
report("ozone_missing", sum(is.na(d$Ozone)))
report("ozone_missing_by_month", tapply(is.na(d$Ozone), d$Month, sum))
section("A. Complete cases: oneway.test(Ozone ~ Month)")
report("complete_case_p", oneway.test(Ozone ~ Month, data = d)$p.value)
section("B. Mean imputation (single imputation; standard errors too small)")
mi1 <- d; mi1$Ozone[is.na(mi1$Ozone)] <- mean(d$Ozone, na.rm = TRUE)
report("mean_imputation_p", oneway.test(Ozone ~ Month, data = mi1)$p.value)
section("C. Multiple imputation (mice, 20 imputations, seed 1973): the same question")
# Solar.R, Wind and Temp inform the imputation of Ozone (Sterne et al. 2009);
# the analysis model is the same comparison of months as in A.
imp <- mice(d, m = 20, seed = 1973, printFlag = FALSE)
pooled <- D1(with(imp, lm(Ozone ~ Month)), with(imp, lm(Ozone ~ 1)))
report("mi_month_p", unname(pooled$result[1, "P(>F)"]))
report("complete_case_lm_p", anova(lm(Ozone ~ Month, data = d))["Month", "Pr(>F)"])
finish()
