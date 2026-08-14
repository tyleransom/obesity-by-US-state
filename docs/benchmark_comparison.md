# Comparison against published BRFSS estimates

Generated 2026-08-14.

Benchmark: `data/reference/published_state_prevalence.csv`.

- **2000** — Mokdad et al. (2001), JAMA 286(10):1195-1200
- **2022** — CDC Adult Obesity Prevalence Maps (accessed 2024-08-23)

Both benchmarks are derived from the same BRFSS microdata this pipeline parses. Unlike the NHANES comparison in `validation.md`, a gap here is **not** explained by self-report bias — it is a difference in how the estimate was constructed. All figures are percentage points.

## 1. Level agreement

| year | n_states | mean_diff_pp | mean_abs_pp | max_abs_pp | pearson_r | spearman_r | pct_covered | median_abs_z | pct_same_sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2000 | 51 | 0.028 | 0.085 | 0.315 | 0.999 | 0.998 | 100 | 0.089 | 56.863 |
| 2022 | 51 | -0.239 | 0.239 | 0.402 | 1 | 1 | 100 | 0.306 | 100 |

`pct_covered` is the share of states whose published value falls inside this panel's 95% confidence interval. `median_abs_z` is the typical discrepancy measured in our own standard errors — values near or below 2 mean the differences are within sampling noise.

**2022 carries a systematic offset.** This panel runs 0.24 pp lower than the published series, and 100% of states share that sign. Each state individually sits well inside its own standard error (median |z| = 0.31), so the per-state intervals do not flag it — but a common sign across 51 states is not sampling noise. It is a difference in construction.

Candidate sources for a systematic offset, none of which are adjusted for here: this panel computes BMI from reported height and weight while CDC's published figures use the precomputed `_BMI*` (which rounds up to its stored precision — see `DECISIONS.md` §1a); the pregnancy exclusion (§5), which CDC's published figures do not consistently apply; the 18+ screen versus any age standardization (§4); or differing treatment of records with missing height or weight.

Note that the 2000 offset was **eliminated** by switching to computed BMI — it fell from +0.58 pp to +0.03 pp, and the share of states sharing its sign fell from 100% to near half, which is what sampling noise looks like. A residual offset in a later year is therefore unlikely to have the same cause, since the rounding bias is negligible once the stored precision reaches two decimals.

## 2. Rank agreement

| year | n_states | rank_cor | mean_abs_rank_d | max_rank_d | n_within_3 |
| --- | --- | --- | --- | --- | --- |
| 2000 | 51 | 0.998 | 0.588 | 3 | 51 |
| 2022 | 51 | 0.999 | 0.196 | 2 | 51 |

Rank agreement is reported separately because a uniform level offset leaves the cross-state ordering intact, and the ordering is what most analyses of this panel would use.

## 3. Threshold counts

| year | threshold | constructed | published | difference |
| --- | --- | --- | --- | --- |
| 2000 | ≥ 20% | 23 | 23 |  0 |
| 2022 | ≥ 35% | 20 | 22 | -2 |

Counts near a threshold are mechanically fragile: any state within a standard error of the cutoff flips on trivial construction differences.

**The 2022 count differs by -2, and these are the states responsible:**

| state_name | constructed_prev | constructed_se | published_prev | diff_pp |
| --- | --- | --- | --- | --- |
| Virginia | 34.91 | 0.71 | 35.2 | -0.29 |
| South Carolina | 34.86 | 0.71 | 35.0 | -0.14 |

Every one of these sits within 0.20 pp of the 35% cutoff and differs from the published value by less than its own standard error. The count difference is a boundary effect, not a disagreement about prevalence.

## 4.1 Largest discrepancies, 2000

| state_name | constructed_prev | constructed_se | published_prev | diff_pp | z | covered |
| --- | --- | --- | --- | --- | --- | --- |
| Arizona | 19.12 | 1.53 | 18.8 |  0.32 |  0.21 | TRUE |
| Virginia | 17.76 | 0.99 | 17.5 |  0.26 |  0.26 | TRUE |
| Rhode Island | 16.98 | 0.73 | 16.8 |  0.18 |  0.24 | TRUE |
| New Jersey | 17.78 | 0.76 | 17.6 |  0.18 |  0.23 | TRUE |
| Alaska | 20.67 | 1.28 | 20.5 |  0.17 |  0.13 | TRUE |
| Georgia | 20.74 | 0.81 | 20.9 | -0.16 | -0.20 | TRUE |
| Wyoming | 17.75 | 0.91 | 17.6 |  0.15 |  0.17 | TRUE |
| Iowa | 20.94 | 0.83 | 20.8 |  0.14 |  0.17 | TRUE |
| Kansas | 20.23 | 0.72 | 20.1 |  0.13 |  0.19 | TRUE |
| Connecticut | 17.03 | 0.72 | 16.9 |  0.13 |  0.18 | TRUE |

