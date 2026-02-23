## BSE Opinion Dynamics Experiments – Reproducible Pipeline and Report Guide

### Abstract
This project provides a BSE-based pipeline for experiments on opinion dynamics. Building on baseline work (DeGroot/HK), it extends to heterogeneous network topologies, policy stress testing, and PRDE–opinion fusion (OPRDE), forming a closed loop from opinions to strategies to prices. The pipeline delivers unified data, robust metrics (volatility/liquidity/inequality/efficiency), and publication-ready visualizations. Results quantify trade-offs between stability and liquidity, show how network/policy levers shift these trade-offs, and illustrate that OPRDE effects can be mixed (e.g., improved fairness but reduced price efficiency in some runs).

### Purpose
This repository contains this pipeline to study opinion–market interactions on the BSE, organized across five phases:
- Phase 0: Reproduce baseline experiments and establish a reliable data/metrics baseline
- Phase 1: Diagnose and fix anomalies (profit distribution “brushing” issues)
- Phase 2: Introduce heterogeneous opinion dynamics and network topology
- Phase 3: Policy toggles and external shocks for stress testing
- Phase 4: Fuse PRDE/PRZI with opinions (OPRDE) for a closed loop opinion ↔ strategy ↔ price


## Repository layout
- `src/`
  - `cli.py`: Canonical entrypoint (`python -m src.cli`) for running experiments and full phase presets
  - `runner.py`: Shared runner API used by all scripts (YAML → run → postprocess → metrics/figures)
  - `run_experiment.py`: Legacy CLI wrapper (kept for compatibility), calls `runner.py`
  - `pipeline/`
    - `postprocess.py`: Normalize BSE dumps to `trades.csv` and compute volatility, liquidity, spreads, depth, Gini, efficiency/stability
    - `compare.py`: Baseline/DeGroot/HK comparison; produces table-first outputs (`comparison.csv/.md`)
    - `policy_sweep.py`: Generate policy/shock grid of experiments and capture metrics
    - `policy_plots.py`: 2x3 policy dashboard (meltdown, fees, tick, pulse) + summary
    - `heatmaps.py`: Network × epsilon × tick panels; auto-switch to bar plots when epsilon is invariant
    - `compare_oprde.py`: Run matched PRDE-only vs OPRDE runs and produce PRDE↔OPRDE comparison tables/figures
    - `viz.py`: 2x3/2x4 single-experiment panels and small-multiples across experiments
  - `traders/`
    - `opinion_traders.py`: Opinion traders (DeGroot/HK), non-linear opinion→quote mapping
    - `opinion_przi.py`: OPRDE fusion (opinion state + PRDE/PRZI + attention from OFI/MLOFI)
  - `opinion/networks.py`: ER/WS/BA topologies, leaders, and model mixing (DeGroot/HK/FJ/RA/RD)
- `exp/`: YAML experiment configurations
- `outputs/phase{0..4}/raw/<exp_id>_*`: BSE dumps (tape, blotters, LOB, opinions, balances)
- `outputs/phase{0..4}/clean/<exp_id>/trades.csv`: unified trades
- `outputs/phase{0..4}/csv/`: per-experiment metrics, sweeps, comparisons
- `outputs/phase{0..4}/figs/`: figures (price paths, profit histograms, policy/OPRDE plots)
- `conf/requirements.txt`: dependencies
- `BSE_PATCHLOG.md`: minimal, necessary engine edits and reasons
- `PROJECT_CHANGES.md`: non-engine code changes and how they address supervisor feedback


## Environment and quick start
1) Create venv and install requirements

**Python requirement (important):** use **Python 3.12 (recommended)** or **Python 3.11**.
Python 3.13 may fail because some builds are missing `pickle.PickleBuffer`, which breaks `pandas`.

```
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r conf/requirements.txt
```

2) Run key experiments (new recommended CLI)

The canonical entrypoint is now `python -m src.cli`, which:
- runs a YAML end-to-end (engine → raw dumps → clean trades → metrics → standard figures)
- writes a reproducibility manifest for each run
- supports one-command phase presets


