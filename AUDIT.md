# AUDIT — EE302 MagLev project (INTECO MLS1EM USB2)

Reviewer audit, done in stages. Nothing in `scripts/`, `data/`, `models/` or the READMEs was edited; proposed fixes
are listed here for the author to decide on. Classes: **CRITICAL** = a conclusion is wrong or unsupported;
**MAJOR** = a number/method error that changes a stated value; **MINOR** = cosmetic, wording, unclear documentation;
**OK** = checked and correct.

Scratch work (independent recomputations, script re-runs) lives outside the repo in the session scratch folder
(`indep_stage1.py`, `pd_grid.py`, `cmp_mat.m`, `run_s01_s02.log`).

---

## Stage 1 (2026-11-16) — Foundations

Scope: `maglev_params.m`, `scripts/maglev_plant.m`, `scripts/maglev_equilibrium.m`, `scripts/s01_verify_model.m`,
`scripts/s02_plant_analysis.m`, `manual/PS9.pdf`, `manual/mls1em_usb2_um.pdf`, figs `p1_*`, `p2_*`.

### How it was checked
1. Read all five files in full; extracted the text of both PDFs (`pdftotext`) and rendered manual pp. 34–38 as images
   (Figs. 42–46), with a 300-dpi zoom of Fig. 42.
2. Ran s01 and s02 with MATLAB R2026a on a **copy** of the project in the scratch folder (running them in the repo
   would overwrite `data/phase1_results.mat`, `data/phase2_results.mat` and five figures).
   Result: s01 **36/36 PASS**, s02 **39/39 PASS**.
3. Compared the re-run `.mat` files with the repo's: the test values in `phase1_results.mat` and
   `phase2_results.mat` are **identical** (`isequal` true; sweep x30 max difference 0). Repo files date from
   2026-11-11 and are current with the code.
4. Independent recomputation in **Python** (written from the manual formulas, not from the scripts): all equilibria,
   linearization entries, headroom numbers and the five s02 "regression" closed-loop pole values.
5. Grepped s03–s18 for uses of the Stage-1 objects (`P.loop`, `P.act`, `maglev_plant`, `phase1/2_results`).

### PS9 requirements and deliverables (from `manual/PS9.pdf`, read in full)
Requirements:
- **R1** Modelling and linearization: operating point, linearized model, assumptions, **operating range** over which
  the model applies. (PS9 gives no gap range; "hardware frame" is not defined — the range must be chosen and justified.)
- **R2** Uncertainty: bounded parameter variations + unmodelled dynamics, ranges **justified by system info or
  measured data**.
- **R3** Controller design: robust law accommodating equilibrium shifts and uncertainty; explain approach and the
  stability/robustness criteria; structure chosen and justified by the students.
- **R4** Simulation and robustness verification in MATLAB/Simulink: model + uncertainty cases + controller; evaluate
  stability and **"guaranteed stability margins over the defined uncertainty range"**; document cases and results.
- **R5** Hardware: implement, demonstrate stable levitation, record response, **compare with simulation**.

Deliverables (6 bullets):
- **D1** Linearized operating model, assumptions, uncertainty characterization.
- **D2** MATLAB/Simulink models for **nominal and uncertain** system cases.
- **D3** Controller design rationale, implementation files, robustness/stability analysis.
- **D4** Simulation plots of response and stability under the specified uncertainty cases.
- **D5** Experimental demonstration, recorded data, simulation-vs-hardware comparison.
- **D6** Technical report and final presentation (methodology, results, limitations, conclusions).

Also binding (PS9 "Safety"): use approved actuator limits, verify sensor feedback and controller output before
enabling levitation, keep stop/override available, do not exceed apparatus limits.

Tentative map to repo evidence (to be verified in later stages): D1 → s01/s02 (manual model), s07/s08 (force fit),
s10; D2 → `build_maglev_cl_sim.m` / `maglev_cl_sim.slx`, s09; D3 → s05, s11; D4 → s09, s11; D5 → `data/lab_*`,
s06–s08, s16–s18; D6 → not in repo yet. Note for R4: the local install has **no Robust Control Toolbox**, so any
"guaranteed" margin claim must rest on an analytic argument (e.g. a |W T| bound), not on a grid alone — Stage 3.

### Findings

| # | File / claim | What I did | Result | Class |
|---|---|---|---|---|
| 1.1 | Nonlinear model in `maglev_equilibrium.m`: x2' = −Fem/m + g, x3' = (ki u + ci − x3)/fi, Fem = x3²(P1/P2)e^(−x1/P2) | Compared with manual p.33 equations | Identical | OK |
| 1.2 | Parameter values in `maglev_params.m` (m 0.0571, P1 1.7521e-2, P2 5.8231e-3, fi 0.6263e-3, ci 0.0367586, ki 0.5432595, x1max 0.02, x3max 2.345, u 0..5) | Compared with manual p.34 table (image) | Identical. ki, ci, fi are the means of the Gain-1 rows of the p.24 step table (my means 0.54325 / 0.0367525 / 0.62625 ms) | OK |
| 1.3 | x3min conflict 0.0345 (p.17) vs 0.03884 (p.34) | Read both pages | Both values are in the manual as stated; code keeps both; irrelevant near 0.8 A | OK |
| 1.4 | Linearization a21, a23, a33, b3 | Compared with manual p.36 formulas; code uses partial derivatives | Match. Identities a21 = g/P2 and a23 = −2g/x30 hold (verified analytically) | OK |
| 1.5 | s01 equilibrium table (4 cases) | Independent Python | All entries agree to printed precision (e.g. 39.288 g @ 9 mm: x30 0.77514 A, u0 1.35916 V, K 13.7508, Kp_min 122.514 V/m; 57.1 g: Kp_min 147.70) | OK |
| 1.6 | s01 plot-reading checks: Fig 42 Fem(0)=2.63 N, Fig 43 Fem(2.3 A, 9 mm)≈3.4 N, Fig 46 (36 g @ 10 mm) ≈0.8 A / 1.4 V | Read the manual figures (Fig 42 at 300 dpi) | Fig 42 at x1=0 reads ≈2.63 N (model 2.627); also 0.004/0.006/0.008 m read 1.33/0.95/0.67 vs model 1.32/0.94/0.67. Fig 43 end ≈3.38 (model 3.39). Fig 46 settles ≈0.82 A, ≈1.43 V (model 0.809, 1.421) | OK |
| 1.7 | Sign convention: e = x − x_ref, u = u0 + C e, physical G = −K/(s²−a21), loop = feedback(G·C, −1) ≡ feedback(Gs·C, +1) with Gs = −G; feedback(G·C, +1) is the wrong form | Hand derivation: x'' = a21 x − K u, u = Kp x ⇒ s² + (K Kp − a21) | Correct; the sign tests in s01 §5 and s02 §2f test exactly this and would fail on a sign error | OK |
| 1.8 | s02 "P-only cannot stabilize" | Routh on (fi s+1)(s²−a21) + K Kp = fi s³ + s² − a21 fi s + (K Kp − a21) | The s-coefficient is −a21 fi < 0 for every fi > 0, so P-only is unstable for **all** Kp on the 3rd-order plant and at best marginal on the reduced plant. Claim verified in general, not only at the 4 tested gains | OK |
| 1.9 | s02 "[regression]" pole values (−3.438, −2.654, 3.497, 8.992, 16.313) | Independent Python (polynomial + own 3rd-order Padé) | Identical to 3 decimals | OK |
| 1.10 | Re-run vs stored results | `cmp_mat.m` | Stored `phase1/2_results.mat` test values identical to the re-run | OK |
| 1.11 | Figures p1_sweep, p1_force_curves, p2_bode, p2_nyquist, p2_polemap | Viewed | Show what the text says. Nyquist: PD curve starts at −1.5 (= −Kp/Kp_min) and encircles −1 once counter-clockwise; P-only lies on the real axis through −1 (marginal). One defect, see 1.17 | OK |
| 1.12 | **`maglev_params.m` is stale and no longer "the ONE place where every number lives"** (header lines 3–6). P.loop.Ts = 10 ms, filtersInPath = true (three 5 ms filters), P.act.fi = 0.63 ms, P.act.ki = 0.543 A/V, status strings still "UNCONFIRMED". The 12-Nov lab discovery (per memory notes and `data/lab_2026-11-12/README.md`, to be verified in Stage 2) found T0 = 3 ms, no filter blocks, coil τ ≈ 25–29 ms, ≈2.44 A per unit of u | Grep of s03–s18 | s03–s18 do **not** use P.loop, P.act or maglev_plant; they hard-code their own lab values (e.g. s05 line 124: tau 0.027, ka 2.44). So s01's equilibrium/force results are unaffected, but **every quantitative s02 result** (fidelity ladder, p·τ = 0.205/0.616, Bode delays 5/15 ms, π/Ts line, sampled pole e^(pTs) = 1.507) describes the manual's assumed loop, not this rig. There are now two sources of truth | **MAJOR** |
| 1.13 | **Units of u.** Manual model: u in volts, ki = 0.543 A/V. Lab: ≈2.44 A per unit of the command (ratio ≈ 4.5, not verified here) | Compared definitions | s01/s02's u0 = 1.36 V, K, Kp_min = 122.5 V/m and the demo gains are in **manual volts** and cannot be compared with the lab controller gains (e.g. lab PD Kp = 35) without conversion. Nothing in s01/s02 says so | **MAJOR** (for any report use) |
| 1.14 | Provenance of the "57.1 g @ 9 mm" reference values: `maglev_params.m` line 128 says "manual pp.35-36, briefing sec.3" | Grepped the manual text for 1.65, 1684, 41.05, 21.0, 1597, 867, 11.41 | Only **x30 = 0.9345 A** is in the manual (p.35). u0, a21, p, a23, a33, b3, K appear nowhere in the manual; they come from the briefing (a second calculation with the same formulas). So 1 of the 8 checks is against the manual, 7 are consistency checks. The values are nevertheless right (my independent recomputation, 1.5) | MINOR |
| 1.15 | Checks that cannot fail with the current inputs: "all gaps inside assumed sensor range" (max sweep gap 11 mm < 14 mm by construction), "p spread = 0", "K decreases with gap", "x30 ratio = sqrt(mass ratio)" | Analysis | The last three are exact identities of the exponential force law (a21 = g/P2; K = 2 g ki / x30). They are valid **code-consistency** checks, not evidence about the plant. The sensor-range check is a constant | MINOR |
| 1.16 | s02 header claim (2) "PD ... stabilizes the REDUCED plant, but the same PD fails once filter and delay are added" | Grid over Kp ∈ [1.01, 6]·Kp_min, Kd ∈ [0.05, 6] V s/m on S1–S3 (manual units, Padé 3) | True **for the demo gains only** (Kd = 0.5). Other PD gains are nominally stable in every scenario: best max Re = −62.8 (S1), −39.3 (S2), −12.9 (S3) rad/s, all needing Kd ≈ 4–6 V s/m. With a lab-like coil lag (fi = 27 ms, no filter, 1.5 ms hold) a PD is still nominally stabilizable (best max Re −10.9 rad/s at Kp ≈ 1.09 Kp_min, Kd ≈ 5) — but only just. The report must not say "PD cannot stabilize with filter/delay"; margins, not existence, are the issue | MINOR (wording/scope) |
| 1.17 | `figs/p2_polemap.png` | Viewed | The legend box (full view) hides the upper Padé/filter pole near −730 + 700j; only its mirror is visible | MINOR |
| 1.18 | Stale file name in headers: "CHECKED by 01_verify_model.m" (`maglev_params.m` line 9, `maglev_equilibrium.m` line 129) | Read | File is `s01_verify_model.m` | MINOR |
| 1.19 | Fig 45 shows a Desired-position block of 0.009 m while Fig 46 settles at 0.010 m | Viewed manual pp. 37–38 | The s01 check correctly uses 10 mm (the plotted value) but the script/params do not say why | MINOR |

### Proposed fixes (author decides)
- **1.12** Either (a) update `maglev_params.m` with the measured lab values (T0 = 3 ms, filters false, fi, actuator gain
  in lab units) and make s05+ read them from P, or (b) mark P.loop/P.act explicitly as "manual / pre-lab values, used
  only by s01–s02" and change the header claim. In the report, present s02 as a **pre-lab prediction from the
  manual's assumptions**, and state what the lab changed.
- **1.13** Add one line to s01/s02 (and the report) stating the unit of u in each model and the conversion to the lab
  command (once Stage 2 confirms the ≈2.44 A/unit figure). Give Kp_min also in lab units if it is quoted.
- **1.14** Change the comment to "x30 from manual p.35; other values from the briefing (same formulas)".
- **1.15** Label these four rows "[identity]" / "[constant]" in the PASS table, or drop the sensor-range row.
- **1.16** Reword s02 PURPOSE (2) to "the demo PD (Kd = 0.5 V s/m) that works on the reduced plant fails once the
  filter and delay are added; larger Kd restores nominal stability, at reduced margin".
- **1.17** `legend('Location','southwest')` (or `'bestoutside'`) for the full-view tile.
- **1.18, 1.19** Fix the name; add a one-line comment on the Fig 45/46 set-point discrepancy.

### Stage 1 summary
Counts: **CRITICAL 0, MAJOR 2, MINOR 6, OK 11.**

Three most important findings:
1. **The model code is right.** Equations, parameters and linearization match the manual exactly; every number
   s01/s02 print was reproduced independently, and stored results equal a fresh re-run (1.1–1.11).
2. **`maglev_params.m` still holds the manual's pre-lab loop and actuator values** (10 ms, 5 ms filters, 0.63 ms,
   0.543 A/V) while all later scripts hard-code lab values. s02's quantitative conclusions are therefore a pre-lab
   prediction about a loop that the rig does not have (1.12).
3. **Units of u differ between the manual model (volts) and the lab command** (≈2.44 A per unit); Stage-1 gains such as
   Kp_min = 122.5 V/m are not comparable to lab gains without conversion (1.13). Related: "PD fails once
   filter/delay are added" holds only for the demo gains (1.16).

For Stage 2 to look at:
- Verify the lab actuator figures (≈2.44 A/unit, offset, τ 25–29 ms) from the raw `.fig` files, and establish the
  conversion between the lab command and the manual's volts (1.13).
- Verify T0 = 3 ms and the absence of the Fig 30 filters from `data/lab_2026-11-12/discovery/*.txt` (1.12).
- Check the 12-Nov claim "x-only PD is fundamentally limited / unstable" against 1.16: my continuous-time grid with
  a 27 ms lag finds nominally stabilizing PD gains (large Kd, Kp ≈ 1.1 Kp_min); the claim may be true only for the
  discrete 3 ms loop with the measured delay, or only for the tested gains — check how s03/s05 reached it.
- Under the exponential force law the unstable pole p = sqrt(g/λ) does not depend on mass or gap (1.4, 1.15).
  Any uncertainty range for a21 in s05/s10 should come from λ alone; check that s05's grid "a21 981–1685" (from λ up
  to 10 mm, a pre-fit hypothesis) is still justified after the λ ≈ 5.81 mm fit.
- s05 hard-codes `tau 0.027, ka 2.44`, and `P.Fem.P2` is still the manual value; check these against the fits.

---

## Stage 2 (2026-11-16) — Lab identification and design

Scope: `s03_lab_discovery.m`, `s04_save_scope_traces.m`, `s05_cascade_design.m`, `s06_analyze_cascade_run.m`,
`s07_analyze_experiments.m`, `s08_analyze_sweeps.m`, helpers `read_scope_fig.m`, `maglev_cascade_sim.m`;
`data/lab_2026-11-12/` (README, discovery, runs, screenshots), `data/lab_2026-11-13/` (README up to the s08 part;
the s12/s13/s14 paragraphs belong to Stages 3–4); figs `p3_*`, `p4_*`, `p5_*`.

