# Reference data — provenance

External benchmark values, supplied by the user rather than downloaded by the
pipeline. Nothing here is derived from `data/raw/`; nothing in `data/cleaned/`
depends on it. It is read only by `src/cleaning/compare_published.R`.

`data/reference/` is the one place in the tree holding third-party published
numbers. Keep it that way: values transcribed from papers or agency web pages
belong here with a citation, not inlined as constants in a script.

## `published_state_prevalence.csv`

Adult obesity prevalence (BMI ≥ 30) by state, 51 units (50 states + DC), as
**percentages** — not proportions. Ranks are as published, 1 = highest
prevalence.

| Column | Source |
| --- | --- |
| `prev_2022`, `rank_2022` | CDC, Adult Obesity Prevalence Maps — <https://www.cdc.gov/obesity/php/data-research/adult-obesity-prevalence-maps.html>, accessed 2024-08-23 |
| `prev_2000`, `rank_2000` | Mokdad AH et al. (2001), *JAMA* 286(10):1195–1200, "The Continuing Epidemic of Obesity and Diabetes in the United States" |

### Why these are the useful benchmark

Both are built from the **same BRFSS microdata** this pipeline downloads. That
makes them a check on *construction* — age handling, pregnancy exclusion,
weighting, BMI filters — in a way the NHANES comparison in `validation.md`
cannot be. NHANES uses measured height and weight, so a BRFSS/NHANES gap is
expected and mostly reflects self-report bias; a gap against these two should
be small, and where it is not, the difference is in how the estimate was built.

### What the Mokdad comparison established

Reading the paper (Methods, p. 1195) settled the construction questions that
the numbers alone could not:

- **N = 184 450, adults 18+** — exactly the row count of the 2000 BRFSS file,
  so they applied **no** sample exclusions.
- **"We used data on self-reported weight and height to calculate BMI"** — they
  computed BMI rather than taking CDC's precomputed variable.
- **No pregnancy exclusion** is mentioned anywhere in Methods.
- Their "22 states with obesity ≥20%" counts *states*: DC (21.2%) is in their
  Table 2 but not in that count, which is why a naive recount gives 23.

Testing each of this pipeline's exclusions against the 2000 file showed none of
them explained the gap — dropping the pregnancy exclusion, the plausibility
window, and the territory restriction together moved national prevalence by
0.0004. The difference was entirely in the BMI variable: `_BMI2` rounds up at
one implied decimal, worth +0.57 pp. Computing BMI from height and weight
reproduces their 19.8% exactly. See `DECISIONS.md` §1a.

### Remaining construction differences

- CDC's map figures are crude (not age-adjusted) BRFSS prevalence, so they are
  comparable in principle to this panel's estimates.
- Neither source states a BMI plausibility window. `diagnostics.md` §5 shows
  that choice moves under 0.2% of records, so it cannot explain a large gap.
- This panel excludes pregnant women and Mokdad et al. do not, but on the 2000
  file that is worth 0.0001 in prevalence.
