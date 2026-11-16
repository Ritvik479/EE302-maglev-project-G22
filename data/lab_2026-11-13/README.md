# Lab session 2026-11-13 (group 22): first levitation, experiments A–C, afternoon sweeps and holds

Contents: morning first levitation (s06) → experiments A, B, C (s07) → afternoon sweeps, 11.5 mm holds (s08).
Where an early number was later revised, the earlier line says so and points to the newer one.

Model: `my_cascade_rt` (copy of `my_pd_rt`, red block replaced by the cascade controller from
`scripts/s05_cascade_design.m`). Ball: 39.288 g. Stand at ~11.9 mm. T0 = 3 ms.
Gains: Kc 2.05, Kp 151.2, Kd 2.6, Ki 734 (integral clamp ±0.3 A), i0 0.75 A, 1/ka = 1/2.44, u limited to 0..0.9.
Analysis: `scripts/s06_analyze_cascade_run.m` → `figs/p3_lab_run3.png`, `figs/p3_lab_run4.png`, `run34_metrics.mat`.

## screenshots/
01 top level of `my_cascade_rt` · 02 inside the Cascade controller block (wiring checked: correct).

## runs/  (read with load(file,'-mat'); openfig fails on the laptop)
| File | What | Result |
|---|---|---|
| `cascade_run1.fig` | Step 1, i_test 0.3 | **Rig power supply was OFF**: u followed the control law, i stayed at the 0.05 A sensor offset |
| `cascade_run2.fig` | u held at 0.9 for 16 s | Same: power off. Kept only for the record |
| `cascade_run3.fig` | Step 1, inner loop, i_test 0.3 → 0.5 A, ball on stand | i = 0.294 / 0.497 A, 63 % in 2 samples (6 ms) vs 27 ms open coil. Current noise std 0.03 A |
| `cascade_run4.fig` | Step 2, levitation: x_ref 11 mm, switch on at 3.6 s; x_ref → 10 mm at 14.4 s | **Levitated.** Lift-off 45 ms after switch-on, highest point 8.9 mm, within ±0.25 mm in 0.6 s. Step 11→10 mm: overshoot 1.12 mm (sim 0.94 mm), within ±0.25 mm in 0.13 s. Hover std 0.07 mm (broad 4-7 Hz wobble), zero mean error. Hover current 0.898 A at 11 mm, 0.830 A at 10 mm |

## Findings (first levitation; both bullets SUPERSEDED by the s07 analysis below)
- [Superseded: two-point, constant-offset estimate. Final: λ = 5.81 mm (s07), 5.90 mm (s08, all data).] The two hover points give a force decay length λ = 6.3 mm (raw) / 6.0 mm (after removing the 0.05 A sensor offset),
  close to the manual's P2 = 5.82 mm. The manual model predicts 0.845 A at 10 mm (measured 0.83 raw / 0.78 corrected).
  So the 2026-11-12 inference "λ > 8.25 mm" (from lift thresholds on the stand) was wrong: lift-off from the stand is
  not a clean static equilibrium.
- [Superseded: explained by the current-sensor zero drift, s07. The true current does not drift.] Hover current at 10 mm drifts 0.830 → 0.817 A over 15 s while u/i rises (coil warming?). Small.

## Experiments A, B, C (analysis: `scripts/s07_analyze_experiments.m` → `figs/p4_*.png`, `exp_ABC_results.mat`; all checks PASS)
Models: A, B = `my_cascade_rt`; C = `my_cascade_kg_rt` (Product × Constant `kg` before the u limit, kg logged on the i_ref scope).
No log sheet was received; set points were rebuilt from the data.

