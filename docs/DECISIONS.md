# Construction decisions

Every choice below can move the estimates. Each entry states what was done,
why, and the alternative not taken. Where a decision is arguable, that is
said plainly rather than defended.

Code references: `src/cleaning/build_panel.R` unless noted.

---

## 1a. BMI is computed from height and weight, not taken from `_BMI*`

**Decision.** BMI is computed as kg/m² from reported height and weight
(`compute_bmi()`). CDC's precomputed `_BMI`/`_BMI2`/`_BMI4`/`_BMI5` is
retained only for comparison and as a fallback for any year lacking height or
weight (no such year exists in 1990–2023).

**Why — this is the most consequential decision in the pipeline.** CDC's
precomputed BMI rounds **up** to its stored precision, and that precision
changes across the series. Measured against BMI computed from the same
respondents' height and weight, the precomputed variable runs:

| Year | `_BMI` − computed | Implied decimals |
| --- | --- | --- |
| 2000 | **+0.0557** | 1 |
| 2010 | −0.0015 | 2 |
| 2019 | +0.0002 | 2 |

With one implied decimal the upward rounding is worth about +0.05 BMI units,
which pushes respondents sitting just under the cutoff (true BMI 29.95+)
across it. In 2000 that inflates national obesity prevalence by **0.57 pp**.
With two implied decimals the effect is ~0.005 units and vanishes.

The bias is therefore confined to 1990–2000, the one-implied-decimal era. Used
uncorrected, it puts a **spurious level shift of roughly half a percentage
point across the 2000/2001 boundary** into the series — an artifact of a
storage-format change that would read as a real turn-of-the-century trend
break. For a project whose entire purpose is separating real distributional
change from BRFSS methodology artifacts, shipping that would have defeated the
exercise.

**Validation.** Computing BMI directly reproduces Mokdad et al. (2001) exactly:
national 2000 prevalence of **0.1980** against their published **19.8%**
(SE 0.17). The precomputed variable gave 0.2038. See
`docs/benchmark_comparison.md`.

**Construction details.**
- Height is taken in **inches**, the precision at which BRFSS actually asks it
  ("feet and inches"). CDC's `HTM*` is those inches converted to whole
  centimetres, which is *coarser*, so it is not used.
- 1990–2000 have only the reported fields, decoded here: height as `FII`
  (507 = 5 ft 7 in), weight in pounds.
- From 2001 CDC ships `HTIN*` (inches) and `WTKG*` (kg, two implied decimals),
  which already resolve the imperial/metric dual encoding carried in the
  reported fields (`9XXX` = centimetres or kilograms). These are preferred,
  with the reported fields as fallback.
- Physiological bounds (36–84 in, 20–300 kg) double as sentinel filters, since
  BRFSS's 7777/9999 don't-know/refused codes fall far outside them.
- **Implied decimals on `WTKG*` are detected, not assumed.** `WTKG` is whole
  kilograms in 2001 (median 75) but carries two implied decimals from 2002
  (median 7522 = 75.22). A hardcoded ÷100 turned every 2001 weight into
  0.75 kg, which the physiological bounds then rejected — emptying the year.
  `detect_scale_divisor()` now infers the power of ten for both height and
  weight, on the same principle as §1 and for the same reason: **no encoding
  in this dataset is stable across years, including the ones that look
  derived and clean.** 2001 is the third separate variable on which that year
  alone breaks the pattern (`_BMI2` decimals, `PREGNT2` naming, `WTKG`
  scaling).

**Alternative not taken.** Keeping `_BMI*` for consistency with CDC's own
published figures. Rejected: it would embed a known, quantified, era-dependent
bias into the exact comparison the panel exists to support. Note the
consequence — this panel will sit ~0.5 pp *below* CDC's published values for
1990–2000 by construction, and that is the intended behaviour, not a defect.

---

## 1. BMI scale is detected, not hardcoded

