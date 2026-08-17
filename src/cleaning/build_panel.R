# build_panel.R -----------------------------------------------------------
# Construct data/cleaned/state_obesity_panel.csv: weighted adult obesity
# prevalence (BMI >= 30) plus weighted mean BMI, height, weight and age by
# state-year, with design-based standard errors.
#
# All five measures are estimated on the SAME analytic sample in a single
# svyby() call, so a state-year's mean height and mean BMI describe exactly
# the same set of respondents. A measure that is not complete on that sample
# is reported as NA for the year rather than estimated on a subset -- see
# estimate_year().
#
# All estimates are survey-weighted. The design is built on the FULL year of
# data and then subset, rather than filtering rows first -- dropping rows
# before svydesign() discards stratum/PSU structure and biases the variance
# estimates. See docs/DECISIONS.md.

source(here::here("src", "common.R"))
source(here::here("src", "scrape", "fetch_brfss.R"))
source(here::here("src", "cleaning", "harmonize.R"))

suppressPackageStartupMessages({
  library(survey)
  library(dplyr)
})

# Lonely PSUs (a stratum contributing a single PSU) appear in thin
# state-years. "adjust" centers those strata at the population grand mean
# instead of erroring, which is conservative -- it neither drops the record
# nor understates its variance contribution. Alternatives considered in
# docs/DECISIONS.md.
options(survey.lonely.psu = "adjust")

# BMI plausibility bounds. Applied after rescaling, in BMI units.
BMI_MIN <- 12
BMI_MAX <- 60

OBESE_CUTOFF <- 30

# Age top-code. Raw AGE (1990-2012) is uncapped; from 2013 CDC ships only
# _AGE80, which is collapsed above 80. Capping every year at 80 is what makes
# `mean_age` a comparable series across that switch -- see DECISIONS.md §16.
AGE_TOPCODE <- 80

# Panel measures ------------------------------------------------------------
# Maps the analysis-sample column carrying each measure to the name it takes
# in the published panel. Order fixes the column order of the output.
# Standard-error columns are derived from these names (prev_/mean_ -> se_).
PANEL_MEASURES <- c(
  obese      = "prev_obese",
  bmi_val    = "mean_bmi",
  height_val = "mean_height_in",
  weight_val = "mean_weight_kg",
  age_val    = "mean_age"
)

se_name <- function(measure) paste0("se_", sub("^(prev|mean)_", "", measure))

# BMI percentiles ----------------------------------------------------------
# The percentile panel (data/cleaned/state_bmi_percentiles.csv) reports the
# weighted BMI distribution within each state-year, one row per percentile.
#
# 1:99 and not 1:100. The 100th percentile is the sample maximum, and this
# pipeline caps BMI at BMI_MAX = 60 -- so p100 would report our own filter
# back to us in nearly every cell, not a feature of the data. p0 is the
# minimum and equally an artifact of BMI_MIN. Both are omitted deliberately.
PERCENTILES <- 1:99

# Weighted quantile: the smallest observed BMI whose cumulative weight share
# reaches p. This is exactly what svyquantile() returns as a point estimate
# -- verified bit-identical (max difference 0 across every state and every
# percentile) in 1990, 2001 and 2013 -- but it costs 0.03 s per year against
# svyquantile's 80 s (1990) to 8 min (2013), because svyquantile spends
# essentially all its time on variance/CI machinery that it computes even
# when se = FALSE.
#
# The estimates are survey-weighted: `w` is the final weight, and dropping it
# would give the unweighted distribution, which is a different quantity. What
# is NOT available here is a design-based standard error per percentile --
# see DECISIONS.md §18.
weighted_quantile <- function(x, w, p) {
  keep <- !is.na(x) & !is.na(w) & w > 0
  x <- x[keep]; w <- w[keep]
  if (!length(x)) return(rep(NA_real_, length(p)))
  o <- order(x)
  x <- x[o]; w <- w[o]
  cw <- cumsum(w) / sum(w)
  x[pmin(findInterval(p, cw) + 1L, length(x))]
}