| File | What | Result |
|---|---|---|
| `expA_39g_sweep_{main,iref}.fig` | 39 g, set point 11→10.5→10→9.5→(9)→…→11.5 mm | Held every level. At 37.2 s **i_ref went to 0 in one sample** → ball dropped to the stand; re-lifted at 42.4 s to 9.5 mm. Consistent with a mistyped set point (> 14.9 mm, e.g. 0.09), then 0.0095. **9.0 mm was never done with this ball.** At 11.5 mm: slow ±0.33 mm swing at 2.4 Hz (only 2 s recorded) |
| `expB_42g_step{1,2}_{main,iref}.fig` | 42 g, 11 → 10 mm | Run 1: ball rested at 12.13 mm (others 11.90–11.92) and **turned over** after lift-off: irregular swing, reading 8.7–12.3 mm, for ~3.5 s, never lost (s07 printed "2.3 Hz" from zero crossings; that estimator proved unreliable on irregular motion in s08, so no frequency is claimed). It then hovered exactly like run 2 (0.975/0.902 A vs 0.971/0.897 A at 11/10 mm). Run 2: normal |
| `expB_42g_sweep_{main,iref}.fig` | 42 g, 11→…→9→…→11→**10.5** mm (ended at 10.5, not 11.5) | Held every level 9–11 mm |
| `expC_39g_kg_{main,iref}.fig` | 39 g at 10 mm, kg 1→0.8→0.6→0.5→0.4→1→1.25→1.5→2→1 | **Stable at every kg.** Jitter std 0.05–0.064 mm for kg 0.6–2, 0.073 at 0.5, 0.121 at 0.4 (model, noise only: 0.118 at 0.4). Linear model (fitted plant, **d = 0**): stable for 0.28 < kg < 3.76 (with the measured delay d 0.5: 0.292–3.95, s11) |

### Findings
- **Current-sensor zero drifts** while levitating: the reading at u = 0 fell 0.0405 -> 0.0102 A (Exp A, 61 s) and 0.0405 -> -0.0012 A (Exp C, 59 s), mean -0.52 mA/s. This is why the hover current at a fixed gap reads 10-40 mA lower later in a run (the true current is unchanged; the integral absorbs it). Correcting each visit for the drift cuts the repeat-visit scatter from 12.0 to 4.8 mA rms. Stand reading drifted only -0.03 to -0.08 mm. Exp B sweep and B step 1 stopped recording at switch-off, so they use the mean drift rate. **Tip: keep recording ~3 s after switching to Control 0.**
- Force law (18 drift-corrected hover visits; 39 g at 11.5 mm excluded: one 2 s rocking visit): **lambda = 5.81 mm (manual 5.82)** [2026-11-16: the combined s08 fit, λ 5.90 mm, is the reference value; λ is known to ±0.15 mm (systematic, current-zero model), so "5.81 vs 5.82" is agreement within that, not to 0.01 mm; see `data/README.md`, reference values], c = 3.37 (39 g) / 3.16 (42 g) N/A^2 (manual P1/P2 = 3.01), residual 4.9 mA rms. True hover current, 39 g at 10 mm: 0.800 A (manual model 0.845 A, +5.6 %). The 42 g ball needs 6.9 % more current than the 39 g ball (mass alone: 3.6 %). (An earlier version of this analysis gave lambda = 6.24 mm: constant offset, 11.5 mm point included. Superseded.)
- Sim vs lab, 16 steps of 0.5 mm: overshoot 0.25–0.71 mm (lab) vs 0.40–0.75 (sim), rms difference 0.16 mm; settling ~100 ms in both. Down-steps to 11 mm overshoot LESS in the lab (0.41, 0.25 mm) than in the sim (0.66, 0.75); the afternoon shows the same pattern (s08).
- Hover jitter (0.05–0.09 mm) = sensor-noise floor: the noise-only simulation gives 0.067–0.076 mm, and 0.066 of it comes from the current-sensor noise (σ 0.021 A) through Kc. Lowering Kc does not help (simulated: same jitter, worst Ms 1.66 → 8.3 at Kc 1.0).
- Unmodelled mode: a ~2.4 Hz swing (ball turning over, 11.5 mm wobble) that the vertical model (modes ≥ 6 Hz) does not contain. ~~Likely rocking/rotation of the non-spherical ball (supported by the afternoon Newton test, s08 6b).~~ **[Superseded 2026-11-16]** Rotation is not supported: the 11.5 mm rocking is tied to the stand (it vanished with the stand lowered), and a loss of sensor gain near the stand reproduces 2.4 Hz in the vertical loop; see data/lab_2026-11-16/README.md, 'Stand-proximity effect'.

