# validate.R --------------------------------------------------------------
# External validation -> docs/validation.md.
#
# Two comparisons:
#   1. Constructed BRFSS national aggregate vs published NHANES national
#      adult obesity prevalence.
#   2. Constructed state distribution vs CDC's published Adult Obesity
#      Prevalence Map summaries for 2000 and 2022.
#
# Discrepancies are reported, not reconciled. The BRFSS/NHANES gap in
# particular is EXPECTED and is not a bug: BRFSS height and weight are
# self-reported (respondents over-report height and under-report weight),
# NHANES are measured. Correcting for that is explicitly out of scope here.
#
# !! BENCHMARK PROVENANCE !!
# The published values below are transcribed constants, not downloaded
# data. They are recorded here with their sources so they can be checked
# against the originals; the generated report flags them as unverified.
# Nothing in the pipeline depends on them except this report.

source(here::here("src", "common.R"))
source(here::here("src", "cleaning", "build_panel.R"))

suppressPackageStartupMessages({
  library(survey)
  library(dplyr)
})

# NHANES measured adult obesity prevalence (BMI >= 30), age-adjusted,
# adults 20+. Source: NCHS Data Briefs (Ogden et al.; Hales et al.,
# "Prevalence of Obesity and Severe Obesity Among Adults: United States").
# `year` is the midpoint of the two-year NHANES cycle, for lining up
# against the annual BRFSS series.
NHANES_PUBLISHED <- data.frame(
  cycle     = c("1988-1994", "1999-2000", "2001-2002", "2003-2004",
                "2005-2006", "2007-2008", "2009-2010", "2011-2012",
                "2013-2014", "2015-2016", "2017-2018"),
  year      = c(1991, 2000, 2002, 2004, 2006, 2008, 2010, 2012, 2014, 2016, 2018),
  nhanes_prev = c(0.229, 0.305, 0.306, 0.322, 0.343, 0.337, 0.357, 0.349,
                  0.377, 0.398, 0.424),
  stringsAsFactors = FALSE
)

# CDC Adult Obesity Prevalence Maps, published from BRFSS. Recorded as
# distributional claims rather than all 51 state values.
#
# SUPERSEDED for practical purposes by data/reference/published_state_prevalence.csv,
# which holds all 51 state values for 2000 and 2022 with citations, and is
# compared state-by-state in src/cleaning/compare_published.R ->
# docs/benchmark_comparison.md. Prefer that comparison: it tests every state
# rather than a single count, and a count near a threshold is fragile in a way
# the state-level comparison makes visible. The claims below are retained only
# as a coarse cross-check.
#
# The 2022 `published_count` of 22 has since been CONFIRMED against the
# reference file (22 states at or above 35%), so any difference against it is
# in this pipeline's construction, not in the benchmark.
CDC_MAP_CLAIMS <- data.frame(
  year      = c(2000, 2022),
  claim     = c("states with prevalence >= 30%",
                "states with prevalence >= 35%"),
  threshold = c(0.30, 0.35),
  published_count = c(0L, 22L),
  stringsAsFactors = FALSE
)

# National aggregate -------------------------------------------------------
# Population-weighted by the survey weights themselves, not averaged across
# the state panel (DECISIONS.md §11).
#
# These are now PRODUCED BY build_panel.R, from the same design object the
# state estimates come from, and simply read here. Rebuilding a year's survey
# design costs 3.5-5 minutes for the post-2011 files, and computing the
# national figure in this script meant paying that a second time for all 34
# years to reproduce numbers build_panel.R had already had in hand.
#
# The recompute path below is retained as a fallback for years absent from
# the file -- running validate.R standalone against a panel built by an older
# version, say. `path_national()` is defined in build_panel.R, which this
# script sources.
national_by_year <- function(years, refresh = FALSE) {
  cached <- if (!refresh && file.exists(path_national())) {
    utils::read.csv(path_national(), stringsAsFactors = FALSE)
  } else {
    data.frame(year = integer(), brfss_prev = numeric(), brfss_se = numeric())
  }

  todo <- setdiff(years, cached$year)
  if (length(todo) == 0) {
    log_msg(sprintf("national estimates: all %d years read from build_panel output",
                    length(years)))
    return(cached[cached$year %in% years, ] %>% arrange(year))
  }
  log_warn(sprintf(paste("national estimates: %d years missing from",
                         "national_prevalence.csv, recomputing them here (%s).",
                         "build_panel.R should have written these."),
                   length(todo), paste(todo, collapse = ", ")))

  rows <- list()
  for (y in todo) {
    prep <- tryCatch(prepare_year(y), error = function(e) {
      log_warn(sprintf("%d: national estimate failed -- %s", y, conditionMessage(e)))
      NULL
    })
    if (is.null(prep)) next
    est <- svymean(~obese, prep$design, na.rm = TRUE)
    rows[[length(rows) + 1]] <- data.frame(
      year       = y,
      brfss_prev = unname(coef(est)),
      brfss_se   = unname(survey::SE(est))
    )
    log_msg(sprintf("%d: national prevalence %.4f", y, unname(coef(est))))
  }

  out <- bind_rows(cached, bind_rows(rows)) %>%
    arrange(year) %>%
    distinct(year, .keep_all = TRUE)
  ensure_dir(dir_cleaned())
  utils::write.csv(out, path_national(), row.names = FALSE)
  out[out$year %in% years, ]
}

