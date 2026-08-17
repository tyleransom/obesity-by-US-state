# BRFSS state obesity panel — diagnostics

Generated 2026-08-17 from `data/cleaned/state_obesity_panel.csv`.
Panel covers 1715 state-years across 34 years (1990–2023).

## 1. Unweighted sample size by state-year

Cells below 500 unweighted observations are flagged.

### By year

| year | n_states | total_n | min_n | median_n | n_thin |
| --- | --- | --- | --- | --- | --- |
| 1990 | 45 | 78121 | 794 | 1685 | 0 |
| 1991 | 48 | 83917 | 1133 | 1690.5 | 0 |
| 1992 | 49 | 91743 | 1139 | 1731 | 0 |
| 1993 | 50 | 97690 | 1134 | 1733 | 0 |
| 1994 | 50 | 100833 | 1150 | 1746 | 0 |
| 1995 | 50 | 108566 | 1143 | 1918.5 | 0 |
| 1996 | 51 | 115800 | 1048 | 2011 | 0 |
| 1997 | 51 | 126662 | 1445 | 2325 | 0 |
| 1998 | 51 | 139132 | 1402 | 2466 | 0 |
| 1999 | 51 | 148531 | 1171 | 2759 | 0 |
| 2000 | 51 | 169557 | 1603 | 3119 | 0 |
| 2001 | 51 | 191439 | 1758 | 3597 | 0 |
| 2002 | 51 | 225548 | 2227 | 4104 | 0 |
| 2003 | 51 | 241242 | 1896 | 4111 | 0 |
| 2004 | 50 | 278748 | 2486 | 4818.5 | 0 |
| 2005 | 51 | 328751 | 2666 | 5295 | 0 |
| 2006 | 51 | 325585 | 1983 | 5519 | 0 |
| 2007 | 51 | 398610 | 2401 | 6327 | 0 |
| 2008 | 51 | 383165 | 2515 | 6470 | 0 |
| 2009 | 51 | 400015 | 2294 | 6465 | 0 |
| 2010 | 51 | 418379 | 1850 | 6667 | 0 |
| 2011 | 51 | 467121 | 3310 | 7985 | 0 |
| 2012 | 51 | 439004 | 3573 | 7405 | 0 |
| 2013 | 51 | 456829 | 4025 | 7658 | 0 |
| 2014 | 51 | 425326 | 3552 | 7262 | 0 |
| 2015 | 51 | 396844 | 2697 | 6506 | 0 |
| 2016 | 51 | 437862 | 2736 | 6563 | 0 |
| 2017 | 51 | 407303 | 3029 | 6525 | 0 |
| 2018 | 51 | 395311 | 2598 | 6134 | 0 |
| 2019 | 50 | 373415 | 2362 | 6483 | 0 |
| 2020 | 51 | 353241 | 2278 | 6058 | 0 |
| 2021 | 50 | 384421 | 2466 | 6210.5 | 0 |
| 2022 | 51 | 386774 | 2877 | 6826 | 0 |
| 2023 | 49 | 384217 | 2439 | 6991 | 0 |

### Thin cells (N < 500)

None. Every state-year cell clears the threshold.

### Missing state-years

