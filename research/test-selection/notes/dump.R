for (f in c("rstatix::check_test_assumptions")) { cat("=====", f, "\n"); print(eval(parse(text = f))) }
cat("===== testflow exports\n"); print(getNamespaceExports("testflow"))
cat("===== AssumpSure exports\n"); print(getNamespaceExports("AssumpSure"))