# Long-format percentiles for one year: one row per state x percentile.
percentiles_year <- function(ds, year) {
  p <- PERCENTILES / 100
  sts <- sort(unique(ds$state))
  bind_rows(lapply(sts, function(s) {
    i <- ds$state == s
    data.frame(
      state_fips   = s,
      year         = year,
      percentile   = PERCENTILES,
      bmi          = weighted_quantile(ds$bmi_val[i], ds$finalwt[i], p),
      n_unweighted = sum(i)
    )
  }))
}

# BMI scaling --------------------------------------------------------------
# BRFSS stores BMI as an integer with implied decimals, and the number of
# implied places changes across the series (_BMI2 in 2000 carries one,
# _BMI4/_BMI5 carry two). Detect it from the data instead of hardcoding:
# pick the divisor that puts the median in a physically sensible range.
# The median is robust to the missing-value sentinels (999 / 9999).
detect_bmi_divisor <- function(x) {
  x <- x[is.finite(x) & x > 0]
  if (!length(x)) return(NA_real_)
  for (d in 10^(0:5)) {
    m <- stats::median(x / d)
    if (m >= 15 && m <= 45) return(d)
  }
  NA_real_
}

# Sentinels are all-9s at the variable's own width, and the width tracks the
# number of implied decimals: 999 (2000), 9999 (2010), 999999 (2001).
# Cleared before rescaling so the unweighted N counts are right -- after
# rescaling they land outside BMI_MAX and would be filtered anyway, but they
# would still have been counted.
#
# Safe as a blanket rule: an all-9s code is never a plausible BMI at any of
# the scales in use (999 -> 99.9 at one decimal, 9999 -> 0.9999 at four).
clear_bmi_sentinels <- function(x) {
  x[x %in% (10^(3:8) - 1)] <- NA_real_
  x
}

# BMI from reported height and weight ---------------------------------------
# Preferred over CDC's precomputed _BMI*. See DECISIONS.md §1a.
#
# Physiological bounds double as sentinel filters: BRFSS uses 7777/9999 for
# don't-know/refused, and every such code lies far outside these ranges.
HEIGHT_IN_MIN <- 36    # 3 ft
HEIGHT_IN_MAX <- 84    # 7 ft
WEIGHT_KG_MIN <- 20
WEIGHT_KG_MAX <- 300

LB_PER_KG <- 0.45359237
M_PER_IN  <- 0.0254

# Reported height, "FII" format: 507 = 5 ft 7 in. From 2001 the same field
# also carries metric answers as 9XXX, where XXX is centimetres.
decode_height_in <- function(x) {
  out <- rep(NA_real_, length(x))
  fii <- !is.na(x) & x >= 200 & x <= 711
  out[fii] <- (x[fii] %/% 100) * 12 + (x[fii] %% 100)
  metric <- !is.na(x) & x >= 9000 & x <= 9998
  out[metric] <- (x[metric] - 9000) / 2.54
  out
}

# Reported weight in pounds; from 2001, 9XXX carries kilograms.
decode_weight_kg <- function(x) {
  out <- rep(NA_real_, length(x))
  lbs <- !is.na(x) & x >= 50 & x <= 776
  out[lbs] <- x[lbs] * LB_PER_KG
  metric <- !is.na(x) & x >= 9000 & x <= 9998
  out[metric] <- x[metric] - 9000
  out
}

