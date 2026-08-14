# Adult obesity prevalence by US state, 1990–2023

A state-year panel of adult obesity prevalence (BMI ≥ 30) for the 50 states + DC,
built from BRFSS microdata with **identical construction rules applied to every year**.

The panel is the deliverable; the scripts that produce it are included so any number in
it can be traced back to the CDC file it came from. No analysis is published here.

**→ [`data/cleaned/state_obesity_panel.csv`](data/cleaned/state_obesity_panel.csv)** —
1,715 state-years across 34 years.

---

## The data

| Column | Description |
| --- | --- |
| `state_fips` | State FIPS code |
| `state_name` | State name |
| `year` | Survey year, 1990–2023 |
| `prev_obese` | Weighted prevalence of BMI ≥ 30, as a **proportion** (0–1) |
| `se` | Standard error, from the survey design |
| `n_unweighted` | Unweighted respondents contributing to the cell |
| `ci_lower`, `ci_upper` | 95% CI, normal approximation |

Two supporting files:

- [`data/cleaned/national_prevalence.csv`](data/cleaned/national_prevalence.csv) —
  national prevalence by year, recomputed from the microdata rather than averaged
  across states.
- [`data/cleaned/crosswalk.csv`](data/cleaned/crosswalk.csv) — the year → BRFSS
  variable-name map the pipeline resolved, with the SAS label it matched on. Useful on
  its own if you are pulling other variables out of these files.

## How it is built

Source: [CDC BRFSS Annual Survey Data](https://www.cdc.gov/brfss/annual_data/annual_data.htm),
one XPT file per year, downloaded directly.

- **BMI is computed** from self-reported height and weight, not read from CDC's
  precomputed `_BMI*`. That variable rounds up to its stored precision, which changes
  from one implied decimal to two after 2000 — enough to plant a spurious half-point
  level shift at the 2000/2001 boundary. This is the single most consequential choice in
  the pipeline.
- Sample: **adults 18+**, pregnant respondents excluded, `12 ≤ BMI ≤ 60`, positive final
  weight. Territories dropped.
- Estimates use the **survey design** throughout —
  `svydesign(ids = ~psu, strata = ~strata, weights = ~finalwt, nest = TRUE)`, with
  `survey.lonely.psu = "adjust"`. Nothing is an unweighted mean.
- Variable names, implied decimals, and missing-value sentinels all drift across years
  and are **detected per year at runtime**, never hardcoded.

Every choice that can move an estimate is written up in
[`docs/DECISIONS.md`](docs/DECISIONS.md), with the alternative not taken.

## Two things to know before you use it

**1. There is a survey design break in 2011 that is not repaired.** BRFSS added a cell-phone sample and
replaced post-stratification with raking in 2011. Both moved measured prevalence, and
they are confounded with each other. Pre- and post-2011 estimates sit in the same file
with no adjustment, because any single splice factor would assume the break is a common
additive shift — which is exactly the thing worth testing.
[`docs/diagnostics.md`](docs/diagnostics.md) §2 quantifies it (mean gap −2.0 pp against
an extrapolated pre-2011 trend, and read that as an upper bound). Do not fit
1990–2023 as one comparable series without a regime term.

**2. Nineteen state-years are (deliberately) missing.** Those states are absent from the
underlying CDC file — New Jersey has zero records in 2019, and early-1990s coverage is
incomplete. They are left missing rather than interpolated. The full list is in
[`docs/diagnostics.md`](docs/diagnostics.md) §1.

More generally: known problems in this panel are flagged rather than patched. Rising BMI
item nonresponse and a widening BRFSS/NHANES gap are both reported and neither is
corrected.

## Validation

Checked state-by-state against published BRFSS-derived estimates —
Mokdad et al. (2001) for 2000, CDC's Adult Obesity Prevalence Maps for 2022:

| Year | Pearson *r* | Rank correlation | Published values inside our 95% CI |
| --- | --- | --- | --- |
| 2000 | 0.999 | 0.998 | 100% |
| 2022 | 1.000 | 0.999 | 100% |

Details, including a residual −0.24 pp offset in 2022 that is left unreconciled, are in
[`docs/benchmark_comparison.md`](docs/benchmark_comparison.md). A separate comparison
against NHANES is in [`docs/validation.md`](docs/validation.md); BRFSS runs ~9 pp below
NHANES because BRFSS height and weight are self-reported and NHANES are measured. **No
self-report correction is applied to this panel.**

## Reproducing it

Requires R (≥ 4.5) with `haven`, `survey`, `srvyr`, `dplyr`, `tidyr`, `readr`, `here`,
`moments`. From the repo root:

```sh
Rscript src/run_all.R                    # full range, 1990-2023
Rscript src/run_all.R 2000 2010 2019     # a few years
```

A cold full run takes about 2.4 hours and downloads ~22 GB of XPT files into
`data/raw/` (not tracked here). Every stage is cached and resumable — downloads,
schemas, and parsed extracts are skipped when the artifact already exists, so reruns
cost minutes. Column selection happens before caching; the full-width files are never
loaded.

| Script | Produces |
| --- | --- |
| `src/scrape/fetch_brfss.R` | `data/raw/brfss/<year>/`, narrow per-year caches |
| `src/cleaning/harmonize.R` | `data/cleaned/crosswalk.csv` |
| `src/cleaning/build_panel.R` | `data/cleaned/state_obesity_panel.csv` |
| `src/cleaning/diagnostics.R` | `docs/diagnostics.md` |
| `src/cleaning/validate.R` | `docs/validation.md` |
| `src/cleaning/compare_published.R` | `docs/benchmark_comparison.md` |

`data/reference/` holds published benchmark values transcribed from the sources cited in
its [`SOURCES.md`](data/reference/SOURCES.md). It is read only by
`compare_published.R` and is not downloaded by the pipeline.

## Source and attribution

Underlying microdata are collected and published by the CDC Behavioral Risk Factor
Surveillance System. This repository redistributes no CDC data — only estimates derived
from it and the code that derives them. Errors in the panel are mine, not CDC's.

I heavily used Claude Code (Opus 5 model) to produce this product and am distributing it after verifying results match other publications of the same underlying data (e.g. [Mokdad et al., 2001, JAMA](https://jamanetwork.com/journals/jama/fullarticle/195663)).

## License

[MIT](LICENSE), covering both the code and the derived estimates in `data/cleaned/`.
Use it freely; a citation back to this repository is appreciated. The published
benchmark values in `data/reference/` are third-party figures transcribed from the
sources cited in [`SOURCES.md`](data/reference/SOURCES.md) and carry whatever terms
those sources carry.