*(Applies to CDC's precomputed `_BMI*`, which since §1a is used only for
comparison and fallback. The detection still runs every year, because the
comparison in §1a is what surfaced the rounding bias in the first place.)*

**Decision.** BRFSS stores BMI as an integer with implied decimal places, and
the number of places is *not* constant across the series. The divisor is
inferred per year by `detect_bmi_divisor()`: try 1, 10, 100, 1000 and take
the first that puts the median in [15, 45].

**Why.** Observed in the pilot years: `_BMI2` (2000) has a median of 259 —
one implied decimal, 25.9. `_BMI4` (2010) has a median of 2717 — two
implied decimals, 27.17. Hardcoding two decimals would have divided the
2000 values by 100 and produced a national prevalence near zero. The bug
would have been silent: still a number, still monotone, just wrong.

**The case that proves the point: 2001.** `_BMI2` in 2001 carries *four*
implied decimals (median 258225 = 25.82) — the same variable name as 2000,
which carries one. No rule based on variable name could get both right.
When the divisor list initially stopped at 1000, 2001 failed to resolve and
was dropped with a warning rather than silently mis-scaled; the list now
runs to 10^5. Inferred divisors across the full range are 10 (1990–2000),
10000 (2001), and 100 (2002–2023).

**Alternative not taken.** Reading the implied-decimal count out of each
year's codebook. More authoritative, but the codebooks are PDFs with no
stable machine-readable form, and the empirical rule is checkable from the
data itself. The inferred divisor is logged for every year so a wrong
inference is visible in the run log.

**Residual risk.** The rule would misfire if a year's true median BMI fell
outside [15, 45], which no plausible adult population does.

---

## 2. Missing-value sentinels cleared before rescaling

**Decision.** Raw values that are all-9s at any width from 3 to 8 digits
(999 through 99999999) are set to `NA` before the divisor is applied
(`clear_bmi_sentinels()`).

**Why.** Pre-2011 files encode "don't know / refused / missing" as all-9s at
the variable's own width, and that width tracks the number of implied
decimals: 999 in 2000, 9999 in 2010, 999999 in 2001. 2011+ files use a true
blank instead. Left in place these rescale to ~99.9, which the plausibility
filter would drop anyway — but they would still be counted in
`n_unweighted`, overstating cell sizes.

A blanket all-9s rule is safe here because no all-9s code is a plausible BMI
at any scale in use: 999 is 99.9 at one implied decimal, and 9999 is 0.9999
at four.

**Alternative not taken.** Relying on the plausibility filter alone. Rejected
because it corrupts the sample-size diagnostic, which is the thing used to
judge whether a cell is trustworthy.

---

## 3. BMI plausibility bounds: 12 ≤ BMI ≤ 60

**Decision.** Records outside [12, 60] are excluded from the analytic sample.

**Why.** Removes transcription-error extremes without cutting into the real
right tail. Obesity prevalence is a *right*-tail statistic, so an aggressive
upper bound would mechanically bias prevalence down — the upper cut matters
far more here than the lower one.

**Alternative not taken.** The tighter [15, 55] and looser [10, 70] windows
are both defensible and in use in the literature. It is a one-line change
(`BMI_MIN` / `BMI_MAX`); anyone who disagrees should rerun with their own
bounds rather than argue about it.

**How much it actually matters: almost nothing.** `diagnostics.md` §5 reports
the share of eligible records falling outside the window, and it runs from
0.01% in 1990 to 0.18% in 2023 — never above two-tenths of one percent. This
was expected to be the most arguable threshold in the pipeline and turns out
to be nearly immaterial to the estimates. Widening or tightening the bounds
within any defensible range cannot move state prevalence meaningfully.

**Not done.** No formal sensitivity table across bound choices has been
produced. Given the shares above, it would be a formality.

---

## 4. Age restriction: 18+

**Decision.** Keep respondents aged 18 and over. Years whose age variable
cannot be located are not screened at all (this occurs in no year of
1990–2023 — every year resolved an age variable).

