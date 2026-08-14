# harmonize.R -------------------------------------------------------------
# Build a year -> variable-name crosswalk by inspecting each year's actual
# columns. Nothing here hardcodes a per-year schema: each concept carries an
# ordered list of candidate name patterns plus a label pattern, and the
# resolver takes the first candidate actually present in that year's schema.
#
# Why this is necessary (observed in the pilot years, not assumed):
#   BMI     _BMI2 (2000)     _BMI4 (2010)     _BMI5 (2019)
#   weight  _FINALWT (2000)  _FINALWT (2010)  _LLCPWT (2019)
#   sex     SEX (2000)       SEX (2010)       SEXVAR (2019)
#   age     AGE (2000)       AGE (2010)       -- absent -- (2019, use _AGE80)
#
# Output: data/cleaned/crosswalk.csv, one row per year x concept.
# Years missing a REQUIRED concept are logged to crosswalk_missing.csv and
# excluded from the panel rather than patched.

source(here::here("src", "common.R"))
source(here::here("src", "scrape", "fetch_brfss.R"))

# Concept definitions ------------------------------------------------------
# `patterns` are matched against column names in order, first hit wins, so
# the list runs newest-naming to oldest. `exclude` guards against sibling
# variables that share a prefix (_BMI5CAT is a category, not a BMI; _RFBMI5
# is an overweight-or-obese flag).
CONCEPTS <- list(
  state = list(
    required = TRUE,
    patterns = c("^_STATE$", "^STATE$"),
    label    = "STATE FIPS"
  ),
  psu = list(
    required = TRUE,
    patterns = c("^_PSU$", "^SEQNO$"),
    label    = "PRIMARY SAMPLING UNIT"
  ),
  strata = list(
    required = TRUE,
    patterns = c("^_STSTR$", "^_STRATA$", "^_STRWT$"),
    label    = "STRATIFICATION"
  ),
  finalwt = list(
    required = TRUE,
    # _LLCPWT is the 2011+ landline+cell final weight; _FINALWT the
    # pre-2011 post-stratified final weight. Never _LLCPWT2 (truncated
    # design weight) or _CLLCPWT / _CHILDWT (child weights).
    patterns = c("^_LLCPWT$", "^_FINALWT$", "^_POSTSTR$"),
    exclude  = c("^_LLCPWT2$", "^_CLLCPWT$", "^_CHILDWT$"),
    label    = "FINAL WEIGHT"
  ),
  bmi = list(
    required = TRUE,
    patterns = c("^_BMI5$", "^_BMI4$", "^_BMI3$", "^_BMI2$", "^_BMI$"),
    exclude  = c("CAT$", "^_RFBMI"),
    label    = "BODY MASS INDEX"
  ),
  # Height and weight, for computing BMI directly rather than trusting
  # CDC's precomputed _BMI*. See DECISIONS.md §1a: the precomputed variable
  # rounds UP to its stored precision, and that precision changes across the
  # series, so its upward bias changes with it.
  #
  # Two sources per dimension. From 2001 CDC ships normalized variables
  # (HTIN* in inches, WTKG* in kilograms) that already resolve the
  # imperial/metric dual encoding in the reported variables; before 2001
  # only the reported variables exist and must be decoded here.
  height_in = list(
    required = FALSE,
    patterns = c("^HTIN4$", "^HTIN3$", "^HTIN2$", "^HTIN$"),
    label    = "HEIGHT IN INCHES"
  ),
  weight_kg = list(
    required = FALSE,
    patterns = c("^WTKG3$", "^WTKG2$", "^WTKG$"),
    label    = "WEIGHT IN KILOGRAMS"
  ),
  height_raw = list(
    required = FALSE,
    patterns = c("^HEIGHT3$", "^HEIGHT2$", "^HEIGHT$"),
    label    = "HEIGHT IN FEET AND INCHES"
  ),
  weight_raw = list(
    required = FALSE,
    patterns = c("^WEIGHT2$", "^WEIGHT$"),
    label    = "WEIGHT IN POUNDS"
  ),
  sex = list(
    required = FALSE,
    patterns = c("^SEXVAR$", "^_SEX$", "^SEX$"),
    label    = "SEX"
  ),
  age = list(
    required = FALSE,
    # Raw AGE disappears after 2018; _AGE80 (imputed, top-coded at 80) is
    # the continuous replacement. Both are only used for the 18+ screen.
    patterns = c("^AGE$", "^_AGE80$", "^_IMPAGE$", "^_AGEG5YR$"),
    label    = "AGE"
  ),
  pregnant = list(
    required = FALSE,
    patterns = c("^PREGNANT$", "^PREGNANT2$"),
    label    = "PREGNAN"
  )
)

