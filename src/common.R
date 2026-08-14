# common.R ---------------------------------------------------------------
# Shared paths, constants, and logging helpers.
# Sourced by every other script. Defines only; runs nothing.

suppressPackageStartupMessages({
  library(here)
})

# Year range of the panel. 1990 is the first year with broad state coverage;
# 2023 is the most recent annual file posted by CDC.
YEARS_ALL   <- 1990:2023
YEARS_PILOT <- c(2000, 2010, 2019)   # straddle the 2011 methodology break

# 2011: cell-phone sample added, raking replaced post-stratification.
BREAK_YEAR <- 2011

# Directory layout ---------------------------------------------------------
dir_raw_zip    <- function(year) here("data", "raw", "brfss", year)
dir_parsed     <- function()     here("data", "raw", "parsed")
path_parsed    <- function(year) file.path(dir_parsed(), sprintf("brfss_%d.rds", year))
path_schema    <- function(year) file.path(dir_parsed(), sprintf("schema_%d.rds", year))
dir_cleaned    <- function()     here("data", "cleaned")
dir_docs       <- function()     here("docs")

ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

# Markdown tables ----------------------------------------------------------
# Defined once here on purpose. This previously lived in diagnostics.R,
# validate.R and compare_published.R with three different default precisions;
# run_all.R sources all three, so the last definition silently won and the
# validation table rendered its standard errors as 0. Pass `digits`
# explicitly at every call site.
fmt_table <- function(df, digits = 3) {
  df <- dplyr::mutate(df, dplyr::across(dplyr::where(is.numeric),
                                        ~ round(.x, digits)))
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  rows <- apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  paste(c(hdr, sep, rows), collapse = "\n")
}

# Logging ------------------------------------------------------------------
log_msg <- function(...) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), paste0(...)))
  flush.console()
}

log_warn <- function(...) {
  cat(sprintf("[%s] WARNING: %s\n", format(Sys.time(), "%H:%M:%S"), paste0(...)))
  flush.console()
}

# State FIPS -> name -------------------------------------------------------
# BRFSS _STATE is the FIPS code. Territories (>= 60, plus 66/72/78) are
# dropped from the panel; only 50 states + DC are retained.
STATE_FIPS <- c(
  "1" = "Alabama", "2" = "Alaska", "4" = "Arizona", "5" = "Arkansas",
  "6" = "California", "8" = "Colorado", "9" = "Connecticut", "10" = "Delaware",
  "11" = "District of Columbia", "12" = "Florida", "13" = "Georgia",
  "15" = "Hawaii", "16" = "Idaho", "17" = "Illinois", "18" = "Indiana",
  "19" = "Iowa", "20" = "Kansas", "21" = "Kentucky", "22" = "Louisiana",
  "23" = "Maine", "24" = "Maryland", "25" = "Massachusetts", "26" = "Michigan",
  "27" = "Minnesota", "28" = "Mississippi", "29" = "Missouri", "30" = "Montana",
  "31" = "Nebraska", "32" = "Nevada", "33" = "New Hampshire", "34" = "New Jersey",
  "35" = "New Mexico", "36" = "New York", "37" = "North Carolina",
  "38" = "North Dakota", "39" = "Ohio", "40" = "Oklahoma", "41" = "Oregon",
  "42" = "Pennsylvania", "44" = "Rhode Island", "45" = "South Carolina",
  "46" = "South Dakota", "47" = "Tennessee", "48" = "Texas", "49" = "Utah",
  "50" = "Vermont", "51" = "Virginia", "53" = "Washington",
  "54" = "West Virginia", "55" = "Wisconsin", "56" = "Wyoming"
)

PANEL_FIPS <- as.integer(names(STATE_FIPS))