## Afternoon: automatic set-point sweeps and 11.5 mm holds  (analysis: `scripts/s08_analyze_sweeps.m`, 21/21 PASS → `figs/p5_*.png`, `sweeps_holds_results.mat`)
Model: `my_cascade_sweep_rt` (Save As from `my_cascade_rt`). The sweep clock τ integrates (Forward Euler, 0.003 s) only while
x < 11.5 mm, so it starts at lift-off and pauses if the ball drops. τ drives a 1-D lookup table (Flat, Clip):
breakpoints [0 10 15 20 25 30 35 40 45] s → x_ref [11 10.5 10 9.5 9 9.5 10 10.5 11] mm. An auto/manual switch selects
this or the manual constant (0.011; set to 0.0115 for the holds). Logged on the i_ref scope: i, i_ref, x_ref, τ. Stop Time
90 s for the sweeps, 25 s for the holds. "Hole-up/hole-down" = the ball's hole faces the magnet / faces down. Original file
names are in brackets. "Rest" = position reading with the ball on the stand before switch-on → ≥ 1 s after switch-off.
All numbers below come from s08 and were re-checked with an independent scratch script (2026-11-13 evening).

| File | What | Result |
|---|---|---|
| `sweep_39g_holeup_{main,iref}` [sweep_39g_*] | 39 g, full sweep | Held all 9 levels, mean error within ±3.0 µm, x std 0.052–0.083 mm. **First time at 9 mm with the 39 g ball** (0.744 A raw). Raw hover current 0.900 / 0.822 A at 11 / 10 mm (first visits). Rest 11.925 → 11.915 mm. 12.8 s coil-off tail |
| `sweep_42g_holeup_{main,iref}` [sweep_42g_*] | 42 g, placed hole-up | **Rolled** after lift-off: irregular swings, x 9.76–11.80 mm, last > 0.5 mm excursion 2.6 s after lift, weaker sway to ~5 s; τ paused 0.45 s (as designed). Then held all 9 levels (mean error within ±2.5 µm). Rest 11.873 → 11.682 mm (= hole-down). 6.7 s tail |
| `sweep_42g_holedown_{main,iref}` [sweep_42g_*_second] | 42 g, placed hole-down | Held all 9 levels (mean error within ±3.2 µm). x std 0.028–0.031 mm at 11 mm, up to 0.092 mm at 9–10 mm; the 9 mm visit has weak 2–3 Hz content (flagged, see below). Rest 11.684 mm. Still levitating when the record ended (75 s): no tail, no drift measurement |
| `hold115_39g_holeup_{main,iref}` [hold115_39g_*] | 39 g, 11.5 mm hold | **Rocks**: steady ±0.37 mm (1st–99th percentile) at 2.45 Hz, std 0.252 mm, constant amplitude for the whole 16 s. Raw current 0.903 A. Rest 11.923 mm. No tail |
| `hold115_42g_holeup_{main,iref}` [hold115_42g_*] | 42 g, 11.5 mm hold | **Barely rocks**: the same ~2.4 Hz peak, 14× smaller in std (0.018 vs 0.253 mm; 19× in the 1.5–3.5 Hz band, 0.013 vs 0.250 mm). 2–3 Hz ringing of 0.05 mm rms in the first 2 s after lift, decaying to ~0.01 mm. No roll. Raw current 0.961 A. Rest 12.002 → 11.945 mm. 2.0 s tail. Its current zero at start was 0.014 A (others 0.034–0.039) |
| `hold115_39g_holedown_{main,iref}` | 39 g hole-down, 11.5 mm hold | Rocks, about half as much: ±0.23 mm at 2.31 Hz, std 0.135 mm. Raw current 0.919 A. Rest 12.176 → 12.047 mm (the seating changed during the run). 2.1 s tail |
| `liftoff_39g_SUSPECT_{main,iref}` [liftoff_low_*] | 39 g, meant to be a lift-off from a LOWERED stand | **SUSPECT, excluded from all analysis.** Rest reading 12.004 mm: not meaningfully lower than the normal 11.92 (39 g hole-up), and it lies between the 39 g hole-up (11.92) and hole-down (12.05–12.18) readings, so the ball may also not have sat hole-up. For the record: lift 30 ms after switch-on, min x 8.89 mm, peak 1.27 A, u at 0.9, within ±0.25 mm after 0.26 s. **Redo** at the next lab slot with a rest reading ≥ 13 mm |