REQUIRED_CONCEPTS <- names(CONCEPTS)[vapply(CONCEPTS, `[[`, logical(1), "required")]

# Resolver -----------------------------------------------------------------
# Returns a one-row data.frame for a single concept in a single year.
resolve_concept <- function(concept, spec, schema) {
  nm <- schema$name
  keep <- rep(TRUE, length(nm))
  if (!is.null(spec$exclude)) {
    for (ex in spec$exclude) keep <- keep & !grepl(ex, nm)
  }

  hit <- NA_character_
  how <- NA_character_
  for (p in spec$patterns) {
    idx <- which(grepl(p, nm) & keep)
    if (length(idx)) {
      hit <- nm[idx[1]]
      how <- "name"
      break
    }
  }

  # Fall back to the SAS variable label when no name pattern matched. This
  # is what catches renames we did not anticipate.
  if (is.na(hit) && !is.null(spec$label)) {
    idx <- which(grepl(spec$label, toupper(schema$label), fixed = FALSE) & keep)
    if (length(idx)) {
      hit <- nm[idx[1]]
      how <- "label"
    }
  }

  data.frame(
    year         = schema$year[1],
    concept      = concept,
    source_var   = hit,
    source_label = if (is.na(hit)) NA_character_
                   else schema$label[match(hit, nm)],
    resolved_by  = how,
    required     = spec$required,
    stringsAsFactors = FALSE
  )
}

build_crosswalk <- function(years = YEARS_ALL, write = TRUE) {
  rows <- list()
  for (y in years) {
    sch <- tryCatch(load_schema(y), error = function(e) NULL)
    if (is.null(sch)) {
      log_warn(sprintf("%d: no schema on disk, skipping", y))
      next
    }
    for (cn in names(CONCEPTS)) {
      rows[[length(rows) + 1]] <- resolve_concept(cn, CONCEPTS[[cn]], sch)
    }
  }
  cw <- do.call(rbind, rows)

  # Report unresolved required concepts loudly; these years drop out.
  missing <- cw[cw$required & is.na(cw$source_var), ]
  if (nrow(missing)) {
    for (i in seq_len(nrow(missing))) {
      log_warn(sprintf("%d: required concept '%s' NOT FOUND",
                       missing$year[i], missing$concept[i]))
    }
  }
  # Note where we had to fall back to labels -- worth a human look.
  by_label <- cw[!is.na(cw$resolved_by) & cw$resolved_by == "label", ]
  if (nrow(by_label)) {
    for (i in seq_len(nrow(by_label))) {
      log_msg(sprintf("%d: '%s' resolved by LABEL to %s (%s)",
                      by_label$year[i], by_label$concept[i],
                      by_label$source_var[i], by_label$source_label[i]))
    }
  }

  if (write) {
    ensure_dir(dir_cleaned())
    utils::write.csv(cw, file.path(dir_cleaned(), "crosswalk.csv"),
                     row.names = FALSE)
    utils::write.csv(missing, file.path(dir_cleaned(), "crosswalk_missing.csv"),
                     row.names = FALSE)
    log_msg(sprintf("crosswalk.csv written: %d rows, %d years, %d unresolved required",
                    nrow(cw), length(unique(cw$year)), nrow(missing)))
  }
  cw
}

# Years usable for the panel: every required concept resolved.
usable_years <- function(crosswalk) {
  bad <- unique(crosswalk$year[crosswalk$required & is.na(crosswalk$source_var)])
  sort(setdiff(unique(crosswalk$year), bad))
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  yrs <- if (length(args)) as.integer(args) else YEARS_ALL
  build_crosswalk(yrs)
}