**Why.** BRFSS is an adult survey by design, but the raw `AGE` variable
carries 7 = "don't know" and 9 = "refused" through 2012, the last year CDC
ships raw `AGE` (2013+ files start at 18). Both fall
below 18 and are therefore dropped by the same comparison — which is the
intended outcome, since neither can be confirmed to be an adult.

**Note on the variable itself.** Raw `AGE` disappears after 2012; from 2013
the pipeline uses `_AGE80` (imputed age, top-coded at 80). Since age enters
only as an 18+ screen, top-coding is irrelevant here. Imputation is not:
a handful of records screened in under `_AGE80` would have been screened out
under a raw age. The effect on a prevalence estimate is negligible, but it
is a genuine pre/post inconsistency and is listed here rather than buried.

**Alternative not taken.** Restricting to 20+ to match NHANES published
age-adjusted figures. Rejected because it would make the panel less
comparable to CDC's own BRFSS-based publications, which are the primary
benchmark. It does mean the NHANES comparison in `validation.md` is not
age-aligned — stated there.

---

## 5. Pregnancy exclusion

**Decision.** Drop respondents with `PREGNANT == 1` (currently pregnant).
Records with `NA` are **kept**.

**Why.** Pregnancy raises measured BMI without corresponding to the concept
being measured. `NA` here means "not asked" — men, and women outside
childbearing ages — not "unknown pregnancy status". Dropping `NA` would
delete most of the sample.

**Alternative not taken.** Keeping pregnant respondents, on the grounds that
CDC's own published BRFSS obesity figures do not always exclude them. This
is a real source of divergence from CDC's map values and is one candidate
explanation for any discrepancy reported in `validation.md`.

---

## 6. Records with missing or non-positive final weight are dropped

**Decision.** Records where the final weight is `NA` or ≤ 0 are removed
*before* the design object is constructed.

**Why.** A record with no weight cannot contribute to a weighted estimate,
and `svydesign()` will not accept non-positive weights. The dropped count is
logged per year so the loss is visible rather than silent.

**Alternative not taken.** Imputing a weight (e.g. the stratum mean). Rejected
— it invents survey information that the sample design does not contain.

---

## 7. Design built on the full year, then subset

**Decision.** `svydesign()` is constructed on all of a year's records, and
the analytic sample is selected afterwards with `subset(design, keep)`.
Filters are carried as a `keep` indicator column, not applied by dropping
rows first.

**Why.** This is the one decision here that is a correctness issue rather
than a judgment call. Filtering rows before building the design discards
strata and PSU structure: strata that lose all their records vanish, others
become single-PSU artificially, and the variance estimate is wrong —
generally too small. `subset()` on a design object retains the full
structure and adjusts the estimate properly.

**Alternative not taken.** Pre-filtering. Faster and simpler; produces
standard errors that are quietly biased.

---

## 8. Lonely PSUs: `survey.lonely.psu = "adjust"`

**Decision.** `options(survey.lonely.psu = "adjust")`.

**Why.** A stratum contributing a single PSU has no within-stratum variance
to estimate. `"adjust"` centers such strata at the population grand mean
rather than at their own mean, which is the conservative choice: it neither
drops the record nor understates its variance contribution. Lonely PSUs
arise in thin state-years, exactly the cells where an understated SE would
be most misleading.

**Alternatives not taken.**
- `"fail"` (the default): halts the run. Rejected — a single thin stratum
  in one state would block the entire panel.
- `"remove"`: drops the stratum's variance contribution, understating SEs.
- `"average"`: uses the average within-stratum variance across strata; less
  conservative than `"adjust"`, and harder to justify when strata differ in
  size as much as they do here.

---

## 9. Confidence intervals: normal approximation

**Decision.** `prev ± 1.96 × SE`, on the prevalence scale.

**Why.** Standard for design-based survey estimates and matches what CDC
publishes for BRFSS.