Run a whole phase preset:
```
python -m src.cli phase --name phase0
python -m src.cli phase --name phase1
python -m src.cli phase --name phase2
python -m src.cli phase --name phase3
python -m src.cli phase --name phase4
```

3) Opinion logging controls (to keep sweeps lightweight)

When `dump_opinions: true`, the engine logs:
- one aggregate row per integer second (`kind=agg`)
- one final per-trader snapshot at session end (`kind=trader`)

Optional YAML flags under `dumps:`:
- `dump_opinions_detail`: if `true`, also log per-trader snapshots periodically during the run
- `opinions_detail_every`: integer period (seconds) for periodic snapshots (default: 50)

## Documentation (what changed and why)
- **Engine edits**: `BSE_PATCHLOG.md`
- **All other code edits**: `PROJECT_CHANGES.md`


## Data protocol
- Unified trades schema: `time, price, bid, ask, spread, trade_qty`
- Example (first 5 rows from `baseline`):

```markdown
|   time |   price |   bid |   ask |   spread |   trade_qty |
|-------:|--------:|------:|------:|---------:|------------:|
|   8.1  |     146 |   nan |   nan |      nan |           1 |
|   9.05 |     164 |   nan |   nan |      nan |           1 |
|  10.1  |     143 |   nan |   nan |      nan |           1 |
|  11.15 |     155 |   nan |   nan |      nan |           1 |
|  17.55 |     145 |   nan |   nan |      nan |           1 |
```

- Metrics CSV (per experiment) includes volatility (std & annualized), liquidity counts, spreads/depth, inequality (Gini), stability/efficiency (max drawdown, Calmar, Sortino, EWMA vol, skew/kurt, RMSE-to-median, misprice duration), and polarization/consensus when opinions are enabled


## Visualization design
- Single-experiment basic figures: `outputs/phaseX/figs/<exp_id>_price_spread.png` and `..._profit_hist.png`
- Optional panels and small multiples: generated via `viz.py` (see functions within for usage)
- Network sweeps: per-network/cadence panels via `heatmaps.py`
  - If epsilon is invariant for a metric, a bar plot by tick replaces the heatmap
- Policy dashboard: generated via `policy_plots.py`
- Baseline comparison: tables (`outputs/phase0/csv/comparison.csv` and `.md`) are preferred in the report


## Metrics interpretation
| Metric           | Interpretation                                   |
|------------------|---------------------------------------------------|
| Volatility (std) | Price stability (lower = more stable)            |
| Liquidity        | Transactional efficiency (higher = better)       |
| Avg Spread       | Cost of immediacy (lower often better)           |
| Gini (balances)  | Profit inequality (higher = more unequal)        |
| Polarization     | Opinion fragmentation (higher = more polarized)  |
| RMSE-to-median   | Price efficiency error vs median                 |
| Impact rebound   | Shock recovery speed (lower = faster rebound)    |


## Phase 0 – Reproducible Baselines
### Aim
Reproduce baseline (ZIC+ZIP), DeGroot, and HK with fixed seeds and consistent parameters.

### Design
YAMLs: `exp/exp_baseline_seed{41,42,43}.yaml`, `exp/exp_degroot_seed{41,42,43}.yaml`, `exp/exp_hk_seed{41,42,43}.yaml`.
The runner executes each seed, normalizes `trades.csv`, computes metrics, and aggregates a mean comparison table via `src/pipeline/compare.py`.

### Results (from outputs/phase0/csv/comparison.csv)
Aggregated across seeds (mean over `seed41/42/43`):

```markdown
| exp_id   |   volatility_std |   liquidity_trades |   avg_spread |   gini_balance |
|:---------|-----------------:|-------------------:|-------------:|---------------:|
| baseline |         20.6168   |            4376.33 |     30.0275  |       0.127666 |
| degroot  |         32.0149   |            7309.67 |     48.1341  |       0.0722307|
| hk       |         31.9869   |            7306.33 |     48.0996  |       0.0732088|
```

Source: `outputs/phase0/csv/comparison.csv` (generated by `src/pipeline/compare.py`).

### Discussion
- Baseline → opinion models: both DeGroot and HK increase liquidity substantially, but also widen spreads and increase volatility relative to baseline.
- DeGroot vs HK: under these parameters, DeGroot/HK are very similar on the core market metrics (interpretation should focus on *why* they converge under the chosen setup).