### screenshots/ (afternoon)
03 sweep model wiring (14:29) · 04/05 sweep table dialog (breakpoints; Algorithm = Flat, Clip) · 06 **unexplained** (the student
does not know what it was): scope with Control 0, I ≈ 0.06 A (sensor offset), x = 3.80 mm steady for ~8 s. Not used ·
07–09 final sweep model: top level, Cascade controller inside, solver (ode3, 0.003 s, Stop 90).

### Models (`models/`)
Only the **build caches** (`*.slxc`) were copied, not the editable `.slx` files (still on the lab PC in
`C:\Users\hp\Desktop\group_22`; to be fetched). The generated C code inside the caches confirms the deployed parameters. All
three cascade models: Kp 151.2, Ki 734, Kd 2.6, Kc 2.05, i0 0.75 A, 1/ka = 1/2.44, u 0..0.9, i_ref 0..2 A, integral clamp
±0.3 A; `kg` (default 1) inside the controller subsystem; sweep clock = Forward Euler. Driver: Saturation Position 0..0.02 m.
`group22_sensor.mat` = the sensor calibration used for every build (33 points).

### Findings (s08, verified)
- **Sweep machinery** verified from the logs: x_ref = table(τ) at every sample; τ starts 1 sample after x < 11.5 mm and
  advances by exactly T0 whenever x < 11.5 mm (100 % of samples). **Sign check:** regressing the logged i_ref on
  e = x − x_ref and v gives Kp = +151.6, Kd = +2.53 (design +151.2, +2.60).
- **Validated range 9–11 mm for both balls:** 27/27 plateaus held, mean error within ±3.2 µm, x std 0.028–0.092 mm.
- **Prediction test:** the MORNING force law (s07), never fitted at 39 g / 9 mm, predicts the afternoon true hover currents
  within 10.2 mA rms (39 g at 9 mm: 0.728 measured vs 0.734 A predicted).
- **Combined force law** (18 morning + 24 afternoon visits): λ = 5.90 mm (morning 5.81, manual 5.82), c = 3.29 / 3.02 N/A²
  (39 / 42 g), residual 5.9 mA rms. The 42 g ball needs 8.1 % more current than the 39 g ball (mass alone: 3.6 %).
- **Current-sensor zero drift** −0.82 / −0.85 mA/s in the two long sweeps (morning mean −0.52). Hold-run values (2 s tails)
  are less reliable: −0.31 (42 g) and −0.64 mA/s (39 g hole-down).
- **Analysis choices made after a first FAIL** (documented in the script): (1) S42d has no tail, so it uses S42u's measured
  drift rate (same ball, run directly before) instead of the all-run mean. With the mean rate the two 42 g sweeps disagreed
  by 5–13 mA; with S42u's rate they agree within 2.4 mA. (2) Plateaus with 1.5–3.5 Hz band rms > 0.04 mm are flagged and
  kept out of the fit and the repeatability test: S39u visit 6 (9.5 mm), S42u visit 1 (11 mm, right after the roll), S42d
  visit 5 (9 mm). Their residuals are −2.1 / +6.1 / +4.1 mA, so including them changes little.