### How it was checked
1. Read all eight files and both READMEs in full; read the three `discovery/*.txt` reports and screenshot 04 (lab PD).
2. Ran s05, s06, s07, s08 on a scratch copy of the project (they write to `data/` and `figs/`). All checks PASS
   (s05 25/25, s06 7/7, s07 10/10, s08 21/21). Every console number quoted in the two READMEs (s05–s08 parts) was
   compared with the console: **all match**.
3. The re-run `.mat` files (`phase3_cascade`, `run34_metrics`, `exp_ABC_results`, `sweeps_holds_results`) are
   **identical** to the repo's, field by field.
4. Independent checks with my own code (scratch `indep/`): an own `.fig` reader that keeps the raw samples (`rawfig.m`);
   own coil-step fits; own regressions of the logged controller signals; an own force-law fit of the three afternoon
   sweeps with the logged x_ref and own windows; an own grid over position-only PD gains on the fitted plant.

### Findings

| # | File / claim | What I did | Result | Class |
|---|---|---|---|---|
| 2.1 | s03 discovery: T0 = 3 ms, ode3, external mode, target `mls1em_rtcon_usb2.tlc`; no driver filters; velocity = (x[k]−x[k−1])/T0 | Read the three reports | All three models: FixedStep 0.003, ode3, external, ExtMode on. Block counts contain **no** TransferFcn, DiscreteFilter, (Discrete)StateSpace, UnitDelay or Delay block. Driver: `Memory` + `Gain 1/T0` (velocity). The Fig. 30 5 ms filters are not present as Simulink blocks (see 2.18 for the caveat) | OK |
| 2.2 | Lab PD: Kp 35, Kd 450 on Δe, u0 0.282 | Discovery report + screenshot 04 | Kd 450 multiplies e[k] − e[k−1] (Memory block and a Sum), so the effective derivative gain is 450·T0 = 1.35 per (m/s). Correct | OK |
| 2.3 | Logged signals are usable sample by sample | Own reader on 3 files (coil steps, cascade run 3, 39 g sweep) | Spacing exactly 3 ms, **no duplicated samples** in the stored data (so `read_scope_fig`'s `unique` is a harmless no-op, no one-sample shift). See 2.17 | OK |
| 2.4 | Deployed cascade controller = s05 design; signals synchronous; sign e = x − x_ref | Regressed logged i_ref on [1, e, v, Σe·T0] at lags −2..+2 (two sweeps, three windows each) | At lag 0 the fit is **exact** (residual ≈ 1e-15 A): Kp 149.0, Kd 2.600, Ki 734. 149.0 = 151.2 − Ki·T0, the signature of a forward-Euler integral that excludes the current sample, so the deployed gains are exactly the design and the integrator is forward Euler as claimed. Inner law u = i_ref/2.44 + 2.05(i_ref − i) also exact at lag 0, wrong at ±1. Stronger than s08's own approximate check (Kp 151.6, Kd 2.53), which with other windows would sit at the edge of its ±10 % tolerance (I got Kd 2.32–2.37 without the integral term) | OK |
| 2.5 | s05 gains (Kc 2.054, Kp 151.2, Kd 2.599, Ki 734, clamp ±0.30 A) | Hand calculation from the pole-placement formulas | Kc = (e^(−3/27) − e^(−1))/(2.44(1 − e^(−3/27))) = 2.053; Kp = (1600 + 672 + 1684.7)/26.16 = 151.3; Kd = 68/26.16 = 2.599; Ki = 19200/26.16 = 734. Characteristic polynomial s³ + bKd s² + (bKp − a21)s + bKi derived independently. Correct | OK |
| 2.6 | s05 discrete loop model (`cascade_loop`) and robustness grid (nominal Ms 1.36, worst 1.67, +1 sample 5.23) | Read the state-space construction; re-ran | Structure is right (ZOH plant, controller memory xp, forward-Euler z, delay chain, S = 1/(1+L) broken at the plant input, wrong-sign test). Numbers reproduced | OK |
| 2.7 | Coil static gain 2.44 A/unit | Own fit of the 4 coil steps | Incremental gain 1.91 (0→0.2, low-end nonlinearity), 2.33, 2.46, 2.43; s07 from hover data 2.43. 2.44 is well supported; the s05 grid 2.2–2.7 covers the spread | OK |
| 2.8 | 12-Nov run 4: PD gains and 7–9 Hz oscillation | Own regression u ~ [1, e, Δe] in 4 windows; own spectra | Recovers u0 0.300/0.320/0.340, Kp 45.0 (40.0 after 16 s), KdRaw 450 exactly. Peak 7.4 / 9.0 / 9.2 / 8.7 Hz; x range up to 2.9–12.5 mm, so the ball hits the stand (~11.9–12.5 mm) every cycle; u = 0 in up to 15 % of samples | OK |
| 2.9 | s06: run 3 inner loop 0.294 / 0.497 A, 63 % in 2 samples; run 4 lift-off 45 ms, highest 8.89 mm, overshoot 1.12 mm (sim 0.94), hover 0.898 / 0.830 A | Independent recomputation | All reproduced (0.294 / 0.497; 45 ms; 8.89; 1.12; 0.898; 0.830 over the 2 s window, 0.824 over the whole 10 mm hover) | OK |
| 2.10 | Exp A drop = mistyped set point (inferred) | Re-derived | At the drop the integral was ≈ +0.04 A (hover 0.79 − i0 0.75), so i_ref = 0 in one sample needs e ≤ −0.79/151 = −5.2 mm, i.e. x_ref ≥ 14.7 mm; s07's "≥ 14.9 mm" uses the −0.3 A clamp instead. Same conclusion (far outside the range; 0.09 m fits). Correctly labelled "inferred, not confirmed" | OK |
| 2.11 | Exp C: stable at every kg 0.4–2.0; jitter 0.121 mm at kg 0.4 | Own segments per logged kg level | Levels 0.4/0.5/0.6/0.8/1/1.25/1.5/2 confirmed from the logged kg; x std 0.119/0.073/0.061/0.057/–/0.061/0.050/0.064 mm, max x while on 11.19 mm (never back on the stand). Matches | OK |
| 2.12 | Sensor noise x 0.011 mm, i 0.018–0.021 A; current-zero drift −0.52 (morning), −0.82/−0.85 (afternoon) mA/s | s07/s08 console; own computation for the sweeps | Reproduced (sweeps: −0.82, −0.85 mA/s) | OK |
| 2.13 | s07/s08 PASS checks and README numbers | Console vs README; `.mat` comparison | All match; saved results identical; `maglev_cascade_sim` "default unchanged, bit-identical" claim (15-Nov edit) confirmed by the identical s07/s08 outputs | OK |
| 2.14 | Post-hoc analysis choices in s08 (S42d drift rate taken from S42u after a first FAIL; rocking flag 0.04 mm) | Read code + README | Both disclosed in the code and the README. My test: using the mean measured rate instead changes λ by < 0.01 mm, so the choice matters only for check 3b, not for the force law | OK |
| 2.15 | **s05 header (WHY): "the lab PD is predicted (and was observed) to oscillate at 7-9 Hz"**; 12-Nov claim "x-only PD is fundamentally limited / unstable" | Own discrete grid: u = u0 + Kp e + Kr(e[k]−e[k−1]), fitted plant (λ 5.90 mm, i0 0.80 A, ka 2.44), τ 22.5/27/29 ms, extra delay d = 0/0.5/1 sample, Kp 10–300, Kr 0–4000 | (a) The linear model does **not** predict 7–9 Hz: the lab PD's unstable pole is at **5.2–5.6 Hz** (max\|eig\| 1.004–1.011 for Kp 45; Kp 40 with d = 0 is even stable, 0.995), yet the lab kept oscillating at 8.7 Hz with Kp 40. The observed 7.4–9.2 Hz is a large-amplitude cycle with stand impacts and command saturation, which the linear model cannot describe. (b) A position-only PD is **not** impossible: 1–4 % of the gain grid is stable for every τ and d tested, but the best points have **Ms 5.7–13** (fragile). So the defensible statement is "position-only PD is at best very fragile on this rig (Ms ≥ 5.7); the lab PD sits on the stability boundary", which still justifies the cascade | **MAJOR** |
| 2.16 | Force law precision: README states λ = 5.81 mm (s07), 5.90 (s08), "manual 5.82" | Own fit of the 27 afternoon plateaus (logged x_ref, own windows), with different treatments of the current-sensor zero | Raw reading: 6.12 ± 0.32 mm (rms 12.5 mA); constant start zero: 5.85 ± 0.30; **linear drift (s08 method): 5.99 ± 0.05** (rms 2.1 mA); constant offsets 0.02/0.04/0.06 A: 5.97/5.83/5.69. Per-run (drift-corrected): 5.83 / 6.04 / 6.10. So λ is known to about **±0.15 mm (±2.5 %)**, limited by the sensor-zero model (linear drift, endpoints only, n = 5 runs with tails), not by scatter. "Agrees with the manual's 5.82" is fair; quoting 5.81 vs 5.82 as a match to 0.01 mm is not. No uncertainty is stated anywhere | MINOR (needed for R2) |
| 2.17 | "The scope stores each sample twice" (`read_scope_fig.m` header, 12-Nov notes, `group 28/README.md` line 25) | Raw data, 2.3 | False for the stored files; harmless because `unique` then does nothing | MINOR |
| 2.18 | "No driver filters" (12-Nov README) stated without caveat | Discovery report | Only Simulink-level blocks are listed. Two S-Functions (PWM read/write) and the hardware could still filter or delay; the 0.5-sample extra delay found later (s12) is consistent with that. Say "no filter blocks in the Simulink driver" | MINOR |
| 2.19 | **Unit of u** (follow-up of Stage 1 item 1.13) | Discovery report | The driver contains a `PWM` subsystem with `Gain 4095` and a "12-bit" switch, so the command is a **PWM duty fraction** (0..1 → 0..4095 counts), not volts. The scope label "Control [V]" and the README's "Kd = 1.35 V·s/m" are therefore misleading. The relation to the manual's "volts" (ki = 0.543 A/V vs 2.44 A/unit, ratio 4.5) is **not verified** from any file I have | MINOR |
| 2.20 | Coil time constant "25–29 ms" (12-Nov README, `group 28/PARAMETERS.md`) | Own fit of each step (LS with dead time, and the 63 % crossing) | The two steps with the ball **resting** on the stand give τ = 25.0 / 22.5 ms (63 % at 24 ms in both). The 0.3→0.4 and 0.4→0.2 steps give 25–29 ms, but the ball jumped to the magnet during the 0.3→0.4 step, which changes the coil inductance. Better: "≈ 23–25 ms with the ball on the stand, up to 29 ms with the ball at the magnet". The 27 ms nominal is at the upper end; the s05 grid (20–35 ms) still covers it | MINOR |
| 2.21 | s05 still prints "lab data need λ > 8.25 mm … manual model INCONSISTENT" and its lift-off sims (`p3_liftoff_sim.png`) use force constants built on that premise | Re-run | The premise was withdrawn on 13-Nov (README), but the script and figure were not marked. Don't use `p3_liftoff_sim.png` in the report as evidence for the fitted plant | MINOR |
| 2.22 | s05 robustness grid ranges | Compared with the fits | a21 grid 981–1685 s⁻² comes from λ 5.82–10 mm (the withdrawn hypothesis); fitted λ 5.8–6.1 mm gives a21 1610–1690. Hover-current grid 0.65–0.90 A, but measured true hover currents reach 0.94 A (42 g, 11 mm) and 0.95 A (42 g, 11.5 mm), above the grid edge (smaller loop gain b = 2g/i0). Superseded by later robustness work? → Stage 3 | MINOR |
| 2.23 | Overshoot metric differs between s07 and s08 | Read both `step_metrics`; run-4 step as a test case | s07 takes the lab overshoot from **raw** x (includes sensor noise and jitter) and compares it with a **noise-free** simulation; s08 uses a 33 ms running mean for both. Run 4: raw 1.12 mm vs smoothed 1.05 mm. So s07's lab overshoots are biased up by ~0.05–0.07 mm, and its "rms 0.16 mm" is not like-for-like with s08's "0.18 mm". Also both scripts report a settling time of **0 ms** for two 10.5 → 11 mm steps (overshoot inside the ±0.25 mm band), which reads like a bug | MINOR |
| 2.24 | s08 3a "morning law predicts the afternoon within 10.2 mA rms" | Console | The residual has a **mean of +6.4 mA** (afternoon currents systematically higher), not reported in the README. `p5_force_fit_all.png` shows the 42 g morning points ~10–15 mA below the afternoon (hole-down) points at 9–10.5 mm; the morning 42 g orientation in flight is unknown (it rested like hole-up and may have rolled, as S42u did). One c per ball therefore mixes orientations | MINOR |
| 2.25 | Exp C model range "stable for 0.28 < kg < 3.76" (13-Nov README) | Read s07 `cl_eig` | Computed with **no** extra loop delay. The 15-Nov delay estimate (d ≈ 0.5) gives 0.293–3.57 (s12, per the README). The Exp C line is not annotated | MINOR |
| 2.26 | Step overshoot size | Console tables | Overshoot is **100–130 % of the step** (0.5 mm steps → 0.5–0.7 mm; 1 mm → 1.12 mm). The simulation reproduces it, so it is a property of the design (proportional action on e plus the slow integral zero at Ki/Kp ≈ 4.9 rad/s), not a model error. The READMEs only give millimetres; the report should give it relative to the step and explain it (a set-point weight on Kp would reduce it) | MINOR |

### Proposed fixes (author decides)
- **2.15** Reword the s05 header and any report text: "the linear model puts the lab PD on the stability boundary
  (unstable pole ~5.5 Hz); the observed 7–9 Hz cycle is large-amplitude and hits the stand, so it is not a linear
  prediction. A position-only PD is at best fragile on this rig (best Ms 5.7–13 over a full gain grid), so the
  current loop is needed for robustness." If wanted, add the gain-grid result as a figure (stable island vs Ms).
- **2.16** Report λ = 5.9 ± 0.15 mm (systematic, sensor-zero model) and propagate it into the uncertainty set (Stage 3
  checks how s10/s11 use it). State the linear-drift assumption and that it rests on 5 runs with a coil-off tail.
- **2.17–2.19** Correct the wording in `read_scope_fig.m`, the 12-Nov README and `group 28/README.md`; label u as
  "PWM duty [-]" (scope and READMEs); drop "V·s/m".
- **2.20** Update τ to "23–25 ms (ball on stand), up to 29 ms (ball at magnet)" in the 12-Nov README and PARAMETERS.md.
- **2.21** Mark the λ-bound printout and `p3_liftoff_sim.png` as superseded (pre-lab design check).
- **2.23** Use the same (smoothed) overshoot definition for lab and sim in s07, or note the difference; return NaN or
  "≤ band" instead of 0 ms when the step never leaves the band.
- **2.24, 2.25** Add the +6.4 mA bias and the delay assumption (d = 0) to the README lines.
- **2.26** Report overshoot in % of the step and explain the integral zero.

### Stage 2 summary
Counts: **CRITICAL 0, MAJOR 1, MINOR 11, OK 14.**

Three most important findings:
1. **The lab pipeline is sound and reproducible.** Every README number for s05–s08 equals the console; saved results
   equal a fresh run; and the logged signals prove the deployed controller is exactly the s05 design (exact lag-0
   regression with a forward-Euler integral), with synchronous logging and no duplicated samples (2.3, 2.4, 2.13).
2. **The rationale "the lab PD was predicted to oscillate at 7–9 Hz" is not supported** (2.15). The linear model gives
   ~5.5 Hz and only marginal instability; a position-only PD can be stabilised, but only fragilely (Ms ≥ 5.7). The
   choice of the cascade still stands, on robustness grounds.
3. **λ is known to about ±0.15 mm, not to 0.01 mm** (2.16): the result depends on how the drifting current-sensor zero
   is modelled. Agreement with the manual (5.82 mm) holds within that uncertainty.

For Stage 3 to look at:
- Which λ, τ, ka, c, hover-current and delay values `maglev_cases.m`, s10 and s11 use, and whether their uncertainty
  ranges cover: λ 5.7–6.1 mm (2.16), τ 22–29 ms (2.20), true hover current up to 0.95 A (2.22), and per-ball /
  per-orientation c (2.24).
- The kg stability range with the measured delay (2.25), and whether s11's margins are computed with d = 0.5.
- Whether any "guaranteed margin" claim (PS9 R4) rests only on a grid.

For Stage 4: the 11.5 mm hover points lie 20–36 mA **below** the force-law fit (`p5_force_fit_all.png`), and the
12-Nov PD cycle hit the stand every period; both are candidates for the stand-proximity effect found on 16-Nov.

---

## Stage 3 (2026-11-16) — Models and robustness

Scope: `scripts/maglev_cases.m`, `scripts/maglev_cascade_sim.m`, `scripts/build_maglev_cl_sim.m`,
`scripts/s09_sim_models.m`, `s10_linear_model.m`, `s11_robustness.m`, `s12_delay_estimate.m`; `models/README.md`
(simulation part), `data/lab_2026-11-13/README.md` (s12 section, s11 references), `data/README.md`; figs `p6_*`, `p7_*`,
`p8_*`, `p9_*`.

### How it was checked
1. Read all seven files in full, and the README sections that quote them.
2. Ran s12 → s10 → s11 → s09 (dependency order) on a **copy** of the project in the scratch folder. Result: s12 all
   PASS (7/7), s10 **12 PASS / 0 FAIL**, s11 **12 PASS / 4 FAIL**, s09 **15 PASS / 1 FAIL** (CLEARANCE). The re-run
   `delay_estimate.mat`, `linear_model.mat`, `robustness.mat` and `sim_cases_results.mat` are **identical** to the
   repo's (every field, `isequaln`).
3. Every console number quoted in `models/README.md` (simulation part) and in the 13-Nov README s12 section was
   compared with the console: **all match** (one README claim was broader than what s09 tests, see 3.19).
4. Independent recomputation (scratch `s3/indep/`, own code, not the scripts' functions):
   - `loop_indep.py`: the discrete cascade loop written from the equations with my own matrix exponential and my own
     derivation of the fractional-delay ZOH (modified z-transform), its own frequency response and margins.
   - `wt_indep.py`: worst-Ms grid point, Exp C contradictions, and the Option 2 |W T| test for the weakest region.
   - `delay_indep2.py`: s12 method A with a different estimator (k_a and offset by linear least squares, τ and d by
     grid search, no fminsearch) and method B on a fine (τ, k_a, d) grid with my own Welch PSD.
   - `nlsim_indep.py`: a third nonlinear simulation of s09 scenario 2a (RK4 at T0/40 instead of ode4 at T0/10).
   - `sim_delays.m`: Simulink vs `maglev_cascade_sim` at all five delays named in `models/README.md`.
   - `expA_step.m`: the Exp A 11 → 11.5 mm step that s09 quotes as a hard-coded number.
5. Viewed all ten figures `p6_*`–`p9_*`.

### Findings

| # | File / claim | What I did | Result | Class |
|---|---|---|---|---|
| 3.1 | s12 data checks: every 3 ms sample present; u and i logged in the same sample (lag-0 R² 0.9996) | Re-run; same check was done independently in Stage 2 (2.3, 2.4) | Confirmed | OK |
| 3.2 | s12 method A: best extra delay d = 0.55 sample (τ 24.9 ms, k_a 2.68); d = 0 and d = 1 rejected (+9.9 / +10.8 % fit error) | Own estimator (`delay_indep2.py`) | Best d **0.55**, τ 25.0 ms, k_a 2.685; fit error +10.0 % at d = 0, +10.8 % at d = 1; also 0.55 without the switch-on (τ 26.5 ms). Reproduced | OK |
| 3.3 | s12 method A: what the estimate rests on | Read code; compared fitted parameters with Stage 2 | (a) **n = 1**: one run (13-Nov run 3), ball on the stand, inner current loop only; the outer (position) loop's delay was never measured. (b) The fit needs **k_a 2.69–2.72 and an offset −0.07 A**, against the static k_a 2.43 (s07, Stage 2 2.7) and a current-sensor zero of **+0.04 A**. The first-order coil model is therefore not exact, and part of the "delay" may be unmodelled coil dynamics; the author says so for the LR interval. (c) The model puts d on u, so it delays both loops. If the cause is a current-sensor filter (one of the three causes s12 lists), only the inner loop sees it | MINOR (caveat) |
| 3.4 | s12 method B and 13-Nov README: "a resonance at ~65 Hz that only a fractional delay reproduces (d = 0.32–0.50)" | Own PSD ratio; fine grid τ 10–35 ms, k_a 1.8–3.2, d 0–1.2 | Best fit τ 22 ms, k_a 2.75, **d 0.48**, so d ≈ 0.5 stands. But the measured \|S\|² peak is **≈ 6 at 62 Hz**, while every model in that range peaks at ≤ 2.9 (`p9_delay.png` shows it too). A fractional delay reproduces the peak's **frequency**, not its height. s12's own best τ (20 ms) sits on the edge of its 3-value τ grid. The method also assumes the current-sensor noise is the same with the coil off as with the PWM running: not verified | MINOR |
| 3.5 | Two "nominal" delays in circulation | Read s12, `maglev_cases.m`, README | s12 prints "ESTIMATE d = 0.55 (method A)" and the README quotes margins at d = 0.55 (Ms 1.65). `maglev_cases` takes the **spectral** best fit (0.50) as the nominal, so all models use d = 0.5 (Ms 1.59). Both values are fine; the text should name one nominal | MINOR |
| 3.6 | s12 header: "with +1 sample the robust-stability test fails and the worst Ms is 5.0 (s11)" | Searched current s11 | s11 no longer evaluates the grid at d = 1 (only the nominal loop: Ms 2.41). The 5.0 comes from an older version and cannot be reproduced | MINOR |
| 3.7 | s10 sections 1–4: refit = s08; analytic Jacobian; sign test; one unstable pole p = √(g/λ) = 40.76 rad/s (6.49 Hz); fractional delay acts as a pure delay | Re-run + `loop_indep.py` | a21 = g/λ = 1661 s⁻², b = 2g/i0 = 24.59 m s⁻² A⁻¹ at 39 g / 10 mm (mine 24.594). The sign test can fail (the +b model moves the other way) | OK |
| 3.8 | Uncertainty ranges λ ± 5 %, c ± 5 % (`maglev_cases` U table: "refits moved c by 2–4 %") | s10 console + Stage 2 2.16 | s10's own 95 % CI: λ ± 4.3 % (**statistical only**; Stage 2 found a further ± 2.5 % systematic from the sensor-zero model, together ≈ ± 5 %), c **± 7.4 %** (correlation with λ −1.00). So c ± 5 % does **not** cover c's own CI. That is acceptable only because the loop depends on the hover current i0 (CI ± 0.57 %), which the set covers. λ ± 5 % is just enough. The U-table evidence should say this | MINOR |
| 3.9 | s10 "the uncertainty set covers every measured hover current (42 / 42)" | Own coverage test, including the 4 points s10 leaves out (3 rocking-flagged, 1 unused) | All 46 inside. But the check **cannot realistically fail**: the band is about ± 7 % wide, and the residuals (max 1.5 %) come from the same data the band is centred on. It is a consistency check, not evidence | MINOR |
| 3.10 | s10 header: "a21 = g/lam, b = 2g/i0 (exact for any force law F = c i² f(x) with f = exp(−x/lam))" | Derivation | b = 2g/i0 holds for **any** f(x); a21 = g/λ holds **only** for the exponential. The sentence mixes the two | MINOR |
| 3.11 | s10 5c: linearization is not the cause of the lab-vs-model overshoot gap (local linear vs nonlinear 0.026 mm rms; one linear model 0.086 mm) | Console + `p7_lin_vs_nl_overshoot.png` | Correct. Two notes: (a) the 0.10 mm threshold "≈ half the lab-vs-model gap" is not marked as chosen before or after the run; (b) the single constant linear model fits the **lab** better (0.130 mm rms) than the nonlinear model (0.175), because the nonlinear model's trend with gap runs the wrong way (lab overshoot falls toward 11 mm, model rises). That pattern is the Stage 4 topic | MINOR |
| 3.12 | s10 "unmodelled effects" table | Compared with the 16-Nov README | Stale: rocking "PROVISIONAL – lab: stand-lowered hold" and "position-sensor calibration nonlinearity: open (hypothesis for the 11 mm step mismatch)" predate the stand-proximity finding. It also says current noise 0.018 A while the simulations use 0.021 A | MINOR |
| 3.13 | s11 loop model and margins: nominal (39 g, 10 mm) at d = 0 / 0.3 / 0.5 / 0.6 / 1: Ms 1.36 / 1.41 / 1.59 / 1.71 / 2.41, gain range, PM, DM; grid of 1458 points all stable; worst Ms 2.23 | `loop_indep.py`, `wt_indep.py` | All reproduced to 3 digits (e.g. d 0.5: Ms 1.595, gain 0.292–3.952, PM 45.4°, DM 5.34 ms; worst Ms **2.2303** at the same grid point). The stable gain set is **one interval** at every d, so s11's bisection is valid. The upper gain limit is a fast inner-current-loop mode (52–167 Hz), not the ball | OK |
| 3.14 | s11 results vs the PS9 R4 requirement "guaranteed stability margins over the defined uncertainty range" | Re-run, exact values from `robustness.mat`, own recomputation | (a) The **pre-declared** target worst Ms ≤ 2 **FAILS: 2.23** (d 0.6, 39 g, 9 mm, λ +5 %, c +5 %, τ 20 ms, k_a 2.7; at d 0.5 the worst is 1.97). (b) Grid-worst margins: upper gain limit ≥ 2.23 (+7.0 dB), lower ≤ 0.54, PM ≥ 29.3°, delay margin ≥ 2.8 ms (0.93 sample). (c) The \|W T\| < 1 test passes only in the Option 2 split, and in its weakest region (42 g, 10–11 mm) the maximum is **0.9973** (my recomputation: 0.9973; without the +10 % inflation of W, 0.907). (d) The room left for **unmodelled** error is 22 % below 2 Hz, **0–0.1 % at 2–10 Hz**, 2 % at 10–30 Hz. **None of (a)–(d) is written in any README** (only "12 PASS / 4 FAIL") | MINOR (must be in the report) |
| 3.15 | s11 method: is the \|W T\| < 1 "guarantee" valid? | Theory check + `wt_indep.py` | Valid as a sufficient test. Every grid loop has the same number of open-loop poles outside the unit circle (one plant pole, since a21 > 0 always) plus the shared integrator at z = 1, and that is what the Nyquist argument needs. At grid points stability is also proven directly (eigenvalues). **Between** grid points it rests on 400 random plants per region (max \|δ\|/W 0.77–0.88; my 300: 0.78) and on a 1500-point frequency grid: strong evidence, not a proof. Option 1/2 were added after the one-disk test failed: **disclosed** | OK (method) |
| 3.16 | The actuator gain error kg 0.4–2.0 is listed in the uncertainty table (`maglev_cases` U, printed by s09, saved in `linear_model.mat`) as part of the set | s11 sec. 4 and 6 output; own count | kg is **not** in the robust-stability set. At kg = 0.4, **33 of 243** grid points at 39 g / 10 mm are unstable (my count: 33), all with τ = 35 ms and k_a ≤ 2.43. Over the whole grid only 148 / 324 (ball × gap × λ × c × k_a × sensor zero) are stable for every τ and d. So "robust over the uncertainty set" is **false if kg is counted in the set**. What the data actually show is that the real plant is not at those corners: Exp C was stable at kg 0.4 | **MAJOR** |
| 3.17 | s11 section 6 / variant D | Console + `p8_clamp_fix.png` | Numbers reproduce. The check "every option and case … never closer than 6 mm to the magnet" FAILs **by design** (option C reaches the magnet), and it is one of the 4 FAILs. "SIMULATION ONLY" is stale: D ran on the hardware on 16-Nov (Stage 5) | MINOR |
| 3.18 | s11 section 3 model checks (fractional = integer-delay loop at d 0 / 1; negated gains → unstable; allmargin = eigenvalue sweep; nonlinear sim settles inside both gain limits, not outside) | Re-run; read code | All PASS and each can fail. The nonlinear check was revised after a first FAIL: **disclosed** | OK |
| 3.19 | `models/README.md`: Simulink model = MATLAB simulation "within 0.0001 mm for d = 0, 0.3, 0.5, 0.6 and 1" | `sim_delays.m` (all five), `nlsim_indep.py` | s09 itself tests **only d = 0.5**. My run of all five: max \|x diff\| 0.00013–0.00014 mm, \|i diff\| 0.03–0.04 mA, so the README claim holds. A third implementation (mine, different integrator and step) agrees within **0.005 mm** in x (5.8 mA in current, during lift-off). The model builds, so every block path exists | OK |
| 3.20 | s09 2a: "two independent implementations" | Read both | Same author, same equations. It verifies the Simulink wiring, not the physics. 3.19 adds a genuinely separate implementation | MINOR |
| 3.21 | `models/README.md`: s09 "reproduces the lab 39 g sweep: lift timing 36 vs 39 ms, overshoot 0.14 mm rms, hover current 3.0 mA rms" | Console; checked which data the force law was fitted to | Numbers match. But (a) the current agreement is **in-sample**: this run (S39u) is one of the three afternoon runs used to fit λ and c. (b) The overshoot threshold (0.2 mm rms on ~0.6 mm overshoots) is loose and its origin not stated. (c) The misfit is **systematic**: the sim under-predicts the turn-around steps at 9 mm (0.44 / 0.45 vs lab 0.58 / 0.63) and over-predicts 10.5 → 11 (0.61 vs 0.32). Only the lift timing and the overshoots are out-of-sample | MINOR |
| 3.22 | s09 case metrics: "54 of 73 cases in the set fully ok" | Read `case_metrics`; `p6_cases_special.png` | For any case with noise **or** tilt, "ok" skips the ringing test. So "39 g, lab-like (noise + drift + tilt)" counts as **ok** although the **true** ball swings with std 0.45 mm at 2.45 Hz on every level (figure, bottom panel). The tilt case applies the 0.27 mm artifact at **every** gap and drives ± 0.4 mm of true motion at 9–11 mm, where the lab shows ≤ 0.051 mm rms (13-Nov README, s14). "Lab-like" is therefore not lab-like at 9–11 mm; it is an 11.5 mm stress case. Correct count: 53 of 73. Smaller: `lost` only checks the final position, so a ball stuck at the magnet would not count as lost (no case is affected: worst lift-off 7.10 mm) | **MAJOR** (method changes a stated count) |
| 3.23 | s09 CLEARANCE FAIL: 19 cases come within 0.1 mm of the stand, all on the final 10.5 → 11 mm down-step, explained as "the model overpredicts the lab overshoot near 11 mm ~2×", i.e. pessimistic | Console | The count is right. The explanation predates the 16-Nov stand-proximity finding: if something near the stand brakes the real ball, the model is missing physics there, not being pessimistic → Stage 4. Also in the console only: **4 corner plants** (42 g, λ −5 %, c −5 %, k_a 2.2) sit **0.204 mm** off at 11 mm with the integral clamped. Inside the declared set, the deployed controller cannot hold 11 mm with the 42 g ball | MINOR |
| 3.24 | s09 3b, hard-coded: "Lab (Exp A, 39 g, same step 11 → 11.5 mm): overshoot 0.34 mm, no contact" | `expA_step.m` (Exp A has no logged set point; step found from x) | 0.33 mm (33 ms mean) / 0.34 mm raw, so the number is right. But the 2.4 Hz rocking is superposed and only 2.4 s were recorded. The closest approach to the stand reading is 0.11 mm, so "no contact" is plausible but not shown | MINOR |
| 3.25 | Consistency of the uncertainty table and headers | Compared with s10, s11, s14, Stage 2 | Operating gap "9–11.5 mm, validated" vs s10 "11.5 provisional", s11 grid 9–11, and the 13-Nov README "11.5 mm stays out of the claimed range". τ evidence "coil step test 25–29 ms" vs 22.5–25 (Stage 2 2.20), 24.9–26.5 (s12) and ≈ 21 ms at 12–40 Hz (`group 28/PARAMETERS.md`, Stage 5); the nominal 27 ms sits at the top of that, and the worst Ms occurs at τ = 20 ms. `maglev_cases` header "D = SIMULATION ONLY (not on the hardware)" and s09 "same 75 cases" (there are 77) are stale | MINOR |
| 3.26 | `p6_cases_special.png` top panel | Viewed | The kg 0.4 line is drawn under the kg 2.0 line (both flat at 10 mm), so it cannot be seen | MINOR |
| 3.27 | Stage 2 follow-ups for this stage | Compared | s05's a21 grid 981–1685 is superseded by s11's 1582–1749 (λ ± 5 %). τ 22–29 ms and λ 5.7–6.1 mm are inside the ranges. The hover current up to 0.95 A (42 g, 11.5 mm) is inside the s11 b-range (corner 42 g / 11 mm gives 1.011 A). The per-ball +6.4 mA bias (≈ 0.7 %) is inside c ± 5 %. The Exp C kg range is now computed with the measured delay (0.292–3.95 at d 0.5) | OK |
| 3.28 | Re-runs vs repo, console vs README | `peek.m` | All four `.mat` identical; all quoted numbers match | OK |

### Proposed fixes (author decides)
- **3.14 / 3.15 (report wording for PS9 R4).** State exactly: "Closed-loop stability is proven at every point of a
  3⁷ = 1458-point grid (λ, c ± 5 %, τ 20–35 ms, k_a 2.2–2.7, d 0.3–0.6, both balls, 9–11 mm) and, by a multiplicative
  \|W T\| < 1 bound in four operating-point regions (worst 0.997), for the plants between grid points that 1600 random
  samples covered. Grid-worst margins: Ms 2.23 (target 2 not met), PM 29°, gain range [0.54, 2.23], delay margin
  2.8 ms. The bound leaves no room for unmodelled error at 2–10 Hz." Add these numbers to a README (the 13-Nov
  README only says "12 PASS / 4 FAIL").
- **3.16** Take kg out of the uncertainty table, or label it "lab gain-margin test (nominal plant), not part of the
  robust set". Optionally use Exp C to trim the set (it excludes τ = 35 ms with k_a ≤ 2.43), which would also lower the
  worst Ms.
- **3.22** In `case_metrics`, keep a ringing test for noisy cases (e.g. the 1.5–3.5 Hz band of the true x against a
  limit), or report the tilt cases separately as "11.5 mm stress cases". Rename "lab-like" or scale the tilt artifact
  with gap. Make `lost` also catch x ≈ 0. Correct the "fully ok" count.
- **3.3–3.5** In the README: "d ≈ 0.5 sample from one inner-loop run (ball on the stand); the first-order coil fit
  needs k_a 2.7 and a −0.07 A offset, so part of the lag may be coil dynamics; the outer-loop delay was not measured
  separately"; "the fractional delay reproduces the frequency of the 62 Hz noise peak, not its height"; and name one
  nominal (0.5). Remove "worst Ms 5.0" from the s12 header (3.6). The 16-Nov sine-injection data can test d on the
  full loop (Stage 5).
- **3.8, 3.9** U table: "c ± 5 % is narrower than c's own CI (± 7.4 %) but covers the hover current i0, which is what
  the loop depends on (CI ± 0.57 %)". Label the coverage row "[consistency]".
- **3.21** `models/README.md`: "hover current agrees within 3 mA (this run was part of the force-law fit, so this is
  in-sample)"; report the overshoot misfit pattern rather than one rms number.