## Phase 1 – Anomaly diagnosis (profit “brushing”)
### Aim
Explain and repair near-identical profit distributions.

### Design
- Enforce BSE quote-to-limit, tick rounding; non-linear opinion mapping with clipping; noise/private signals; quote-to-limit gap metrics.

### Results (before/after summary)
Summary from `outputs/phase1/csv/phase1_before_after.csv`:

```markdown
| exp_id     |   gini_balance |   profit_variance |   profit_std |
|:----------|---------------:|------------------:|-------------:|
| p1_before |            nan |           0       |      0       |
| p1_after  |       0.153747 |      265343.342   |    515.115   |
```

Note: `p1_before` has zero dispersion in end balances (all profits are 0), so Gini is undefined/NaN by construction.

### Discussion
- The “before” setup collapses to a degenerate outcome (no profit dispersion), which is useful as a diagnostic control.
- The “after” setup produces meaningful dispersion (non-zero variance/std, finite Gini), so distributional analysis becomes interpretable.


## Phase 2 – Heterogeneous opinions and networks
### Aim
Introduce ER/WS/BA topologies, model mixing (DeGroot/HK/FJ/RA/RD), leaders, and noise/private signals.

### Design
Sweeps across network × cadence × epsilon × tick. Adaptive visuals auto-switch to bars when epsilon is invariant for a metric.

### Results
Primary outputs:
- Full sweep table: `outputs/phase2/csv/sw_sweep.csv`
- Rankings: `outputs/phase2/csv/sw_ranked_polarize.csv`, `outputs/phase2/csv/sw_ranked_stable.csv`
- Opinion snapshot summary: `outputs/phase2/csv/opinion_snapshots_summary.csv`
- Figures: `outputs/phase2/figs_new/heatmap_panel_<network>_c<cadence>.png`

Top-3 by **stability score** (from `outputs/phase2/csv/sw_ranked_stable.csv`):

```markdown
| exp_id | network | leaders | epsilon | tick | cadence | volatility_std | liquidity_trades | avg_spread | pol_std | score_stable |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| ws_eps01_t1_c10_L2 | ws | 2 | 0.1 | 1 | 10 | 19.2636 | 3680 | 30.2403 | 0.158674 | 0.633333 |
| ws_eps03_t1_c10_L2 | ws | 2 | 0.3 | 1 | 10 | 19.2636 | 3680 | 30.2403 | 0.158674 | 0.633333 |
| ba_eps01_t1_c10_L0 | ba | 0 | 0.1 | 1 | 10 | 19.3878 | 3683 | 29.9301 | 0.162476 | 0.6125 |
```

Top-3 by **polarization score** (from `outputs/phase2/csv/sw_ranked_polarize.csv`):

```markdown
| exp_id | network | leaders | epsilon | tick | cadence | pol_std | pol_q90_gap | pol_entropy | volatility_std | liquidity_trades | score_polarize |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| er_eps01_t1_c10_L0 | er | 0 | 0.1 | 1 | 10 | 0.167387 | 0.559355 | 1.16565 | 19.8512 | 3704 | 0.758333 |
| er_eps01_t1_c10_L2 | er | 2 | 0.1 | 1 | 10 | 0.167387 | 0.559355 | 1.16565 | 19.8509 | 3704 | 0.758333 |
| er_eps03_t1_c10_L0 | er | 0 | 0.3 | 1 | 10 | 0.167387 | 0.559355 | 1.16565 | 19.8512 | 3704 | 0.758333 |
```

### Discussion
- In this sweep, `epsilon` has only two levels and other knobs are held fixed, so many outcomes are near-identical across `epsilon`.
- Polarization is now measurable (`pol_std`, `pol_entropy` in `sw_sweep.csv`), so Phase 2 can be used to rank configurations by “polarize” vs “stable” objectives.


## Phase 3 – Policy and shocks
### Aim
Stress test with circuit breakers, maker–taker fees, tick adjustments, supply/demand pulses, and news waves.