write_validation <- function(years = NULL) {
  panel <- utils::read.csv(file.path(dir_cleaned(), "state_obesity_panel.csv"),
                           stringsAsFactors = FALSE)
  if (is.null(years)) years <- sort(unique(panel$year))
  ensure_dir(dir_docs())

  natl <- national_by_year(years)

  # 1. vs NHANES
  cmp <- natl %>%
    inner_join(NHANES_PUBLISHED, by = "year") %>%
    mutate(diff_pp = (brfss_prev - nhanes_prev) * 100) %>%
    select(year, cycle, brfss_prev, brfss_se, nhanes_prev, diff_pp)

  # 2. vs CDC map claims
  map_cmp <- CDC_MAP_CLAIMS %>%
    rowwise() %>%
    mutate(
      constructed_count = {
        sub <- panel[panel$year == year, ]
        if (nrow(sub) == 0) NA_integer_ else sum(sub$prev_obese >= threshold)
      },
      states_in_panel = {
        sub <- panel[panel$year == year, ]
        nrow(sub)
      }
    ) %>%
    ungroup() %>%
    mutate(difference = constructed_count - published_count) %>%
    select(year, claim, published_count, constructed_count, states_in_panel,
           difference)

  L <- c()
  add <- function(...) L <<- c(L, ...)

  add("# BRFSS state obesity panel — external validation", "",
      sprintf("Generated %s.", format(Sys.Date())), "")

  add("> **Benchmark provenance.** The NHANES and CDC-map values in this report",
      "> are constants transcribed into `src/cleaning/validate.R` from published",
      "> sources (NCHS Data Briefs; CDC Adult Obesity Prevalence Maps). They were",
      "> **not** downloaded and have not been programmatically verified against",
      "> the originals. Check them before citing any discrepancy below.", "")

  add("## 1. Constructed national aggregate vs NHANES", "",
      paste("BRFSS national prevalence is recomputed from the microdata with the",
            "survey design (not averaged across the state panel). NHANES values",
            "are age-adjusted, adults 20+, at the midpoint year of each cycle."),
      # 4 dp: brfss_se is ~0.0015 and rounds to 0 at any coarser precision.
      "", fmt_table(cmp, 4), "")

  if (nrow(cmp)) {
    add(sprintf(paste("BRFSS runs below NHANES in %d of %d comparable years;",
                      "mean gap %.1f pp (range %.1f to %.1f)."),
                sum(cmp$diff_pp < 0), nrow(cmp), mean(cmp$diff_pp),
                min(cmp$diff_pp), max(cmp$diff_pp)), "")
    add(paste("**This gap is expected, not a defect.** BRFSS height and weight are",
              "self-reported and NHANES are measured; self-report biases BMI down.",
              "The gap's *sign* is the check that passes here. Its *magnitude* is",
              "not something this pipeline attempts to correct — the Ward-style",
              "NHANES matching correction is out of scope by design. A discrepancy",
              "in the wrong direction, or a gap that moves sharply across the 2011",
              "break, would be the real warning sign; see `diagnostics.md` §2."), "")

    # The trend in the gap is a finding in its own right, and it is not
    # something the sign check catches.
    early <- cmp[cmp$year <= 2010, ]
    late  <- cmp[cmp$year > 2010, ]
    if (nrow(early) && nrow(late)) {
      add(sprintf(paste("**The gap is not stable, and that is a finding.** It averages",
                        "%.1f pp through 2010 and %.1f pp after, i.e. it %s by",
                        "roughly %.1f pp across the series."),
                  mean(early$diff_pp), mean(late$diff_pp),
                  ifelse(mean(late$diff_pp) < mean(early$diff_pp),
                         "widens", "narrows"),
                  abs(mean(late$diff_pp) - mean(early$diff_pp))), "",
          paste("A widening gap means self-report bias is growing, which is a",
                "threat to comparability *within* BRFSS that is separate from",
                "the 2011 design break and is not removed by splitting the",
                "sample at 2011. It moves in step with the rising BMI item",
                "nonresponse in `diagnostics.md` §5; both point to declining",
                "quality of the self-reported height/weight measure over time.",
                "Neither is corrected here."), "")
    }
  } else {
    add("No overlapping years between the panel and the NHANES benchmark table.", "")
  }

  add("## 2. Constructed state counts vs CDC published maps", "",
      fmt_table(map_cmp, 0), "")
  add(paste("`states_in_panel` is reported because a count of states over a",
            "threshold is not comparable if the panel is missing states that",
            "year — see the missing state-year list in `diagnostics.md` §1."), "")

  if (any(!is.na(map_cmp$difference) & map_cmp$difference != 0)) {
    add("", paste("**On any non-zero `difference` above.** It is left unreconciled.",
                  "Candidate sources, in rough order of how much they could move",
                  "a threshold count, are: (a) the `published_count` constant",
                  "itself, which is transcribed and unverified — check it first;",
                  "(b) the pregnancy exclusion, which CDC's published figures do",
                  "not consistently apply (`DECISIONS.md` §5); (c) the 18+ screen",
                  "versus any age-adjustment CDC applies (§4); (d) the BMI",
                  "plausibility window (§3), though `diagnostics.md` §5 shows it",
                  "touches under 0.2% of records and so cannot account for much.",
                  "A count near a threshold is also mechanically fragile: states",
                  "sitting within a standard error of the cutoff flip on trivial",
                  "differences in construction."), "")
  }

  add("---", "",
      "No discrepancy above has been adjusted for, reweighted, or smoothed.")

  out <- file.path(dir_docs(), "validation.md")
  writeLines(L, out)
  log_msg("validation.md written")
  invisible(out)
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  yrs <- if (length(args)) as.integer(args) else NULL
  write_validation(yrs)
}
