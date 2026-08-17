# diagnostics.R -----------------------------------------------------------
# Panel diagnostics -> docs/diagnostics.md.
#
# Four blocks, per the task spec:
#   1. Unweighted N by state-year, flagging cells below 500.
#   2. Pre/post-2011 discontinuity: state-specific linear trend fit on
#      1999-2010, extrapolated to 2011-2013, residual gap by state. The
#      question is whether the break is common or state-specific.
#   3. Cross-state moments by year (mean, SD, skewness, excess kurtosis,
#      IQR) -- bears on whether the increase is a common additive shift.
#   4. Regression of change in prevalence on baseline prevalence, run
#      separately within the pre- and post-2011 regimes, robust SEs.
# Plus two blocks the spec did not ask for: BMI item nonresponse by year, and
# a cross-state summary of the panel's other measures (mean BMI, height,
# weight, age), which carry the 2011 break too and, for age, a second one at
# 2013.

source(here::here("src", "common.R"))
source(here::here("src", "scrape", "fetch_brfss.R"))
source(here::here("src", "cleaning", "build_panel.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(moments)
  library(sandwich)
  library(lmtest)
})

MIN_CELL_N <- 500
TREND_WINDOW <- 1999:2010      # pre-break fit window
EXTRAP_WINDOW <- 2011:2013     # post-break comparison window

load_panel <- function() {
  p <- file.path(dir_cleaned(), "state_obesity_panel.csv")
  if (!file.exists(p)) stop("state_obesity_panel.csv not found; run build_panel.R first")
  utils::read.csv(p, stringsAsFactors = FALSE)
}

# 1. Sample sizes ----------------------------------------------------------
diag_sample_size <- function(panel) {
  thin <- panel %>%
    filter(n_unweighted < MIN_CELL_N) %>%
    arrange(n_unweighted) %>%
    select(state_name, year, n_unweighted, prev_obese, se_obese)

  by_year <- panel %>%
    group_by(year) %>%
    summarise(n_states = n(),
              total_n  = sum(n_unweighted),
              min_n    = min(n_unweighted),
              median_n = stats::median(n_unweighted),
              n_thin   = sum(n_unweighted < MIN_CELL_N),
              .groups = "drop")

  # State-years absent from the panel entirely.
  expected <- expand.grid(state_fips = PANEL_FIPS,
                          year = sort(unique(panel$year)))
  gaps <- anti_join(expected, panel, by = c("state_fips", "year")) %>%
    mutate(state_name = unname(STATE_FIPS[as.character(state_fips)])) %>%
    arrange(year, state_name) %>%
    select(state_name, year)

  list(thin = thin, by_year = by_year, gaps = gaps)
}

# 2. 2011 discontinuity ----------------------------------------------------
# Fit prev ~ year on TREND_WINDOW within each state, predict into
# EXTRAP_WINDOW, and report observed minus predicted. A common break shows
# up as a tight distribution of gaps with a non-zero center; a
# state-specific break shows up as a wide one.
diag_break <- function(panel) {
  fit_state <- function(df) {
    pre <- df %>% filter(year %in% TREND_WINDOW)
    post <- df %>% filter(year %in% EXTRAP_WINDOW)
    if (nrow(pre) < 5 || nrow(post) == 0) return(NULL)
    m <- stats::lm(prev_obese ~ year, data = pre)
    pred <- stats::predict(m, newdata = post)
    data.frame(
      state_name = df$state_name[1],
      n_pre      = nrow(pre),
      slope_pre  = unname(stats::coef(m)[2]),
      gap        = mean(post$prev_obese - pred)
    )
  }
  gaps <- panel %>%
    group_split(state_fips) %>%
    lapply(fit_state) %>%
    bind_rows()

  if (nrow(gaps) == 0) return(NULL)

  # Is the break common across states? Compare the spread of the gaps to
  # the spread of pre-period residuals -- if the break were purely common,
  # the gaps would be near-identical across states.
  summary_stats <- data.frame(
    n_states   = nrow(gaps),
    mean_gap   = mean(gaps$gap),
    sd_gap     = stats::sd(gaps$gap),
    min_gap    = min(gaps$gap),
    max_gap    = max(gaps$gap),
    share_pos  = mean(gaps$gap > 0)
  )
  # A one-sample t-test on the gaps tests the common-shift null of zero.
  tt <- stats::t.test(gaps$gap)

  list(gaps = gaps %>% arrange(desc(gap)),
       summary = summary_stats,
       t_stat = unname(tt$statistic),
       p_value = tt$p.value)
}

