## Project change log

For engine-only edits, see `BSE_PATCHLOG.md`.

---

### A) Reproducibility & runnability

#### A1) Added a stable runner API and CLI
- **Files**: `src/runner.py`, `src/cli.py`, `src/phase_presets.py`
- **What changed**:
  - Introduced `run_experiment()` as a single end-to-end entrypoint (YAML → run → postprocess → metrics/figures).
  - Added `python -m src.cli run ...` for running a single YAML.
  - Added `python -m src.cli phase --name phaseX` presets to run complete phases.
- **Addresses feedback**:
  - **Utility/reproducibility**: makes the project clearly runnable and auditable.
  - **Clarity**: reduces “confusion” by standardizing execution.

#### A2) Backwards-compatible legacy entrypoint
- **Files**: `src/run_experiment.py`
- **What changed**: kept the file, but made it call the new runner API internally.
- **Why**: preserves existing workflow while converging on one stable implementation.
- **Addresses**: **Runnability / clarity**

#### A3) Added Makefile shortcuts
- **Files**: `Makefile`
- **What changed**: `make phase0`, `make phase3`, `make run CFG=...`
- **Why**: fastest “human-friendly” way to run phases without remembering CLI arguments.
- **Addresses**: **Utility / presentation**

#### A4) Run manifest for each experiment
- **Files**: `src/runner.py` (writes `*_run_manifest.json`)
- **What changed**: each run writes a reproducibility manifest including config hash and output locations.
- **Why**: supports strict reproducibility claims and makes it easy to locate inputs/outputs.
- **Addresses**:
  - **Utility**
  - **Report clarity** (“where to find outputs / how to reproduce”)

---

### B) Environment robustness (avoid “it works on my machine”)

#### B1) Added runtime compatibility checks
- **Files**: `src/env_check.py`, wired in `src/cli.py`, documented in `README.md`
- **What changed**: fail fast with an actionable message when Python is incompatible (e.g., Python 3.13 builds missing `pickle.PickleBuffer` which breaks pandas).
- **Reason**: prevents confusing stack traces and makes setup deterministic.
- **Addresses**:
  - **Techniques/tools deployed effectively**: makes dependency/tooling predictable.

---

### C) Evidence chain improvements (metrics, logs, parsing)

#### C1) Robust parsing of opinions/quotes logs (new + legacy formats)
- **Files**: `src/pipeline/postprocess.py`
- **What changed**:
  - Added `load_opinion_log()` and `load_quotes_log()` that can parse both the new structured CSV format and legacy tokenized logs.
  - Polarization and consensus and quote-limit gap metrics now depend on these loaders.
- **Why**:
  - Avoids silent “all NaN / all 0.0” metrics caused by fragile string parsing.
- **Addresses**:
  - **Critical interpretation / evaluation design**: ensures metrics are actually computed from data.
  - **Report clarity**: reduces the chance of describing figures that don’t match underlying data.

#### C2) Added diagnostic signatures for “identical results”
- **Files**: `src/pipeline/postprocess.py`, `src/pipeline/compare.py`
- **What changed**:
  - Added `returns_hist_sha256` and `profit_hist_sha256` to metrics.
  - `compare.py` writes warnings into `comparison.md` if DeGroot and HK have identical signatures.
- **Why**:
  - If results are identical, it must be explained (parameter degeneracy, model collapse, etc.).
- **Addresses**:
  - **Supervisor example**: “DeGroot and HK identical copies” → now automatically flagged.
  - **Evaluation design**: makes anomalies explicit.

---

### D) Phase-specific scripts updated to use the runner API

#### D1) Sweeps no longer spawn subprocesses
- **Files**: `src/pipeline/sweep.py`, `src/pipeline/policy_sweep.py`, `src/pipeline/compare_oprde.py`
- **What changed**: replaced `subprocess.run(['python', ...])` with direct `run_experiment(...)`.
- **Why**:
  - Cleaner error handling, consistent environment, faster debugging.
- **Addresses**:
  - **Techniques/tools**: “deployed more effectively”

#### D2) Optional dependency made optional (statsmodels)
- **Files**: `src/pipeline/compare_oprde.py`
- **What changed**: `statsmodels` import is now inside a `try`, Granger analysis is skipped if unavailable.
- **Why**: prevents Phase 4 from failing due to an optional analysis dependency.
- **Addresses**: **Runnability**

---

### E) Visualization alignment with canonical output layout

#### E1) Fixed `viz.py` to use `outputs/phaseX/...` layout
- **Files**: `src/pipeline/viz.py`
- **What changed**: removed references to legacy `data/` and `reports/` paths; now reads from canonical `outputs/<phase>/...`.
- **Why**: avoids “figure references don’t match produced files”.
- **Addresses**:
  - **Report presentation / clarity**: consistent file naming and location.