- **Steps, sim vs lab** (24 steps, morning-fitted plant, no re-tuning): overshoot rms difference 0.18 mm, settling median
  111 ms in both. Systematic: lab down-step overshoot FALLS as the gap grows (39 g: 0.63 → 0.56 → 0.49 → 0.32 mm for steps
  ending at 9.5 → 11 mm) while the sim's RISES (0.51 → 0.64). Largest gap on 10.5 → 11 mm (lab 0.25–0.32, sim 0.64–0.73);
  the morning data show the same. Partly explained by s13 (2026-11-15), see below.

## Down-step overshoot mismatch (s13, 2026-11-15; `scripts/s13_overshoot_mismatch.m` -> `figs/p10_overshoot_mismatch.png`, `data/overshoot_mismatch.mat`)
- With the measured delay (d = 0.5) the model is within 0.10 mm rms on 21 of 24 steps; the misfit is the three
  10.5 -> 11 mm steps (lab 0.25-0.32 mm, model 0.64-0.73).
- Rejected: linearization (s10); the sensor calibration table's kinks (33 points 0.7 mm apart, slope jumps <= 10 %).
  Checked by simulation: a smooth trajectory read through the table gives 0.04-0.20 m/s^2 of fake acceleration
  (estimator stride h = 10..3), <= 7 % of the spike at the same h. Assumes linear interpolation: the manual's
  "Position scaling" block (Fig. 8) is "1-D linear interpolation, Interpolation-Extrapolation"; the lab PC copy is
  still to be opened (1 min).
- Newton test per step: on all three 10.5 -> 11 steps (2 balls, both orientations) the measured ball brakes at
  1.8-2.0 m/s^2 (h = 5; 1.0-3.3 for h = 10..3, always 1.7-2.3x the worst control step) at 33-36 ms, at
  x = 10.93-11.03 mm, which the logged current cannot produce. Raw reading: it reverses 0.08 mm within 12 ms at ~11.1 mm.
  Steps that stay below 10.8 mm show nothing like it (worst -0.97, median -0.65 m/s^2 at h = 5).
  CAVEAT (verification): position (x = 11.0 mm) and timing (~35 ms after the step) are confounded, because all three
  steps are identical; the 42 g roll's passes through 11 mm cannot separate them (its residual is < -2 m/s^2 25 % of
  the time anyway).
- H-force (force decays more slowly than exp(-x/lam) beyond 11 mm): UNRESOLVED, conflicting evidence.
  * Static: hovering at 11.5 mm needs x1.04-1.08 the extrapolated force (3 holds; robust to the current-sensor zero,
    x1.04-1.09 for every plausible zero).
  * Dynamic (refinement, 2026-11-15): Newton solved for the force in all 13 lift-offs. Relative to each lift-off's own
    10.3-10.9 mm baseline, 11.4-11.8 mm gives x0.997 +- 0.011 (h = 3) / x0.959 +- 0.009 (h = 5): NO stronger force.
    No current-to-force lag (slope -0.8 ms). Coil-off falls were unusable (few samples, current collapsing).
  * WITHDRAWN: the 12.9 mm stand-lift bound (">= x1.20"). Lift thresholds from the stand are not a clean equilibrium
    (see "Findings (first levitation)" above), so they cannot bound the force law.
  * IF the holds are right (kf = 0.120 /mm vs the s07 plant), H-force halves the 10.5 -> 11 gap (0.42 -> 0.20 mm) and
    cuts rms(lab - model) 0.18 -> 0.11 mm. The slow ramp (lab test e) measures the quasi-static law directly.