# Implied decimals on the derived height/weight variables are no more stable
# than they are on _BMI*: WTKG is whole kilograms in 2001 but carries two
# implied decimals from 2002. Detect the divisor from the data, the same way
# detect_bmi_divisor() does, rather than hardcoding one.
#
# `plausible` is the range the MEDIAN of a national adult sample must fall in
# -- deliberately tight, since it only has to discriminate between powers of
# ten, and a wrong guess here silently empties a year.
detect_scale_divisor <- function(x, plausible) {
  x <- x[is.finite(x) & x > 0]
  if (!length(x)) return(NA_real_)
  for (d in 10^(0:4)) {
    m <- stats::median(x / d)
    if (m >= plausible[1] && m <= plausible[2]) return(d)
  }
  NA_real_
}

# Returns a list of height (inches), weight (kilograms) and the BMI implied
# by them, or NULL when the year carries neither source.
#
# Height is taken in inches throughout: that is the precision at which it is
# actually reported, and CDC's HTM* is inches rounded to whole centimetres,
# which is coarser. Weight is kept in kilograms, the unit BMI is defined in;
# pounds are weight_kg / 0.45359237.
derive_anthro <- function(d, year = NA_integer_) {
  n <- nrow(d)

  height_in <- rep(NA_real_, n)
  if ("height_in" %in% names(d)) {
    hdiv <- detect_scale_divisor(as.numeric(d$height_in), c(60, 72))
    if (is.na(hdiv)) {
      log_warn(sprintf("%s: could not infer height scale, ignoring height_in",
                       year))
    } else {
      height_in <- as.numeric(d$height_in) / hdiv
      if (hdiv != 1) {
        log_msg(sprintf("%s: height_in divisor %g", year, hdiv))
      }
    }
  }
  if ("height_raw" %in% names(d)) {
    fallback <- decode_height_in(as.numeric(d$height_raw))
    height_in[is.na(height_in)] <- fallback[is.na(height_in)]
  }

  weight_kg <- rep(NA_real_, n)
  if ("weight_kg" %in% names(d)) {
    wdiv <- detect_scale_divisor(as.numeric(d$weight_kg), c(50, 110))
    if (is.na(wdiv)) {
      log_warn(sprintf("%s: could not infer weight scale, ignoring weight_kg",
                       year))
    } else {
      weight_kg <- as.numeric(d$weight_kg) / wdiv
      log_msg(sprintf("%s: weight_kg divisor %g (median %.2f kg)", year, wdiv,
                      stats::median(weight_kg, na.rm = TRUE)))
    }
  }
  if ("weight_raw" %in% names(d)) {
    fallback <- decode_weight_kg(as.numeric(d$weight_raw))
    weight_kg[is.na(weight_kg)] <- fallback[is.na(weight_kg)]
  }

  if (all(is.na(height_in)) || all(is.na(weight_kg))) return(NULL)

  height_in[height_in < HEIGHT_IN_MIN | height_in > HEIGHT_IN_MAX] <- NA_real_
  weight_kg[weight_kg < WEIGHT_KG_MIN | weight_kg > WEIGHT_KG_MAX] <- NA_real_

  bmi <- weight_kg / (height_in * M_PER_IN)^2

  # Height, weight and BMI are published side by side, so they must describe
  # the same respondents. A record with an implausible weight already loses
  # its BMI; blanking its height too keeps `mean_height_in` from being the
  # mean over a slightly larger sample than `mean_bmi`.
  height_in[is.na(bmi)] <- NA_real_
  weight_kg[is.na(bmi)] <- NA_real_

  list(bmi = bmi, height_in = height_in, weight_kg = weight_kg)
}