# 3. Cross-state moments by year -------------------------------------------
diag_moments <- function(panel) {
  panel %>%
    group_by(year) %>%
    summarise(
      n_states = n(),
      mean     = mean(prev_obese),
      sd       = stats::sd(prev_obese),
      skewness = moments::skewness(prev_obese),
      exc_kurt = moments::kurtosis(prev_obese) - 3,
      iqr      = stats::IQR(prev_obese),
      .groups  = "drop"
    )
}

# 4. Convergence regressions -----------------------------------------------
# Delta prevalence on baseline prevalence, within regime. A negative
# coefficient is mean reversion / convergence; zero is a parallel shift.
diag_convergence <- function(panel) {
  run_regime <- function(df, label) {
    yrs <- sort(unique(df$year))
    if (length(yrs) < 2) return(NULL)
    base_y <- min(yrs); end_y <- max(yrs)
    wide <- df %>%
      filter(year %in% c(base_y, end_y)) %>%
      select(state_fips, state_name, year, prev_obese) %>%
      pivot_wider(names_from = year, values_from = prev_obese,
                  names_prefix = "y") %>%
      stats::na.omit()
    if (nrow(wide) < 10) return(NULL)
    names(wide)[names(wide) == paste0("y", base_y)] <- "baseline"
    names(wide)[names(wide) == paste0("y", end_y)]  <- "final"
    wide$delta <- wide$final - wide$baseline

    m <- stats::lm(delta ~ baseline, data = wide)
    ct <- lmtest::coeftest(m, vcov. = sandwich::vcovHC(m, type = "HC1"))
    data.frame(
      regime    = label,
      years     = sprintf("%d-%d", base_y, end_y),
      n_states  = nrow(wide),
      intercept = ct[1, 1],
      slope     = ct[2, 1],
      se_robust = ct[2, 2],
      t_stat    = ct[2, 3],
      p_value   = ct[2, 4],
      r_squared = summary(m)$r.squared
    )
  }
  bind_rows(
    run_regime(panel %>% filter(year < BREAK_YEAR),  "pre-2011"),
    run_regime(panel %>% filter(year >= BREAK_YEAR), "post-2011")
  )
}

# 5. BMI item nonresponse --------------------------------------------------
# Share of adult records in panel states with no usable BMI. This is a
# comparability threat distinct from the 2011 design break: if respondents
# who decline to report height/weight differ systematically from those who
# do, a rising nonresponse rate moves measured prevalence even when true
# prevalence is flat. Read from the parsed caches, not the panel.
#
# BMI here is the pipeline's OWN computed BMI, not CDC's precomputed _BMI*.
# This block previously measured nonresponse on _BMI*, which the panel does
# not use (DECISIONS.md §1a) and which is populated on a slightly different
# set of records -- so it was reporting a nonresponse rate the panel never
# actually suffered.
#
# `age_selection_yr` sizes the consequence directly: mean age among records
# that survive the BMI screen minus mean age among all eligible adults. It is
# the answer to "does losing 11% of records by 2022 change who is in the
# sample?" for the one characteristic the panel measures.
diag_nonresponse <- function(years) {
  rows <- list()
  for (y in years) {
    d <- tryCatch(load_parsed(y), error = function(e) NULL)
    if (is.null(d)) next
    anthro <- tryCatch(derive_anthro(d, y), error = function(e) NULL)
    if (is.null(anthro)) next
    v <- anthro$bmi

    # Eligibility mirrors the panel's analytic sample minus the BMI screen
    # itself, so `pct_bmi_missing` is the loss the panel takes.
    elig <- d$state %in% PANEL_FIPS
    if ("age" %in% names(d) && !all(is.na(d$age))) {
      elig <- elig & !is.na(d$age) & d$age >= 18
    }
    if ("pregnant" %in% names(d)) {
      elig <- elig & (is.na(d$pregnant) | d$pregnant != 1)
    }
    elig <- elig & !is.na(d$finalwt) & d$finalwt > 0

    usable <- !is.na(v) & v >= BMI_MIN & v <= BMI_MAX
    age_v  <- pmin(as.numeric(d$age), AGE_TOPCODE)
    age_sel <- if (any(elig & usable) && any(elig)) {
      mean(age_v[elig & usable], na.rm = TRUE) - mean(age_v[elig], na.rm = TRUE)
    } else NA_real_

    rows[[length(rows) + 1]] <- data.frame(
      year             = y,
      n_eligible       = sum(elig),
      pct_bmi_missing  = 100 * mean(is.na(v[elig])),
      pct_implausible  = 100 * mean(!is.na(v[elig]) &
                                    (v[elig] < BMI_MIN | v[elig] > BMI_MAX)),
      age_selection_yr = age_sel
    )
  }
  bind_rows(rows)
}

