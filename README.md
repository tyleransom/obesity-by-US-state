# Adult obesity, BMI, height, weight and age by US state, 1990–2023

State-year panels of adult obesity prevalence (BMI ≥ 30), mean BMI, height, weight and
age, and the full BMI distribution by percentile, for the 50 states + DC — built from
BRFSS microdata with **identical construction rules applied to every year**.

The panel is the deliverable; the scripts that produce it are included so any number in
it can be traced back to the CDC file it came from. No analysis is published here.

Two files, built from the same records, the same weights, and the same analytic sample:

**→ [`data/cleaned/state_obesity_panel.csv`](data/cleaned/state_obesity_panel.csv)** —
one row per state-year. 1,715 rows across 34 years. Prevalence and four means, each
with a design-based standard error.

**→ [`data/cleaned/state_bmi_percentiles.csv`](data/cleaned/state_bmi_percentiles.csv)** —
one row per state-year-**percentile**, 1st through 99th. ~170,000 rows. The full weighted
BMI distribution in each cell, for work that needs distributional shape rather than a
single summary. No standard errors — see [below](#the-percentile-panel).

---

## The data

| Column | Description |
| --- | --- |
| `state_fips` | State FIPS code |
| `state_name` | State name |
| `year` | Survey year, 1990–2023 |
| `prev_obese`, `se_obese` | Weighted prevalence of BMI ≥ 30, as a **proportion** (0–1) |
| `mean_bmi`, `se_bmi` | Weighted mean BMI, kg/m² |
| `mean_height_in`, `se_height_in` | Weighted mean height, inches (× 2.54 for cm) |
| `mean_weight_kg`, `se_weight_kg` | Weighted mean weight, kilograms (÷ 0.45359237 for lb) |
| `mean_age`, `se_age` | Weighted mean age, years, **top-coded at 80 in every year** |
| `ci_lower_obese`, `ci_upper_obese` | 95% CI on the prevalence, normal approximation |
| `n_unweighted` | Unweighted respondents contributing to the cell |

Every `se_*` is design-based. Intervals for the means are `estimate ± 1.96 × se`.

All five measures come from **one `svyby()` call on one analytic sample**, so a row's
mean height and its prevalence describe the same respondents. That also means `mean_bmi`
is *not* recoverable from `mean_height_in` and `mean_weight_kg` — a mean of a ratio is
not the ratio of means.

### The percentile panel

`state_bmi_percentiles.csv` reports the weighted BMI distribution inside each state-year:

| Column | Description |
| --- | --- |
| `state_fips`, `state_name`, `year` | As above |
| `percentile` | 1–99 |
| `bmi` | Weighted BMI at that percentile, kg/m² |
| `n_unweighted` | Respondents in the cell (constant within a state-year) |

**Why it exists.** Obesity prevalence is the mass above a single cut. It cannot tell a
uniform rightward shift of the BMI distribution apart from a stretch concentrated in the
upper tail — and those mean different things while tracing the same prevalence path.
[`docs/diagnostics.md`](docs/diagnostics.md) §7 makes that comparison.

**Percentiles 1–99, not 0–100.** p100 is the sample maximum and this pipeline caps BMI at
60, so p100 would report our own filter back at you rather than anything about the data.
p0 is the minimum and is an artifact of the BMI ≥ 12 floor for the same reason.

**No standard errors, deliberately.** The point estimates are exactly what `svyquantile()`
returns, computed directly from cumulative weights — verified bit-identical (**maximum
difference 0**) across all 45 states × 99 percentiles of 1990, and on four-state probes of
2001, 2013 and 2019. `svyquantile()` itself costs 80 s for all of 1990 but **1,079 s for
four states of 2013** — about 3.8 hours for that one year's 51 states — because it runs
its variance and confidence-interval machinery even when told not to. Design-based SEs for
99 × 51 × 34 cells are not a slower run; they are infeasible here. Rerun the check with
`Rscript src/cleaning/verify_percentiles.R`.

So: **this file supports description of the distribution, not inference about it.** To
test whether a percentile moved significantly, compute the design-based variance with
`svyquantile()` for the specific cells you care about. `n_unweighted` is on every row so
thin cells are visible. Full reasoning in [`docs/DECISIONS.md`](docs/DECISIONS.md) §18.

The two files agree: the share of a state-year's 99 percentiles at or above BMI 30 tracks
`prev_obese` with correlation 0.988 and mean absolute difference 0.004, the residual being
the 1-point granularity of the grid.

### Read this before using `mean_age`

**Age is top-coded at 80 in every year of the panel, including years where the raw data
were not top-coded.** CDC ships an uncapped `AGE` through 2012 and, from 2013, only
`_AGE80` — which is collapsed above 80. Averaging the two as they come would put a step
down in mean age at 2013 that is purely an artifact of the changed top-code. Capping the
earlier years to match is what removes it.

The cost is real and one-directional: the pre-2013 files could have supported an uncapped
mean and this panel does not report one. If you need the right tail of the age
distribution before 2013, go back to the raw files. Two further caveats:

- `_AGE80` is **imputed** for respondents who gave no age; the pre-2013 raw `AGE` was
  not. Records that would have been screened out before 2013 are screened in afterwards.
  Top-coding does nothing about this and it is not corrected.
- `mean_age` is the mean age of adults who **reported height and weight**, since that is
  the sample every column is built on. That group falls from 97% of eligible adults in
  1990 to 89% in 2022. The resulting age selection is small — at most **0.16 years**,
  in 2022 — and is reported for every year as `age_selection_yr` in
  [`docs/diagnostics.md`](docs/diagnostics.md) §5.

Two supporting files:

- [`data/cleaned/national_prevalence.csv`](data/cleaned/national_prevalence.csv) —
  national prevalence by year, computed from the microdata with the survey design rather
  than averaged across states, so it is population-weighted by the survey weights
  themselves. Prevalence only; the four means are state-level.
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
  weight. Territories dropped. The same sample defines every column — height and weight
  are blanked wherever the BMI they imply is missing.
- **Age is top-coded at 80 in every year**, for the reasons above.
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
1990–2023 as one comparable series without a regime term. **This applies to every column,
not just prevalence** — mean BMI, height and weight cross the same break, and `mean_age`
crosses a second one at 2013 where the age variable changes source
([`docs/diagnostics.md`](docs/diagnostics.md) §6).

**2. Nineteen state-years are (deliberately) missing.** Those states are absent from the
underlying CDC file — New Jersey has zero records in 2019, and early-1990s coverage is
incomplete. They are left missing rather than interpolated. The full list is in
[`docs/diagnostics.md`](docs/diagnostics.md) §1.

More generally: known problems in this panel are flagged rather than patched. Rising BMI
item nonresponse and a widening BRFSS/NHANES gap are both reported and neither is
corrected.

## Validation

Checked state-by-state against published BRFSS-derived estimates —
Mokdad et al. (2001) for 2000, CDC's Adult Obesity Prevalence Maps for 2022. **The
validation covers `prev_obese` only**; the four means are constructed the same way and on
the same sample, but no published state-year benchmark was located for them.

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
| `src/cleaning/build_panel.R` | `state_obesity_panel.csv`, `state_bmi_percentiles.csv`, `national_prevalence.csv` |
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
