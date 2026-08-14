# BRFSS state obesity panel — diagnostics

Generated 2026-08-14 from `data/cleaned/state_obesity_panel.csv`.
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

Share of adult records in panel states with no usable BMI (`pct_bmi_missing`), and share whose BMI falls outside the [12, 60] plausibility window (`pct_implausible`).

| year | n_eligible | pct_bmi_missing | pct_implausible |
| --- | --- | --- | --- |
| 1990 | 81154 | 2.57 | 0.01 |
| 1991 | 87364 | 2.75 | 0.01 |
| 1992 | 95662 | 2.92 | 0.02 |
| 1993 | 101782 | 2.83 | 0.03 |
| 1994 | 105447 | 3.25 | 0.02 |
| 1995 | 113450 | 3.1 | 0.03 |
| 1996 | 121762 | 3.78 | 0.03 |
| 1997 | 132624 | 3.43 | 0.02 |
| 1998 | 146336 | 3.77 | 0.03 |
| 1999 | 156095 | 3.66 | 0.05 |
| 2000 | 179139 | 4.24 | 0.05 |
| 2001 | 203021 | 4.62 | 0.05 |
| 2002 | 238852 | 4.49 | 0.06 |
| 2003 | 255657 | 4.58 | 0.06 |
| 2004 | 295027 | 4.48 | 0.09 |
| 2005 | 347278 | 4.38 | 0.1 |
| 2006 | 344487 | 4.58 | 0.11 |
| 2007 | 420217 | 4.31 | 0.11 |
| 2008 | 403191 | 4.2 | 0.12 |
| 2009 | 420968 | 4.28 | 0.11 |
| 2010 | 440788 | 4.45 | 0.13 |
| 2011 | 493064 | 5.15 | 0.11 |
| 2012 | 462810 | 5.03 | 0.1 |
| 2013 | 483865 | 5.45 | 0.13 |
| 2014 | 456158 | 6.64 | 0.12 |
| 2015 | 434382 | 8.3 | 0.33 |
| 2016 | 477665 | 8.2 | 0.12 |
| 2017 | 444023 | 8.14 | 0.12 |
| 2018 | 430949 | 8.1 | 0.16 |
| 2019 | 409810 | 8.72 | 0.15 |
| 2020 | 394831 | 10.38 | 0.15 |
| 2021 | 431639 | 10.76 | 0.17 |
| 2022 | 435826 | 11.08 | 0.17 |
| 2023 | 425106 | 9.43 | 0.18 |

A rising nonresponse rate is a comparability threat separate from the 2011 design break. If the people who decline to give height and weight differ systematically from those who do, measured prevalence moves even when true prevalence does not. Nothing in this pipeline corrects for it; the series is reported as constructed.

---

Estimates are survey-weighted throughout (`svydesign` + `svyby`/`svymean`, `survey.lonely.psu = "adjust"`). Construction decisions are documented in `DECISIONS.md`; the 2011 comparability break is documented there and in §2 above.