## 4.2 Largest discrepancies, 2022

| state_name | constructed_prev | constructed_se | published_prev | diff_pp | z | covered |
| --- | --- | --- | --- | --- | --- | --- |
| Maine | 32.70 | 0.68 | 33.1 | -0.40 | -0.59 | TRUE |
| Kentucky | 37.34 | 1.11 | 37.7 | -0.36 | -0.33 | TRUE |
| Indiana | 37.34 | 0.65 | 37.7 | -0.36 | -0.55 | TRUE |
| Louisiana | 39.76 | 0.91 | 40.1 | -0.34 | -0.38 | TRUE |
| Nevada | 33.16 | 1.30 | 33.5 | -0.34 | -0.26 | TRUE |
| Oklahoma | 39.67 | 0.81 | 40.0 | -0.33 | -0.41 | TRUE |
| Iowa | 37.07 | 0.69 | 37.4 | -0.33 | -0.47 | TRUE |
| West Virginia | 40.69 | 0.90 | 41.0 | -0.31 | -0.35 | TRUE |
| North Dakota | 35.09 | 0.94 | 35.4 | -0.31 | -0.33 | TRUE |
| Montana | 30.20 | 0.72 | 30.5 | -0.30 | -0.42 | TRUE |

## 5. Full comparison

### 2000

| state_name | constructed_prev | published_prev | diff_pp | covered |
| --- | --- | --- | --- | --- |
| Mississippi | 24.18 | 24.3 | -0.12 | TRUE |
| Alabama | 23.60 | 23.5 |  0.10 | TRUE |
| West Virginia | 22.85 | 22.8 |  0.05 | TRUE |
| Tennessee | 22.81 | 22.7 |  0.11 | TRUE |
| Louisiana | 22.75 | 22.8 | -0.05 | TRUE |
| Texas | 22.64 | 22.7 | -0.06 | TRUE |
| Arkansas | 22.48 | 22.6 | -0.12 | TRUE |
| Kentucky | 22.22 | 22.3 | -0.08 | TRUE |
| Michigan | 21.86 | 21.8 |  0.06 | TRUE |
| Missouri | 21.64 | 21.6 |  0.04 | TRUE |
| South Carolina | 21.50 | 21.5 |  0.00 | TRUE |
| Indiana | 21.29 | 21.3 | -0.01 | TRUE |
| North Carolina | 21.24 | 21.3 | -0.06 | TRUE |
| District of Columbia | 21.23 | 21.2 |  0.03 | TRUE |
| Oregon | 21.01 | 21.0 |  0.01 | TRUE |
| Iowa | 20.94 | 20.8 |  0.14 | TRUE |
| Ohio | 20.93 | 21.0 | -0.07 | TRUE |
| Illinois | 20.82 | 20.9 | -0.08 | TRUE |
| Georgia | 20.74 | 20.9 | -0.16 | TRUE |
| Pennsylvania | 20.70 | 20.7 |  0.00 | TRUE |
| Nebraska | 20.69 | 20.6 |  0.09 | TRUE |
| Alaska | 20.67 | 20.5 |  0.17 | TRUE |
| Kansas | 20.23 | 20.1 |  0.13 | TRUE |
| North Dakota | 19.84 | 19.8 |  0.04 | TRUE |
| Maine | 19.67 | 19.7 | -0.03 | TRUE |
| Maryland | 19.58 | 19.5 |  0.08 | TRUE |
| Wisconsin | 19.39 | 19.4 | -0.01 | TRUE |
| South Dakota | 19.28 | 19.2 |  0.08 | TRUE |
| California | 19.13 | 19.2 | -0.07 | TRUE |
| Arizona | 19.12 | 18.8 |  0.32 | TRUE |
| Oklahoma | 18.94 | 19.0 | -0.06 | TRUE |
| New Mexico | 18.70 | 18.8 | -0.10 | TRUE |
| Idaho | 18.46 | 18.4 |  0.06 | TRUE |
| Washington | 18.44 | 18.5 | -0.06 | TRUE |
| Utah | 18.43 | 18.5 | -0.07 | TRUE |
| Florida | 18.16 | 18.1 |  0.06 | TRUE |
| New Jersey | 17.78 | 17.6 |  0.18 | TRUE |
| Virginia | 17.76 | 17.5 |  0.26 | TRUE |
| Wyoming | 17.75 | 17.6 |  0.15 | TRUE |
| Vermont | 17.64 | 17.7 | -0.06 | TRUE |
| New York | 17.27 | 17.2 |  0.07 | TRUE |
| New Hampshire | 17.17 | 17.1 |  0.07 | TRUE |
| Nevada | 17.17 | 17.2 | -0.03 | TRUE |
| Connecticut | 17.03 | 16.9 |  0.13 | TRUE |
| Rhode Island | 16.98 | 16.8 |  0.18 | TRUE |
| Minnesota | 16.91 | 16.8 |  0.11 | TRUE |
| Massachusetts | 16.35 | 16.4 | -0.05 | TRUE |
| Delaware | 16.28 | 16.2 |  0.08 | TRUE |
| Montana | 15.27 | 15.2 |  0.07 | TRUE |
| Hawaii | 15.10 | 15.1 |  0.00 | TRUE |
| Colorado | 13.71 | 13.8 | -0.09 | TRUE |