- OPEN: the braking spike. Candidates: contact/braking by something near 11 mm, a sensor feature finer than the
  0.7 mm table, or ball tilt. Lab test (next slot, ~30 min): photo of stand vs ball at 11 mm; static sensor check
  10.2-12.6 mm in 0.1-0.2 mm steps; sweep with the stand lowered ~1 mm (spike moves with stand = contact); small steps
  10.8 -> 11.1 and 10.6 -> 11.0 mm (position vs timing; keep steps <= 0.5 mm, the stand is at ~11.9 mm); slow ramp
  10.5 -> 11.6 -> 10.5 mm (hysteresis = contact/friction; smooth curve = force law directly); open the lab PC's
  Position scaling block (confirm linear interpolation).
- `maglev_cascade_sim.m` got an optional force multiplier `opts.fx` (default unchanged; checked bit-identical).

## 2.4 Hz rocking: bounds (s14, 2026-11-15; `scripts/s14_rocking.m` -> `figs/p11_rocking.png`, `data/rocking.mat`)
- Frequency 2.3-2.5 Hz. Amplitude (1.5-3.5 Hz band of x, an upper bound): <= 0.051 mm rms in all 24 sweep plateaus at
  9-11 mm (both balls); at 11.5 mm 0.250 (39 g hole-up), 0.133 (39 g hole-down), 0.013 mm (42 g).
- Nature: 39 g hole-up at 11.5 mm is a limit cycle (envelope CV 0.04, no growth or decay); 42 g is a damped mode
  excited by noise (CV 0.56, ringing after lift decays with zeta ~ 0.07).
- The 2.4 Hz current is the controller's response to the measured x (154 A/m vs the controller's 151-152 A/m, phase
  within 6 deg), and the coil is the only power source, so the oscillation is sustained THROUGH the loop.
- Not a vertical-loop mode: the vertical model's slowest mode is >= 6.6 Hz (zeta >= 0.37) for a21 from 1661 down to
  200 1/s^2 and d 0.3-0.6. ~~Most likely a rotation of the ball (s08 Newton test); not observed directly.~~
  **[Superseded 2026-11-16]** This scan changed a21 only. With a position-sensor gain of 0.45-0.6 near the stand (the
  reading moving less than the ball), the vertical loop itself oscillates at 2.4-3.1 Hz, so a rotation is not needed;
  see data/lab_2026-11-16/README.md, 'Stand-proximity effect' (AUDIT.md 4.12).
- Robustness: a sustained oscillation at 11.5 mm needs a total relative loop error >= 1/|T| = 0.84 at 2.4 Hz; after
  the parametric spread (W ~ 0.55) the UNMODELLED part is >= 0.19, about the whole margin s11 leaves at 2.4 Hz
  (Wu 0.17-0.24). So the mode is not safely covered; 11.5 mm stays out of the claimed range, and its size at 9-11 mm
  must be measured: sine injection at u at 1.5, 2, 2.4, 3, 4 Hz (plus higher), 10 and 11 mm, both balls.
- s11 now also saves the per-region W, |T|, Wu curves (`RB.opt2curves`); its results are unchanged (12 PASS / 4 FAIL).
- **Re-run 2026-11-16 (11 PASS / 0 FAIL)** with three additions: (1) the same 39 g hold at 11.5 mm with the stand
  LOWERED (16-Nov): band rms 0.048 mm vs 0.250 mm on the normal stand, i.e. the rocking is tied to the stand, not the
  gap; (2) a stand "spring" (a21_eff 0 … −10 000 s⁻²) only moves the slowest mode UP (11–22 Hz); (3) a position-sensor
  gain s on the outer loop: s 0.6 / 0.5 / 0.45 / 0.4 gives an unstable mode at 3.07 / 2.64 / 2.44 / 2.25 Hz in the
  vertical loop itself. The "≥ 0.19 unmodelled error" figure above assumes an unstructured extra mode; for a sensor-gain
  loss it does not apply. See `data/lab_2026-11-16/README.md`, 'Stand-proximity effect'.

