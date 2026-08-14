# fetch_brfss.R -----------------------------------------------------------
# Download and unzip BRFSS annual archives, extract each year's schema
# (column names + SAS labels), and cache a narrow per-year .rds.
#
# Two-pass design, driven by the memory constraint: recent XPT files are
# 400k+ rows x 300+ columns, so we never read one at full width.
#   Pass 1 (extract_schema): read_xpt(n_max = 0) -> names + labels only.
#   Pass 2 (parse_year):     read_xpt(col_select = <crosswalk cols>) -> .rds.
# Pass 2 requires data/cleaned/crosswalk.csv, which harmonize.R builds from
# the pass-1 schemas. run_all.R sequences the three steps.
#
# Nothing here modifies data/raw/ after download, and nothing re-downloads or
# re-parses when the target artifact already exists.

source(here::here("src", "common.R"))

suppressPackageStartupMessages({
  library(haven)
})

BRFSS_BASE <- "https://www.cdc.gov/brfss/annual_data"

# CDC uses two file-naming conventions across the range. Verified by HEAD
# request for every year 1990-2023.
brfss_zip_name <- function(year) {
  if (year <= 2010) {
    sprintf("CDBRFS%02dXPT.zip", year %% 100)
  } else {
    sprintf("LLCP%dXPT.zip", year)
  }
}

brfss_url <- function(year) {
  sprintf("%s/%d/files/%s", BRFSS_BASE, year, brfss_zip_name(year))
}

# Locate the extracted transport file for a year, if present. CDC is not
# consistent about extension case (.XPT / .xpt), and every LLCP-era archive
# (2011+) stores the member with a TRAILING SPACE in its name -- e.g.
# "LLCP2019.XPT ". We match around that rather than renaming, since
# data/raw/ is read-only after download.
find_xpt <- function(year) {
  d <- dir_raw_zip(year)
  if (!dir.exists(d)) return(NA_character_)
  f <- list.files(d, pattern = "\\.xpt\\s*$", ignore.case = TRUE,
                  full.names = TRUE)
  if (length(f) == 0) NA_character_ else f[1]
}

# Download + unzip ---------------------------------------------------------
# Returns the path to the extracted XPT. No-op when it already exists.
download_year <- function(year, overwrite = FALSE) {
  existing <- find_xpt(year)
  if (!is.na(existing) && !overwrite) {
    log_msg(sprintf("%d: XPT already present, skipping download", year))
    return(existing)
  }

  d <- ensure_dir(dir_raw_zip(year))
  zip_path <- file.path(d, brfss_zip_name(year))
  url <- brfss_url(year)

  if (!file.exists(zip_path) || overwrite) {
    log_msg(sprintf("%d: downloading %s", year, url))
    # Download to a temp name first so an interrupted transfer never leaves a
    # half-written file that a later run would treat as complete.
    tmp <- paste0(zip_path, ".part")
    status <- utils::download.file(url, tmp, mode = "wb", quiet = TRUE,
                                   method = "libcurl")
    if (status != 0) {
      unlink(tmp)
      stop(sprintf("%d: download failed with status %s (%s)", year, status, url))
    }
    # CDC serves an HTML error page with HTTP 200 for some bad paths; a real
    # archive starts with the "PK" zip magic bytes.
    magic <- readBin(tmp, "raw", n = 2)
    if (!identical(magic, as.raw(c(0x50, 0x4b)))) {
      unlink(tmp)
      stop(sprintf("%d: downloaded file is not a zip archive (%s)", year, url))
    }
    file.rename(tmp, zip_path)
    log_msg(sprintf("%d: downloaded %.1f MB", year,
                    file.size(zip_path) / 1024^2))
  }

  log_msg(sprintf("%d: unzipping", year))
  utils::unzip(zip_path, exdir = d, overwrite = TRUE)

  xpt <- find_xpt(year)
  if (is.na(xpt)) {
    stop(sprintf("%d: no .xpt file found in %s after unzip", year, d))
  }
  xpt
}