- **3.10–3.12, 3.17, 3.20, 3.23–3.26** Wording and stale text as listed. Mark the s10 unmodelled-effects table and the
  s09 CLEARANCE explanation "to be revised after the stand-proximity finding (16-Nov)". Draw the kg 0.4 line on top
  or dashed.

### Stage 3 summary
Counts: **CRITICAL 0, MAJOR 2, MINOR 17, OK 9.**

Three most important findings:
1. **The models and the robustness numbers are computed correctly.** Three independent implementations of the
   closed loop agree: Simulink vs MATLAB within 0.00013 mm at all five delays, and my own simulation within 0.005 mm.
   Every s11 margin, the worst-Ms point, the Exp C contradictions and the \|W T\| peak 0.9973 were recomputed with my
   own loop model; the delay estimate d ≈ 0.5 was reproduced with a different estimator (3.2, 3.13, 3.19).
2. **The PS9 R4 claim holds only narrowly.** The pre-declared target worst Ms ≤ 2 fails (2.23). Robust stability is
   shown only in the split version, at 0.997 of the limit, and it leaves no room at 2–10 Hz for anything outside the
   parametric model. None of this is documented outside the console (3.14). The actuator gain error kg 0.4–2.0, listed
   in the uncertainty table, is **not** covered (33 of 243 grid points unstable at kg 0.4) (3.16).