State-years with no estimate at all (state absent from that year's file):

| state_name | year |
| --- | --- |
| Alaska | 1990 |
| Arkansas | 1990 |
| Kansas | 1990 |
| Nevada | 1990 |
| New Jersey | 1990 |
| Wyoming | 1990 |
| Kansas | 1991 |
| Nevada | 1991 |
| Wyoming | 1991 |
| Arkansas | 1992 |
| Wyoming | 1992 |
| Wyoming | 1993 |
| Rhode Island | 1994 |
| District of Columbia | 1995 |
| Hawaii | 2004 |
| New Jersey | 2019 |
| Florida | 2021 |
| Kentucky | 2023 |
| Pennsylvania | 2023 |

## 2. Pre/post-2011 discontinuity

State-specific linear trends fit on 1999–2010, extrapolated to 2011–2013. `gap` is mean observed minus predicted prevalence.

| n_states | mean_gap | sd_gap | min_gap | max_gap | share_pos |
| --- | --- | --- | --- | --- | --- |
| 51 | -0.0201 | 0.0108 | -0.0413 | 0.0073 | 0.0196 |

One-sample t-test of mean gap = 0: t = -13.29, p = 4.9e-18.

Interpretation: the SD of the gap relative to its mean is what distinguishes a common break from a state-specific one. An SD comparable to or larger than the mean means the break is not a uniform additive shift.

**This statistic does not identify the design break on its own.** It compares observed post-2011 values against a *linear* extrapolation of the 1999–2010 trend, so it absorbs any curvature in the underlying series along with the methodology change. If true prevalence growth was decelerating before 2011, a linear fit over-predicts and part of the measured gap is that deceleration, not the cell-phone/raking switch. Nothing in the BRFSS data separates the two: 2011 changed the frame and the weighting simultaneously, with no overlap sample. Read the gap as an upper bound on the design effect, not an estimate of it.

### Gap by state

| state_name | n_pre | slope_pre | gap |
| --- | --- | --- | --- |
| Connecticut | 12 | 0.0062 |  0.0073 |
| District of Columbia | 12 | 0.0023 | -0.0020 |
| Arkansas | 12 | 0.0093 | -0.0031 |
| Iowa | 12 | 0.0075 | -0.0039 |
| Rhode Island | 12 | 0.0082 | -0.0046 |
| Idaho | 12 | 0.0072 | -0.0057 |
| Maine | 12 | 0.0081 | -0.0061 |
| Vermont | 12 | 0.0064 | -0.0062 |
| Indiana | 12 | 0.0082 | -0.0086 |
| Virginia | 12 | 0.0073 | -0.0092 |
| Oregon | 12 | 0.0063 | -0.0104 |
| Wisconsin | 12 | 0.0081 | -0.0106 |
| Louisiana | 12 | 0.0098 | -0.0116 |
| Colorado | 12 | 0.0063 | -0.0119 |
| Utah | 12 | 0.0062 | -0.0119 |
| North Dakota | 12 | 0.0079 | -0.0124 |
| West Virginia | 12 | 0.0087 | -0.0146 |
| New Mexico | 12 | 0.0080 | -0.0151 |
| Nebraska | 12 | 0.0078 | -0.0161 |
| Michigan | 12 | 0.0083 | -0.0164 |
| Pennsylvania | 12 | 0.0082 | -0.0180 |
| New Jersey | 12 | 0.0071 | -0.0191 |
| Massachusetts | 12 | 0.0076 | -0.0193 |
| Alaska | 12 | 0.0062 | -0.0196 |
| Illinois | 12 | 0.0078 | -0.0202 |
| Montana | 12 | 0.0084 | -0.0211 |
| Kansas | 12 | 0.0100 | -0.0238 |
| Maryland | 12 | 0.0093 | -0.0239 |
| California | 12 | 0.0058 | -0.0244 |
| Ohio | 12 | 0.0092 | -0.0255 |
| Texas | 12 | 0.0082 | -0.0257 |
| Washington | 12 | 0.0087 | -0.0257 |
| Wyoming | 12 | 0.0085 | -0.0262 |
| New Hampshire | 12 | 0.0103 | -0.0262 |
| Nevada | 12 | 0.0084 | -0.0270 |
| Georgia | 12 | 0.0083 | -0.0277 |
| Kentucky | 12 | 0.0097 | -0.0279 |
| North Carolina | 12 | 0.0086 | -0.0281 |
| Florida | 12 | 0.0090 | -0.0291 |
| Hawaii | 11 | 0.0080 | -0.0293 |
| Delaware | 12 | 0.0109 | -0.0301 |
| Missouri | 12 | 0.0095 | -0.0305 |
| Mississippi | 12 | 0.0110 | -0.0309 |
| Oklahoma | 12 | 0.0119 | -0.0319 |
| South Dakota | 12 | 0.0098 | -0.0319 |
| Alabama | 12 | 0.0097 | -0.0322 |
| South Carolina | 12 | 0.0104 | -0.0322 |
| New York | 12 | 0.0075 | -0.0325 |
| Arizona | 12 | 0.0105 | -0.0351 |
| Minnesota | 12 | 0.0087 | -0.0357 |
| Tennessee | 12 | 0.0109 | -0.0413 |

## 3. Cross-state distribution moments by year

Moments are computed across states within each year, unweighted by state population (each state is one observation).

| year | n_states | mean | sd | skewness | exc_kurt | iqr |
| --- | --- | --- | --- | --- | --- | --- |
| 1990 | 45 | 0.1123 | 0.0178 | 0.1928 | 0.1795 | 0.0181 |
| 1991 | 48 | 0.1201 | 0.0211 | 0.0294 | -0.9855 | 0.029 |
| 1992 | 49 | 0.1249 | 0.02 | 0.3498 | 0.2768 | 0.022 |
| 1993 | 50 | 0.1331 | 0.0221 | 0.2203 | -0.8151 | 0.0363 |
| 1994 | 50 | 0.1413 | 0.0195 | 0.2639 | -0.293 | 0.029 |
| 1995 | 50 | 0.1504 | 0.0225 | -0.0866 | -0.6327 | 0.0314 |
| 1996 | 51 | 0.1575 | 0.0223 | -0.2753 | -0.4406 | 0.0361 |
| 1997 | 51 | 0.1621 | 0.0226 | 0.239 | -0.3621 | 0.0339 |
| 1998 | 51 | 0.1757 | 0.0245 | -0.0056 | -0.8984 | 0.0411 |
| 1999 | 51 | 0.1856 | 0.0266 | -0.3946 | -0.3431 | 0.0349 |
| 2000 | 51 | 0.1954 | 0.0237 | -0.2131 | -0.5588 | 0.0348 |
| 2001 | 51 | 0.211 | 0.024 | -0.0373 | -0.3002 | 0.0326 |
| 2002 | 51 | 0.2178 | 0.0272 | 0.0321 | -0.8783 | 0.0441 |
| 2003 | 51 | 0.2243 | 0.0283 | -0.2087 | -0.2819 | 0.0434 |
| 2004 | 50 | 0.2316 | 0.0266 | 0.0016 | -0.0848 | 0.0353 |
| 2005 | 51 | 0.2452 | 0.0304 | 0.1892 | -0.4914 | 0.0447 |
| 2006 | 51 | 0.2507 | 0.0292 | 0.0447 | -0.4011 | 0.04 |
| 2007 | 51 | 0.2621 | 0.0288 | -0.22 | -0.4627 | 0.0382 |
| 2008 | 51 | 0.2663 | 0.0303 | -0.0503 | -0.2648 | 0.0387 |
| 2009 | 51 | 0.2725 | 0.0351 | -0.046 | -0.3078 | 0.0488 |
| 2010 | 51 | 0.276 | 0.0326 | 0.0798 | -0.9817 | 0.0498 |
| 2011 | 51 | 0.2744 | 0.0303 | 0.0644 | -0.3724 | 0.0437 |
| 2012 | 51 | 0.2782 | 0.0334 | 0.1452 | -0.4934 | 0.043 |
| 2013 | 51 | 0.2845 | 0.0342 | -0.0885 | -0.6857 | 0.047 |
| 2014 | 51 | 0.2903 | 0.0339 | -0.3042 | -0.0245 | 0.0409 |
| 2015 | 51 | 0.2898 | 0.0378 | -0.2129 | -0.4857 | 0.0509 |
| 2016 | 51 | 0.2958 | 0.037 | 0.0309 | -0.5663 | 0.0473 |
| 2017 | 51 | 0.3039 | 0.0384 | -0.1324 | -0.7208 | 0.052 |
| 2018 | 51 | 0.3108 | 0.0387 | 0.0434 | -0.6218 | 0.0582 |
| 2019 | 50 | 0.318 | 0.0397 | -0.1742 | -0.4449 | 0.0544 |
| 2020 | 51 | 0.3183 | 0.0408 | -0.1529 | -0.7541 | 0.0649 |
| 2021 | 50 | 0.332 | 0.0409 | -0.2536 | -0.5687 | 0.0534 |
| 2022 | 51 | 0.3352 | 0.0403 | -0.4133 | -0.3973 | 0.0607 |
| 2023 | 49 | 0.3335 | 0.0412 | -0.3748 | -0.417 | 0.0528 |

A stable SD alongside a rising mean is the signature of a common additive shift; a rising SD means states are diverging.

## 4. Change on baseline prevalence, by regime

OLS of (final − baseline) prevalence on baseline prevalence, within regime, heteroskedasticity-robust (HC1) standard errors. A negative slope indicates convergence.

| regime | years | n_states | intercept | slope | se_robust | t_stat | p_value | r_squared |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pre-2011 | 1990-2010 | 45 | 0.1561 | 0.0793 | 0.3418 | 0.2319 | 0.8177 | 0.0028 |
| post-2011 | 2011-2023 | 49 | 0.0038 | 0.2047 | 0.0865 | 2.3661 | 0.0222 | 0.1039 |

## 5. BMI item nonresponse by year

Share of eligible adult records in panel states with no usable BMI (`pct_bmi_missing`), and share whose BMI falls outside the [12, 60] plausibility window (`pct_implausible`). BMI is the pipeline's own computed BMI, not CDC's `_BMI*`, so this is the loss the panel actually takes.

| year | n_eligible | pct_bmi_missing | pct_implausible | age_selection_yr |
| --- | --- | --- | --- | --- |
| 1990 | 80178 | 2.55 | 0.01 | -0.12 |
| 1991 | 86296 | 2.74 | 0.01 | -0.13 |
| 1992 | 94496 | 2.89 | 0.02 | -0.11 |
| 1993 | 100534 | 2.8 | 0.03 | -0.07 |
| 1994 | 104237 | 3.24 | 0.02 | -0.08 |
| 1995 | 112057 | 3.09 | 0.03 | -0.08 |
| 1996 | 120373 | 3.77 | 0.03 | -0.07 |
| 1997 | 131176 | 3.42 | 0.02 | -0.07 |
| 1998 | 144583 | 3.74 | 0.03 | -0.06 |
| 1999 | 154209 | 3.64 | 0.05 | -0.05 |
| 2000 | 177103 | 4.21 | 0.05 | -0.02 |
| 2001 | 200758 | 4.6 | 0.05 | -0.01 |
| 2002 | 236260 | 4.47 | 0.06 | 0.02 |
| 2003 | 252921 | 4.56 | 0.06 | 0.03 |
| 2004 | 292029 | 4.46 | 0.09 | 0.02 |
| 2005 | 344047 | 4.35 | 0.1 | 0.07 |
| 2006 | 341545 | 4.57 | 0.11 | 0.06 |
| 2007 | 416985 | 4.3 | 0.11 | 0.06 |
| 2008 | 400466 | 4.2 | 0.12 | 0.04 |
| 2009 | 418358 | 4.28 | 0.11 | 0.06 |
| 2010 | 438417 | 4.45 | 0.12 | 0.06 |
| 2011 | 489995 | 4.54 | 0.13 | 0.04 |
| 2012 | 460030 | 4.45 | 0.12 | 0.02 |
| 2013 | 480894 | 4.85 | 0.15 | 0.03 |
| 2014 | 453740 | 6.13 | 0.13 | 0.07 |
| 2015 | 432004 | 7.79 | 0.35 | 0.08 |
| 2016 | 475205 | 7.71 | 0.14 | 0.08 |
| 2017 | 441491 | 7.6 | 0.14 | 0.08 |
| 2018 | 428584 | 7.57 | 0.19 | 0.08 |
| 2019 | 407743 | 8.24 | 0.17 | 0.09 |
| 2020 | 392726 | 9.88 | 0.17 | 0.09 |
| 2021 | 429307 | 10.26 | 0.2 | 0.06 |
| 2022 | 433564 | 10.59 | 0.2 | 0.16 |
| 2023 | 423018 | 8.95 | 0.22 | 0.09 |

A rising nonresponse rate is a comparability threat separate from the 2011 design break. If the people who decline to give height and weight differ systematically from those who do, measured prevalence moves even when true prevalence does not. Nothing in this pipeline corrects for it; the series is reported as constructed.

`age_selection_yr` sizes that selection on the one characteristic the panel measures: mean age among records that survive the BMI screen, minus mean age among all eligible adults. It bounds how much the screen reshapes the sample's age composition — and therefore how much of `mean_age` is selection rather than demography.

The largest such gap in the series is **0.16 years** (2022, where 10.6% of eligible adults are lost). Age selection is therefore small in absolute terms even where nonresponse is worst — which bounds this threat for age, and says nothing about selection on weight, which is unobservable for exactly the people who declined to report it.

## 6. The other panel measures

Cross-state summary of the panel's remaining measures: `xs_*` is the unweighted mean across states within a year, `xs_sd_*` its cross-state SD. Every measure is estimated on the same analytic sample as `prev_obese`, so these describe the same respondents.

| year | n_states | xs_bmi | xs_sd_bmi | xs_height_in | xs_weight_kg | xs_age | xs_sd_age |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1990 | 45 | 24.899 | 0.306 | 67.199 | 72.888 | 43.507 | 1.66 |
| 1991 | 48 | 25.032 | 0.334 | 67.232 | 73.352 | 43.633 | 1.424 |
| 1992 | 49 | 25.182 | 0.342 | 67.262 | 73.855 | 43.687 | 1.31 |
| 1993 | 50 | 25.321 | 0.319 | 67.239 | 74.214 | 44.069 | 1.396 |
| 1994 | 50 | 25.455 | 0.329 | 67.304 | 74.757 | 44.038 | 1.374 |
| 1995 | 50 | 25.619 | 0.326 | 67.297 | 75.238 | 44.614 | 1.27 |
| 1996 | 51 | 25.735 | 0.319 | 67.285 | 75.519 | 44.986 | 1.167 |
| 1997 | 51 | 25.822 | 0.311 | 67.287 | 75.781 | 45.103 | 1.127 |
| 1998 | 51 | 26.032 | 0.371 | 67.309 | 76.443 | 45.282 | 1.079 |
| 1999 | 51 | 26.208 | 0.391 | 67.313 | 76.972 | 45.433 | 1.085 |
| 2000 | 51 | 26.356 | 0.352 | 67.364 | 77.514 | 45.427 | 1.003 |
| 2001 | 51 | 26.594 | 0.364 | 67.349 | 78.175 | 45.613 | 0.982 |
| 2002 | 51 | 26.682 | 0.387 | 67.352 | 78.468 | 45.377 | 1.194 |
| 2003 | 51 | 26.777 | 0.414 | 67.372 | 78.771 | 45.859 | 1.175 |
| 2004 | 50 | 26.887 | 0.394 | 67.386 | 79.121 | 45.695 | 1.125 |
| 2005 | 51 | 27.089 | 0.425 | 67.323 | 79.567 | 45.94 | 1.142 |
| 2006 | 51 | 27.168 | 0.427 | 67.339 | 79.836 | 46.045 | 1.115 |
| 2007 | 51 | 27.353 | 0.425 | 67.33 | 80.356 | 46.442 | 1.099 |
| 2008 | 51 | 27.386 | 0.46 | 67.349 | 80.503 | 46.364 | 1.083 |
| 2009 | 51 | 27.491 | 0.512 | 67.37 | 80.857 | 46.672 | 1.194 |
| 2010 | 51 | 27.539 | 0.486 | 67.371 | 81.009 | 47.135 | 1.338 |
| 2011 | 51 | 27.548 | 0.466 | 67.268 | 80.749 | 46.663 | 1.133 |
| 2012 | 51 | 27.587 | 0.527 | 67.238 | 80.787 | 46.982 | 1.166 |
| 2013 | 51 | 27.678 | 0.537 | 67.232 | 81.033 | 47.159 | 1.127 |
| 2014 | 51 | 27.769 | 0.521 | 67.224 | 81.279 | 47.334 | 1.162 |
| 2015 | 51 | 27.792 | 0.572 | 67.238 | 81.375 | 47.451 | 1.188 |
| 2016 | 51 | 27.864 | 0.563 | 67.266 | 81.651 | 47.527 | 1.192 |
| 2017 | 51 | 28 | 0.591 | 67.253 | 82.011 | 47.698 | 1.25 |
| 2018 | 51 | 28.089 | 0.583 | 67.257 | 82.253 | 47.86 | 1.255 |
| 2019 | 50 | 28.203 | 0.601 | 67.271 | 82.628 | 48.02 | 1.257 |
| 2020 | 51 | 28.19 | 0.617 | 67.279 | 82.608 | 48.161 | 1.244 |
| 2021 | 50 | 28.413 | 0.629 | 67.291 | 83.275 | 48.272 | 1.176 |
| 2022 | 51 | 28.465 | 0.629 | 67.245 | 83.315 | 48.579 | 1.289 |
| 2023 | 49 | 28.446 | 0.641 | 67.243 | 83.259 | 48.704 | 1.43 |

**These break where prevalence does.** Mean BMI, height, weight and age all cross the 2011 design change described in §2, and none is any more spliceable across it than prevalence is.

**Mean age carries a second break, at 2013.** CDC stops shipping raw `AGE` after 2012 and ships only `_AGE80`, which is collapsed above 80. The panel top-codes age at 80 in *every* year so the two sources are on one scale (`DECISIONS.md` §16), but `_AGE80` is also imputed for non-responders while raw `AGE` was not, and that residual difference is not removed. Treat a level shift in `xs_age` at 2013 as a measurement change first.

## 7. Shape of the BMI distribution

Read from `data/cleaned/state_bmi_percentiles.csv`. Each figure is the unweighted mean across states of that state's weighted BMI percentile, so each state counts once.

| year | n_states | p10 | p50 | p90 | p95 | p90_p10 | p50_p10 | p90_p50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1990 | 45 | 19.99 | 24.3 | 30.41 | 32.83 | 10.42 | 4.31 | 6.11 |
| 1991 | 48 | 20.04 | 24.43 | 30.64 | 33.13 | 10.6 | 4.39 | 6.21 |
| 1992 | 49 | 20.12 | 24.57 | 30.85 | 33.46 | 10.73 | 4.44 | 6.29 |
| 1993 | 50 | 20.23 | 24.73 | 31.05 | 33.66 | 10.82 | 4.5 | 6.32 |
| 1994 | 50 | 20.26 | 24.82 | 31.29 | 33.9 | 11.03 | 4.56 | 6.47 |
| 1995 | 50 | 20.33 | 24.98 | 31.55 | 34.17 | 11.22 | 4.66 | 6.56 |
| 1996 | 51 | 20.42 | 25.02 | 31.83 | 34.56 | 11.41 | 4.61 | 6.8 |
| 1997 | 51 | 20.44 | 25.18 | 31.89 | 34.48 | 11.46 | 4.74 | 6.72 |
| 1998 | 51 | 20.53 | 25.3 | 32.36 | 35.28 | 11.83 | 4.77 | 7.06 |
| 1999 | 51 | 20.63 | 25.51 | 32.54 | 35.45 | 11.91 | 4.89 | 7.03 |
| 2000 | 51 | 20.7 | 25.56 | 32.84 | 35.84 | 12.14 | 4.87 | 7.28 |
| 2001 | 51 | 20.79 | 25.8 | 33.25 | 36.33 | 12.46 | 5.01 | 7.45 |
| 2002 | 51 | 20.85 | 25.88 | 33.41 | 36.5 | 12.57 | 5.04 | 7.53 |
| 2003 | 51 | 20.89 | 25.95 | 33.59 | 36.78 | 12.71 | 5.06 | 7.65 |
| 2004 | 50 | 20.92 | 26.05 | 33.78 | 36.96 | 12.86 | 5.13 | 7.73 |
| 2005 | 51 | 20.99 | 26.23 | 34.16 | 37.41 | 13.18 | 5.24 | 7.93 |
| 2006 | 51 | 21.03 | 26.28 | 34.31 | 37.63 | 13.28 | 5.25 | 8.03 |
| 2007 | 51 | 21.11 | 26.5 | 34.6 | 37.95 | 13.5 | 5.39 | 8.11 |
| 2008 | 51 | 21.06 | 26.5 | 34.74 | 38.06 | 13.68 | 5.43 | 8.24 |
| 2009 | 51 | 21.09 | 26.6 | 34.92 | 38.38 | 13.82 | 5.51 | 8.31 |
| 2010 | 51 | 21.16 | 26.63 | 35.02 | 38.38 | 13.86 | 5.47 | 8.39 |
| 2011 | 51 | 21.05 | 26.59 | 35.22 | 38.74 | 14.17 | 5.54 | 8.63 |
| 2012 | 51 | 21.08 | 26.63 | 35.26 | 38.75 | 14.18 | 5.56 | 8.63 |
| 2013 | 51 | 21.07 | 26.72 | 35.42 | 38.95 | 14.35 | 5.65 | 8.7 |
| 2014 | 51 | 21.14 | 26.78 | 35.61 | 39.17 | 14.47 | 5.63 | 8.84 |
| 2015 | 51 | 21.17 | 26.81 | 35.61 | 39.24 | 14.44 | 5.64 | 8.8 |
| 2016 | 51 | 21.19 | 26.9 | 35.75 | 39.29 | 14.56 | 5.71 | 8.85 |
| 2017 | 51 | 21.23 | 26.99 | 36.06 | 39.58 | 14.83 | 5.76 | 9.07 |
| 2018 | 51 | 21.23 | 27.06 | 36.23 | 39.82 | 15 | 5.82 | 9.17 |
| 2019 | 50 | 21.27 | 27.16 | 36.44 | 40.17 | 15.17 | 5.89 | 9.28 |
| 2020 | 51 | 21.29 | 27.15 | 36.38 | 39.98 | 15.09 | 5.86 | 9.23 |
| 2021 | 50 | 21.35 | 27.37 | 36.86 | 40.56 | 15.51 | 6.02 | 9.49 |
| 2022 | 51 | 21.35 | 27.41 | 36.96 | 40.68 | 15.61 | 6.06 | 9.55 |
| 2023 | 49 | 21.33 | 27.39 | 36.94 | 40.66 | 15.61 | 6.06 | 9.55 |

**Why this table exists.** Obesity prevalence is the mass above a single cut (BMI 30), so it cannot distinguish a uniform rightward shift of the whole distribution from a stretch concentrated in the upper tail — the two imply very different things about what changed, and can trace out the same prevalence path.

`p50_p10` against `p90_p50` is the discriminating comparison. Under a pure location shift both are flat over time and only the levels move. If `p90_p50` widens while `p50_p10` does not, the distribution is stretching upward and the gain is concentrated among the already-heaviest — which prevalence alone would not reveal.

Across 1990–2023 the mean p50 moves +3.09 BMI units and the mean p90 moves +6.53; `p50_p10` changes +1.75 while `p90_p50` changes +3.44. **These endpoints sit on opposite sides of the 2011 design break, so read this as description, not as an estimated change** — see §2.

Percentiles carry **no design-based standard error** — see `DECISIONS.md` §18 for why, and treat cells with small `n_unweighted` accordingly.

---

Estimates are survey-weighted throughout (`svydesign` + `svyby`/`svymean`, `survey.lonely.psu = "adjust"`). Construction decisions are documented in `DECISIONS.md`; the 2011 comparability break is documented there and in §2 above.