### 2022

| state_name | constructed_prev | published_prev | diff_pp | covered |
| --- | --- | --- | --- | --- |
| West Virginia | 40.69 | 41.0 | -0.31 | TRUE |
| Louisiana | 39.76 | 40.1 | -0.34 | TRUE |
| Oklahoma | 39.67 | 40.0 | -0.33 | TRUE |
| Mississippi | 39.30 | 39.5 | -0.20 | TRUE |
| Tennessee | 38.66 | 38.9 | -0.24 | TRUE |
| Alabama | 38.08 | 38.3 | -0.22 | TRUE |
| Ohio | 37.82 | 38.1 | -0.28 | TRUE |
| Delaware | 37.71 | 37.9 | -0.19 | TRUE |
| Wisconsin | 37.46 | 37.7 | -0.24 | TRUE |
| Indiana | 37.34 | 37.7 | -0.36 | TRUE |
| Kentucky | 37.34 | 37.7 | -0.36 | TRUE |
| Arkansas | 37.14 | 37.4 | -0.26 | TRUE |
| Iowa | 37.07 | 37.4 | -0.33 | TRUE |
| Georgia | 36.73 | 37.0 | -0.27 | TRUE |
| South Dakota | 36.64 | 36.8 | -0.16 | TRUE |
| Missouri | 36.11 | 36.4 | -0.29 | TRUE |
| Kansas | 35.41 | 35.7 | -0.29 | TRUE |
| Texas | 35.31 | 35.5 | -0.19 | TRUE |
| North Dakota | 35.09 | 35.4 | -0.31 | TRUE |
| Nebraska | 35.01 | 35.3 | -0.29 | TRUE |
| Virginia | 34.91 | 35.2 | -0.29 | TRUE |
| South Carolina | 34.86 | 35.0 | -0.14 | TRUE |
| Michigan | 34.20 | 34.5 | -0.30 | TRUE |
| Wyoming | 34.08 | 34.3 | -0.22 | TRUE |
| North Carolina | 33.91 | 34.1 | -0.19 | TRUE |
| Minnesota | 33.39 | 33.6 | -0.21 | TRUE |
| Pennsylvania | 33.25 | 33.4 | -0.15 | TRUE |
| Illinois | 33.17 | 33.4 | -0.23 | TRUE |
| Nevada | 33.16 | 33.5 | -0.34 | TRUE |
| Arizona | 33.01 | 33.2 | -0.19 | TRUE |
| Maryland | 33.00 | 33.2 | -0.20 | TRUE |
| Idaho | 32.91 | 33.2 | -0.29 | TRUE |
| Maine | 32.70 | 33.1 | -0.40 | TRUE |
| New Mexico | 32.27 | 32.4 | -0.13 | TRUE |
| Alaska | 32.01 | 32.1 | -0.09 | TRUE |
| Washington | 31.45 | 31.7 | -0.25 | TRUE |
| Florida | 31.32 | 31.6 | -0.28 | TRUE |
| Utah | 30.92 | 31.1 | -0.18 | TRUE |
| Oregon | 30.74 | 30.9 | -0.16 | TRUE |
| Rhode Island | 30.66 | 30.8 | -0.14 | TRUE |
| Connecticut | 30.37 | 30.6 | -0.23 | TRUE |
| Montana | 30.20 | 30.5 | -0.30 | TRUE |
| New Hampshire | 30.10 | 30.2 | -0.10 | TRUE |
| New York | 29.93 | 30.1 | -0.17 | TRUE |
| New Jersey | 28.89 | 29.1 | -0.21 | TRUE |
| California | 27.88 | 28.1 | -0.22 | TRUE |
| Massachusetts | 26.94 | 27.2 | -0.26 | TRUE |
| Vermont | 26.52 | 26.8 | -0.28 | TRUE |
| Hawaii | 25.74 | 25.9 | -0.16 | TRUE |
| Colorado | 24.88 | 25.0 | -0.12 | TRUE |
| District of Columbia | 24.02 | 24.3 | -0.28 | TRUE |

---

No estimate has been adjusted to match the benchmark.