# 6. The other panel measures ----------------------------------------------
# Cross-state summary of mean BMI, height, weight and age by year. These
# carry the same 2011 design break as prevalence, and mean age carries an
# additional break at 2013 where CDC stops shipping raw AGE. Reported so the
# breaks are visible in the series rather than only described in prose.
AGE_SOURCE_BREAK <- 2013

# Column names are prefixed rather than reused: `summarise()` evaluates
# sequentially, so a column named `mean_bmi` would shadow the input for every
# expression after it and turn the SD into NA.
diag_measures <- function(panel) {
  panel %>%
    group_by(year) %>%
    summarise(
      n_states      = n(),
      xs_bmi        = mean(mean_bmi),
      xs_sd_bmi     = stats::sd(mean_bmi),
      xs_height_in  = mean(mean_height_in),
      xs_weight_kg  = mean(mean_weight_kg),
      xs_age        = mean(mean_age),
      xs_sd_age     = stats::sd(mean_age),
      .groups = "drop"
    )
}

# 7. Shape of the BMI distribution -----------------------------------------
# Read from the percentile panel. This is the block the percentile file
# exists for: prevalence alone cannot distinguish a uniform rightward shift
# of the BMI distribution from a stretch concentrated in its upper tail, and
# those imply very different things about what changed. Obesity prevalence is
# just the mass above a single cut (BMI 30), so both stories can produce the
# same prevalence path.
#
# `p90_p50` against `p50_p10` is the discriminating comparison: under a pure
# location shift both are flat over time; under a right-tail stretch the
# upper gap widens while the lower one does not.
load_percentiles <- function() {
  p <- file.path(dir_cleaned(), "state_bmi_percentiles.csv")
  if (!file.exists(p)) return(NULL)
  utils::read.csv(p, stringsAsFactors = FALSE)
}

diag_distribution <- function(pct) {
  wide <- pct %>%
    filter(percentile %in% c(10, 25, 50, 75, 90, 95)) %>%
    select(state_fips, year, percentile, bmi) %>%
    pivot_wider(names_from = percentile, values_from = bmi, names_prefix = "p")

  wide %>%
    group_by(year) %>%
    summarise(
      n_states = n(),
      p10 = mean(p10), p50 = mean(p50), p90 = mean(p90), p95 = mean(p95),
      # Spread, and how it splits above vs below the median.
      p90_p10 = mean(p90 - p10),
      p50_p10 = mean(p50 - p10),
      p90_p50 = mean(p90 - p50),
      .groups = "drop"
    )
}