## Robustness over the uncertainty set (s11; numbers written here 2026-11-16, AUDIT.md 3.14)
Before 2026-11-16 these numbers existed only in the console ("12 PASS / 4 FAIL"). Re-run 2026-11-16, unchanged.
- **Set:** 1458 grid points = 2 balls × gap 9 / 10 / 11 mm × λ ±5 % × c ±5 % × coil τ 20 / 27 / 35 ms ×
  k_a 2.2 / 2.43 / 2.7 A/unit × extra delay d 0.3 / 0.5 / 0.6 sample. The actuator gain error kg 0.4–2.0 is **not**
  part of this set (see below).
- **Nominal** (39 g, 10 mm, d 0.5): Ms 1.59, stable gain range 0.292–3.95, phase margin 45.4°, delay margin
  5.3 ms (1.78 samples) on top of d. At d 0.3 / 0.6: Ms 1.41 / 1.71. (Ms = peak of |S| = |1/(1+L)|.)
- **Stability:** closed loop stable at **all 1458** grid points (eigenvalues).
- **Grid-worst margins:** Ms **2.23**, PM ≥ 29.3°, stable gain range at least [0.54, 2.23], delay margin ≥ 2.8 ms.
  The target **worst Ms ≤ 2**, declared before the run, is **NOT met**. The worst point is 39 g, 9 mm, λ +5 %, c +5 %,
  τ 20 ms, k_a 2.7, d 0.6 (fast coil, high gain, long delay). All 64 points with Ms > 2 are at d 0.6; at d 0.5 the
  worst is 1.97. The measured coil (τ ≈ 21–23 ms, s17) and delay (0.5–0.6) sit near this corner, so it cannot be
  argued away.
- **Between grid points** (multiplicative bound |W T| < 1, W = envelope of the grid plants + 10 %): one disk for the
  whole set fails (max 1.11); Option 1 (centred nominal) fails (1.25); **Option 2** (four ball × gap regions) passes:
  max |W T| 0.96 / 0.97 / 0.95 / **0.997** (39 g 9–10, 39 g 10–11, 42 g 9–10, 42 g 10–11 mm). W covers 400 random
  interior plants per region (|δ|/W ≤ 0.88). Options 1 and 2 were added after the one-disk test failed (disclosed in
  s11). So "guaranteed" means: proven at the grid points, and a sufficient bound between them that random sampling
  supports. It is strong evidence, not a proof.
- **Room left for unmodelled error** on top of the set (Option 2, worst region): 22 % below 2 Hz, **0 % at 2–10 Hz**,
  2 % at 10–30 Hz, 13 % at 30–166 Hz. The 2–10 Hz band holds the unstable pole (6.5 Hz) and the crossover region.
- **kg (Exp C) is a hardware gain-margin test, not part of the set.** The nominal model (d 0.5) is stable for
  kg 0.292–3.95, consistent with Exp C (stable at 0.4 and 2.0). With kg 0.4, 33 of the 243 grid points at 39 g / 10 mm
  are unstable (all τ 35 ms with k_a ≤ 2.43), so the real plant is not at those corners. Removing them from the set
  would not change the worst Ms (2.23 sits at τ 20 ms; checked 2026-11-16 from `robustness.mat`).
- **Measured** (sine injection 2026-11-16, s17): phase margin ≈ 47° (43–50° depending on which amplitude is used at
  20 Hz) vs model 45.4°; |S| 1.51 at 40 Hz vs model 1.58. The loop below 3 Hz and at the model's |S| peak (45 Hz) was
  not measured.

## Afternoon runs, further notes (s08, continued)
- **42 g roll (placed hole-up):** see the table. The rest reading after the run equals the hole-down reading within 0.002 mm.
  The 39 g and 42 g hole-down lift-offs were quiet after 0.6 s.
- **Rest reading as an orientation check: weaker than first thought.** 42 g hole-up rests read 11.87–12.00 mm across runs
  (0.13 mm spread), and hole-down 11.68 mm, so it does separate 42 g hole-up from hole-down. For the 39 g ball the shift goes
  the OTHER way (hole-up 11.92, hole-down 12.05–12.18). The reading depends on how the ball sits, not only on the hole.
