# data/

## Lab sessions (raw measurements, never edited)
| Folder | Contents |
|---|---|
| `lab_2026-11-12/` | Discovery of the lab models (`discovery/*.txt`), PD runs and coil step test (`runs/*.fig`), screenshots, `unusable/` (empty or 1-sample logs, kept for the record). See its README |
| `lab_2026-11-13/` | First levitation, experiments A/B/C, automatic sweeps, 11.5 mm holds (`runs/*.fig`), screenshots. See its README |
| `lab_2026-11-16/` | Small steps, slow ramp, sine injection, lowered-stand sweep, variant D (`runs/*.fig`), screenshots. See its README |

Every run `.fig` is read with `scripts/read_scope_fig.m`.

## Derived results (written by the scripts; regenerate by re-running the script)
The scripts load these by path, so they stay here.

| File | Written by | Contents |
|---|---|---|
| `phase1_results.mat` | `s01_verify_model.m` | manual model verification |
| `phase2_results.mat` | `s02_plant_analysis.m` | plant analysis, PD scenarios |
| `phase3_cascade.mat` | `s05_cascade_design.m` | cascade controller design (C, L) |
| `lab_2026-11-13/run34_metrics.mat` | `s06_analyze_cascade_run.m` | first-levitation metrics |
| `lab_2026-11-13/exp_ABC_results.mat` | `s07_analyze_experiments.m` | s07 plant fit (lam, c, ka, sensor noise, current zero) |
| `lab_2026-11-13/sweeps_holds_results.mat` | `s08_analyze_sweeps.m` | combined force fit, step table, holds, lift-offs |
| `sim_cases_results.mat` | `s09_sim_models.m` | Simulink case results (lab controller and variant D) |
| `linear_model.mat` | `s10_linear_model.m` | linear model and uncertainty table |
| `robustness.mat` | `s11_robustness.m` | robustness results (|WT|, margins, per-region curves) |
| `delay_estimate.mat` | `s12_delay_estimate.m` | measured extra loop delay |
| `overshoot_mismatch.mat` | `s13_overshoot_mismatch.m` | overshoot-mismatch analysis |
| `rocking.mat` | `s14_rocking.m` | 2.4 Hz rocking analysis |

Note (2026-11-16): s14 was re-checked after the audit (stand-lowered hold, stand-spring and sensor-gain scans; 11/0).
s13 still predates the stand-proximity finding in `lab_2026-11-16/README.md`: its H-force and "position vs timing"
conclusions are superseded there (see `FIXPLAN.md` steps 9-10). `rocking.mat` gained `bLow`, `SP`, `SG`.