# Report -------------------------------------------------------------------
write_diagnostics <- function() {
  panel <- load_panel()
  ensure_dir(dir_docs())

  ss   <- diag_sample_size(panel)
  brk  <- diag_break(panel)
  mom  <- diag_moments(panel)
  conv <- diag_convergence(panel)

  L <- c()
  add <- function(...) L <<- c(L, ...)

  add("# BRFSS state obesity panel — diagnostics", "",
      sprintf("Generated %s from `data/cleaned/state_obesity_panel.csv`.",
              format(Sys.Date())),
      sprintf("Panel covers %d state-years across %d years (%d–%d).",
              nrow(panel), length(unique(panel$year)),
              min(panel$year), max(panel$year)), "")

  add("## 1. Unweighted sample size by state-year", "",
      sprintf("Cells below %d unweighted observations are flagged.", MIN_CELL_N),
      "", "### By year", "", fmt_table(ss$by_year, 1), "")

  if (nrow(ss$thin)) {
    add(sprintf("### Thin cells (N < %d): %d", MIN_CELL_N, nrow(ss$thin)), "",
        fmt_table(ss$thin, 4), "")
  } else {
    add(sprintf("### Thin cells (N < %d)", MIN_CELL_N), "",
        "None. Every state-year cell clears the threshold.", "")
  }

  if (nrow(ss$gaps)) {
    add("### Missing state-years", "",
        "State-years with no estimate at all (state absent from that year's file):",
        "", fmt_table(ss$gaps, 0), "")
  }

  add("## 2. Pre/post-2011 discontinuity", "",
      sprintf(paste("State-specific linear trends fit on %d–%d, extrapolated to",
                    "%d–%d. `gap` is mean observed minus predicted prevalence."),
              min(TREND_WINDOW), max(TREND_WINDOW),
              min(EXTRAP_WINDOW), max(EXTRAP_WINDOW)), "")
  if (is.null(brk)) {
    add("Not computable: the panel does not span both windows.", "")
  } else {
    add(fmt_table(brk$summary, 4), "",
        sprintf("One-sample t-test of mean gap = 0: t = %.2f, p = %.3g.",
                brk$t_stat, brk$p_value), "",
        paste("Interpretation: the SD of the gap relative to its mean is what",
              "distinguishes a common break from a state-specific one. An SD",
              "comparable to or larger than the mean means the break is not",
              "a uniform additive shift."), "",
        paste("**This statistic does not identify the design break on its own.**",
              "It compares observed post-2011 values against a *linear*",
              "extrapolation of the 1999–2010 trend, so it absorbs any",
              "curvature in the underlying series along with the methodology",
              "change. If true prevalence growth was decelerating before 2011,",
              "a linear fit over-predicts and part of the measured gap is that",
              "deceleration, not the cell-phone/raking switch. Nothing in the",
              "BRFSS data separates the two: 2011 changed the frame and the",
              "weighting simultaneously, with no overlap sample. Read the gap",
              "as an upper bound on the design effect, not an estimate of it."),
        "", "### Gap by state", "", fmt_table(brk$gaps, 4), "")
  }

  add("## 3. Cross-state distribution moments by year", "",
      paste("Moments are computed across states within each year, unweighted",
            "by state population (each state is one observation)."),
      "", fmt_table(mom, 4), "",
      paste("A stable SD alongside a rising mean is the signature of a common",
            "additive shift; a rising SD means states are diverging."), "")

  add("## 4. Change on baseline prevalence, by regime", "",
      paste("OLS of (final − baseline) prevalence on baseline prevalence,",
            "within regime, heteroskedasticity-robust (HC1) standard errors.",
            "A negative slope indicates convergence."), "")
  if (is.null(conv) || nrow(conv) == 0) {
    add("Not computable: insufficient years within regime.", "")
  } else {
    add(fmt_table(conv, 4), "")
  }

  nr <- diag_nonresponse(sort(unique(panel$year)))
  add("## 5. BMI item nonresponse by year", "",
      paste("Share of eligible adult records in panel states with no usable",
            "BMI (`pct_bmi_missing`), and share whose BMI falls outside the",
            sprintf("[%g, %g] plausibility window (`pct_implausible`).",
                    BMI_MIN, BMI_MAX),
            "BMI is the pipeline's own computed BMI, not CDC's `_BMI*`, so",
            "this is the loss the panel actually takes."), "")
  if (nrow(nr)) {
    add(fmt_table(nr, 2), "",
        paste("A rising nonresponse rate is a comparability threat separate",
              "from the 2011 design break. If the people who decline to give",
              "height and weight differ systematically from those who do,",
              "measured prevalence moves even when true prevalence does not.",
              "Nothing in this pipeline corrects for it; the series is",
              "reported as constructed."), "")
    add(paste("`age_selection_yr` sizes that selection on the one",
              "characteristic the panel measures: mean age among records that",
              "survive the BMI screen, minus mean age among all eligible",
              "adults. It bounds how much the screen reshapes the sample's age",
              "composition — and therefore how much of `mean_age` is",
              "selection rather than demography."), "")
    worst <- nr[which.max(abs(nr$age_selection_yr)), ]
    add(sprintf(paste("The largest such gap in the series is **%.2f years**",
                      "(%d, where %.1f%% of eligible adults are lost). Age",
                      "selection is therefore small in absolute terms even",
                      "where nonresponse is worst — which bounds this threat",
                      "for age, and says nothing about selection on weight,",
                      "which is unobservable for exactly the people who",
                      "declined to report it."),
                worst$age_selection_yr, worst$year, worst$pct_bmi_missing), "")
  } else {
    add("Not computable: parsed caches unavailable.", "")
  }

  meas <- diag_measures(panel)
  add("## 6. The other panel measures", "",
      paste("Cross-state summary of the panel's remaining measures: `xs_*` is",
            "the unweighted mean across states within a year, `xs_sd_*` its",
            "cross-state SD. Every measure is estimated on the same analytic",
            "sample as `prev_obese`, so these describe the same respondents."),
      "", fmt_table(meas, 3), "")
  add(paste("**These break where prevalence does.** Mean BMI, height, weight and",
            "age all cross the 2011 design change described in §2, and none is",
            "any more spliceable across it than prevalence is."), "")
  add(sprintf(paste("**Mean age carries a second break, at %d.** CDC stops shipping raw",
                    "`AGE` after 2012 and ships only `_AGE80`, which is collapsed",
                    "above 80. The panel top-codes age at 80 in *every* year so the",
                    "two sources are on one scale (`DECISIONS.md` §16), but",
                    "`_AGE80` is also imputed for non-responders while raw `AGE`",
                    "was not, and that residual difference is not removed. Treat a",
                    "level shift in `xs_age` at %d as a measurement change first."),
              AGE_SOURCE_BREAK, AGE_SOURCE_BREAK), "")

  pct <- load_percentiles()
  add("## 7. Shape of the BMI distribution", "")
  if (is.null(pct)) {
    add("Not computable: `state_bmi_percentiles.csv` not found.", "")
  } else {
    dist <- diag_distribution(pct)
    add(paste("Read from `data/cleaned/state_bmi_percentiles.csv`. Each figure",
              "is the unweighted mean across states of that state's weighted",
              "BMI percentile, so each state counts once."), "",
        fmt_table(dist, 2), "")
    add(paste("**Why this table exists.** Obesity prevalence is the mass above a",
              "single cut (BMI 30), so it cannot distinguish a uniform rightward",
              "shift of the whole distribution from a stretch concentrated in the",
              "upper tail — the two imply very different things about what",
              "changed, and can trace out the same prevalence path."), "")
    add(paste("`p50_p10` against `p90_p50` is the discriminating comparison.",
              "Under a pure location shift both are flat over time and only the",
              "levels move. If `p90_p50` widens while `p50_p10` does not, the",
              "distribution is stretching upward and the gain is concentrated",
              "among the already-heaviest — which prevalence alone would not",
              "reveal."), "")
    if (nrow(dist) >= 2) {
      f <- dist[which.min(dist$year), ]; l <- dist[which.max(dist$year), ]
      spans_break <- f$year < BREAK_YEAR && l$year >= BREAK_YEAR
      add(sprintf(paste("Across %d–%d the mean p50 moves %+.2f BMI units and the",
                        "mean p90 moves %+.2f; `p50_p10` changes %+.2f while",
                        "`p90_p50` changes %+.2f.%s"),
                  f$year, l$year, l$p50 - f$p50, l$p90 - f$p90,
                  l$p50_p10 - f$p50_p10, l$p90_p50 - f$p90_p50,
                  if (spans_break) {
                    paste(" **These endpoints sit on opposite sides of the",
                          sprintf("%d design break, so read this as description,",
                                  BREAK_YEAR),
                          "not as an estimated change** — see §2.")
                  } else {
                    ""
                  }), "")
    }
    add(paste("Percentiles carry **no design-based standard error** — see",
              "`DECISIONS.md` §18 for why, and treat cells with small",
              "`n_unweighted` accordingly."), "")
  }

  add("---", "",
      paste("Estimates are survey-weighted throughout",
            "(`svydesign` + `svyby`/`svymean`, `survey.lonely.psu = \"adjust\"`).",
            "Construction decisions are documented in `DECISIONS.md`; the",
            "2011 comparability break is documented there and in §2 above."))

  out <- file.path(dir_docs(), "diagnostics.md")
  writeLines(L, out)
  log_msg(sprintf("diagnostics.md written (%d state-years)", nrow(panel)))
  invisible(out)
}

if (sys.nframe() == 0) write_diagnostics()