- **Rocking at 11.5 mm:** the same ~2.4 Hz mode shows in both balls: 39 g hole-up 0.253 mm rms (steady limit cycle), 39 g
  hole-down 0.136 mm, 42 g 0.013 mm (band rms; 19× smaller than the 39 g band rms 0.250 mm, 14× in std). No sustained rocking at 9–11 mm in the sweeps (1.5–3.5 Hz band
  0.011–0.065 mm). The linearized vertical loop has no mode below 6.5 Hz **with the nominal sensor gain**~~, so the 2.4 Hz motion is not a vertical-loop mode~~ (superseded 2026-11-16, see the s14 section).
- **Newton test (s08 6b): the 2.4 Hz rocking is NOT pure up-down motion.** If the ball's centre moves as the sensor says, the
  force law fixes the current it needs: i_need = √(m (g − ẍ) e^{x/λ} / c). Slope of measured true current vs i_need:
  24 set-point steps (control) 1.03 (middle half 0.91–1.07, correlation 0.98), so for real vertical motion the sensor, the
  current and the force law agree. During the 39 g rocking: 1.74 (hole-up) and 1.72 (hole-down), correlation 0.98–0.99, so
  the coil pushes 1.7× harder than up-down motion of the measured size needs. Either the reading includes a tilt of the ball,
  or the force depends on the tilt. ~~Both mean a rotation is involved.~~ **[Superseded 2026-11-16]** A third reading
  needs no rotation: near the stand the sensor reading moves less than the ball (gain ≈ 1/1.7 ≈ 0.59), which gives the
  same slope; see data/lab_2026-11-16/README.md, 'Stand-proximity effect'. Model-based evidence, not a direct observation.
  The 10.5 → 11 mm down-steps also have low slopes (0.64–0.88), the same steps the sim overshoots most: maybe related.

## Loop delay from the existing data (s12, 2026-11-15; `scripts/s12_delay_estimate.m` → `figs/p9_delay.png`, `data/delay_estimate.mat`)
- The scope keeps every 3 ms sample, and u and i are logged in the same sample (the inner-loop law holds at lag 0 only,
  R² 0.9996), so a delay between logged u and logged i is a real loop delay.
- **Extra loop delay ≈ 0.5 sample (1.0–1.7 ms; d = 0.32–0.55 over methods and the τ/k_a range)**, beyond the normal
  one-sample ZOH step. Run 3 (inner loop alone): output-error fit best d = 0.55 (also 0.55 without the switch-on); the
  noise shaping PSD(loop on)/PSD(coil off) shows a resonance at ~65 Hz that only a fractional delay reproduces
  (d = 0.32–0.50). Both reject d = 0 AND d = 1. Cause not separable: computation time, PWM, or a current-sensor filter.
- The open-loop coil steps (2026-11-12) cannot discriminate: away from the nonlinear 0 → 0.2 step every d from 0 to
  0.75 fits within 0.5 %. They do not contradict the estimate.
- Nominal loop (39 g, 10 mm) with d = 0.55: Ms 1.65, gain range 0.293–3.57, phase margin 44°, delay margin 5.2 ms
  (d = 0: Ms 1.36, PM 59°; d = 1: Ms 2.41, PM 33°). **The nominal used everywhere since 2026-11-15 is d = 0.5**
  (range 0.3–0.6): there Ms 1.59, gain range 0.292–3.95, PM 45.4°, delay margin 5.3 ms (see the robustness section).
  The 16-Nov sine injection, taken while levitating, independently supports d ≈ 0.5–0.6 (s17).
- **Used in the models from 2026-11-15:** nominal d = 0.5, uncertainty range 0.3–0.6 sample (the measured 0.32–0.55
  rounded outward to tenths, so the Simulink model applies it exactly). `maglev_cases.m` reads it from
  `data/delay_estimate.mat`; s09, s10 and s11 were re-run with it. The earlier "0 / +1 sample" set is kept only as
  reference cases.
