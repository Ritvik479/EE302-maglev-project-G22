# data/

## Lab sessions (raw measurements, never edited)
| Folder | Contents |
|---|---|
| `lab_2026-11-12/` | Discovery of the lab models (`discovery/*.txt`), PD runs and coil step test (`runs/*.fig`), screenshots, `unusable/` (empty or 1-sample logs, kept for the record). See its README |
| `lab_2026-11-13/` | First levitation, experiments A/B/C, automatic sweeps, 11.5 mm holds (`runs/*.fig`), screenshots. See its README |
| `lab_2026-11-16/` | Small steps, slow ramp, sine injection, lowered-stand sweep, variant D (`runs/*.fig`), screenshots. See its README |

Every run `.fig` is read with `scripts/read_scope_fig.m`.

## Reference values for the report (one value per quantity; 2026-11-16, AUDIT.md 6A)
Several quantities appear with different values in different files, each right for the fit, day or definition it
came from. For the report use these. Details and evidence are in the session READMEs and `AUDIT.md`.

| Quantity | Use | Notes |
|---|---|---|
| Command u | PWM duty fraction 0..1 | Not volts (the scope says [V]). The manual model's u is in volts; the two are not comparable |
| Force law | F = c i² e^(−x/λ), **λ = 5.90 ± 0.15 mm**, c = 3.29 / 3.02 N/A² (39 / 42 g) | s08 fit, 42 hover points at 9–11 mm. The ±0.15 mm is systematic (current-sensor zero model). s07's morning fit (λ 5.81, c 3.37 / 3.16) differs by 1.6 % in λ. Holds out of sample on 16-Nov within ~1 % (≥ 0.8 mm above the stand) |
| "The model" | s08 plant for robustness, Simulink cases, s18 | Overshoot comparisons (s08 §4, s13, s16, s17) use the s07 plant; say so when quoting them |
| Coil static gain k_a | **2.43 A/unit** (plant); 2.44 = the controller's feed-forward constant | 1.9 near u = 0. "2.4–2.6" was a ratio I/u that includes the current zero |
| Coil time constant τ | **measured 22–25 ms**; model nominal 27 ms (design value); uncertainty range 20–35 ms | Steps with the ball on the stand 22.5–25 ms; sine injection 22.6 ms (d 0.5) / 20.5 ms (d 0.6); 25–29 ms only with the ball at the magnet |
| Extra loop delay d | **0.5 sample** (range 0.3–0.6) | s12 inner-loop step fit 0.55 / spectral 0.50 (ball on the stand); sine injection while levitating: 0.5–0.6 |
| Sensor noise | x 0.011 mm, i **0.021 A** (std) | 0.018 A in older text is stale |
| Current-sensor zero | 0.03–0.06 A at the start of a session, falling 0.3–1.2 mA per second of coil-on time | Reached −0.02 A on 16-Nov. Measure with u = 0 before and after each run |
| Operating range | set points **9–11 mm**, both balls, stand reading ≥ ~0.85 mm below the set point | 11.5 mm on the normal stand excluded; transients within ~0.8 mm of the stand are outside the model |
| Nominal points | controller designed for i0 = 0.75 A (≈ 9.2 mm, s05); analysis nominal 39 g at **10 mm** (s10, s11, cases, sine); manual comparison 9 mm (s01/s02) | Three different "nominals", each for its purpose |
| Lift-off time | two definitions: "x < rest − 0.2 mm" (s06, s18) and "sweep clock started", i.e. x < 11.5 mm (12.0 mm lowered stand) (s09, s16, s17) | Compare times only within one definition |
| Step overshoot sim vs lab | s13 metric (33 ms running mean, d 0.5, s07 plant): within 0.10 mm on 21 of 24 steps | s07 "0.16 mm rms" (raw lab x), s08 "0.18 mm rms", s09 "0.14 mm rms" (39 g sweep only) use other definitions or subsets. Overshoot is 100–130 % of the step, a property of the design |
| Nominal margins | 39 g, 10 mm, d 0.5: Ms 1.59, PM 45.4°, gain range 0.292–3.95, delay margin 5.3 ms | Values at d 0.55 (13-Nov delay section) are superseded |
| Robust margins | see 13-Nov README, "Robustness over the uncertainty set" | Worst Ms 2.23 (target 2 missed), Option-2 |W T| 0.997 |
| Stand-proximity effect | onset ~0.7–0.8 mm above the stand; braking spike 0.67–0.89 mm above it | Size varies steeply with distance and between days; quote the onset |

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
s13's text was revised the same day (H-force rejected, spike stand-tied; numbers unchanged). Still open from s13:
re-doing its lift-off force check binned by height above the stand (`FIXPLAN.md` step 10). `rocking.mat` gained
`bLow`, `SP`, `SG`.