# Sample construction ------------------------------------------------------
# Returns the survey design for one year, already subset to the analytic
# sample, plus the underlying data frame. Shared by build_panel and
# validate.R so both apply identical construction rules.
prepare_year <- function(year, bmi_source = c("computed", "cdc")) {
  bmi_source <- match.arg(bmi_source)
  d <- load_parsed(year)

  # CDC's precomputed variable, retained for comparison and as a fallback.
  div <- detect_bmi_divisor(clear_bmi_sentinels(d$bmi))
  if (is.na(div)) {
    log_warn(sprintf("%d: could not infer BMI scale, year dropped", year))
    return(NULL)
  }
  bmi_cdc <- clear_bmi_sentinels(d$bmi) / div

  anthro <- derive_anthro(d, year)

  if (bmi_source == "computed" && !is.null(anthro)) {
    d$bmi_val    <- anthro$bmi
    d$height_val <- anthro$height_in
    d$weight_val <- anthro$weight_kg
    both <- !is.na(anthro$bmi) & !is.na(bmi_cdc)
    log_msg(sprintf("%d: BMI computed from height/weight (median %.2f; CDC %s median %.2f, offset %+.4f)",
                    year, stats::median(anthro$bmi, na.rm = TRUE),
                    sprintf("_BMI/%d", div), stats::median(bmi_cdc, na.rm = TRUE),
                    if (any(both)) mean(bmi_cdc[both] - anthro$bmi[both]) else NA_real_))
  } else {
    if (bmi_source == "computed") {
      log_warn(sprintf("%d: no height/weight available, falling back to CDC _BMI", year))
    }
    d$bmi_val <- bmi_cdc
    # Height and weight are unavailable (or deliberately unused) here, so the
    # panel reports them as NA for this year rather than mixing sources.
    d$height_val <- NA_real_
    d$weight_val <- NA_real_
    log_msg(sprintf("%d: BMI from CDC precomputed, divisor %d (median %.2f)",
                    year, div, stats::median(bmi_cdc, na.rm = TRUE)))
  }
  d$obese <- as.numeric(d$bmi_val >= OBESE_CUTOFF)

  # Age, top-coded at 80 in every year so the pre-2013 raw AGE and the
  # 2013+ _AGE80 are on the same scale. The don't-know/refused codes 7 and 9
  # (present through 2012, the last raw-AGE year) fall below 18 and are
  # removed by the adult screen below, so they never reach the mean.
  # 99 is a legitimate coded age in those files, not a sentinel, and the
  # top-code absorbs it either way. See DECISIONS.md §16a.
  d$age_val <- if ("age" %in% names(d)) {
    pmin(as.numeric(d$age), AGE_TOPCODE)
  } else {
    NA_real_
  }

  # Analytic-sample indicator. Kept as a column so the design can be built
  # on all rows and subset afterwards.
  plausible <- !is.na(d$bmi_val) & d$bmi_val >= BMI_MIN & d$bmi_val <= BMI_MAX
  # Age screen: BRFSS is an adult survey, but raw AGE carries 7/9 as
  # don't-know/refused through 2012; both fall below 18 and drop out here.
  # Years whose age concept is absent are not screened.
  adult <- if ("age" %in% names(d) && !all(is.na(d$age))) {
    !is.na(d$age) & d$age >= 18
  } else {
    rep(TRUE, nrow(d))
  }
  # Pregnancy: 1 = currently pregnant. NA means not asked (men, women
  # outside childbearing ages) and must be kept.
  notpreg <- if ("pregnant" %in% names(d)) {
    is.na(d$pregnant) | d$pregnant != 1
  } else {
    rep(TRUE, nrow(d))
  }
  in_panel <- d$state %in% PANEL_FIPS
  usable_wt <- !is.na(d$finalwt) & d$finalwt > 0

  d$keep <- plausible & adult & notpreg & in_panel & usable_wt

  if (sum(d$keep) == 0) {
    log_warn(sprintf("%d: analytic sample empty, year dropped", year))
    return(NULL)
  }

  # Records with a missing or non-positive final weight cannot enter a
  # weighted estimate at all; drop them before the design is built and log
  # the count so the loss is visible.
  n_badwt <- sum(!usable_wt)
  if (n_badwt > 0) {
    log_warn(sprintf("%d: %d records with missing/non-positive weight dropped",
                     year, n_badwt))
  }
  d <- d[usable_wt, ]

  des <- svydesign(ids = ~psu, strata = ~strata, weights = ~finalwt,
                   data = d, nest = TRUE)
  list(design = subset(des, keep), data = d, divisor = div)
}