3. **s09's "lab-like" case is not lab-like, and its "ok" ignores a 0.45 mm sustained oscillation** (3.22). The tilt
   artifact is applied at every gap, while the lab shows ≤ 0.05 mm of rocking at 9–11 mm.

For Stage 4 to look at:
- The s09 CLEARANCE explanation and 3b ("model overpredicts near 11 mm, so pessimistic") and the s10 5c pattern (lab
  overshoot falls toward 11 mm, model rises) in the light of the stand-proximity finding (3.11, 3.23, 3.24).
- s14's robustness numbers come from `RB.opt2curves`: I confirmed W ≈ 0.52–0.57 and Wu 0.17–0.24 at 2.4 Hz (README:
  "W ~ 0.55", "Wu 0.17–0.24"). But Wu is **≈ 0 at 5.9–8.9 Hz**, so any unmodelled effect near crossover matters more
  than one at 2.4 Hz.
- The tilt-artifact model (0.27 mm from the 39 g 11.5 mm hold, applied at all gaps) (3.22).

For Stage 5: test d and the coil τ with the 16-Nov sine-injection data (`PARAMETERS.md` says τ ≈ 21 ms at 12–40 Hz,
close to the worst-Ms corner τ = 20 ms; it also says the delay was "estimated from levitation data", but it came from
run 3 with the ball on the stand). Check variant D lab vs simulation (s09/s11 still call D "simulation only").

---

## Stage 4 (2026-11-16) — Open puzzles from 13-Nov (s13, s14) after the stand-proximity finding

