# BRFSS state obesity panel — external validation

Generated 2026-08-17.

> **Benchmark provenance.** The NHANES and CDC-map values in this report
> are constants transcribed into `src/cleaning/validate.R` from published
> sources (NCHS Data Briefs; CDC Adult Obesity Prevalence Maps). They were
> **not** downloaded and have not been programmatically verified against
> the originals. Check them before citing any discrepancy below.

## 1. Constructed national aggregate vs NHANES

BRFSS national prevalence is recomputed from the microdata with the survey design (not averaged across the state panel). NHANES values are age-adjusted, adults 20+, at the midpoint year of each cycle.

| year | cycle | brfss_prev | brfss_se | nhanes_prev | diff_pp |
| --- | --- | --- | --- | --- | --- |
| 1991 | 1988-1994 | 0.1201 | 0.0017 | 0.229 | -10.8924 |
| 2000 | 1999-2000 | 0.1980 | 0.0017 | 0.305 | -10.6971 |
| 2002 | 2001-2002 | 0.2193 | 0.0016 | 0.306 |  -8.6708 |
| 2004 | 2003-2004 | 0.2347 | 0.0016 | 0.322 |  -8.7317 |
| 2006 | 2005-2006 | 0.2506 | 0.0017 | 0.343 |  -9.2363 |
| 2008 | 2007-2008 | 0.2668 | 0.0015 | 0.337 |  -7.0167 |
| 2010 | 2009-2010 | 0.2783 | 0.0014 | 0.357 |  -7.8663 |
| 2012 | 2011-2012 | 0.2754 | 0.0014 | 0.349 |  -7.3580 |
| 2014 | 2013-2014 | 0.2872 | 0.0014 | 0.377 |  -8.9773 |
| 2016 | 2015-2016 | 0.2936 | 0.0014 | 0.398 | -10.4388 |
| 2018 | 2017-2018 | 0.3068 | 0.0016 | 0.424 | -11.7169 |

BRFSS runs below NHANES in 11 of 11 comparable years; mean gap -9.2 pp (range -11.7 to -7.0).

**This gap is expected, not a defect.** BRFSS height and weight are self-reported and NHANES are measured; self-report biases BMI down. The gap's *sign* is the check that passes here. Its *magnitude* is not something this pipeline attempts to correct — the Ward-style NHANES matching correction is out of scope by design. A discrepancy in the wrong direction, or a gap that moves sharply across the 2011 break, would be the real warning sign; see `diagnostics.md` §2.

**The gap is not stable, and that is a finding.** It averages -9.0 pp through 2010 and -9.6 pp after, i.e. it widens by roughly 0.6 pp across the series.

A widening gap means self-report bias is growing, which is a threat to comparability *within* BRFSS that is separate from the 2011 design break and is not removed by splitting the sample at 2011. It moves in step with the rising BMI item nonresponse in `diagnostics.md` §5; both point to declining quality of the self-reported height/weight measure over time. Neither is corrected here.

## 2. Constructed state counts vs CDC published maps

| year | claim | published_count | constructed_count | states_in_panel | difference |
| --- | --- | --- | --- | --- | --- |
| 2000 | states with prevalence >= 30% |  0 |  0 | 51 |  0 |
| 2022 | states with prevalence >= 35% | 22 | 20 | 51 | -2 |

`states_in_panel` is reported because a count of states over a threshold is not comparable if the panel is missing states that year — see the missing state-year list in `diagnostics.md` §1.


**On any non-zero `difference` above.** It is left unreconciled. Candidate sources, in rough order of how much they could move a threshold count, are: (a) the `published_count` constant itself, which is transcribed and unverified — check it first; (b) the pregnancy exclusion, which CDC's published figures do not consistently apply (`DECISIONS.md` §5); (c) the 18+ screen versus any age-adjustment CDC applies (§4); (d) the BMI plausibility window (§3), though `diagnostics.md` §5 shows it touches under 0.2% of records and so cannot account for much. A count near a threshold is also mechanically fragile: states sitting within a standard error of the cutoff flip on trivial differences in construction.

---

No discrepancy above has been adjusted for, reweighted, or smoothed.
