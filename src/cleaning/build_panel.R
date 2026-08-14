# build_panel.R -----------------------------------------------------------
# Construct data/cleaned/state_obesity_panel.csv: weighted adult obesity
# prevalence (BMI >= 30) by state-year, with design-based standard errors.
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

# Returns BMI in kg/m^2, or NULL when the year carries neither source.
# Height is taken in inches throughout: that is the precision at which it is
# actually reported, and CDC's HTM* is inches rounded to whole centimetres,
# which is coarser.
compute_bmi <- function(d, year = NA_integer_) {
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

  weight_kg / (height_in * M_PER_IN)^2
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

  bmi_computed <- compute_bmi(d, year)

  if (bmi_source == "computed" && !is.null(bmi_computed)) {
    d$bmi_val <- bmi_computed
    both <- !is.na(bmi_computed) & !is.na(bmi_cdc)
    log_msg(sprintf("%d: BMI computed from height/weight (median %.2f; CDC %s median %.2f, offset %+.4f)",
                    year, stats::median(bmi_computed, na.rm = TRUE),
                    sprintf("_BMI/%d", div), stats::median(bmi_cdc, na.rm = TRUE),
                    if (any(both)) mean(bmi_cdc[both] - bmi_computed[both]) else NA_real_))
  } else {
    if (bmi_source == "computed") {
      log_warn(sprintf("%d: no height/weight available, falling back to CDC _BMI", year))
    }
    d$bmi_val <- bmi_cdc
    log_msg(sprintf("%d: BMI from CDC precomputed, divisor %d (median %.2f)",
                    year, div, stats::median(bmi_cdc, na.rm = TRUE)))
  }
  d$obese <- as.numeric(d$bmi_val >= OBESE_CUTOFF)

  # Analytic-sample indicator. Kept as a column so the design can be built
  # on all rows and subset afterwards.
  plausible <- !is.na(d$bmi_val) & d$bmi_val >= BMI_MIN & d$bmi_val <= BMI_MAX
  # Age screen: BRFSS is an adult survey, but raw AGE carries 7/9 as
  # don't-know/refused in the pre-2019 files; both fall below 18 and drop
  # out here. Years whose age concept is absent are not screened.
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
estimate_year <- function(year) {
  prep <- prepare_year(year)
  if (is.null(prep)) return(NULL)
  des_sub <- prep$design
  d <- prep$data

  est <- svyby(~obese, ~state, des_sub, svymean, na.rm = TRUE,
               keep.names = FALSE)
  names(est) <- c("state_fips", "prev_obese", "se")

  n_unw <- d %>%
    filter(keep) %>%
    count(state, name = "n_unweighted") %>%
    rename(state_fips = state)

  out <- est %>%
    left_join(n_unw, by = "state_fips") %>%
    mutate(
      year       = year,
      state_name = unname(STATE_FIPS[as.character(state_fips)]),
      ci_lower   = prev_obese - stats::qnorm(0.975) * se,
      ci_upper   = prev_obese + stats::qnorm(0.975) * se
    )

  log_msg(sprintf("%d: %d states, mean prevalence %.3f, N = %s", year,
                  nrow(out), mean(out$prev_obese),
                  format(sum(out$n_unweighted), big.mark = ",")))
  out
}

build_panel <- function(years = NULL, write = TRUE) {
  if (is.null(years)) {
    cw <- utils::read.csv(file.path(dir_cleaned(), "crosswalk.csv"),
                          stringsAsFactors = FALSE)
    years <- usable_years(cw)
  }
  res <- list()
  for (y in years) {
    r <- tryCatch(estimate_year(y), error = function(e) {
      log_warn(sprintf("%d: estimation failed -- %s", y, conditionMessage(e)))
      NULL
    })
    if (!is.null(r)) res[[as.character(y)]] <- r
  }
  panel <- bind_rows(res) %>%
    select(state_fips, state_name, year, prev_obese, se,
           n_unweighted, ci_lower, ci_upper) %>%
    arrange(state_fips, year)

  if (write) {
    ensure_dir(dir_cleaned())
    utils::write.csv(panel, file.path(dir_cleaned(), "state_obesity_panel.csv"),
                     row.names = FALSE)
    log_msg(sprintf("state_obesity_panel.csv written: %d rows, %d years",
                    nrow(panel), length(unique(panel$year))))
  }
  panel
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  yrs <- if (length(args)) as.integer(args) else NULL
  invisible(build_panel(yrs))
}