Scope: `scripts/s13_overshoot_mismatch.m`, `scripts/s14_rocking.m`, the s13/s14 sections of
`data/lab_2026-11-13/README.md`, figs `p10_*`, `p11_*`. Judged against `data/lab_2026-11-16/README.md` ("Main
results"). The 16-Nov scripts s16–s18 themselves are Stage 5; here their console output is used, and the facts the
verdicts depend on were re-checked with my own code.

### How it was checked
1. Read s13 and s14 in full, and the 13-Nov and 16-Nov README sections that quote them.
2. Ran s13 and s14 on the scratch copy: s13 **13 PASS / 1 FAIL** (the FAIL is intended: "H-force alone would
   explain…"), s14 **8 PASS / 0 FAIL**. Every number in the 13-Nov README's s13 and s14 sections matches the console.
   Also ran s16 (9/2), s17 (10/1), s18 (5/0) to have the 16-Nov facts; their numbers match the 16-Nov README.
3. Own checks (scratch `s4/indep/`):
   - `stand_spring.py`: closed-loop modes of the vertical loop at 11.5 mm with (a) a stand "spring" (upward stand
     force growing toward the stand, i.e. lower a21, down to negative values) and (b) a reduced **sensor gain**
     (reading moves s × the true motion) in the outer loop only. Neither case was in s14's scan.
   - `stand_checks.m`: Newton residual with a different acceleration estimator (local quadratic fit over ± 7 samples)
     on the decisive steps; true hover current vs the 13-Nov force law on the **lowered-stand** sweep and its
     11.5 mm hold (zero drift linear between coil-off readings); 2.4 Hz content of the slow ramp near the stand.
   - Opened `models/my_driver.slx`, `my_cascade_rt.slx`, `my_cascade_sweep_rt.slx` as zip/XML: the
     "Position scaling [V] to [m]" block is a legacy `Lookup` block with no lookup method saved, i.e. the default.
     `lookup_default.m` confirms that the default is `Interpolation-Extrapolation` (linear).

### Verdict on each s13 / s14 conclusion

| Conclusion (13-Nov README / console) | Verdict | Evidence |
|---|---|---|
| s13 §1: lab down-step overshoot falls toward 11 mm, the model's rises; on 10.5 → 11 the lab is ≤ ½ the model | **Stands** (record), **re-interpret** | Reproduced. Those are exactly the steps whose overshoot reaches 0.6–0.9 mm above the stand. s17: down-steps without a spike have lab/model median 0.99 |
| s13 §2: H-lin (linearization) rejected | **Stands** | s10 (Stage 3, 3.11) |
| s13 §3: H-table (calibration-table kinks) rejected | **Stands**, premise now verified | The interpolation was "ASSUMED linear"; the lab model files confirm linear (`Interpolation-Extrapolation`, default). Item f of the lab plan is answered |
| s13 §4: braking spike on every 10.5 → 11 step at x ≈ 11.0 mm, ~35 ms after the step | **Stands** (reproduced) | Own estimator: 13-Nov 39 g −1.28 m/s² at 39 ms, x 11.06 mm; 16-Nov normal stand −1.13 at 36 ms. The size depends on the estimator (s13 already showed this) |
| s13 §4: "position and timing NOT separable" | **Superseded** | s16: position-tied (spike time 24–57 ms, position within 0.09 mm). s17 and mine: **stand-tied**. The same 10.5 → 11.0 step on the lowered stand shows **no** spike (mine: −0.60 m/s², control up-step −0.51). A 10.5 → 11.6 jump on the lowered stand spikes at 12.46 mm = 0.66 mm above that stand (mine: −1.89) |
| s13 §6 candidates: (i) contact near 11 mm, (ii) sensor feature finer than the table, (iii) tilt | **Superseded** | (ii) as a feature fixed in sensor coordinates is rejected: the spike moves with the stand. (i) as contact/friction is unlikely: the slow ramp shows no up/down hysteresis (s18). (iii) was never tested. Replacement: a stand-proximity effect whose mechanism is still open (see 4.15) |
| s13 §5a: "hovering at 11.5 mm needs ×1.04–1.08 the force exp(−x/λ) extrapolates" (H-force: the magnet force decays more slowly beyond 11 mm) | **Superseded: H-force rejected** | Lowered stand (16-Nov, same 39 g ball, 13-Nov force law, own zero-drift correction): the force multiplier needed is **×0.994–1.010 at 9–11 mm and ×1.011 at 11.5 mm**, which is 1.69 mm above that stand. With the same method the 13-Nov 11.5 mm hold (0.43 mm above the normal stand) needs ×1.070. So the hold deficit belongs to the stand, not to the force law |
| s13 §5b: lift-offs passing 11.4–11.8 mm show no stronger force (×1.00 / ×0.96) | **Stands as data; conflict now OPEN in a new form** | Those lift-offs pass 0.1–0.5 mm above the normal stand. That is the same height where the hold (×1.07) and the 16-Nov ramp (−65 mA, ≈ ×1.15) show the static stand effect. So "static" (holds, ramp) and "fast passage" (lift-offs) disagree at the same height. **Needs re-run** binned by height above the stand, adding the two lowered-stand lift-offs |
| s13 §5c: "IF H-force holds it halves the 10.5 → 11 gap (52 % explained)" | **Superseded** | The hypothesis is rejected. The 13-Nov README sentence "Partly explained by s13" is stale |
| s14 §1: rocking band ≤ 0.051 mm rms at 9–11 mm; 0.250 / 0.133 / 0.013 mm at 11.5 mm | **Stands** (record), **re-interpret** | Lowered-stand 11.5 mm hold: band rms **0.050 mm**, spectral peak 4.3 Hz (mine; s17: x std 0.115 mm). The amplitude depends on the distance from the **stand**, not on the gap |
| s14 §2: 39 g hole-up = limit cycle, 42 g = damped mode (ζ ≈ 0.07) | **Stands** as a description | n = 1 record each |
| s14 §3: "the 2.4 Hz current is the controller's response to x ⇒ sustained through the loop" | **Stands, but the check is weak** | see 4.11 |
| s14 §4: "the vertical loop has no mode below 6.6 Hz even with a21 cut to 200: the rocking is an EXTRA mode, most likely a rotation of the ball" | **Wrong as stated / superseded** | see 4.12 |
| s14 §5: "unmodelled part ≥ 0.19 ≈ the whole margin at 2.4 Hz; keep 11.5 mm out of the claimed range; measure L(jω) at 9–11 mm" | **Conclusion stands, reason changes** | see 4.13 |

### Findings

| # | File / claim | What I did | Result | Class |
|---|---|---|---|---|
| 4.1 | s13 / s14 console vs 13-Nov README | Re-run | All numbers match (s13: spikes −2.0/−1.8/−1.9 m/s² at 33–36 ms; ×1.04–1.08; ×0.997 ± 0.011 / ×0.959 ± 0.009; lag −0.8 ms; 0.42 → 0.20 mm. s14: ≤ 0.051 mm; CV 0.04 / 0.56; 154 / 183 / 154 A/m; ≥ 6.6 Hz; 0.84, W 0.55, Wu 0.17–0.24, ≥ 0.19) | OK |
| 4.2 | s13 §1 pattern | Re-run | Reproduced (lab 0.65 → 0.28 mm, model 0.55 → 0.70 mm) | OK |
| 4.3 | s13 §2 H-lin rejected | Stage 3 3.11 | Correct | OK |
| 4.4 | s13 §3 H-table; "interpolation ASSUMED linear" | XML of three lab models + MATLAB default of the legacy `Lookup` block | Linear interpolation confirmed for the lab model copies of 16-Nov (caveat: the `.slx` files were saved after the runs, `models/README.md`). Kink artefact ≤ 0.20 m/s² vs spikes ≥ 0.99 m/s² at every stride | OK |
| 4.5 | s13 §4 spike reproduced with a different estimator | `stand_checks.m` | Yes, at the same time and place, but smaller (−1.28 vs −2.01 at h = 5). The 16-Nov **10.8 → 11.1** step, which s16 counts as a spike (−1.23 against a −1.22 threshold), gives −0.81 with my estimator, only 1.6× the control step. That one spike is marginal | OK (note) |
| 4.6 | s13 console summary and 13-Nov README: "position and timing confounded", candidates (i)–(iii), "OPEN" | Compared with s16, s17 and my check | Superseded by the 16-Nov results (table above). The text in s13 §6 and the README is stale | MINOR |
| 4.7 | s13 §5a / §5c and README: H-force "UNRESOLVED", "IF the holds are right … halves the gap" | Lowered-stand hold current vs the force law | **H-force rejected**: ×1.011 at 11.5 mm with the lowered stand vs ×1.070 on the normal stand (same method). The 52 % figure must not be used | MINOR (stale, but must not reach the report) |
| 4.8 | s13 §5b lift-off result vs the static stand effect | Comparison of heights above the stand | At 0.1–0.5 mm above the stand the holds and the ramp need ×1.07–1.15, while lift-offs show none. Unresolved; possible reasons (fast passage, squeeze film during the upward pull, how the reading behaves while moving) are untested. Re-run s13 §5b binned by **height above the stand**, including the lowered-stand lift-offs | MINOR (open) |
| 4.9 | s13 "record:" PASS lines (e.g. "position and timing are NOT separable", "CONFLICT …") | Read code | These are statements of a result written as checks. They cannot fail in a meaningful way and inflate the PASS count (s13: 4 of 13; s14: 3 of 8). The post-hoc thresholds are disclosed (s13 line 171) | MINOR |
| 4.10 | s14 §1–2 amplitudes and limit-cycle/damped classification | Re-run + lowered-stand hold | Correct as records. The lowered stand removes the 11.5 mm rocking (0.050 vs 0.250 mm band rms; one run each) | OK |
| 4.11 | s14 §3: "measured i/x equals the controller ⇒ the oscillation is sustained through the loop" | Reasoning | In closed loop **any** motion of the reading at 2.4 Hz produces i = C(jω)·x_read, whatever its cause, so this check cannot fail while the inner loop works. The 42 g case is already 21 % / −14° off. The conclusion (the coil is the energy source) is reasonable but is not shown by this check | MINOR |
| 4.12 | s14 §4 and 13-Nov README: "not a vertical-loop mode … an EXTRA mode, most likely a rotation of the ball (s08 Newton test)"; also in s08 6b ("a rotation is involved"), the s10 unmodelled-effects table, and s09's tilt-artifact case | `stand_spring.py` (own loop model, 39 g, 11.5 mm, d 0.5) | s14 lowered a21 only to +200 s⁻². (a) A stand **spring** (a21_eff down to −10 000 s⁻²) moves the slowest mode **up** to 12–22 Hz, so it cannot make 2.4 Hz. (b) A reduced outer-loop **sensor gain** s gives an **unstable** mode: s = 0.6 → 3.1 Hz (ζ −0.06), 0.5 → 2.6 Hz, 0.45 → **2.4 Hz**. That is the vertical loop, with a reading that moves less than the ball near the stand. It fits three observations: s08's Newton slope **1.7** (= 1/s, s ≈ 0.59); a **limit cycle** (the gain loss exists only inside a zone near the stand, so the amplitude settles where the ball spends enough time outside it); and the **disappearance with the lowered stand**. So "an extra mode, most likely a rotation" is no longer supported; a stand-zone sensor gain is a candidate that the data fit better. **Not proven** either: not observed directly, and it does not explain why the 42 g ball barely rocks at the same height | **CRITICAL** (for any report use) |
| 4.13 | s14 §5: "unmodelled part ≥ 0.19, about the whole margin at 2.4 Hz; keep 11.5 mm out; measure L(jω) at 9–11 mm" | Reasoning + 16-Nov data | "Keep 11.5 mm out" **stands** for the normal stand; the reason is now "within ~0.7 mm of the stand". The number 0.19 treats the effect as an unstructured extra mode. If it is a sensor-gain loss (−40 to −55 % on the outer loop), that number does not describe it. The sine injection (16-Nov, 10 mm) did **not** resolve 1.5–2.4 Hz (> 20 % error, s17), so "measure L(jω) in the rocking band" is still not done. It matters less now: at 10 mm the ball is 1.9 mm above the stand | MINOR |
| 4.14 | Force law across days (bonus from 4.7) | Lowered-stand sweep, 16-Nov | The **13-Nov** force law (λ 5.905 mm, c 3.294) predicts the **16-Nov** true hover current within ± 1 % force at 9, 9.5, 10, 10.5, 11, 11.5 mm (×0.994–1.011, 11 plateaus, 1.7–4.2 mm above the stand). This is an **out-of-sample** validation of the R2 model away from the stand (compare Stage 3 3.21, where the agreement was in-sample) | OK |
| 4.15 | 16-Nov README: "equivalent to ~0.8 mm of reading error … Leading (unproven) explanation: the stand shadows the optical sensor" | Arithmetic on s18's ramp table (78 mA/mm) | A pure reading error cannot produce the static curve. From 0.68 to 0.48 mm above the stand the residual grows from −24 to −65 mA, i.e. the implied reading error grows by 0.52 mm while the reading moves only 0.2 mm. The true ball would then have to move **up** 0.32 mm as the reading moves down: a negative sensor slope, which would reverse the feedback sign. Yet the ramp tracked within 0.001 mm. So at least part of the static effect is a **real force** (or the force law differs there), and "shadowing" can at most be part of the story. With 4.12, the data point to two effects or a different mechanism | MINOR (wording; Stage 5) |
| 4.16 | Size of the static effect | Compared numbers | 13-Nov hold, 0.43 mm above the stand: −30 to −32 mA (×1.07). 16-Nov ramp, 0.48 mm above the stand: −65 mA (≈ ×1.15). These differ by about 2× at nearly the same height. Different days, different stand reading (11.92 vs 11.85 mm), different zero corrections, and the ramp residual is relative to a local fit. Must be reconciled before quoting "15 % of the weight" | MINOR (Stage 5) |
| 4.17 | Does the slow ramp rock near the stand? | 1.5–3.5 Hz band of x vs height above the stand | No: 0.013–0.018 mm band rms at 0.4–0.8 mm above the stand, while the 13-Nov hold at 0.43 mm rocked at 0.25 mm. Under the sensor-gain hypothesis the mode grows slowly (ζ ≈ −0.06 → e-folding ~1 s) and the ramp spends only ~1 s there, so this neither confirms nor refutes it. A hold at 11.4–11.5 mm on the normal stand with x_ref ramped slowly in would test it | MINOR (open) |
| 4.18 | Strength of the "stand-tied" evidence | Counted | Clean comparison: the same 10.5 → 11.0 step spikes on the normal stand in 5 / 5 cases (13-Nov × 3, 16-Nov × 2) and **not** on the lowered stand (1 / 1). The one lowered-stand spike comes from a 1.1 mm jump (a different, faster step). The rocking comparison is one run per stand height. The conclusion is well supported qualitatively but rests on **one lowered-stand session** | MINOR (state n) |
| 4.19 | Knock-on stale text (outside s13 / s14) | Grep / read | s08 6b and 13-Nov README "a rotation is involved"; s09 tilt case built on the rotation hypothesis (Stage 3 3.22); s09 CLEARANCE and 3b "model overpredicts near 11 mm, so pessimistic" (Stage 3 3.23–3.24). Better: the model lacks the stand effect, and away from the stand it matches (s17 lab/model 0.99). s10 unmodelled table rows "rocking/tilt" and "calibration nonlinearity (hypothesis for the 11 mm mismatch)"; `maglev_cases` U row "tilt artifact" | MINOR |

### Proposed fixes (author decides)
- **Re-run / extend s13:** replace §5 (H-force) by the lowered-stand hold check (4.7, 4.14). Bin the Newton spike and
  the §5b lift-off force by **height above the stand**, including the 16-Nov runs and the lowered-stand lift-offs
  (4.8). Rewrite the §6 summary (4.6). Turn the "record:" lines into plain output or label them `[record]` (4.9).
- **Re-run / extend s14:** add the sensor-gain and stand-spring scans to §4 (4.12). Add the lowered-stand 11.5 mm hold
  to §1. Reword §5: "the effect lives within ~0.7 mm of the stand; the claimed range is x ≤ stand − ~0.9 mm"
  (4.13). Drop "most likely a rotation" unless new evidence supports it.
- **Report (R2, unmodelled dynamics):** "Within ~0.7 mm of the stand the rig shows a static, stand-tied effect
  (current up to 30–65 mA below the force law) and, on 13-Nov, a 2.4 Hz limit cycle at 11.5 mm. Both vanish with the
  stand lowered (one session). The mechanism is not identified. A loss of position-sensor gain to ~0.5 near the stand
  reproduces the 2.4 Hz mode in the linear model but not the static current deficit. The model and robustness results
  apply ≥ ~0.9 mm above the stand." Cite 4.14 as the out-of-sample force-law validation.
- **16-Nov README (Stage 5):** soften "leading explanation: shadowing" (4.15) and reconcile the 30 vs 65 mA
  magnitudes (4.16).
- **Stale text (4.19):** mark the s08 6b, s09, s10 and `maglev_cases` items "superseded by the stand-proximity finding".

### Stage 4 summary
Counts: **CRITICAL 1, MAJOR 0, MINOR 11, OK 7.**

Three most important findings:
1. **H-force is rejected; the 13-Nov force law holds out-of-sample.** With the stand lowered, the same ball hovers at
   11.5 mm (and 9–11 mm) on the force law within ± 1 %. The ×1.04–1.08 "extra force" of s13 belongs to the stand.
   This also gives the report a clean cross-day validation of the plant model (4.7, 4.14).
2. **s14's "not a vertical-loop mode, most likely a rotation" no longer holds** (CRITICAL if used). A loss of
   position-sensor gain to 0.45–0.6 near the stand makes the vertical loop itself go unstable at 2.4–3.1 Hz, matching
   the frequency, s08's Newton slope 1.7, the limit-cycle character and the disappearance with the lowered stand. A
   stand spring cannot do it. This is plausible, not proven (4.12).
3. **The stand-proximity story is not closed.** A pure reading error ("shadowing") cannot produce the static current
   curve without a negative sensor slope (4.15). Lift-offs show no extra force at the same height (4.8). The
   hold and ramp magnitudes differ 2× (4.16). The lowered-stand evidence is one session (4.18).

What still stands from 13-Nov: the overshoot pattern (as a record), H-lin and H-table rejected (H-table premise now
verified), the spike itself, the rocking amplitudes, and "keep 11.5 mm out of the claimed range" (normal stand).

For Stage 5 to look at:
- s16 spike criterion (one spike sits on its threshold, −1.23 vs −1.22; my estimator gives −0.81) and s17's
  "criterion set after the first look" (disclosed).
- s18 ramp: the far-field fit window, zero-drift correction, and the 30 vs 65 mA discrepancy with the 13-Nov hold
  (4.16); the "15 % of weight / 0.83 mm reading error" equivalence (4.15).
- s17 sine injection: coil τ 20.7 ms at 12–40 Hz vs the model's 27 ms (Stage 3: worst Ms sits at τ 20 ms); crossover
  29 vs 23.6 Hz; |Δ T| 1.08 at 2 Hz (flagged as too noisy). Does it bound the delay d independently?
- `group 28/PARAMETERS.md` against all of the above (delay "from levitation data", τ, the stand effect).

---

## Stage 5 (2026-11-16) — The 2026-11-16 session (s15–s18, 16-Nov README, models/README, `group 28/`)

Scope: `scripts/s15_rebuild_lab_models.m`, `s16_analyze_3a.m`, `s17_analyze_1116.m`, `s18_analyze_D_ramp.m`,
`data/lab_2026-11-16/README.md`, `models/README.md`, `group 28/README.md`, `group 28/PARAMETERS.md`, `group 28.zip`,
figs `p12`–`p15`. Also answers the Stage 3/4 hand-overs (delay d and coil τ from the sine data, variant D lab vs
simulation, the s16 spike threshold, the s18 ramp method, the 30 vs 65 mA discrepancy, PARAMETERS.md).

### How it was checked
1. Read all four scripts, both READMEs and both package files in full.
2. Re-ran on a scratch copy of the repo (repo figures and `.mat` files untouched): **s15 (stub mode) 33 PASS / 0 FAIL,
   s16 9 / 2, s17 10 / 1, s18 5 / 0.** Every number in the 16-Nov README "Runs" table and "Main results", and in
   `models/README.md` about 16-Nov, was compared with the console.
3. s15: unzipped the 13-Nov build caches (`models/build_cache_2026-11-13/*.slxc`) and compared every value in s15's
   `V` struct with the generated `*_data.c`, and the controller wiring with the generated `*.c` (sum sign, integrator
   update, switch semantics, kg position, sweep-clock gate, Flat lookup, stop times).
4. 16-Nov lab models: unzipped the six `models/my_cascade_*_rt.slx` and read gains, i0, clamp, reset, lookup tables and
   interpolation settings from the XML; confirmed in R2026a that an unset `1-D Lookup Table` InterpMethod is
   "Linear point-slope".
5. Own code (scratch `s5/indep/`): `indep_s5.m` — PARAMETERS.md numbers from the saved fits and the 12-Nov coil test;
   sine injection re-estimated with a plain least-squares sinusoid fit (instead of s17's Hann lock-in) and a complex
   fit of the coil (k_a, τ, d); the ramp residual against the **absolute** 13-Nov force law with the current zero taken
   from the coil-off readings before and after the run (instead of s18's local far-field fit); the 13-Nov 11.5 mm hold
   by the same method; per-plateau oscillation on the lowered-stand sweep; lowered-stand lift-off simulated over the
   9 corners s18 uses; variant D lift metrics. `standforce_lift.m` — exploratory: lift-offs simulated with a
   stand-tied force multiplier. `misc_checks.m` — remaining README facts.
6. Looked at `p12`–`p15`, and at the 12-Nov screenshot 08.

### Findings

| # | File / claim | What I did | Result | Class |
|---|---|---|---|---|
| 5.1 | s15: "every value from the deployed 13-Nov build caches" | `*_data.c` and `*.c` of `my_cascade_rt`, `_kg_rt`, `_sweep_rt` | All values match (Kp 151.2, Ki 734, Kd 2.6, i0 0.75, clamp ±0.3, i_ref 0..2, i_test 0.5, Kc 2.05, 1/2.44, u 0..0.9, x_ref 0.011, lift 0.0115, table and breakpoints, kg 1, stop times 65/75/90). The C code confirms e = x − x_ref, a forward-Euler integral with state clamp, u = Kc(i_ref − i) + i_ref/2.44, kg after Add2, Flat lookup (index only), sweep clock gated by x < 0.0115, Manual Switch setting 1 = first input (so s15's `sw 0` = coil off is right) | OK |
| 5.2 | s15 "tested on the laptop with a stand-in plant, 33/0" (`models/README.md`) | Re-ran in stub mode | 33 PASS / 0 FAIL. The controller-recurrence test (C8) reaches every limit and can fail | OK |
| 5.3 | s15 checks C4 ("all parameters = deployed values") and C3 in stub mode | Read code | C4 compares the built blocks with the same `V` used to build them, and in stub mode C3 checks a solver the script itself set. They catch API failures only; the real claim (V = deployed) was a manual step, now verified (5.1). Never run on the lab PC (README says so) | MINOR |
| 5.4 | `models/README.md` table: controller values, variant D (i0 0.85, clamp ±0.45, level reset, saved with run = 0), ramp table and "Linear", ramp116 threshold 12.0 mm | XML of the six `.slx` | All match. `my_cascade_ramp_rt` saves no InterpMethod, i.e. the default "Linear point-slope" (confirmed in R2026a). D: `ExternalReset level`, `run` saved as 0 | OK |
| 5.5 | Saved lab model copies vs their use | XML | (a) `my_cascade_ramp116_rt.slx` is **still saved Flat**: rebuilding it repeats the 16-Nov mistake. (b) `my_cascade_steps_rt` breakpoints [0 8 13 18 23 28 33]: the first level lasts 8 s, not "every 5 s" (16-Nov README). (c) The demo model `my_cascade_sweep_rt` is saved with `x_ref manual` = 11.5 mm, 0.4 mm above the normal stand (the rocking height) | MINOR |
| 5.6 | s16 console vs README and vs the values s17 hard-codes from s16 | Re-run | Match (rests 11.903 / 11.887, spikes 24–57 ms at 11.05–11.14 mm, lab/model 0.33–0.48 on down-steps, 10.5 → 11 lab 0.26 / 0.35 vs model 0.64 / 0.73). The two FAILs are honest data-quality flags (coil-off tails 0.44 / 0 s); s16 does not need the tail because it takes the current zero per step from the 0.5 s before it | OK |
| 5.7 | s16 "POSITION-TIED: time spread ≥ 20 ms, position spread ≤ 0.12 mm" | Console numbers | (a) The 33 ms time spread comes from **one** step (42 g 10.8 → 11.1 at 57 ms; the other five are 24–36 ms). (b) Every down-step ends at 11.0 or 11.1 mm and the spike comes 3–9 ms after passing 11.0, so "tied to x ≈ 11 mm" cannot be separated from "tied to arriving at the target". The spread of x at the spike (0.09 mm) vs that of x − target (0.16 mm) favours position only weakly (n = 6). The marginal spike (−1.23 vs −1.22) is Stage 4 4.5. The deciding evidence is s17's lowered-stand control (stand-tied, not x-tied), as s16's own NOTE says; the PASS message overstates what s16 alone shows | MINOR |
| 5.8 | s17 console vs README | Re-run | All README numbers match (29 Hz, 47°, \|S\| 1.51 vs 1.58, τ 20.7 ms, > 20 % error at 1.5–2.4 Hz, spike distances 0.70–0.85 mm, 0.115 vs 0.253 mm, 4.3 vs 2.43 Hz, lift-offs 8.59 / 8.65 mm). The FAIL (ball within 0.03 mm of the stand on the Flat 0.9 mm step) is honest | OK |
| 5.9 | s17 sine method: L = −U_c/U, S = U/D = 1/(1+L), model L = −(C_x G_xu − K_c G_iu) | Derived u_c = (1/k_a + K_c)·PID(x) − K_c·i; own LS sinusoid fit | Definitions and signs correct; Kd on the backward difference and the forward-Euler integral match the deployed C code. My estimator agrees with s17 at 6–40 Hz within ~10 % (40 Hz: 0.757 / 0.788 vs 0.749 / 0.812), except **12 Hz, A 0.01: 1.36 vs 1.59** (estimator-dependent; s17's se of 9 % understates it). At 1.5–4 Hz the two estimators differ by 7–40 %, confirming "too noisy" | OK |
| 5.10 | README: "crossover ≈ 29 Hz (model 23.6), phase margin ≈ 47°" | Own interpolation with each amplitude pair at 20 / 40 Hz | Crossover **27.7–30.4 Hz**, PM **43–50°**, depending on which amplitude is used (s17 takes the A 0.04 point at 20 Hz only because of the time order). The model's PM (d 0.5) is **45.4°**, not quoted. So the measured PM agrees with the model; only the crossover is ~4–7 Hz higher (\|L\| 4–36 % above the model at 20–40 Hz) | MINOR |
| 5.11 | README / PARAMETERS.md: "coil time constant 20.7 ms (≈ 21 ms) at 12–40 Hz"; Stage 3: does the sine data bound d? | Complex fit of G_iu = I/U at 12–40 Hz, free k_a and τ, for d = 0…1 | s17 fits the **magnitude only, with k_a fixed**: above the corner (5.9 Hz) the magnitude fixes only k_a/τ (τ 20 / 25 / 27 ms fit equally with k_a 2.32 / 2.77 / 2.96). With the phase: d 0.5 → k_a **2.40**, τ **21.8 ms** (cost 0.098); d 0.6 → 2.21, 19.8 ms (0.101); d 0.3 → 2.85, 26.8 ms (0.142); d 0 and d 1 cost 0.31 (rejected). So (a) **the sine data, taken while levitating, independently support d ≈ 0.5–0.6** and reject 0 and 1 (6 points, no formal interval); (b) τ ≈ 22 ms holds **given d ≈ 0.5**, and then k_a = 2.40 agrees with the static 2.43. The nominal 27 ms is at the slow end; Stage 3's worst-Ms corner (τ 20 ms) is close to the measured value | MINOR (wording) |
| 5.12 | s17 PASS "where L is measured to < 20 %, \|ΔT\| < 1 (max 0.74): the model error there cannot destabilize the loop" | Read code | Post-hoc (disclosed). The wording overclaims: 10 frequencies, none at 1.5–2.4 Hz or at the model's \|S\| peak (45 Hz), and the measured L belongs to a loop already known to be stable. Say "the model error at the measured points is below the robust-stability bound" | MINOR |
| 5.13 | `p13_sine_loop.png`, phase panel | Looked | The model curve is unwrapped from +120° while the lab points are wrapped to −240…−140°, so the curve sits **+360° above** the points and looks like a total mismatch (the angles agree mod 360°). The ratio panel joins points in time order (vertical jumps at repeated frequencies) and shows the noisy 1.5–4 Hz points unflagged. Fix before using the figure | MINOR |
| 5.14 | README: "down-steps with a spike: lab/model 0.33–0.56; without: median 0.99" (s17 check, "criterion set after the first look") | Console | The check's "with spike" group has **n = 1** (the lowered 10.5 → 11.6 step); 0.33–0.48 come from s16 as text. The "without" group spans 0.61–1.20, so the ranges nearly touch (0.56 vs 0.61); the medians (≈ 0.41 vs 0.99) separate clearly. These are **16-Nov** steps, while the README sentence says "the 13-Nov overshoot mismatch" | MINOR |
| 5.15 | s17 text "(model from 13.0–13.5 mm: 8.65–8.70)" and README "Lift-off from the lowered stand … closest approach 8.59–8.65 mm (simulation 8.65–8.70)" | Grep (hard-coded, computed in no script); own simulation over the 9 corners s18 uses (d 0.3 / 0.5 / 0.6, c ×0.95 / 1 / 1.05) | 8.65–8.70 is the **worst corner** of the 9 cases (from 13.5 / 13.0 mm), not the nominal. Nominal (d 0.5, c ×1): **8.89–8.90 mm**; range 8.68–9.14 mm from the actual rest readings 13.13 / 13.19 mm. The lab (8.65 / 8.59) rises 0.25–0.3 mm higher than nominal, and the 13.19 mm lift (8.59) is **outside all 9 cases**. The README sentence reads as agreement; it is the edge of the set or beyond. (Normal stand for comparison: sim worst 8.84, lab 8.95–9.07, inside) | MAJOR |
| 5.16 | README: "11.5 mm hold with the stand lowered: no 2.4 Hz rocking (x std 0.115 mm, peak 4.3 Hz)" | Same statistic on every plateau of that run | 9–11 mm plateaus of the same run: std 0.055–0.120 mm, 1.5–3.5 Hz rms 0.037–0.059 mm; the 11.5 mm hold: 0.115 / **0.048** mm. So the hold is ordinary for that run. The clear contrast with 13-Nov is the band rms (0.048 vs 0.25 mm, Stage 4), not the std (0.115 vs 0.253) | OK |
| 5.17 | s18 console vs both READMEs | Re-run | Match (reset: i_ref 0.969 / 0.969 / 0.974 A vs expected, no drift; D lifts 33 / 30 ms, closest 10.60 / 10.38 mm, settle 0.14 s; lab 8.95–9.07 mm, 0.27–0.52 s; sim D ≥ 10.96, lab ≥ 8.84; ramp −65 mA at 0.48 mm, 10.2 se, 78 mA/mm, 0.83 mm, 15 %) | OK |
| 5.18 | Variant D reset and lift metrics | Own code | Same lift times and closest approaches. x_ref is not logged; from x, the typed step to 10.5 mm happened ~9–14 s after lift 1, outside the 1.5 s lift window, so it does not affect the settle metric | OK |
| 5.19 | `models/README.md`: "simulation is optimistic for D" (10.38–10.60 lab vs ≥ 10.96 sim) | s18 console + `standforce_lift.m` | The **lift time** also differs: sim ≤ 90 ms (nominal 48 ms) vs lab 30–33 ms, not mentioned. Exploratory: a stand-tied force multiplier (1 beyond 0.78 mm above the stand, rising linearly to ×1.2–1.37 at contact, the shape measured on the ramp) gives D lift times of 27–30 ms (matches) but closest approach still 10.77–10.97 mm (lab 10.38–10.60). A faster coil (τ 22 ms) does not help (11.00 mm). So the stand effect can explain the timing; **0.2–0.6 mm of D's extra rise remains unexplained**. Not a script error; an open model gap at lift-off | MINOR (open) |
| 5.20 | s18 ramp residual (−65 mA at 0.48 mm above the stand, onset ~0.7 mm) | Absolute residual vs the **13-Nov** force law, current zero linear between the coil-off readings (0.0558 → 0.0236 A, −1.12 mA/s; s18's hold-based value −1.16) | Reproduced: **+1 to +4 mA** from 1.33 down to 0.78 mm above the stand, then −9.6 (0.73 mm), −20 (0.68), −31, −41, −50, **−58.5 mA (0.48 mm)**; relative to the far-field mean −60.7. Force multiplier needed: ×1.002 at 0.78 mm → **×1.145** at 0.48 mm. So s18's −65 mA is right within ~6 mA, and the 13-Nov force law again predicts the 16-Nov hover current within ~0.5 % away from the stand (adds to Stage 4 4.14). The se assumes a 10-sample correlation; the current's autocorrelation in a hold dies within 1 sample, so the se is conservative; the far-field extrapolation error (not in the se) is ~4–6 mA by this comparison | OK |
| 5.21 | 16-Nov README "equivalent to ~0.8 mm of reading error … Leading (unproven) explanation: the stand shadows the optical sensor"; PARAMETERS.md "The likely cause is the stand shadowing the optical sensor (not proven)" | s18's own up/down columns; 5.20 | **Model-free**: as the set point moves 11.025 → 11.375 mm (toward the stand) the drift-corrected hover current **falls** by ~35 mA (up: 38.5 → 2.7, down: 38.8 → 4.2 mA), while the force law needs +27 mA. If the force were unchanged and only the reading were wrong, the true ball would have to rise ~0.45 mm while the reading moved down 0.35 mm: a **negative** sensor slope, which reverses the feedback sign; yet the ramp tracked within 0.001 mm. So shadowing **alone is excluded**: at least part of the effect is a real upward force on the ball near the stand (mechanism unknown). This turns Stage 4 4.15 (argued via a fit) into a direct observation. "0.8 mm of reading error" is therefore not a physical equivalent; "15 % of the weight" is ≈ 14 % (s18 divides by the logged current at 10.5 mm, offset included) | **CRITICAL** (one-sentence fix, but the stated cause is contradicted and sits in a document given to another group) |
| 5.22 | s18 "RECORD: … the stand effect is STATIC" | Read code | `chkp(true, …)` always prints PASS; only the counter uses `isStatic`. If the test failed, the console would show PASS and the summary a FAIL. The two-outcome rephrasing after a first FAIL is disclosed | MINOR |
| 5.23 | Stage 4 4.16: 13-Nov hold −30 mA (0.43 mm above the stand) vs 16-Nov ramp −65 mA (0.48 mm) | Same absolute method on the 13-Nov hold | 13-Nov hold: **−39 mA** with a constant current zero (that record has no coil-off tail), −30 to −34 mA if the usual −0.5 to −0.85 mA/s drift is assumed (Stage 4's ×1.07). Ramp by the same method: −58.5 mA. Near the stand the residual changes by ~10 mA per 0.05 mm (~200 mA/mm), so a factor 1.5–2 corresponds to a **0.1–0.15 mm** shift of the effective stand position between days, smaller than the uncertainty of the rest reading as a stand reference (hole orientation alone moves it 0.2 mm). Not a contradiction, but "65 mA at 0.5 mm" does not transfer between days. The onset (~0.7–0.8 mm above the stand) is the robust number | MINOR |
| 5.24 | New evidence at contact (in no README) | 12-Nov coil test and screenshot 08, 39 g ball | Coil test, stand at 12.9 mm: the ball left the stand at logged 0.930 A (zero 0.060 A → ≈ 0.87 A true), while the force law needs **1.020 A** true (×1.37 in force). Screenshot 08, stand at 11.8 mm: 0.87 A logged (≈ 0.82–0.83 A true) for 30 s did **not** lift, while the law needs 0.93 A (so < ×1.27). Both point to an upward stand effect at contact but disagree on its size; the 12.9 mm value extrapolates the law 1.9 mm past its fit range, and the 11.8 mm value is a screenshot reading. Plausible, unverified; context, not a number | MINOR (open) |
| 5.25 | PARAMETERS.md numbers | `indep_s5.m` | λ 5.90 mm (5.9046), c 3.29 / 3.02 N/A² (3.2936 / 3.0228), **42** points at 9.00–11.00 mm (18 morning + 24 afternoon), i_eq table 0.73 / 0.79, 0.80 / 0.86, 0.87 / 0.94 A, a21 1661 s⁻², √a21 40.76 rad/s = 6.49 Hz, b 24.59, k_a 2.43 (2.4321), low-end 1.9 (Stage 2: 1.91), x noise 0.011 mm (0.0109), i noise 0.021 A, zero ≈ 0.04 A (seen 0.035–0.060), drift −0.5 to −1.3 mA/s (seen −0.52 to −1.16), hole-down rest −0.2 mm, Saturation Control 0..5 (C code), u = 1 → 2.45 A (12-Nov screenshot) | OK |
| 5.26 | PARAMETERS.md "Extra loop delay 0.3–0.6 sample … estimated from levitation data" | Stage 3 3.3; 5.11 | The s12 estimate came from 13-Nov run 3 (ball on the stand, inner loop only), not from levitation. The 16-Nov sine injection (levitating) now supports d ≈ 0.5–0.6 (5.11), so the statement can be made true by citing both | MINOR |
| 5.27 | PARAMETERS.md coil τ rows: "25–29 ms, step test" and "≈ 21 ms at 12–40 Hz" | Stage 2 2.20; 5.11 | Step test: 22.5–25 ms with the ball on the stand, 25–29 ms only with the ball at the magnet. Sine: ≈ 22 ms **if** d ≈ 0.5 (trades with d). Suggest one row: "τ ≈ 22–25 ms (step test with the ball on the stand; sine injection at 12–40 Hz assuming d = 0.5)" | MINOR |
| 5.28 | `group 28/` package: files, zip, README facts | `cmp`; `misc_checks.m` | All 5 `.fig`, the reader and the sensor table are **byte-identical** to the repo originals; the zip holds exactly the folder's 9 files, identical. Durations 71.5 s / 75.1 s and "42 g still levitating" are correct. Small issues: coil-test currents "0.69" (plateau end 0.672 A) and "0.93" (value at lift-off; plateau end 0.920 A); "each sample stored twice" is false for the stored files (Stage 2 2.17, harmless) | MINOR |
| 5.29 | 16-Nov README run table and notes | `misc_checks.m`, s16–s18 consoles | Rest readings, switch-on times, tails (0.44 / 0 / 5.8 / 0.6 / 2.2 s), variant D switching times, the −5.4 A glitch at 2.38 s (before switch-on at 4.46 s), the 11.5 mm hold 59.8–71.4 s, < 1 % limit hits (max 0.98 %), ramp tracking 0.001 mm: all correct | OK |
| 5.30 | 16-Nov README / figure `p12`, `p14`, `p15` content | Looked | `p12` and `p14` show what the text says (spike points, threshold line, the lowered-stand 10.5 → 11.6 outlier in the overshoot panel); `p15` right panel shows the residual turning down below ~0.75 mm. Cosmetic: legends overlap the "stand" label in `p12`; "expected (reset)" label overlaps data in `p15` | MINOR |

### Verdict on the 16-Nov "Main results"

| README claim | Verdict |
|---|---|
| Braking spike 0.70–0.85 mm above the stand on both stand heights | **Stands** (one lowered-stand session; one spike there; Stage 4 4.18) |
| Slow ramp: quasi-static current below the force law from ~0.7 mm, −65 mA at 0.48 mm, 10 se → static | **Stands**, reproduced by an independent absolute method (−58.5 mA, 5.20) |
| "Equivalent to ~0.8 mm of reading error or ~15 % of the weight" | Reading-error equivalence **misleading** (5.21); ≈ 14 % of the weight |
| "Leading (unproven) explanation: the stand shadows the optical sensor" | **Contradicted**: shadowing alone would need a negative sensor slope (5.21) |
| Overshoot mismatch goes with the spike (0.33–0.56 vs median 0.99) | **Stands qualitatively**; n = 1 in the check, ranges nearly touch, these are 16-Nov steps (5.14) |
| 11.5 mm lowered-stand hold: no 2.4 Hz rocking | **Stands** (one run each; contrast best shown by band rms, 5.16) |
| Sine: crossover ≈ 29 Hz, PM ≈ 47°, \|S\| 1.51 vs 1.58, τ 20.7 ms | Crossover 27.7–30.4 Hz, PM 43–50° (model 45°: agrees), τ ≈ 22 ms given d ≈ 0.5; supports d ≈ 0.5–0.6 (5.10, 5.11) |
| Variant D works: reset holds, 10.38–10.60 vs 8.95–9.07 mm, 0.14 vs 0.27–0.52 s | **Stands** (n = 2 vs 3); simulation optimistic in height and slow in timing (5.19) |
| Lowered-stand lift-off 8.59–8.65 mm (simulation 8.65–8.70) | Lab numbers right; **the simulation figure is the worst corner** (nominal 8.89–8.90), the lab is at or beyond it (5.15) |

### Proposed fixes (author decides)
- **5.21 (16-Nov README "Main results", `group 28/PARAMETERS.md` Caveats, s18 header and RECORD text):** replace the
  shadowing sentence by: "Within ~0.7–0.8 mm of the stand the current needed to hover falls below the force law and,
  closer than ~0.75 mm, even decreases as the ball gets closer to the stand (−35 mA over the last 0.35 mm). A sensor
  error alone cannot do this, so at least part of the effect is a real upward force on the ball; the mechanism is not
  known." Drop "~0.8 mm of reading error"; write "≈ 14 % of the weight at 0.5 mm". If the package was already shared,
  send the corrected PARAMETERS.md.
- **5.15:** compute the lowered-stand simulation in s17 (nominal and the 9 corners, from the measured rest readings)
  instead of the hard-coded text; README: "lab 8.59–8.65 mm, simulation nominal 8.89–8.90 mm (corners 8.68–9.14 mm):
  the lab rises 0.25–0.3 mm higher than nominal".
- **5.10 / 5.11 / 5.26 / 5.27:** README and PARAMETERS: "crossover 28–30 Hz (model 23.6), PM 43–50° (model 45°)";
  "coil τ ≈ 22 ms with d = 0.5 (fit of the complex G_iu, k_a 2.40); the sine data also support d ≈ 0.5–0.6"; delay
  source "inner-loop step fit (ball on the stand) and sine injection while levitating".
- **5.13:** in s17, plot the model phase with the same wrapping as the lab points, mark the noisy points, sort by
  frequency.
- **5.12, 5.7, 5.22:** reword the s17 \|ΔT\| message; s16: "consistent with position (or with arrival at the target);
  s17 decides"; in s18 print the RECORD line with `chkp(isStatic, …)`.
- **5.14, 5.16, 5.23:** README: give n and both ranges; use band rms for the rocking contrast; quote the stand effect by
  its onset (~0.7–0.8 mm) and say that its size depends steeply on the distance (~200 mA/mm) and so varies between
  days.
- **5.19, 5.24:** add to `models/README.md`: "the simulation also lifts slower (≤ 90 vs 30–33 ms); a stand-tied force
  explains the timing, not the 0.2–0.6 mm extra rise". Optionally mention in the report, as context only, that lift-off
  from the stand needs roughly 10–30 % less force-law current (12-Nov).
- **5.5, 5.28, 5.3, 5.30:** re-save `my_cascade_ramp116_rt` with Linear (or note "still Flat" in models/README); "first
  level 8 s, then 5 s"; note that the demo model is saved with manual x_ref 11.5 mm; group-28 README coil currents
  "0.67 / 0.92 A (0.93 A at lift-off)"; s15 header: "C4 checks the build against V; V was checked against the build
  cache by hand"; tidy the overlapping labels.

### Stage 5 summary
Counts: **CRITICAL 1, MAJOR 1, MINOR 16, OK 12.**

Three most important findings:
1. **The "shadowing" explanation is contradicted by the ramp itself** (5.21). Closer than ~0.75 mm to the stand the
   hover current *decreases* as the ball goes lower (−35 mA over 0.35 mm, model-free). A pure reading error would need
   a negative sensor slope, i.e. reversed feedback, while the ramp tracked within 0.001 mm. At least part of the effect
   is a real force. The sentence is in the 16-Nov README and in the PARAMETERS.md prepared for another group.
2. **The 16-Nov quantitative results reproduce with independent methods** (5.9, 5.11, 5.20): the ramp residual
   (−58.5 vs −65 mA, onset ~0.7–0.8 mm), the 13-Nov force law out-of-sample on 16-Nov within ~0.5 % away from the
   stand, and the sine-injection loop gain. The sine data (levitating) **independently support d ≈ 0.5–0.6** and give
   τ ≈ 22 ms with k_a 2.40 at that d, which answers the Stage 3 hand-over; the PM agrees with the model (43–50° vs 45°).
3. **"Simulation 8.65–8.70" for the lowered-stand lift-off is the worst corner, not the nominal** (5.15): the nominal
   is 8.89–8.90 mm, so the lab rises 0.25–0.3 mm higher than predicted. With variant D (simulation 0.4–0.6 mm too
   optimistic and ~2–3× too slow to lift, 5.19), lift-off from the stand is the least well-modelled phase.

For Stage 6 to look at:
- Every number that now has two values: d (0.5 vs 0.55, Stage 3 3.5; sine 0.5–0.6), τ (27 ms nominal vs 22–25 ms
  measured), crossover / PM, λ precision (±0.15 mm, Stage 2 2.16), stand-effect size (30–65 mA, ×1.07–1.15).
- `data/README.md` index: does it list the s15–s18 results and figures `p12`–`p15`? (not checked here).
- Stale text that the 16-Nov results touch: s09 / s11 / `maglev_cases` "variant D simulation only" (Stage 3 3.17,
  3.25); s13 / s14 (Stage 4 4.6, 4.7, 4.12, 4.19); the robustness claims (Stage 3 3.14) in the light of the measured
  τ ≈ 22 ms and d ≈ 0.5–0.6.
- What the report may claim about the operating range (≥ ~0.9 mm above the stand) and about lift-off (5.15, 5.19).

---

## Stage 6 (2026-11-16) — Synthesis

Scope: every number that appears in more than one place (the four READMEs, `group 28/` docs, script headers and
console text, figures, earlier stages of this file), then the final lists for the report. Memory notes from earlier
sessions were read as claims only.

### How it was checked
1. Re-read the Stage 1–5 sections, `data/README.md`, the 12-, 13- and 16-Nov READMEs, `models/README.md` and
   `group 28/*.md` in full.
2. Grepped `scripts/`, `models/`, `data/`, `group 28/` and `maglev_params.m` for each recurring quantity (τ, k_a, d,
   λ / c, noise, current zero and drift, operating range, nominal point, case counts, "simulation only", "rotation").
3. New recomputations (scratch `s6/`): current-sensor zero and drift for every 16-Nov run that has a coil-off tail
   (`drift16.m`); the per-step 13-Nov spike positions from `data/overshoot_mismatch.mat` against each run's rest
   reading; the lift-off definitions used by s06, s08, s09, s16, s17, s18.
4. Nothing was re-run that Stages 1–5 already verified; their console checks are cited by item number.

### 6A. Numbers that appear in more than one place

| Quantity | Values and where | Verdict | Class |
|---|---|---|---|
| Force decay length λ | 5.81 mm (s07, 13-Nov README), **5.90 mm** (s08, `maglev_cases`, PARAMETERS.md), manual 5.82; ± 0.15 mm systematic (2.16) | Consistent; each value labelled with its fit. Report 5.90 ± 0.15 mm | OK |
| Force constant c (39 / 42 g) | 3.37 / 3.16 (s07), **3.29 / 3.02** (s08, `maglev_cases`, PARAMETERS) | Consistent, but **two plants are in use as "the model"**: s07's (λ 5.81, c 3.37) for every lab-vs-model overshoot (s08 §4, s13, s16, s17), s08's for `maglev_cases` → s09–s12, s18 and all Newton tests. See 6.1 | MINOR |
| Coil gain k_a | 2.44 (controller feed-forward, s05, all lab models), **2.43** (plant, s07 `kaP`, `maglev_cases`, PARAMETERS), "2.4–2.6" (12-Nov README, `maglev_cases` U), 1.9 near u = 0, 2.68–2.72 (s12 fit), 2.40 (sine fit at d 0.5, 5.11) | Consistent once each is labelled (controller constant vs plant estimate vs model-fit artefact). 2.4–2.6 comes from a ratio I/u that includes the current zero; 2.43 is the better plant value | OK |
| Coil time constant τ | **27 ms** nominal (s05, `maglev_cases`, s06/s17 legends); "25–29 ms" (12-Nov README, `maglev_cases` U, s05 comment, s10 table, s17 text, PARAMETERS); 22.5–25 ms ball on stand (2.20); 24.9–26.5 ms (s12 A), 20–22 ms (s12 B, 3.4); ≈ 22 ms at 12–40 Hz given d 0.5 (5.11); "≈ 21 ms" (PARAMETERS) | **Inconsistent text.** The measured values cluster at 22–25 ms; 27 ms is the slow end and "25–29" is only right with the ball at the magnet. The uncertainty range 20–35 ms covers all of them, so no result changes; the words do | MINOR |
| Extra loop delay d | **0.55** (s12 "ESTIMATE", 13-Nov README margins at 0.55), **0.5** nominal (`maglev_cases`, s09–s11, s16–s18), 0.32–0.55 measured, 0.3–0.6 range, sine 0.5–0.6 (5.11), PARAMETERS "0.3–0.6, from levitation data" (5.26) | Two nominals (3.5). Use **d = 0.5 (range 0.3–0.6)** everywhere; quote the nominal margins at 0.5 | MINOR |
| Nominal margins (39 g, 10 mm) | 13-Nov README at d 0.55: Ms 1.65, gain 0.293–3.57, PM 44°, DM 5.2 ms; s11 at d 0.5: Ms 1.59, gain 0.292–3.95, PM 45.4°, DM 5.34 ms; measured PM 43–50°, \|S\| 1.51 at 40 Hz (5.10) | Both model sets correct for their d; the measured PM fits either. Pick d 0.5 | MINOR |
| kg stable range | 0.28–3.76 (13-Nov README, d = 0, 2.25), 0.292–3.95 (d 0.5, 3.27), 0.293–3.57 (README "gain range" at d 0.55) | Correct for each d; the README Exp C line is not annotated with d = 0 | MINOR |
| Current-sensor noise | **0.021 A** (s07, simulations, 13-Nov README, PARAMETERS), 0.018 A (s10 table), "std 0.03 A" (13-Nov run 3 line) | 0.018 is stale (3.12); run 3's 0.03 includes the step response window | MINOR |
| Current-sensor zero | "0.05 A" (13-Nov first-levitation text), 0.0386 A (s07 `ioff`, `maglev_cases`), "≈ 0.04 A" (PARAMETERS, group-28 README); measured at coil-off: +0.060 (12-Nov), 0.035–0.041 (13-Nov), +0.044 → **−0.020 A** (16-Nov, falling through the day) | "≈ 0.04 A" is a typical start-of-session value, not a constant; it reached −0.02 A on 16-Nov. PARAMETERS already says "measure it before each run" | MINOR (6.2) |
| Zero drift while levitating | −0.52 (13-Nov morning), −0.82 / −0.85 (13-Nov sweeps), −0.31 / −0.64 (hold tails), 16-Nov: −0.47, −0.77, −0.79, −1.01, −1.12 mA/s (`drift16.m`); s18 −1.16; PARAMETERS "−0.5 to −1.3" | **−1.3 is found nowhere**; data span −0.3 to −1.2 mA/s | MINOR (6.2) |
| Operating range | "validated 9–11 mm, both balls" (13-Nov README, s08, s10 text, memory decision), "9–11.5 mm, validated" (`maglev_cases` U, s10 header), s14 figure "validated range ends 11.25", s11 grid 9–11 mm | Inconsistent (3.25). With the stand finding the defensible statement is: **set points 9–11 mm, both balls, stand reading ≥ ~0.85 mm below the set point** (6.4) | MINOR |
| Nominal operating point | s01/s02 and `maglev_params` `P.nom.x10` = **9 mm** (manual); s05 gains designed for i0 = 0.75 A (≈ 9.2 mm on the fitted law); s10, s11, `maglev_cases`, s17 sine: **10 mm** | Three nominals in circulation; harmless for the results, confusing in a report | MINOR (6.5) |
| Braking-spike position | 13-Nov: x 10.93–11.03 mm (s13); 16-Nov: 11.05–11.14 (s16), 11.07 / 12.43 (s17); README "0.70–0.85 mm above the stand on both stand heights" | My per-step check: 13-Nov spikes are **0.89 mm** (39 g, stand 11.92) and **0.67–0.76 mm** (42 g hole-down, stand reading 11.68) above the rest reading; with 16-Nov the full range is **0.67–0.89 mm** over 9 spikes, 3 sessions-worth of stand settings, 2 balls. Supports the README; "~0.7–0.9 mm" is the honest range | OK |
| Stand-effect size | ×1.04–1.08 (s13 holds), −30 to −39 mA / ×1.07–1.09 at 0.43 mm (Stage 4, 5.23), −65 mA ≈ 15 % (s18, 16-Nov README, PARAMETERS "up to ~65 mA at 0.5 mm"), −58.5 mA / ×1.145 at 0.48 mm (5.20) | Consistent once the steep distance dependence (~200 mA/mm) and the day-to-day stand reference are accounted for (5.23). Quote the onset, not one size | MINOR |
| 11.5 mm rocking | 39 g hole-up: std 0.252 / 0.253 mm, band rms 0.250, 2.45 / 2.43 Hz (2.3–2.5 by s14); hole-down std 0.135 / 0.136, band 0.133; 42 g std 0.018, band 0.013 mm, "20× smaller" | Values agree within estimator; the "20×" mixes a std (0.253) with a band rms (0.013): std/std is 14×, band/band 19× | MINOR |
| Lift-off time | 45 ms (13-Nov run 4, s06), 27–33 ms (16-Nov, s18), both "x < rest − 0.2 mm"; 36 vs 39 ms (s09 sim vs lab), 36 / 39 ms (s16), 45 / 48 ms (s17 lowered), all "sweep clock started", i.e. x < 11.5 or 12.0 mm | **Two definitions**, same word; numbers are not comparable across READMEs (6.3) | MINOR |
| Lift-off closest approach | run 4 8.89 mm; 13-Nov SUSPECT 8.89; 16-Nov lab ctrl 8.95–9.07 (normal), 8.59–8.65 (lowered); sim lab ctrl ≥ 8.84 (9 cases, normal), "≥ 7.10 worst of 77" (`models/README`); lowered sim nominal 8.89–8.90, worst 8.65–8.70 (5.15) | Lab numbers consistent. The lowered-stand "simulation 8.65–8.70" is the worst corner (5.15) | (MAJOR, 5.15) |
| Variant D, lift-off | lab 10.38–10.60 mm; sim "≥ 10.96" (s18, 9 cases from the 16-Nov rest), "≥ 10.31" (`models/README`, all 77 cases) | The lab values lie **inside** the 77-case envelope but **outside** the 9-case one; "simulation is optimistic for D" is true for the nominal plant, not for the whole set (6.6) | MINOR |
| 10.5 → 11 mm overshoot | 13-Nov lab 0.25–0.32, model 0.64–0.73 (s08, s13, README); 16-Nov lab 0.26 / 0.35, model 0.64 / 0.73 (s16) | Consistent across days | OK |
| Step overshoot sim vs lab | rms 0.16 mm (s07, raw), 0.18 mm (s08, smoothed), "within 0.10 mm on 21 of 24 steps" (s13, d 0.5), 0.14 mm rms (s09 `models/README`, 39 g sweep only) | Different definitions and subsets (2.23, 3.21); all right for what they measure. The report should use one (s13's, d 0.5) | MINOR |
| PASS / FAIL totals | 12-Nov —; s06 all PASS; s07 all PASS; s08 21/21; s09 15/1; s10 12/0; s11 12/4; s12 7/0; s13 13/1; s14 8/0; s15 33/0; s16 9/2; s17 10/1; s18 5/0 (READMEs, memory) | Every total reproduced in Stages 1–5. The FAILs are by design or honest data-quality flags, each explained in the stage that ran it | OK |
| Simulation case counts | "77 cases (73 + 4 delay refs)" (`models/README`), "same 75 cases" (s09 comment), "54 of 73 fully ok" (s09) | 75 is stale; 54 should be 53 (3.22) | (MAJOR, 3.22) |
| Variant D status | "SIMULATION ONLY" (`maglev_cases` header, s09 §5, s11 §6) vs tested on the hardware 16-Nov (s18, both READMEs) | Stale (3.17, 3.25) | MINOR |
| Rocking mechanism | "rotation of the ball" (s07 text, s08 6b, s14, 13-Nov README ×3) vs Stage 4 4.12 | Superseded; still in four files | (CRITICAL, 4.12) |
| Stand-effect mechanism | "leading explanation: shadowing" (16-Nov README, PARAMETERS, s18 header, memory notes) vs 5.21 | Contradicted; still in three repo files | (CRITICAL, 5.21) |
| `data/README.md` index | Lists all three sessions and every derived `.mat`; s15–s18 write no `.mat` (figures only), so nothing is missing. Figures `p1`–`p15` are indexed only in the session READMEs | Complete for data; there is no figure index (useful for the report) | MINOR |
| `group 28/` vs repo | 9 files byte-identical to the repo and the zip (5.28); numbers checked in 5.25 | Consistent except 5.21, 5.26, 5.27, 6.2 | (see those) |

### 6B. New findings

| # | File / claim | What I did | Result | Class |
|---|---|---|---|---|
| 6.1 | "Model" in every lab-vs-model overshoot comparison | Traced `load(...)` in s08, s13, s16, s17 vs `maglev_cases` | Overshoot comparisons simulate the **s07 morning plant** (λ 5.81, c 3.37, n = 18 visits); the robustness and Simulink results use the **s08 combined plant** (λ 5.90, c 3.29, n = 42). The scripts state which they load, but the READMEs call both "the model". The difference is 1.6 % in λ, so the conclusions do not change; the report should name one plant (s08's) or say which is used where | MINOR |
| 6.2 | PARAMETERS.md / group-28 README: current zero "≈ 0.04 A", drift "−0.5 to −1.3 mA/s" | `drift16.m` + earlier stages | Zero seen from +0.060 A down to −0.020 A (it keeps falling through a session); drift −0.3 to −1.2 mA/s, never −1.3. Suggest "zero typically 0.03–0.06 A at the start of a session, falling by 0.3–1.2 mA per second of coil-on time; measure it with u = 0 before and after each run" | MINOR |
| 6.3 | "Lift-off N ms after switch-on" in four READMEs | Read the code of s06, s08, s09, s16, s17, s18 | Two definitions: "x < rest − 0.2 mm" (s06, s18: 45 ms on 13-Nov, 27–33 ms on 16-Nov) and "sweep clock started", i.e. x < 11.5 mm (or 12.0 mm) (s09, s16, s17: 36–48 ms). Comparisons inside one script are fine; across READMEs they are not | MINOR |
| 6.4 | Claimed operating range | 6A rows "operating range", "spike position", "stand-effect size" | The static effect starts 0.7–0.8 mm above the stand and the braking spike at 0.67–0.89 mm. On the normal stand (11.85–11.92 mm) a hover at 11.0 mm sits 0.85–0.92 mm above it, i.e. **just outside** the zone, while the 10.5 → 11 overshoots (peaks 11.25–11.38 mm) **enter it**. So "9–11 mm" holds for hovering; transients toward the stand beyond ~11.1 mm are affected, which is exactly where the model misfits | MINOR (wording, important for R1) |
| 6.5 | Nominal operating point | Grep | 9 mm (`maglev_params`, s01/s02), i0 0.75 A ≈ 9.2 mm (s05 design), 10 mm (s10, s11, `maglev_cases`, s17). State in the report: "design gains for i0 = 0.75 A; analysis nominal 39 g at 10 mm; manual comparison at 9 mm" | MINOR |
| 6.6 | `models/README.md` "simulation is optimistic for D" | Compared the two simulated envelopes | True against the nominal plant and the 9-case set from the 16-Nov rest (≥ 10.96 mm); **not** against the 77-case set (≥ 10.31 mm), which contains the lab values 10.38–10.60. Say which | MINOR |
| 6.7 | Memory notes (not in the repo) | Read as claims | They match the repo, except that they still carry the superseded "shadowing" reasoning ("no physical upward static force known") and s14's "likely ball rotation". Updated after this stage | OK |

### 6C. What the report can claim (PS9 R1–R5 / D1–D6)

| # | Claim | Evidence | Caveat that must go with it |
|---|---|---|---|
| R1/D1-a | The manual's nonlinear model and linearization are reproduced exactly | Stage 1 1.1–1.11 (independent Python) | The manual's loop assumptions (10 ms, three 5 ms filters, u in volts) do not describe the rig; s02 is a **pre-lab** prediction (1.12, 1.13) |
| R1/D1-b | Identified force law F = c i² e^(−x/λ), λ = 5.90 ± 0.15 mm, c = 3.29 / 3.02 N/A² (39 / 42 g), from 42 drift-corrected hover points at 9–11 mm, residual 5.9 mA rms | s08; Stage 2 2.16; 5.25 | λ uncertainty is systematic (current-zero model). c per ball mixes ball orientations (2.24) |
| R1/D1-c | The force law predicts hover currents **out of sample**: on 16-Nov, 9–11.5 mm with the stand lowered within ± 1 %, and 10.5–11.0 mm on the normal stand within ~0.5 % | Stage 4 4.14; 5.20 | Only ≥ ~0.8 mm above the stand |
| R1/D1-d | Actuator: static gain 2.43 A/unit (1.9 near u = 0), τ ≈ 22–25 ms, extra loop delay d ≈ 0.5 sample (0.3–0.6), shown by two methods (inner-loop step fit, ball on the stand; sine injection while levitating) | 2.7, 2.20, 3.2–3.4, 5.11 | τ and d trade off; the first-order coil model is approximate (s12 needs k_a 2.7) |
| R1/D1-e | Linear model: a21 = g/λ = 1661 s⁻² (unstable pole 6.49 Hz, independent of mass and gap for this law), b = 2g/i0; linearization error is not the cause of the lab–model misfit | 1.4, 3.7, 3.11 | u is a PWM duty fraction, not volts (2.19) |
| R1 range | Set points 9–11 mm, both balls, with the stand at least ~0.85 mm below the set point | s08 27/27 plateaus; 6.4 | 11.5 mm excluded on the normal stand; transients that come within ~0.8 mm of the stand are outside the model |
| R2/D1 | Uncertainty set λ, c ± 5 %, τ 20–35 ms, k_a 2.2–2.7, d 0.3–0.6, both balls, 9–11 mm; each range justified by data | 3.8, 3.27, 5.11 | c ± 5 % is narrower than c's CI but covers the hover current (3.8). **kg 0.4–2.0 is not part of the robust set** (3.16) |
| R2 unmodelled | Named and bounded: sensor noise (x 0.011 mm, i 0.021 A), current-zero drift, the stand-proximity effect (static upward force within ~0.7–0.8 mm, braking spike, 2.4 Hz limit cycle at 0.4 mm), lift-off dynamics | 2.12, Stage 4, 5.20, 5.21 | Stand-effect mechanism unknown; it is **not** shadowing alone and **not** shown to be a ball rotation |
| R3/D3 | Cascade controller (inner current loop Kc 2.05 + feed-forward 1/2.44; outer PID by pole placement ωn 40 rad/s, ζ 0.7, ωi 12; integral clamp ± 0.3 A) deployed exactly as designed | 2.4, 2.5, 5.1 | Rationale is robustness: a position-only PD is at best fragile (Ms ≥ 5.7). Do **not** claim "the PD was predicted to oscillate at 7–9 Hz" (2.15) |
| R4/D2 | Simulink model = MATLAB simulation within 0.0001 mm at five delays; a third independent implementation within 0.005 mm | 3.19 | Same equations in the first two (3.20) |
| R4/D3 | Nominal (39 g, 10 mm, d 0.5): Ms 1.59, PM 45°, gain range 0.29–3.95, delay margin 5.3 ms; **measured** PM 43–50° and \|S\| 1.51 at 40 Hz agree | 3.13, 5.10 | Measured loop only 3–40 Hz; 1.5–2.4 Hz not resolved |
| R4/D3 robust | Stable at all 1458 grid points; Option-2 \|W T\| < 1 in all four regions (worst 0.997); grid-worst Ms 2.23, PM 29°, gain range [0.54, 2.23], delay margin 2.8 ms | 3.14, 3.15 | "Guaranteed" = grid + sampled bound, not a proof; the target Ms ≤ 2 is **not** met; no room left for unmodelled error at 2–10 Hz |
| R4/D4 | Case simulations: 73 cases in the set, no ball lost; 53 of 73 fully OK | 3.22 | 19 cases come within 0.1 mm of the stand on 10.5 → 11 mm, where the model lacks the stand effect; the "lab-like" tilt case is a stress case |
| R5/D5-a | Stable levitation of both balls at 9–11 mm: mean error ≤ 3.2 µm, jitter 0.03–0.09 mm (sensor-noise floor); stable for actuator gain kg 0.4–2.0 on the hardware | s08, s07, 2.11 | n = 1 run per kg level |
| R5/D5-b | Simulation vs hardware: step overshoot within 0.10 mm on 21 of 24 steps (d 0.5); lift-off time and height close on the normal stand; loop gain 3–40 Hz within 0.9–1.36× | s13 (Stage 4 4.2), 5.9, s18 | The misfit (10.5 → 11 mm, lab ≈ 0.4× model) is tied to the stand: without a spike the median ratio is 0.99 (5.14). Overshoot itself is 100–130 % of the step, a property of the design (2.26). Hover-current agreement on the fit run is in-sample (3.21) |
| R5/D5-c | Variant D (i0 0.85 A, clamp ± 0.45 A, integral reset while off) works on the hardware: closest approach 10.38–10.60 mm vs 8.95–9.07 mm, settles in 0.14 s vs 0.27–0.52 s | s18, 5.17, 5.18 | n = 2 vs 3, one ball, normal stand only; simulation of D is optimistic against the nominal plant (5.19, 6.6) |
| Finding | A stand-proximity effect: within ~0.7–0.9 mm of the stand the plant departs from the model (static upward force, braking spike on fast approach, 2.4 Hz limit cycle at 0.4 mm). It moves with the stand and vanishes when the stand is lowered | Stage 4, 5.20, 5.21, 6A spike row | One lowered-stand session; mechanism unknown |

### 6D. Unresolved (say so in the report; do not paper over)
1. **Mechanism of the stand effect.** A real upward force is required (5.21); its cause (contact, magnetic, other) is
   unknown, and its size varies steeply with distance and between days (5.23). Lift-offs passing the same heights show
   no extra force (4.8).
2. **The 2.4 Hz rocking.** "Ball rotation" is unsupported; a sensor-gain loss near the stand reproduces it in the
   linear model but not the static current deficit (4.12, 4.15). Not observed directly.
3. **Lift-off modelling.** From the lowered stand the lab rises 0.25–0.3 mm higher than the nominal simulation
   (5.15); variant D lifts ~2–3× faster and 0.4–0.6 mm higher than its nominal simulation; a stand force explains the
   timing only (5.19). Contact evidence from 12-Nov disagrees on size (5.24).
4. **Loop gain below 3 Hz** (rocking band) and at 11 mm / 42 g were never measured (5.9, Stage 4 4.13).
5. **Cause and placement of the delay** (computation, PWM, or current-sensor filter; one loop or both) (3.3).
6. **Unit conversion of u** to the manual's volts is not verified from any file (1.13, 2.19).
7. **Robust margin at 2–10 Hz is ≈ 0** for unmodelled error (3.14), the band where the stand effect and the unstable
   pole sit.

### 6E. Fix before writing the report (ordered)
1. **5.21 (CRITICAL)** Remove "shadowing" as the leading/likely cause from the 16-Nov README, `group 28/PARAMETERS.md`
   and the s18 header; drop "≈ 0.8 mm of reading error"; "≈ 14 % of the weight". Send the corrected PARAMETERS.md to
   the other group if it was already shared.
2. **4.12 (CRITICAL)** Remove "rotation / extra mode" from s14 §4, the s08 6b text, s07's printout, the 13-Nov README
   (three places) and the s10 unmodelled-effects table; mark s09's tilt case "11.5 mm stress case".
3. **3.16 (MAJOR)** Take kg 0.4–2.0 out of the uncertainty table (or label it "hardware gain-margin test").
4. **3.22 (MAJOR)** Fix s09's "ok" test for noisy cases; 53 of 73, not 54; rename "lab-like".
5. **5.15 (MAJOR)** Compute the lowered-stand lift-off simulation in s17 instead of the hard-coded "8.65–8.70";
   README: nominal 8.89–8.90 mm.
6. **1.12, 1.13 (MAJOR)** Mark `maglev_params.m` loop/actuator values as manual / pre-lab (or update them), and state
   the unit of u everywhere (PWM duty fraction; lab gains in A per unit).
7. **2.15 (MAJOR)** Reword the s05 rationale (no "predicted 7–9 Hz").
8. **3.14** Write the robustness numbers (Ms 2.23, target missed, \|W T\| 0.997, PM 29°, gain range, delay margin) into
   a README; they exist only in the console.
9. **One value per quantity** (6A): d = 0.5 (0.3–0.6); τ "22–25 ms measured, 27 ms nominal model"; i-noise 0.021 A;
   the s08 plant as "the model" (6.1); one nominal point (6.5); one lift-off definition (6.3); operating range as in 6.4.
10. **Stale text:** s13 §5–6 and the 13-Nov README H-force paragraphs (4.6, 4.7); "Partly explained by s13"; "variant D
    simulation only" (3.17); s12 header "worst Ms 5.0" (3.6); s09 "75 cases" (3.25); `data/README.md` note on s13/s14.
11. **Figures:** fix `p13` phase wrapping (5.13); do not use `p3_liftoff_sim.png` (2.21), `p10`/`p11` (stale
    interpretation, Stage 4) or `p6_cases_special.png` (3.22, 3.26) without the fixes; legend in `p2_polemap.png` (1.17).
12. **PARAMETERS.md:** τ row (5.27), delay source (5.26), zero and drift (6.2).

### Stage 6 summary
Counts (this stage): **CRITICAL 0, MAJOR 0, MINOR 16, OK 6.** Counted once per issue: 6B gives 6 MINOR + 1 OK;
6A adds the 10 MINOR and 5 OK rows that are not already 6B items. 6A rows that only point back to an earlier
CRITICAL/MAJOR (closest approach, case counts, both mechanisms, group 28) are not counted again. Several 6A MINOR rows
restate earlier-stage MINORs (3.5, 3.12, 3.17, 3.25, 2.25) from the cross-document angle.

Whole audit (sum of stage counts, Stages 1–6): **CRITICAL 2 (4.12, 5.21), MAJOR 6 (1.12, 1.13, 2.15, 3.16, 3.22,
5.15), MINOR 77, OK 59.**

Three most important findings of the synthesis:
1. **The core results are sound and reproducible.** Every PASS/FAIL total and every README number checked in Stages 1–5
   reproduces; the force law holds out of sample on a second day; three simulations agree; the measured loop gain
   matches the model at 3–40 Hz. The report has a solid D1–D5 evidence base.
2. **Two explanations in circulation are wrong and must go before the report:** "the stand shadows the sensor"
   (5.21) and "the rocking is a ball rotation" (4.12). Both are still written in several files, one of them shared with
   another group.
3. **Numbers drift between documents** (6A): τ (27 / 25–29 / 22–25 / 21 ms), d (0.5 / 0.55), the nominal point
   (9 / 10 mm), the operating range (9–11 / 9–11.5 mm), the plant used as "the model" (s07 / s08), the lift-off
   definition, the zero-drift range. None changes a conclusion, but the report needs one value for each, and the
   robust-stability claim must be stated as narrowly as the evidence allows (target Ms ≤ 2 missed, \|W T\| 0.997,
   kg outside the set).

Audit complete. Next: apply the fixes in 6E (author's decision), then write D6.