**Known limitation.** The normal interval can extend below 0 or above 1 for
very small cells, and is not the best interval for a proportion near a
boundary. A logit-transformed interval (`svyciprop(method = "logit")`) would
be better behaved. Not used here to keep the reported interval identical in
construction to CDC's. For any state-year flagged as thin in
`diagnostics.md` §1, prefer the SE to the interval.

---

## 10. Geography: 50 states + DC only

**Decision.** Keep FIPS codes for the 50 states and DC. Guam, Puerto Rico,
the Virgin Islands and other territories are dropped.

**Why.** The panel is specified as 50 states + DC. Territories enter and
leave the BRFSS sample across years, so including them would introduce
composition changes that look like distributional changes.

---

## 11. National aggregate is recomputed, not averaged

**Decision.** The national figure in `validation.md` is computed from the
microdata via `svymean()` over the full design, not averaged across the
state panel.

**Why.** A simple mean across states weights Wyoming equally with
California. The survey weights already carry population, so the design-based
national estimate is the correct one. (By contrast, the cross-state moments
in `diagnostics.md` §3 *are* unweighted across states — deliberately, since
the object of interest there is the distribution across states, where each
state is one observation.)

**Where it is computed.** `build_panel.R`, from the same design object the
state estimates come from, written to `data/cleaned/national_prevalence.csv`.
`validate.R` reads that file. It previously built its own design for every
year to produce these numbers, which meant reconstructing all 34 designs a
second time — 3.5 to 5 minutes apiece for the post-2011 files — to reproduce
figures `build_panel.R` already had in hand. Computing both from one design
object is also strictly stronger than computing them from two identical ones:
the national figure and the state figures cannot drift apart.

The file is **merged, not overwritten**, because `build_panel()` is routinely
run on a subset of years; writing it wholesale would delete the other 31 rows.
`validate.R` retains a recompute path for years missing from the file, and
warns when it uses it.

**Scope.** This file carries prevalence only, not the four means added in §16.
It exists to support the NHANES comparison in `validation.md`, which is a
prevalence comparison.

---

## 12. What is NOT corrected

- **Self-report bias.** BRFSS height and weight are self-reported and bias
  BMI downward relative to measured NHANES values. Out of scope by
  instruction; the uncorrected panel is built first. `validation.md`
  quantifies the resulting gap but does not close it.
- **The 2011 methodology break.** No splicing, no adjustment factor, no
  smoothing. See below.

---

## 13. The 2011 break is measured, not repaired

**Decision.** Pre-2011 and post-2011 estimates sit in the same file with no
adjustment. `diagnostics.md` §2 quantifies the discontinuity; nothing
removes it.

**Why.** In 2011 BRFSS added a cell-phone sample and replaced
post-stratification with raking. Both changes move measured prevalence, and
they are confounded with each other — no split of the data identifies their
separate contributions. Any single splice factor would impose the assumption
that the break is a common additive shift, which is precisely the question
`diagnostics.md` §2 is built to test. Applying a correction would bury the
evidence needed to judge whether the correction was valid.

**Consequence for users of the panel.** Do not run a specification that
treats 1990–2023 as a single comparable series without addressing the break.
A regime indicator interacted with the trend is the minimum; separate
pre/post analyses are safer.

---

## 14. Known data gaps (flagged, not filled)

- **19 missing state-years in total**, all left missing. Interpolating any of
  them would fabricate the one thing the panel is supposed to measure. The
  generated list lives in `diagnostics.md` §1; the substantive ones are:
  - **New Jersey, 2019** — entirely absent from the file, zero records.
  - **Florida, 2021**; **Kentucky and Pennsylvania, 2023**; **Hawaii, 2004**
    — absent from their respective files.
  - The remainder are pre-1996 phase-in (see next bullet).

  The recent absences matter more than their count suggests: 2023 is the
  panel's endpoint, and it is missing two states, one of them (Kentucky)
  a persistently high-prevalence state. A national or cross-state figure for
  2023 is therefore not constructed on the same basis as 2022. Any endpoint
  comparison should either exclude 2023 or restrict both years to the states
  present in both.