### Design
Policy toggles in YAML feed into engine (trade-time fee application, freeze windows, tick schedules, shocks). Dashboard summarizes effects.

### Results (top policy scores)
Top policies (from `outputs/phase3/csv/policy_effective_summary.csv`):

```markdown
| policy_tag                          |   policy_score |
|:------------------------------------|---------------:|
| md=off_fee=0_tk=1_pulse=2_wave=none |       0.898420 |
| md=off_fee=1_tk=1_pulse=2_wave=none |       0.898420 |
| md=off_fee=1_tk=2_pulse=2_wave=none |       0.854466 |
| md=off_fee=0_tk=2_pulse=2_wave=none |       0.854466 |
| md=off_fee=1_tk=2_pulse=2_wave=reverse |    0.838045 |
```

See also `outputs/phase3/csv/policy_deltas.csv` (Δ vs baseline) and `outputs/phase3/figs/policy_dashboard.png` (dashboard figure).

### Discussion
- Present a short table of Δvolatility/Δliquidity/Δspread vs base; discuss which policy best meets the objective (e.g., stability without crippling liquidity).


## Phase 4 – PRDE/OPRDE fusion
### Aim
Close the loop with opinion-driven PRDE and microstructure attention.

### Design
OPRDE mounts onto PRZI/PRDE; opinions mapped nonlinearly to `s`, attention derived from OFI/MLOFI; news added to LOB and `apply_exogenous`.

### Results (PRDE vs OPRDE side-by-side)
See:
- Per-tag PRDE vs OPRDE: `outputs/phase4/csv/panel_prde_oprde.csv`
- Aggregate summary (mean/std across reps): `outputs/phase4/csv/oprde_summary.csv`

Aggregate summary (from `outputs/phase4/csv/oprde_summary.csv`):

```markdown
| exp | volatility_std_mean | volatility_std_std | rmse_to_median_mean | rmse_to_median_std | gini_balance_mean | gini_balance_std | impact_rebound_t_mean | impact_rebound_t_std |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| OPRDE | 16.4312 | 0.459011 | 16.4286 | 0.458599 | 0.167942 | 0.00927696 | 1.64 | 2.27024 |
| PRDE | 15.8888 | 1.11047 | 15.897 | 1.09338 | 0.184157 | 0.0399214 | 1.07 | 0.435431 |
```

Top-3 tags by **fairness gain** (most negative \(\Delta\)Gini = OPRDE − PRDE), from `outputs/phase4/csv/panel_prde_oprde.csv`:

```markdown
| tag | prde_gini | oprde_gini | d_gini | prde_rmse_med | oprde_rmse_med | d_rmse | prde_vol | oprde_vol | d_vol | prde_impact_rebound_t | oprde_impact_rebound_t | d_rebound |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 0 | 0.25316 | 0.175507 | -0.0776523 | 14.0069 | 15.7776 | 1.77073 | 13.9683 | 15.7805 | 1.8122 | 1.52 | 5.7 | 4.18 |
| 1 | 0.18245 | 0.175094 | -0.0073554 | 16.6796 | 16.3404 | -0.339149 | 16.6849 | 16.3458 | -0.33911 | 0.98 | 0.62 | -0.36 |
| 2 | 0.165151 | 0.16398 | -0.00117085 | 15.9409 | 17.057 | 1.11615 | 15.9383 | 17.062 | 1.12366 | 0.66 | 0.68 | 0.02 |
```

### Discussion
- In the current run summary (`outputs/phase4/csv/oprde_summary.csv`), OPRDE shows **lower average Gini** (more equal outcomes) but **higher RMSE-to-median and higher volatility** than PRDE on average.
- Adaptation speed (`impact_rebound_t`) is mixed and shows higher variance for OPRDE in this batch.


## Notes
- Random seed: set in each YAML (`seed: 42` by default)
- BSE version: vendored `BSEv1_9_ALTR.py` with policy/shock hooks and OFI/MLOFI fields
- Minimal engine patches: see `BSE_PATCHLOG.md` for an explicit list of necessary modifications and reasons
- Data integrity: quote constraints and tick rounding enforced; unit consistency in plotting
- Tables over plots for definitive comparisons; plots for dynamics and distributions