# Per-year estimation ------------------------------------------------------
# Which measures can be estimated for this year.
#
# This is an ASSERTION, not a repair. The analytic sample is already complete
# on all five measures by construction -- `keep` requires a usable BMI, which
# requires both a plausible height and a plausible weight, and the 18+ screen
# requires an age -- and it was verified to drop zero records in all 34 years
# (DECISIONS.md §16). The check earns its place only as a guard: if a measure
# with genuine item nonresponse is ever added here, svymean(na.rm = TRUE)
# would delete records missing it and quietly shift every other estimate in
# the call, including prev_obese. Failing loudly beats that.
#
# The one live case is a year that fell back to CDC's precomputed _BMI*,
# which carries no height or weight to report. No year currently does.
available_measures <- function(ds, year) {
  vars <- names(PANEL_MEASURES)
  ok <- vapply(vars, function(v) {
    v %in% names(ds) && sum(!is.na(ds[[v]])) == nrow(ds)
  }, logical(1))
  if (any(!ok)) {
    log_warn(sprintf("%d: not complete on the analytic sample, reported as NA: %s",
                     year, paste(PANEL_MEASURES[vars[!ok]], collapse = ", ")))
  }
  vars[ok]
}

estimate_year <- function(year) {
  prep <- prepare_year(year)
  if (is.null(prep)) return(NULL)
  des_sub <- prep$design
  d <- prep$data
  ds <- d[d$keep, , drop = FALSE]

  vars <- available_measures(ds, year)
  if (!"obese" %in% vars) {
    log_warn(sprintf("%d: obesity indicator unusable, year dropped", year))
    return(NULL)
  }

  # One svyby call for all measures: same design, same domains, and the
  # estimates are guaranteed to come from the same records.
  est <- svyby(stats::reformulate(vars), ~state, des_sub, svymean,
               na.rm = TRUE, keep.names = FALSE)
  # svyby returns the by-variable, then one estimate column per variable in
  # formula order, then the matching standard errors in the same order.
  k <- length(vars)
  stopifnot(ncol(est) == 2 * k + 1)
  names(est) <- c("state_fips", unname(PANEL_MEASURES[vars]),
                  se_name(unname(PANEL_MEASURES[vars])))

  n_unw <- ds %>%
    count(state, name = "n_unweighted") %>%
    rename(state_fips = state)

  out <- est %>%
    left_join(n_unw, by = "state_fips") %>%
    mutate(
      year       = year,
      state_name = unname(STATE_FIPS[as.character(state_fips)]),
      # CI reported for the prevalence only, since that is the quantity the
      # panel is benchmarked on. For the means, use estimate +/- 1.96 * se.
      ci_lower_obese = prev_obese - stats::qnorm(0.975) * se_obese,
      ci_upper_obese = prev_obese + stats::qnorm(0.975) * se_obese
    )

  # Measures dropped above still need their columns, so every year has the
  # same schema.
  for (m in setdiff(unname(PANEL_MEASURES), names(out))) out[[m]] <- NA_real_
  for (s in setdiff(se_name(unname(PANEL_MEASURES)), names(out))) out[[s]] <- NA_real_

  # National prevalence, from the SAME design object the state estimates came
  # from. It is population-weighted by the survey weights themselves, not
  # averaged across the state panel (DECISIONS.md §11). Computed here rather
  # than in validate.R because the design is already built: doing it there
  # meant reconstructing every year's design a second time, which was the
  # single most expensive redundancy in the pipeline.
  natl_est <- svymean(~obese, des_sub, na.rm = TRUE)
  natl <- data.frame(
    year       = year,
    brfss_prev = unname(coef(natl_est)),
    brfss_se   = unname(survey::SE(natl_est))
  )

  # BMI percentiles, from the same analytic sample and the same weights.
  pct <- percentiles_year(ds, year)
  pct$state_name <- unname(STATE_FIPS[as.character(pct$state_fips)])

  log_msg(sprintf("%d: %d states, mean prevalence %.3f, mean BMI %.2f, national %.4f, N = %s",
                  year, nrow(out), mean(out$prev_obese), mean(out$mean_bmi),
                  natl$brfss_prev, format(sum(out$n_unweighted), big.mark = ",")))
  list(state = out, national = natl, percentiles = pct)
}