- **Incomplete state coverage before 1996.** BRFSS was phased in across
  states, so the early panel is not a balanced 51 units: 1990 yields 45
  states, rising to a full 51 by 1996. This matters directly for the
  cross-state moments in `diagnostics.md` §3 — a change in the SD across
  states between 1990 and 1996 partly reflects *which* states are present,
  not how the distribution moved. Treat pre-1996 moments as not comparable
  to later years. The panel is left unbalanced rather than restricted to a
  common set of states, since that choice is better made by the analysis
  than baked into the panel.
- Any count of "states above threshold X" is not comparable across years when
  the number of states present differs; `validation.md` §2 reports
  `states_in_panel` alongside each count for this reason.

---

## 15. Rising BMI item nonresponse is reported, not corrected

**Decision.** The share of adult records with no usable BMI is reported by
year in `diagnostics.md` §5. Nothing adjusts for it.

**Why it matters.** Item nonresponse on height/weight roughly triples across
the series — about 3% in the early 1990s against about 11% by 2022. If the
respondents who decline to answer differ systematically from those who do
(and for a self-reported weight question there is every reason to think they
might), then measured prevalence drifts even where true prevalence is flat.
This is a distinct threat from the 2011 design break and it is not removed by
splitting the sample at 2011.

**Alternative not taken.** Nonresponse reweighting within state-year cells.
It would require an assumption about missingness that the data cannot test,
and it would obscure a trend the user should see directly.

---

## 16. The panel reports four means alongside prevalence

**Decision.** `state_obesity_panel.csv` carries weighted state-year means of
BMI, height (inches), weight (kilograms) and age, each with its design-based
standard error, next to `prev_obese`. All five are estimated in a single
`svyby()` call on one design and one analytic sample, so a cell's mean height
and its prevalence describe exactly the same respondents.

**Why one sample.** The obvious alternative — estimate each measure on
whatever records happen to carry it — buys a few percent more observations
for height and weight at the cost of making the columns non-comparable within
a row. Mean BMI would then be computed over a different set of people than
mean weight, and the identity linking them would not hold even approximately.
The analytic sample is defined once (18+, not pregnant, plausible BMI,
positive final weight, panel state) and every column obeys it.

**Listwise deletion is a no-op here, and that was verified rather than
assumed.** `svymean(na.rm = TRUE)` over several variables deletes a record
missing *any* of them. On this sample it deletes **zero records in all 34
years**: `keep` already requires a usable BMI, which requires both a
plausible height and a plausible weight, and the 18+ screen already requires
an age, so every record that reaches the estimator is complete on all five
measures by construction.

`available_measures()` is therefore an assertion, not a repair. It admits a
measure only if it is complete on the analytic sample and writes `NA` for
that year otherwise. It earns its place as a guard on future edits: a measure
with genuine item nonresponse — income, smoking status — added carelessly to
`PANEL_MEASURES` would silently move every other estimate in the same
`svyby()` call, `prev_obese` included. Failing loudly beats that. The only
live case it covers today is a year falling back to CDC's precomputed
`_BMI*`, which carries no height or weight to report; no year currently does.

**The real selection question, and its size.** The analytic sample is
conditioned on having reported height and weight, and that condition is not
free: it drops 2.6% of eligible adults in 1990 and 10.8% by 2022 (§15). So
`mean_age` is the mean age of adults who answered the height/weight
questions, not of all adults. Measured, that selection is small — mean age
among the retained differs from mean age among all eligible adults by −0.12
years in 1990, +0.06 in 2010, and +0.16 in 2022, its largest value in the
series and in the year with the worst nonresponse. `diagnostics.md` §5
reports it for every year as `age_selection_yr`.

