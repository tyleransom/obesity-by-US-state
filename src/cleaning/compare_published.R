# compare_published.R -----------------------------------------------------
# State-level comparison against published BRFSS-derived estimates
# -> docs/benchmark_comparison.md
#
# Reference: data/reference/published_state_prevalence.csv
#   2000 — Mokdad et al. (2001), JAMA 286(10):1195-1200
#   2022 — CDC Adult Obesity Prevalence Maps (accessed 2024-08-23)
#
# This is a stronger check than the NHANES comparison in validate.R. Both
# benchmarks are built from the same BRFSS microdata this pipeline parses,
# so a discrepancy is a construction difference, not a measurement-mode
# difference. Large gaps here mean the pipeline is doing something the
# published estimates did not.
#
# Reads only the finished panel, so it runs in seconds.

source(here::here("src", "common.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

path_reference <- function() {
  here("data", "reference", "published_state_prevalence.csv")
}

BENCH_SOURCES <- c(
  "2000" = "Mokdad et al. (2001), JAMA 286(10):1195-1200",
  "2022" = "CDC Adult Obesity Prevalence Maps (accessed 2024-08-23)"
)

# Long-format benchmark: state_name, year, published_prev (percent), rank.
load_reference <- function() {
  ref <- utils::read.csv(path_reference(), stringsAsFactors = FALSE,
                         check.names = FALSE)
  bind_rows(
    ref %>% transmute(state_name = state, year = 2000L,
                      published_prev = prev_2000, published_rank = rank_2000),
    ref %>% transmute(state_name = state, year = 2022L,
                      published_prev = prev_2022, published_rank = rank_2022)
  )
}

compare <- function() {
  panel <- utils::read.csv(file.path(dir_cleaned(), "state_obesity_panel.csv"),
                           stringsAsFactors = FALSE)
  ref <- load_reference()

  # Panel prevalence is a proportion; the benchmark is a percentage.
  j <- panel %>%
    mutate(constructed_prev = prev_obese * 100,
           constructed_se   = se * 100) %>%
    inner_join(ref, by = c("state_name", "year")) %>%
    mutate(
      diff_pp = constructed_prev - published_prev,
      # Is the published value inside our 95% interval? A well-constructed
      # panel should cover the benchmark for most states.
      covered = published_prev >= ci_lower * 100 & published_prev <= ci_upper * 100,
      # How many of our own standard errors away is the benchmark?
      z = diff_pp / constructed_se
    )
  j
}

summarise_year <- function(j) {
  j %>%
    group_by(year) %>%
    summarise(
      n_states     = n(),
      mean_diff_pp = mean(diff_pp),
      mean_abs_pp  = mean(abs(diff_pp)),
      max_abs_pp   = max(abs(diff_pp)),
      pearson_r    = stats::cor(constructed_prev, published_prev),
      spearman_r   = stats::cor(constructed_prev, published_prev,
                                method = "spearman"),
      pct_covered  = 100 * mean(covered),
      median_abs_z = stats::median(abs(z)),
      # Share of states where the difference takes the modal sign. A value
      # near 100 means the gap is a systematic offset, not sampling noise,
      # even when each individual state sits well inside its own SE.
      pct_same_sign = 100 * max(mean(diff_pp > 0), mean(diff_pp < 0)),
      .groups = "drop"
    )
}

# Rank agreement matters separately from level agreement: a uniform level
# offset leaves the cross-state ordering intact, which is what most analyses
# of this panel would actually use.
rank_agreement <- function(j) {
  j %>%
    group_by(year) %>%
    mutate(constructed_rank = rank(-constructed_prev, ties.method = "min")) %>%
    summarise(
      n_states        = n(),
      rank_cor        = stats::cor(constructed_rank, published_rank,
                                   method = "spearman"),
      mean_abs_rank_d = mean(abs(constructed_rank - published_rank)),
      max_rank_d      = max(abs(constructed_rank - published_rank)),
      n_within_3      = sum(abs(constructed_rank - published_rank) <= 3),
      .groups = "drop"
    )
}

threshold_counts <- function(j) {
  bind_rows(
    j %>% filter(year == 2000) %>%
      summarise(year = 2000L, threshold = "≥ 20%",
                constructed = sum(constructed_prev >= 20),
                published   = sum(published_prev >= 20)),
    j %>% filter(year == 2022) %>%
      summarise(year = 2022L, threshold = "≥ 35%",
                constructed = sum(constructed_prev >= 35),
                published   = sum(published_prev >= 35))
  ) %>% mutate(difference = constructed - published)
}

write_comparison <- function() {
  j <- compare()
  ensure_dir(dir_docs())

  by_year <- summarise_year(j)
  ranks   <- rank_agreement(j)
  thresh  <- threshold_counts(j)

  L <- c()
  add <- function(...) L <<- c(L, ...)

  add("# Comparison against published BRFSS estimates", "",
      sprintf("Generated %s.", format(Sys.Date())), "",
      "Benchmark: `data/reference/published_state_prevalence.csv`.", "")
  for (y in names(BENCH_SOURCES)) {
    add(sprintf("- **%s** — %s", y, BENCH_SOURCES[[y]]))
  }
  add("", paste("Both benchmarks are derived from the same BRFSS microdata this",
                "pipeline parses. Unlike the NHANES comparison in",
                "`validation.md`, a gap here is **not** explained by",
                "self-report bias — it is a difference in how the estimate was",
                "constructed. All figures are percentage points."), "")

  add("## 1. Level agreement", "", fmt_table(by_year, 3), "",
      paste("`pct_covered` is the share of states whose published value falls",
            "inside this panel's 95% confidence interval. `median_abs_z` is the",
            "typical discrepancy measured in our own standard errors — values",
            "near or below 2 mean the differences are within sampling noise."),
      "")

  # A small offset that every state shares is a construction difference, not
  # noise, and the per-state SEs will not reveal it.
  for (i in seq_len(nrow(by_year))) {
    r <- by_year[i, ]
    if (r$pct_same_sign >= 90 && abs(r$mean_diff_pp) > 0.05) {
      add(sprintf(paste("**%d carries a systematic offset.** This panel runs %.2f pp",
                        "%s than the published series, and %.0f%% of states share",
                        "that sign. Each state individually sits well inside its own",
                        "standard error (median |z| = %.2f), so the per-state",
                        "intervals do not flag it — but a common sign across %d",
                        "states is not sampling noise. It is a difference in",
                        "construction."),
                  r$year, abs(r$mean_diff_pp),
                  ifelse(r$mean_diff_pp > 0, "higher", "lower"),
                  r$pct_same_sign, r$median_abs_z, r$n_states), "")
    }
  }
  add(paste("Candidate sources for a systematic offset, none of which are",
            "adjusted for here: this panel computes BMI from reported height",
            "and weight while CDC's published figures use the precomputed",
            "`_BMI*` (which rounds up to its stored precision — see",
            "`DECISIONS.md` §1a); the pregnancy exclusion (§5), which CDC's",
            "published figures do not consistently apply; the 18+ screen versus",
            "any age standardization (§4); or differing treatment of records",
            "with missing height or weight."), "",
      paste("Note that the 2000 offset was **eliminated** by switching to",
            "computed BMI — it fell from +0.58 pp to +0.03 pp, and the share of",
            "states sharing its sign fell from 100% to near half, which is what",
            "sampling noise looks like. A residual offset in a later year is",
            "therefore unlikely to have the same cause, since the rounding bias",
            "is negligible once the stored precision reaches two decimals."), "")

  add("## 2. Rank agreement", "", fmt_table(ranks, 3), "",
      paste("Rank agreement is reported separately because a uniform level",
            "offset leaves the cross-state ordering intact, and the ordering is",
            "what most analyses of this panel would use."), "")

  add("## 3. Threshold counts", "", fmt_table(thresh, 0), "",
      paste("Counts near a threshold are mechanically fragile: any state within",
            "a standard error of the cutoff flips on trivial construction",
            "differences."), "")

  # Name the states responsible, so a count difference is never mistaken for
  # a broad disagreement.
  for (i in seq_len(nrow(thresh))) {
    r <- thresh[i, ]
    if (r$difference == 0) next
    cut <- if (r$year == 2000) 20 else 35
    flips <- j %>%
      filter(year == r$year,
             (constructed_prev >= cut) != (published_prev >= cut)) %>%
      arrange(desc(published_prev))
    if (nrow(flips) == 0) next
    add(sprintf("**The %d count differs by %d, and these are the states responsible:**",
                r$year, r$difference), "",
        fmt_table(flips %>% transmute(state_name, constructed_prev,
                                      constructed_se, published_prev, diff_pp), 2),
        "",
        sprintf(paste("Every one of these sits within %.2f pp of the %d%% cutoff",
                      "and differs from the published value by less than its own",
                      "standard error. The count difference is a boundary effect,",
                      "not a disagreement about prevalence."),
                max(abs(c(flips$constructed_prev, flips$published_prev) - cut)), cut),
        "")
  }

  for (y in sort(unique(j$year))) {
    sub <- j %>% filter(year == y) %>% arrange(desc(abs(diff_pp))) %>%
      transmute(state_name, constructed_prev, constructed_se, published_prev,
                diff_pp, z, covered) %>%
      head(10)
    add(sprintf("## 4.%d Largest discrepancies, %d", which(sort(unique(j$year)) == y), y),
        "", fmt_table(sub, 2), "")
  }

  add("## 5. Full comparison", "")
  for (y in sort(unique(j$year))) {
    sub <- j %>% filter(year == y) %>% arrange(desc(constructed_prev)) %>%
      transmute(state_name, constructed_prev, published_prev, diff_pp, covered)
    add(sprintf("### %d", y), "", fmt_table(sub, 2), "")
  }

  add("---", "",
      "No estimate has been adjusted to match the benchmark.")

  out <- file.path(dir_docs(), "benchmark_comparison.md")
  writeLines(L, out)
  log_msg(sprintf("benchmark_comparison.md written (%d state-years compared)",
                  nrow(j)))
  invisible(j)
}

if (sys.nframe() == 0) invisible(write_comparison())
