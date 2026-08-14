# run_all.R ---------------------------------------------------------------
# End-to-end pipeline: scrape -> harmonize -> parse -> panel -> diagnostics
# -> validation.
#
#   Rscript src/run_all.R              # full range, 1990-2023
#   Rscript src/run_all.R 2000 2010 2019   # named years only
#
# Every stage is resumable: downloads, schemas, and parsed caches are all
# skipped when the target artifact already exists.

source(here::here("src", "common.R"))
source(here::here("src", "scrape", "fetch_brfss.R"))
source(here::here("src", "cleaning", "harmonize.R"))
source(here::here("src", "cleaning", "build_panel.R"))
source(here::here("src", "cleaning", "diagnostics.R"))
source(here::here("src", "cleaning", "validate.R"))
source(here::here("src", "cleaning", "compare_published.R"))

run_all <- function(years = YEARS_ALL) {
  t0 <- Sys.time()

  log_msg("=== 1/5  download + schema ===")
  fetch_all(years)

  log_msg("=== 2/5  crosswalk ===")
  cw <- build_crosswalk(years)
  ok <- usable_years(cw)
  dropped <- setdiff(years, ok)
  if (length(dropped)) {
    log_warn(sprintf("years excluded for unresolved required variables: %s",
                     paste(dropped, collapse = ", ")))
  }

  log_msg("=== 3/5  parse to narrow caches ===")
  parse_all(ok, crosswalk = cw)

  log_msg("=== 4/5  panel ===")
  build_panel(ok)

  log_msg("=== 5/5  diagnostics + validation ===")
  write_diagnostics()
  write_validation(ok)
  # Cheap: reads the finished panel only. Skipped if the reference file is
  # absent, since it is user-supplied rather than downloaded.
  if (file.exists(path_reference())) {
    write_comparison()
  } else {
    log_warn("reference benchmark absent, skipping published comparison")
  }

  log_msg(sprintf("done in %.1f min",
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  invisible(TRUE)
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  yrs <- if (length(args)) as.integer(args) else YEARS_ALL
  run_all(yrs)
}