This bounds the threat for age. It says nothing about selection on *weight*,
which is by construction unobservable for the people who declined to report
it, and which is the direction that would actually bias `prev_obese`. That
remains uncorrected and flagged (§15).

**Alternative not taken.** Estimating `mean_age` on all eligible adults
rather than on the BMI-complete sample, which would use ~10% more records by
the end of the series. Rejected because it would make `mean_age` describe a
different population than every other column in the same row — breaking the
one property that makes this panel usable for compositional questions
("is rising obesity explained by an aging sample?") — in exchange for
correcting a discrepancy measured at 0.16 years.

**Height and weight are blanked wherever BMI is.** `derive_anthro()` sets
both to `NA` whenever the BMI they imply is missing. Without this, a record
with a plausible height and an implausible weight would contribute to
`mean_height_in` but not to `mean_bmi`.

**Units.** Height in inches and weight in kilograms — the units the pipeline
computes BMI in, so the reported means are the ones that actually enter the
BMI. Pounds are `mean_weight_kg / 0.45359237`; centimetres are
`mean_height_in * 2.54`. Note that a mean of a ratio is not the ratio of
means: `mean_bmi` is not recoverable from `mean_height_in` and
`mean_weight_kg`.

**Alternative not taken.** Reporting medians or the full BMI distribution
(quantiles, share overweight). Defensible, and quantiles would be more robust
than the mean for a right-skewed variable, but `svyquantile` by state-year is
substantially more expensive and the request was for means. Nothing in the
construction blocks adding them later.

---

## 16a. Age is top-coded at 80 in every year

**Decision.** `mean_age` is computed on `pmin(age, 80)` for all years, not on
raw age.

**Why.** Raw `AGE` (1990–2012) is uncapped; from 2013 CDC ships only
`_AGE80`, which is collapsed above 80. Averaging the two as they come would
plant a spurious drop in mean age at 2013 that is purely a change in the
top-code — the same class of artifact as the `_BMI*` rounding in §1a.
Applying the 2013+ top-code to the earlier years puts both on one scale.
This is a real cost: the pre-2013 files could have supported an uncapped mean
and no longer do. Comparability across the series was judged worth more than
precision in the right tail, consistent with the rule that construction must
be identical across years.

**What this does not fix.** `_AGE80` is *imputed* for records that did not
give an age, while raw `AGE` was not — records that would have been screened
out pre-2013 are screened in afterwards (§4). Top-coding does nothing about
that, and it is not corrected. `diagnostics.md` §6 flags 2013 so a level
shift there is read as a measurement change first.

**Sentinels.** Raw `AGE` codes 7 = don't know and 9 = refused, in every year
it appears (1990–2012). Both are
below 18 and are removed by the adult screen before any mean is taken, so
neither reaches `mean_age`. The value 99 is a legitimate coded age in those
files (the observed frequencies decline monotonically through 98 and then
jump at 99, consistent with a top-code at 99 rather than a missing-value
flag); top-coding at 80 makes the question moot either way.

**Alternative not taken.** Reporting mean age uncapped before 2013 and
capped after, with a flag column. Rejected: it puts the burden of the
correction on every downstream user and invites exactly the spliced series
this project exists to avoid.

---

## 17. Confidence intervals are reported for the prevalence only

**Decision.** `ci_lower_obese` / `ci_upper_obese` accompany `prev_obese`.
The four means carry standard errors but no interval columns.

**Why.** The prevalence is the quantity benchmarked against published
estimates in `benchmark_comparison.md`, and the coverage check there needs
the interval. For the means the interval is `estimate ± 1.96 × se` under the
same normal approximation documented in §9, and eight more columns of
arithmetic on a column already present adds width without information.

---

## 18. The percentile panel, and why it has no standard errors

**Decision.** `data/cleaned/state_bmi_percentiles.csv` reports the weighted
BMI distribution within each state-year at percentiles 1 through 99 — one row
per state × year × percentile, roughly 100× the rows of the mean panel. It
carries a point estimate and `n_unweighted`, and **no standard error**.