build_panel <- function(years = NULL, write = TRUE) {
  if (is.null(years)) {
    cw <- utils::read.csv(file.path(dir_cleaned(), "crosswalk.csv"),
                          stringsAsFactors = FALSE)
    years <- usable_years(cw)
  }
  res <- list()
  natl <- list()
  pcts <- list()
  for (y in years) {
    r <- tryCatch(estimate_year(y), error = function(e) {
      log_warn(sprintf("%d: estimation failed -- %s", y, conditionMessage(e)))
      NULL
    })
    if (!is.null(r)) {
      res[[as.character(y)]]  <- r$state
      natl[[as.character(y)]] <- r$national
      pcts[[as.character(y)]] <- r$percentiles
    }
  }
  # Estimate and its standard error adjacent, measures in PANEL_MEASURES
  # order, identifiers first and the sample size last.
  value_cols <- as.vector(rbind(unname(PANEL_MEASURES),
                                se_name(unname(PANEL_MEASURES))))
  panel <- bind_rows(res) %>%
    select(state_fips, state_name, year,
           all_of(value_cols), ci_lower_obese, ci_upper_obese,
           n_unweighted) %>%
    arrange(state_fips, year)

  national <- bind_rows(natl)

  percentiles <- bind_rows(pcts) %>%
    select(state_fips, state_name, year, percentile, bmi, n_unweighted) %>%
    arrange(state_fips, year, percentile)

  if (write) {
    ensure_dir(dir_cleaned())
    utils::write.csv(panel, file.path(dir_cleaned(), "state_obesity_panel.csv"),
                     row.names = FALSE)
    log_msg(sprintf("state_obesity_panel.csv written: %d rows, %d years",
                    nrow(panel), length(unique(panel$year))))

    utils::write.csv(percentiles,
                     file.path(dir_cleaned(), "state_bmi_percentiles.csv"),
                     row.names = FALSE)
    log_msg(sprintf("state_bmi_percentiles.csv written: %s rows (%d state-years x %d percentiles)",
                    format(nrow(percentiles), big.mark = ","),
                    nrow(percentiles) / length(PERCENTILES), length(PERCENTILES)))

    write_national(national)
  }
  invisible(list(panel = panel, percentiles = percentiles, national = national))
}

# national_prevalence.csv --------------------------------------------------
# MERGED, never overwritten wholesale: build_panel() is routinely run on a
# subset of years (`Rscript src/run_all.R 2000 2010 2019`), and clobbering the
# file with three rows would silently destroy the other 31. Years present in
# the new estimates replace their cached counterparts; the rest are kept.
path_national <- function() file.path(dir_cleaned(), "national_prevalence.csv")

write_national <- function(national) {
  if (is.null(national) || nrow(national) == 0) return(invisible(NULL))
  cached <- if (file.exists(path_national())) {
    utils::read.csv(path_national(), stringsAsFactors = FALSE)
  } else {
    national[0, ]
  }
  out <- bind_rows(national, cached[!cached$year %in% national$year, ]) %>%
    arrange(year)
  utils::write.csv(out, path_national(), row.names = FALSE)
  log_msg(sprintf("national_prevalence.csv written: %d years (%d new/refreshed)",
                  nrow(out), nrow(national)))
  invisible(out)
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  yrs <- if (length(args)) as.integer(args) else NULL
  invisible(build_panel(yrs))
}
