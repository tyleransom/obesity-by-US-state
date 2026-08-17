# verify_percentiles.R -----------------------------------------------------
# One-off check, NOT part of the pipeline: run_all.R does not source this.
#
# Confirms that weighted_quantile() -- which build_panel.R uses to produce
# data/cleaned/state_bmi_percentiles.csv -- reproduces svyquantile()'s point
# estimates exactly. See DECISIONS.md §18.
#
# Full-panel verification is impractical: svyquantile() across all 51 states
# of 2013 ran over 2h45m without finishing, and 1,079 s for four states. This
# therefore probes a deliberately varied subset -- largest, large, smallest,
# and an atypical jurisdiction -- rather than the whole panel. 1990 was
# checked exhaustively (all 45 states) separately; both returned 0.
#
#   Rscript src/cleaning/verify_percentiles.R
#
# Expected output: "max|diff| = 0" for every year probed.
suppressPackageStartupMessages({library(survey); library(dplyr)})
source(here::here("src", "cleaning", "build_panel.R"))

qs <- PERCENTILES / 100
probe <- c(6, 48, 56, 11)   # California, Texas, Wyoming, District of Columbia

for (y in c(2013, 2019, 2001)) {
  prep <- prepare_year(y)
  des <- prep$design
  ds  <- prep$data[prep$data$keep, ]
  sts <- intersect(probe, unique(ds$state))

  t <- system.time({
    a <- lapply(sts, function(s) {
      as.numeric(svyquantile(~bmi_val, subset(des, state == s),
                             quantiles = qs, se = FALSE)$bmi_val[, 1])
    })
  })
  b <- lapply(sts, function(s) {
    i <- ds$state == s
    weighted_quantile(ds$bmi_val[i], ds$finalwt[i], qs)
  })
  worst <- max(mapply(function(u, v) max(abs(u - v)), a, b))
  cat(sprintf("VERIFY %d: %d states x %d pctiles | svyquantile %.0f s | max|diff| = %g\n",
              y, length(sts), length(qs), t[["elapsed"]], worst))
  flush.console()
}
cat("VERIFY done\n")