# Pass 1: schema -----------------------------------------------------------
# Column names plus the SAS variable labels haven preserves as attributes.
# The labels are what let harmonize.R disambiguate names that drift across
# years (_BMI / _BMI4 / _BMI5, _FINALWT / _LLCPWT, ...).
extract_schema <- function(year, overwrite = FALSE) {
  ensure_dir(dir_parsed())
  out <- path_schema(year)
  if (file.exists(out) && !overwrite) {
    log_msg(sprintf("%d: schema cached, skipping", year))
    return(readRDS(out))
  }

  xpt <- find_xpt(year)
  if (is.na(xpt)) stop(sprintf("%d: XPT not downloaded yet", year))

  log_msg(sprintf("%d: reading schema", year))
  hdr <- haven::read_xpt(xpt, n_max = 0)

  schema <- data.frame(
    year    = year,
    name    = names(hdr),
    label   = vapply(hdr, function(x) {
                 lab <- attr(x, "label", exact = TRUE)
                 if (is.null(lab)) NA_character_ else as.character(lab)
               }, character(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  saveRDS(schema, out)
  log_msg(sprintf("%d: schema has %d columns", year, nrow(schema)))
  schema
}

load_schema <- function(year) {
  p <- path_schema(year)
  if (!file.exists(p)) stop(sprintf("%d: schema not extracted yet", year))
  readRDS(p)
}

# Pass 2: narrow parse -----------------------------------------------------
# Reads only the columns named in the crosswalk and caches them under their
# harmonized names, so src/cleaning/ never touches the full width.
parse_year <- function(year, crosswalk, overwrite = FALSE) {
  ensure_dir(dir_parsed())
  out <- path_parsed(year)
  if (file.exists(out) && !overwrite) {
    log_msg(sprintf("%d: parsed cache present, skipping", year))
    return(invisible(out))
  }

  cw <- crosswalk[crosswalk$year == year & !is.na(crosswalk$source_var), ]
  if (nrow(cw) == 0) {
    log_warn(sprintf("%d: no crosswalk entries, skipping parse", year))
    return(invisible(NA_character_))
  }

  xpt <- find_xpt(year)
  if (is.na(xpt)) stop(sprintf("%d: XPT not downloaded yet", year))

  log_msg(sprintf("%d: parsing %d columns", year, nrow(cw)))
  dat <- haven::read_xpt(xpt, col_select = tidyselect::all_of(cw$source_var))

  # Rename source -> harmonized. Column order follows the crosswalk.
  dat <- dat[, cw$source_var, drop = FALSE]
  names(dat) <- cw$concept
  dat$year <- year

  # Drop haven's labelled class but keep the underlying numerics; the survey
  # package does not handle labelled vectors gracefully.
  dat[] <- lapply(dat, function(x) {
    if (inherits(x, "haven_labelled")) as.numeric(x) else x
  })

  saveRDS(dat, out, compress = "xz")
  log_msg(sprintf("%d: cached %s rows x %d cols (%.1f MB)", year,
                  format(nrow(dat), big.mark = ","), ncol(dat),
                  file.size(out) / 1024^2))
  invisible(out)
}

load_parsed <- function(year) {
  p <- path_parsed(year)
  if (!file.exists(p)) stop(sprintf("%d: parsed cache missing", year))
  readRDS(p)
}

# Drivers ------------------------------------------------------------------
fetch_all <- function(years = YEARS_ALL) {
  for (y in years) {
    download_year(y)
    extract_schema(y)
  }
  invisible(TRUE)
}

# `overwrite = TRUE` is required after any change to the crosswalk: the
# cached .rds holds only the columns the crosswalk named when it was written,
# so adding a concept silently has no effect until the caches are rebuilt.
parse_all <- function(years = YEARS_ALL, crosswalk = NULL, overwrite = FALSE) {
  if (is.null(crosswalk)) {
    p <- file.path(dir_cleaned(), "crosswalk.csv")
    if (!file.exists(p)) stop("crosswalk.csv not found; run harmonize.R first")
    crosswalk <- utils::read.csv(p, stringsAsFactors = FALSE)
  }
  for (y in years) parse_year(y, crosswalk, overwrite = overwrite)
  invisible(TRUE)
}

# Allow `Rscript src/scrape/fetch_brfss.R [years...]` for the download pass.
if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  yrs <- if (length(args)) as.integer(args) else YEARS_ALL
  fetch_all(yrs)
}