**Why the file exists.** Obesity prevalence is the mass above a single cut
(BMI 30). It cannot distinguish a uniform rightward shift of the BMI
distribution from a stretch concentrated in the upper tail, and those imply
very different things about what changed — yet both can trace out the same
prevalence path. The percentile panel is what makes that distinction
visible; `diagnostics.md` §7 does the comparison.

**Why 1:99 and not 1:100.** The 100th percentile is the sample maximum, and
this pipeline caps BMI at 60 (§3). p100 would therefore report our own
plausibility filter back to us in nearly every cell rather than a feature of
the data. p0 is the minimum and is an artifact of the BMI ≥ 12 floor for the
same reason. Both are omitted deliberately. The grid is a one-line change if
a different one is wanted; nothing downstream assumes 99.

**How the point estimates are computed.** The smallest observed BMI whose
cumulative weight share reaches p, using the same final weights and the same
analytic sample as every other column in the project. This is *exactly* what
`svyquantile()` returns as a point estimate, not an approximation, and it is
not an unweighted quantile.

**Verification.** For 1990 the identity was checked exhaustively — all 45
states × 99 percentiles, maximum difference **0**. It could not be checked
exhaustively for a post-2011 year: `svyquantile()` across all 51 states of
2013 ran over two hours and 45 minutes without completing. Later years are
therefore verified on a probe of four deliberately varied states (California,
Texas, Wyoming, DC), covering both sides of the 2011 break and including 2001,
the year that breaks the pattern on three other variables (§1):

| Year | Scope | `svyquantile()` time | max &#124;difference&#124; |
| --- | --- | --- | --- |
| 1990 | all 45 states × 99 pctiles | 80 s | **0** |
| 2001 | 4 states × 99 pctiles | 86 s | **0** |
| 2013 | 4 states × 99 pctiles | 1,079 s | **0** |
| 2019 | 4 states × 99 pctiles | 948 s | **0** |

The probe script is `src/cleaning/verify_percentiles.R`; `run_all.R` does not
source it, since it is a check on the pipeline rather than a stage of it.

**Why no standard error.** The timings in that table *are* the reason. Four
states of 2013 cost 1,079 seconds — roughly 3.8 hours for that single year's
51 states — against 0.03 seconds to compute the entire year directly.
`svyquantile()` spends essentially all of it on variance and
confidence-interval machinery, which it runs even when called with
`se = FALSE`. Design-based SEs for 99 percentiles × 51 states × 34 years are
therefore not a matter of a slower run; on this evidence they are infeasible
in this pipeline's structure, and would have to be obtained a different way
if they were ever needed.

Note the timings are driven by the post-2011 sample sizes, not by the year
label: 2001 costs about what 1990 does, while 2013 and 2019 cost an order of
magnitude more.

This is a real limitation and is not hidden: the percentile file supports
description of the distribution's shape, not inference about it. Anyone wanting to
test whether a percentile moved significantly between two years needs the
design-based variance, and should compute it with `svyquantile()` for the
specific cells in question rather than assume the point estimates come with
uncertainty attached. `n_unweighted` is reported on every row so thin cells
are visible.

**Alternative not taken.** Reporting deciles or a handful of percentiles
(10/25/50/75/90) with full design-based SEs, which would have been affordable.
Rejected because the fine grid is what makes the file useful for
distributional work — reconstructing a CDF, comparing shapes across states,
locating where in the distribution a change occurred — and that use does not
depend on per-percentile inference. The coarse-grid-with-SEs version remains
available to anyone who wants it via `svyquantile()`.

**Consistency check.** The share of a state-year's 99 percentiles at or above
BMI 30 tracks `prev_obese` from the mean panel with correlation 0.988 and mean
absolute difference 0.004. The two files are built from the same records and
the same weights; the small gap is the 1-percentage-point granularity of the
grid, not a disagreement.
