# Number ledger for the D6 report (Stage A, 2026-11-17)

Every number the report will quote, with one value per quantity. The report may only use a number that is in this
table, written as given here (rounding stated in the Value column). Stage G parses the `ID` and `Value` columns.

**Status** (as in the Lab 9 report): **M** measured (hardware data, or a model fitted to hardware data);
**S** simulated (group scripts / Simulink); **D** derived (calculated from stated values, incl. linear-model margins);
**N** not obtained (required or planned, not produced). **B** = benchmark: a value from the manual, not this group's.

**How it was checked.** On 2026-11-17 all 18 analysis scripts (s01, s02, s05–s14, s16–s21) were re-run with
`matlab -batch` on a scratch copy of the repository (repo files untouched). Every PASS/FAIL total matched the record
(s01 36/36, s02 39/39, s05–s08 all PASS, s09 16/1, s10 12/0, s11 12/4, s12 7/0, s13 13/1, s14 11/0, s16 9/2, s17 10/2,
s18 5/0, s19 5/0, s20 6/0, s21 6/1). All twelve derived `.mat` files written by the re-run are numerically identical
to the committed ones (only the stored folder path differs). "Source" names the script whose console line or `.mat`
field gives the value; `data/…` paths are relative to the repo root. Values in **bold** in a note are the ones
that differ from an older statement somewhere in the repo (see Section Z).

---

## A. Rig, setup and run conditions

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| A1 | Rig | INTECO MLS1EM USB2, RT-DAC/USB2 board | M | 12-Nov README, 16-Nov README | |
| A2 | Lab PC MATLAB release | R2024a | M | 12-Nov discovery | Analysis PC: R2026a |
| A3 | Sample time T0 (fixed step) | 3 ms (0.003 s), ode3, external mode | M | 12-Nov discovery; s12 "sample spacing 0.003 s" | Manual assumed 10 ms |
| A4 | Ball masses | 39.288 g and 42.137 g | M | weighed; `maglev_params`, s09 table | "39 g" / "42 g" in text |
| A5 | Ball diameters | 62.7 mm (39.288 g), 55.7 mm (42.137 g), ±0.1 mm | M | `data/ball diameter/README.md` | Read from caliper photos (least count 0.02 mm; vernier line not resolvable). Orientation of each measurement not recorded |
| A6 | Ball placement | hole-up (hole facing the magnet) | M | 13-Nov README | Rest reading as orientation check, ±0.1 mm |
| A7 | Stand rest reading, normal stand | 11.78–12.00 mm for hole-up seatings; tolerance used 11.87–12.00 mm (39 g hole-up) | M | s07, s08, s16, s18 | 39 g hole-up 11.92; other seatings: 42 g hole-down 11.68, 39 g hole-down 12.05–12.18, tilted 42 g 12.13 mm |
| A8 | Stand rest reading, lowered stand | 13.13 / 13.19 mm | M | s17 | 16-Nov only |
| A9 | Command u | PWM duty fraction 0…1, limited to 0…0.9 in our models | M | data/README reference table | Scope labels it [V]; **not volts** |
| A10 | Driver limits | Saturation Control 0…5, Position 0…0.02 m | M | 12-Nov discovery, 13-Nov README | |
| A11 | Position sensor table | `group22_sensor.mat`, 33 points, 0.7 mm spacing, linear interpolation | M | 12-Nov README; s13 §3 | Slope jumps ≤ 10 % between segments (9.5–12.5 mm) |
| A12 | Velocity signal | (x[k] − x[k−1])/T0, unfiltered | M | 12-Nov discovery | |
| A13 | Lab sessions | 12, 13 and 16 Nov 2026 (offline analysis 14–15 Nov) | M | data/README | Cover: "experiments 12–16 Nov 2026" |
| A14 | Lab models used | my_cascade_rt, my_cascade_sweep_rt, my_cascade_kg_rt, my_cascade_steps_rt, my_cascade_ramp_rt, my_cascade_sine_rt, my_cascade_D_rt | M | models/README | |
| A15 | Test-model settings | sweep table 11, 10.5, 10, 9.5, 9, 9.5, 10, 10.5, 11 mm (5 s each, clock runs while x < 11.5 mm); steps 11.0→10.8→11.1→10.6→11.0→10.5→11.0 mm; ramp 10.5→11.4→10.5 mm at 0.2 mm/s | M | 13-Nov README (sweep); 16-Nov README (steps, ramp) | Added in Stage C |
| A16 | Driver PWM | 12-bit duty, driver gain 4095 | M | `maglev_params.m` header (from the 12-Nov model inspection) | Added in Stage C |
| A17 | Nyquist frequency | 1/(2 T0) = 166.7 Hz | D | from A3 | s11 band edge 166 Hz |

## B. Manual model and pre-lab predictions (s01, s02)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| B1 | Manual force constants | P1 = 0.017521 N, P2 = 5.8231 mm (P1/P2 = 3.01 N/A²) | B | `maglev_params`; phase1_results.mat | |
| B2 | Manual actuator | ki 0.5433 A/V, ci 0.0368 A, fi 0.63 ms | B | `maglev_params` | fi far too fast for this rig (C6) |
| B3 | Manual model reproduced | 36/36 checks; 57.1 g @ 9 mm: x30 0.9345 A, u0 1.6525 V, a21 1684.67 s⁻², p 41.045 rad/s, K 11.406 | D | s01 | Matches manual p.34 table |
| B4 | Manual model, 39.288 g @ 9 mm | x30 0.775 A, u0 1.359 V, Kp_min 122.5 V/m | D | s01 | Volts of the manual model |
| B5 | Manual unstable pole | p = 41.05 rad/s (6.53 Hz); doubling time ln2/p = 16.9 ms | D | s01, s02 | |
| B6 | Pre-lab PD prediction (manual model, 39 g @ 9 mm, Kp 183.8 V/m, Kd 0.50 V s/m) | stable on the reduced and 3rd-order plant (max Re −3.44 / −2.65 rad/s); unstable with the 5 ms filter (+3.50), + Ts/2 hold (+8.99), + 1 sample (+16.31) | S | s02 | Pre-lab; the filters turned out absent (C3) |

## C. Lab discovery (12-Nov) and actuator

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| C1 | Lab sign convention | e = x − x_ref, u = u0 + C e | M | 12-Nov discovery; s08 regression | |
| C2 | Lab PD (copy of my_pd_rt) | Kp 35, Kd_raw 450 on Δe, u0 0.282 | M | 12-Nov discovery | |
| C3 | Manual Fig. 30 filters | absent in this version (no TransferFcn/DiscreteFilter blocks) | M | 12-Nov discovery | |
| C4 | Lab PD run 4 (39 g, Kp 45/Kr 450) | sustained 7.3–9.3 Hz oscillation, 2→9 mm p-p, ball hitting the stand | M | 12-Nov README | Nonlinear cycle (H6) |
| C5 | Coil static gain k_a (plant) | 2.43 A/unit (2.4321) | M | s07 `kaP`; linear_model.mat | 1.9 near u = 0; controller feed-forward uses 2.44 |
| C6 | Coil time constant τ, measured | 22–25 ms (steps, ball on stand 22.5–25 ms; sine 22.6 ms at d 0.5 / 20.5 ms at d 0.6) | M | data/README; s17 complex fit | 25–29 ms only with the ball at the magnet |
| C7 | Coil τ, model nominal | 27 ms (design value); uncertainty range 20–35 ms | D | s05, s10 | |
| C8 | Coil step test (my_driver, ball on stand 12.9 mm) | u 0.2/0.3/0.4 → i 0.44/0.69/0.93 A | M | 12-Nov README | Ball jumped at u 0.4 |
| C9 | Open-loop coil 0.3/0.6/1.0 | i ≈ 0.68 / 1.40 / 2.45 A | M | 12-Nov screenshot 07 | |

## D. Identification (13-Nov morning + afternoon)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| D1 | Force law (reference) | F = c i² e^(−x/λ), λ = 5.90 mm (5.905), c = 3.29 / 3.02 N/A² (39 / 42 g) | M | s08 §3c; s10 §1; linear_model.mat | 42 drift-corrected hover visits, 9–11 mm |
| D2 | λ uncertainty | ±0.15 mm (systematic, current-zero model); 95 % CI ±4.3 % | M | data/README; s10 | c CI ±7.4 %, correlation with λ −1.00 |
| D3 | Force-law residual | 5.9 mA rms, max 14.4 mA (42 visits) | M | s08, s10 | |
| D4 | Morning fit (s07 plant) | λ 5.81 mm, c 3.37 / 3.16 N/A², residual 4.9 mA rms (18 visits) | M | s07 §3c | Used by overshoot comparisons (s07, s13, s16, s17); 1.6 % from D1 in λ |
| D5 | Morning law predicts afternoon | 27 plateaus within 10.2 mA rms; 39 g at 9 mm: 0.728 measured vs 0.734 A predicted | M | s08 §3a | Out of sample (same day) |
| D6 | ~~Force law across days (16-Nov)~~ | **NOT USED** (decision 2026-11-17: exists only in audit scratch work, no repo script) | — | AUDIT 4.14 | Report must not claim a cross-day force-law check |
| D7 | Manual model vs measured hover current | manual 0.845 A vs fit 0.800 A, 39 g at 10 mm (+5.6 %) | D | s07 §3c | |
| D8 | 42 g vs 39 g current | +8.1 % at the same gap (mass alone 3.6 %) | M | s08 §3c | s07: 6.9 % (morning) |
| D9 | Extra loop delay d | 0.5 sample (1.5 ms) nominal; range 0.3–0.6 (0.9–1.8 ms); measured 0.32–0.55 (1.0–1.7 ms) | M | s12 verdict; data/README | s12 prints "ESTIMATE 0.55" (method A); 0.5 is the reference. Sine: 0.5–0.6 |
| D10 | Delay methods (run 3) | output-error fit 0.55 (95 % 0.50–0.55); noise shaping 0.50 (0.32–0.50 over τ/k_a); d = 0 and d = 1 rejected | M | s12 A, B | |
| D11 | Sensor noise (std, ball on stand) | x 0.011 mm (0.0109), i 0.021 A | M | s07 | s08 prints 0.018 A (stale, Z3) |
| D12 | Current-sensor zero | 0.03–0.06 A at session start, falling 0.3–1.2 mA per s of coil-on time; reached −0.02 A on 16-Nov | M | data/README; s07, s08, s18 | 13-Nov morning mean −0.52 mA/s; sweeps −0.82/−0.85; s18 −1.16 |
| D13 | Effect of zero-drift correction | repeat-visit scatter 12.0 → 4.8 mA rms | M | s07 §3b | |
| D14 | Inner-loop / log alignment | u and i logged in the same sample (inner-loop law R² 0.9996 at lag 0 only) | M | s12 §0 | |

## E. Linear model (s10; nominal 39 g at 10 mm)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| E1 | Hover current i0, nominal | 0.798 A (0.79779) | D | linear_model.mat `nom.i0` | i0 = √(m g e^{x0/λ}/c) |
| E2 | Hover command u0 | 0.328 (= i0/k_a) | D | `nom.u0` | |
| E3 | a21 = g/λ | 1661 s⁻² (1661.4); range 1582–1749 (−4.8/+5.3 %) | D | s10 §2, §6 | Independent of gap and ball for this law |
| E4 | Unstable pole | p = 40.76 rad/s = 6.49 Hz; range 6.33–6.66 Hz; doubling time ln2/p = 17.0 ms | D | s10; ln2/40.76 = 0.01700 s | |
| E10 | Phase lag of the extra delay | d 0.5: 0.54° / 5.4° / 27.0° at 1 / 10 / 50 Hz (gain unchanged) | D | s10 §4 | = 360° f d T0 |
| E5 | Input gain b = 2g/i0 | 24.59 m s⁻² A⁻¹; over 9–11 mm both balls 20.90–26.77; over the set 19.40–28.44 (−21/+16 %) | D | s10 §2, §6 | |
| E6 | Transfer functions | G_xi = −24.59/(s² − 1661.4) m/A; G_iu = 2.432/(0.027 s + 1) A/unit | D | s10 §4 | |
| E7 | ZOH plant poles (T0 3 ms) | 1.1301 (= e^{pT0}), 0.8948, 0.8849 | D | s10 §4 | Fractional delay adds a pole at z = 0 |
| E8 | Linearization validity | force error ≤ 1.17 % of mg along all 24 steps; local linear vs nonlinear overshoot 0.026 mm rms; one model (39 g, 10 mm) 0.086 mm rms | S | s10 §5 | |
| E9 | Set covers measured hover currents | 42/42 inside, smallest margin 35.9 mA; corner band at 10 mm 0.748–0.856 A (≈5× the scatter) | D | s10 §6 | |

## F. Uncertainty set (s10, s11, s09)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| F1 | Grid | 1458 points = 2 balls × gap 9/10/11 mm × λ ±5 % × c ±5 % × τ 20/27/35 ms × k_a 2.2/2.43/2.7 × d 0.3/0.5/0.6 | D | s11; 13-Nov README | |
| F2 | kg (actuator gain error) | 0.4–2.0 tested on hardware; **not part of the robust set** | M | s09 table; s11 §4 | Hardware gain-margin test |
| F3 | Simulink cases | 77 = 69 in the set (2 nominal, 64 corners, 3 sensor) + 8 outside (4 delay refs d 0/1, 2 kg, 2 stress at 11.5 mm) | S | s09 §3; models/README | |
| F4 | Stress-case artefact | 0.27 mm reading/true mismatch at 2.45 Hz | D | s09 table | Built from the 13-Nov 11.5 mm hold |

## G. Controller design (s05)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| G1 | Structure | inner current loop u = i_ref/2.44 + Kc (i_ref − i); outer PID on e = x − x_ref | D | s05 | |
| G2 | Inner-loop target | τ_in = 3 ms (discrete pole e^{−1} = 0.368) | D | s05 code | |
| G3 | Kc | 2.054 /A (2.0537); deployed 2.05 | D | s05; phase3_cascade.mat | (a − p_in)/b_d, a = e^{−T0/27ms} = 0.8948, b_d = 2.44(1 − a) = 0.2566 |
| G4 | Outer-loop targets | ω_n 40 rad/s, ζ 0.7, ω_i 12 rad/s; design plant a21 = g/P2 = 1684.7, b = 2g/0.75 = 26.16 | D | s05 code | Poles −12, −28 ± j28.57 rad/s |
| G5 | Outer gains | Kp 151.2 A/m (151.25), Kd 2.60 A s/m (2.599), Ki 734 A/(m s) (733.9) | D | s05; phase3_cascade.mat | Deployed exactly; regression on lab logs Kp +151.6, Kd +2.531 (s08) |
| G6 | Bias and limits | i0 0.75 A, integral clamp ±0.30 A, i_ref 0…2 A, u 0…0.9 | D | s05; models/README | |
| G7 | Design-time robustness (pre-delay grid, 81 cases) | worst Ms 1.67 (no extra delay), 5.23 (+1 sample) | S | s05 | Pre-lab grid; superseded by H/K |
| G8 | Inner-loop step, predicted | 63 % in 3.0 ms (open coil 27 ms), steady 0.503 A for 0.5 A | S | s05 | |
| G9 | Wrong-sign test | all gains negated → unstable (max|eig| 1.33 in s05; 1.303 in s11) | D | s05, s11 | |

## H. First levitation (13-Nov, s06)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| H1 | Runs 1–2 | no coil current: rig power supply off | M | 13-Nov README | |
| H2 | Run 3, inner loop | 0.3/0.5 A → 0.294/0.497 A; 63 % in 2 samples (6 ms) | M | s06 | Current std in loop 0.030 A (window incl. step) |
| H3 | Run 4 lift-off | 45 ms after switch-on (x < rest − 0.2 mm), highest point 8.89 mm, within ±0.25 mm in 0.59 s | M | s06 | |
| H4 | Run 4 step 11 → 10 mm | overshoot 1.12 mm (sim 0.94 mm, s05 plant), within ±0.25 mm in 126 ms | M/S | s06 | |
| H5 | Run 4 hover | std 0.071 / 0.068 mm at 11 / 10 mm; i 0.898 / 0.830 A (raw) | M | s06 | 0.824 A in the hover-window line (Z4) |
| H6 | Lab PD on the linear model | Kp 45, Kr 450: max|eig| 0.993–1.020 over τ 22.5–29 ms, d 0–1; unstable mode 5.1–6.2 Hz | D | s21 §1 | Lab's 7.3–9.3 Hz was a nonlinear cycle |

## I. Experiments A, B, C (13-Nov morning, s07)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| I1 | Exp A (39 g sweep) | held 11, 10.5, 10, 9.5 mm; drop at 37.2 s (i_ref → 0 in one sample); re-lift at 42.4 s | M | s07 §2 | |
| I2 | Exp A cause | consistent with a mistyped set point > 14.9 mm (e.g. 0.09), then 0.0095 | D | s07 §2 | **Inferred, not confirmed** by the student |
| I3 | Exp B run 1 (42 g) | rested 12.13 mm, turned over, reading 8.71–12.28 mm for ~3.5 s, never lost | M | s07 §2 | |
| I4 | Exp B hover after the turn | run 1 0.975/0.902 A vs run 2 0.971/0.897 A at 11/10 mm | M | s07 | |
| I5 | Exp C (39 g, 10 mm) | stable at every kg 0.4, 0.5, 0.6, 0.8, 1.0, 1.25, 1.5, 2.0 | M | s07 §6 | |
| I6 | Exp C jitter | x std 0.050–0.064 mm for kg 0.6–2, 0.073 at 0.5, 0.121 at 0.4 (noise-only sim 0.118) | M/S | s07 §6 | |
| I7 | Exp C model range | stable for 0.292 < kg < 3.95 (d 0.5); 0.28–3.76 at d 0 | D | s11 §1; s07 | |
| I8 | Exp C integral at kg 0.4 | 0.267 A lab vs 0.280 A model (clamp 0.30) | M/S | s09 §3b | |
| I9 | Hover jitter source | lab/noise-only sim median 0.98; at 10 mm current noise alone 0.066 mm, position noise 0.014 mm | S | s07 §5 | |
| I10 | Exp A/B overshoot (d = 0 sim) | 16 steps, rms 0.16 mm (raw lab x) | M/S | s07 §4 | Superseded definition (use M3) |

## J. Afternoon sweeps and holds (13-Nov, s08)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| J1 | Validated range | 27/27 plateaus held, 9–11 mm both balls; mean error ≤ 3.2 µm; x std 0.028–0.092 mm | M | s08 §2 | |
| J2 | 39 g at 9 mm | first time held; raw 0.744 A | M | s08 | |
| J3 | Sweep machinery | x_ref = table(τ) at every sample; clock starts 1 sample after x < 11.5 mm | M | s08 §1 | |
| J4 | 42 g placed hole-up | rolled: x 9.76–11.80 mm, last > 0.5 mm excursion 2.59 s after lift; rest 11.873 → 11.682 mm | M | s08 §5 | |
| J5 | 11.5 mm holds (rocking) | 39 g hole-up std 0.252 mm, band 0.253, 2.45 Hz; 39 g hole-down 0.135 / 0.136 mm, 2.32 Hz; 42 g 0.018 / 0.013 mm, 2.43 Hz | M | s08 §6 | 42 g is 14× smaller (std) / 19× (band) |
| J6 | Newton slope | steps 1.03 (middle half 0.91–1.07); rocking 1.74 / 1.72 | M | s08 §6b | |
| J7 | Settling | lab median 111 ms (max 204 ms), sim median 111 ms; all within 400 ms | M/S | s08 §4 | |

## K. Robustness (s11, s19)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| K1 | Nominal margins (39 g, 10 mm, d 0.5) | Ms 1.59, PM 45.4°, gain range 0.292–3.95 (−10.7/+11.9 dB), delay margin 5.3 ms (1.78 samples) on top of d | D | s11 §1; robustness.mat | |
| K2 | Nominal at other d | d 0: Ms 1.36, PM 59.0°; d 0.3: 1.41; d 0.6: 1.71; d 1: 2.41, PM 32.6° | D | s11 §1 | |
| K3 | Grid stability | stable at all 1458 points | D | s11 §2 | |
| K4 | Grid-worst margins | Ms 2.23, PM ≥ 29.3°, gain range ⊇ [0.54, 2.23], delay margin ≥ 2.8 ms | D | s11 §2 | |
| K5 | Ms target | worst Ms ≤ 2 declared before the run: **NOT met** (2.23); at d 0.5 worst 1.97; all 64 points with Ms > 2 at d 0.6 | D | s11; 13-Nov README | Decision R1: reported as is |
| K6 | Worst-Ms point | 39 g, 9 mm, λ +5 %, c +5 %, τ 20 ms, k_a 2.7, d 0.6 | D | s11 §2 | |
| K7 | |W T| one disk | 1.11 at 7.6 Hz (fails) | D | s11 §5 | W = grid envelope + 10 % |
| K8 | |W T| Option 1 (centred nominal) | 1.25 at 7.0 Hz (fails) | D | s11 §5b | Added after the one-disk failure (disclosed) |
| K9 | |W T| Option 2 per region | 0.957 / 0.967 / 0.951 / **0.997** (39 g 9–10, 39 g 10–11, 42 g 9–10, 42 g 10–11 mm); 4 decimals 0.9570/0.9667/0.9511/0.9973 | D | s11 §5b; s19 | Passes |
| K10 | W covers interior plants | 400 random plants per region, |δ|/W ≤ 0.88 | D | s11 §5b | s19 prints 0.81 (Z2) |
| K11 | Room for unmodelled error (Option 2, worst region) | 22 % below 2 Hz, 0 % at 2–10 Hz, 2 % at 10–30 Hz, 13 % at 30–166 Hz | D | s11; s19 | |
| K12 | kg 0.4 vs grid (39 g, 10 mm) | 33 of 243 grid points unstable at kg 0.4 (all τ 35 ms, k_a ≤ 2.43) | D | s11 §4 | |
| K13 | Exp C trimming (s19) | removes 260/1458 grid points, 505/2916 region plants; worst Ms 2.230 unchanged; PM min 29.3° → 31.3°; Option-2 peaks unchanged (0.9973) | D | s19 | Caveat: Exp C was 39 g at 10 mm only |
| K14 | Clamp use (lab controller) | 42 g at 11 mm, λ −5 %, c −5 %, k_a 2.2 needs +0.313 A (104 % of the 0.30 clamp) | D | s11 §6 | |
| K15 | Measured loop vs model (sine) | PM ≈ 47° (43–50°) vs 45.4°; |S| 1.51 at 40 Hz vs 1.58; crossover ≈ 29 Hz (29.4) vs 23.6 Hz | M | s17 A; 16-Nov README | Model |S| peak 1.59 at 45 Hz not measured |

## L. Simulation cases (s09) and variant D in simulation

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| L1 | Simulink = MATLAB sim | max |x| difference 0.0001 mm, |i| 0.03 mA (d 0.5) | S | s09 §2a | Same equations in both |
| L2 | Simulink vs lab 39 g sweep | lift 36 vs 39 ms (sweep-clock definition); lowest point 8.92 vs 9.01 mm; overshoot rms 0.14 mm; current rms 3.0 mA (in-sample) | M/S | s09 §2b | |
| L3 | Cases in the set | 69: ball never lost; **51 fully OK; 18 within 0.1 mm of the stand** (all on 10.5 → 11 mm, x_ref 11 mm); integral clamped in 4 | S | s09 §3 | CLEARANCE FAIL kept |
| L4 | Cases outside the set | 4 delay refs OK, 2 kg OK, 2 stress cases not OK (true-x 1.5–3.5 Hz band 0.42–0.44 mm); none lost | S | s09 §3 | |
| L5 | Corner overshoot | 0.47–0.97 mm; settle ≤ 153 ms | S | s09 §3 | |
| L6 | kg 0.4 from the stand | cannot lift (0.925 A available vs 0.939 A needed) | D/S | s09 §3b | |
| L7 | Lab controller, 77 cases | lift-off highest point worst 7.10 mm, median 9.38 mm; < 8 mm in 2 of 75 | S | s09 §5 | |
| L8 | Variant D, 77 cases | never lost, never clamps, lift ≤ 321 ms, lift-off highest point ≥ 10.31 mm (median 11.00) | S | s09 §5 | |
| L9 | Clamp/i0 options (s11 §6) | only A, B, C, D lift every case and end within 0.02 mm; C reaches the magnet (0 mm) in one case; D worst 10.42 mm at lift-off, 1.18 A peak | S | s11 §6 | |

## M. Steps: simulation vs hardware

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| M1 | Overshoot definition used in the report | s13 metric (s07 plant, d 0.5): within 0.10 mm rms on 21 of 24 steps; all 24: 0.18 mm rms | M/S | s13 §1 | |
| M2 | 10.5 → 11 mm mismatch | lab 0.25–0.32 mm vs model 0.64–0.73 mm (13-Nov); 16-Nov lab 0.26/0.35 vs 0.64/0.73 | M/S | s13, s16 | |
| M3 | Other step comparisons (for the record) | s07 0.16 mm rms (16 steps, d 0, raw x); s08 0.18 mm (24 steps, d 0); s09 0.14 mm (39 g sweep, d 0.5) | M/S | s07, s08, s09 | Different definitions; report uses M1 |
| M4 | Overshoot size | 100–130 % of the 0.5 mm step (a property of the design) | M | data/README | |
| M5 | With / without spike (16-Nov) | lab/model ≤ 0.56 with a spike (0.33–0.48 s16, 0.56 s17); without, median 0.99 (0.61–1.20) | M/S | s16, s17 | |
| M6 | Up-step lab/model (16-Nov) | 0.68–1.16 | M/S | s16 | |

## N. Stand-proximity effect (13-Nov, 16-Nov)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| N1 | Onset | ~0.7–0.8 mm above the stand (static); ≥ 3 se from 0.68 mm | M | s18; 16-Nov README | |
| N2 | Static deficit (slow ramp) | −65 mA at 0.48 mm above the stand (−58…−65 mA, two methods; 10 se) ≈ 13–14 % of the weight | M | s18 §B; 16-Nov README | Hand check: (1 − 0.065/0.898)² = 0.86 |
| N3 | Near-stand slope | current decreases 35 mA over the last 0.35 mm where the law needs +27 mA | M | 16-Nov README | |
| N4 | Ramp hysteresis | up − down median −1.4 mA (none significant) | M | s18 §B | Not contact/friction |
| N5 | Braking spike position | 0.67–0.89 mm above the stand; 11 spikes (3 on 13-Nov, 6 on 16-Nov normal stand, 2 in s17: one normal, one lowered stand), both balls | M | s13 §4, s16 §2, s17 B (distances: s17 B; 13-Nov from s13 x minus rest reading) | Each counted with its script's own threshold |
| N6 | Spike size (h = 5) | −1.75 to −2.01 m/s² (13-Nov 10.5 → 11), 1.7–2.3× the worst control step; table-kink artefact ≤ 0.11 m/s² | M | s13 §4 | |
| N7 | Lowered stand, no spike | steps through 11.0–11.2 mm > 0.9 mm above the lowered stand: no spike (r −0.79/−0.67 m/s²) | M | s17 B | |
| N8 | 11.5 mm hold, lowered stand | band rms 0.048 mm (vs 0.250 normal stand) | M | s14 §1 | One run each |
| N9 | Size changes with distance | ~200 mA/mm near the stand; 13-Nov 0.43 mm: −30…−39 mA vs 16-Nov 0.48 mm: −58…−65 mA | M | 16-Nov README; AUDIT 5.23 | Quote the onset, not one size |
| N10 | Sensor-gain-loss model | gain s 0.6/0.5/0.45/0.4 → mode 3.1/2.6/2.4/2.3 Hz in the vertical loop | D | s14 §4b | Candidate, not observed; does not explain N2 |
| N11 | Stand spring | a21_eff 0…−10 000 s⁻² moves the slowest mode up to 11–22 Hz | D | s14 §4b | Cannot give 2.4 Hz |
| N12 | Lift-offs vs stand zone (s20) | 22 lift-offs cross 0.3–0.7 mm above the stand in 3–18 ms (median 7 ms); 21 of 22 faster than the 18 ms Newton stencil; a ramp-sized force would move the ball 5–165 µm (median 36 µm) | M/D | s20 §3b | Neither confirms nor refutes the static effect |
| N13 | Claimed range | set points 9–11 mm, both balls, stand reading ≥ ~0.85 mm below the set point; 11.5 mm on the normal stand excluded | D | data/README | |

## O. 2.4 Hz rocking (s14)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| O1 | Frequency | 2.3–2.5 Hz | M | s14 §6 | |
| O2 | Amplitude 9–11 mm | ≤ 0.051 mm rms (1.5–3.5 Hz band, 24 plateaus) | M | s14 §1 | Upper bound |
| O3 | Amplitude 11.5 mm (normal stand) | 39 g 0.250 (hole-up) / 0.133 mm (hole-down); 42 g 0.013 mm | M | s14 §1 | |
| O4 | Nature | 39 g hole-up: limit cycle (envelope CV 0.04); 42 g: damped, ζ ≈ 0.07 | M | s14 §2 | |
| O5 | Through the loop | i/x at the peak 154 A/m vs controller 151 A/m, phase within 6° | M | s14 §3 | |
| O6 | Vertical model | no mode below 6.6 Hz for a21 1661…200 s⁻² (nominal sensor gain) | D | s14 §4 | |
| O7 | Margin at 2.4 Hz | sustained oscillation needs |δ| ≥ 0.84; W ≈ 0.55; Wu 0.17–0.24 | D | s14 §5 | "≥ 0.19 unmodelled" only if unstructured |

## P. Sine injection (16-Nov, s17)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| P1 | Test | 39 g at 10 mm; f 1.5, 2, 2.4, 3, 4, 6, 8, 12, 20, 40 Hz; A 0.01 (0.02 at 12, 0.04 at 20, 0.08 at 40 Hz) | M | 16-Nov README | |
| P2 | Usable points | 3–40 Hz (< 20 % error); 1.5–2.4 Hz too noisy | M | s17 A | |
| P3 | Loop gain ratio | |L| lab/model 0.9–1.36 at 12–40 Hz | M | s17 A | |
| P4 | Model error bound | |Δ T| ≤ 0.74 < 1 at the well-measured points | D | s17 A | |
| P5 | Coil fit from G_iu (12–40 Hz) | d 0.5: τ 22.6 ms, k_a 2.45; d 0.6: τ 20.5 ms, k_a 2.25; d 0 and d 1 fit ~2.2× worse | M | s17 A | |
| P6 | Limit hits | u at its limits < 1 % of each window (max 0.98 %) | M | s17 A | |

## Q. Variant D on hardware (16-Nov, s18)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| Q1 | Variant D | i0 0.85 A, clamp ±0.45 A, integral held at 0 while run = 0 | D | s18; models/README | |
| Q2 | Reset works | i_ref steady at 0.969 A (expected 0.968) in all 3 coil-off stretches | M | s18 A | |
| Q3 | Closest approach at lift-off | D 10.60 / 10.38 mm vs lab controller 8.95 / 9.00 / 9.07 mm | M | s18 A | n = 2 vs 3, 39 g, normal stand |
| Q4 | Lift time | D 30–33 ms; lab controller 27–30 ms (x < rest − 0.2 mm) | M | s18 A | |
| Q5 | Settling (±0.25 mm of 11 mm) | D 0.14 s vs 0.27–0.52 s | M | s18 A | |
| Q6 | D hover | integral part −0.017 / −0.023 A; x std 0.029 / 0.032 mm | M | s18 A | |
| Q7 | Sim vs lab, D (9 cases from the same rest) | sim ≥ 10.96 mm, lifts ≤ 90 ms; lab 10.38–10.60 mm, 30–33 ms | M/S | s18; 16-Nov README | Inside the 77-case envelope (≥ 10.31 mm, L8) |
| Q8 | Sim vs lab, lab controller (9 cases) | sim ≥ 8.84 mm, ≤ 30 ms; lab 8.95–9.07 mm | M/S | s18 | |

## R. Lowered-stand lift-off (16-Nov, s17)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| R1 | Closest approach | 8.65 / 8.59 mm (rest 13.13 / 13.19 mm); lift 45 / 48 ms | M | s17 C | |
| R2 | Simulation, same rest | nominal 8.90 / 8.89 mm; 9 cases 8.69–9.14 / 8.68–9.14 mm | S | s17 C | **Both lab values outside the simulated range** (s17 FAIL kept) |
| R3 | Difference | lab 0.25–0.30 mm higher than nominal | M/S | s17 C | Lift-off = least well-modelled phase |

## S. Position-only PD comparison (s21)

| ID | Quantity | Value | St | Source | Note |
|---|---|---|---|---|---|
| S1 | Plant | 39 g at 10 mm, u = Kp e + Kr Δe on the duty u | D | s21 | |
| S2 | Lab PD (Kp 45, Kr 450) | on the stability boundary: max|eig| 0.993–1.020, mode 5.1–6.2 Hz (τ 22.5–29 ms, d 0–1) | D | s21 §1 | = H6 |
| S3 | Grid | Kp 10–300 (60, log) × Kr 0–4000 (81) = 4860 gains | D | s21 §2 | |
| S4 | Per project corner (τ 20/27/35 ms × d 0.3/0.5/0.6) | 1.5–5.7 % of the grid stable; best Ms 4.80–12.44 | D | s21 §2 | Nominal τ 27, d 0.5: 2.8 %, best 7.11 |
| S5 | One PD for all 9 corners | 74 of 4860 gains; best worst-case Ms 10.4 (Kp 30.4, Kr 624) | D | s21 §3 | |
| S6 | Cascade at the same 9 corners | Ms 1.36–1.99 (2.23 over the full set) | D | s21 §3 | |
| S7 | Audit's "5.7–13" | not reproduced (here 4.8–12.7 on its corners); do not quote | D | s21 FAIL | |

## T. Hand calculations to show in Section VII (all D, verified)

| ID | Calculation | Value | Check |
|---|---|---|---|
| T1 | i0 = √(m g e^{x0/λ}/c), 39 g, 10 mm | m g = 0.38542 N; e^{10/5.9046} = 5.4389; 2.0963/3.2936 = 0.63646; √ = 0.798 A | = `nom.i0` 0.79779 |
| T2 | u0 = i0/k_a | 0.79779/2.4321 = 0.328 | = `nom.u0` |
| T3 | a21 = g/λ | 9.81/0.0059046 = 1661.4 s⁻²; p = 40.76 rad/s = 6.49 Hz | s10 |
| T4 | b = 2g/i0 | 19.62/0.79779 = 24.59 | s10 |
| T5 | Outer gains (design plant a21 1684.7, b 26.16) | Kd = (ω_i + 2ζω_n)/b = 68/26.16 = 2.599; Kp = (ω_n² + 2ζω_nω_i + a21)/b = 3956.7/26.16 = 151.25; Ki = ω_i ω_n²/b = 19200/26.16 = 733.9 | = phase3_cascade.mat |
| T6 | Kc | a = e^{−3/27} = 0.8948; b_d = 2.44 × 0.1052 = 0.2566; p_in = e^{−1} = 0.3679; Kc = (0.8948 − 0.3679)/0.2566 = 2.054 | = C.Kc 2.0537 |
| T7 | Delay in ms | 0.5 × 3 ms = 1.5 ms; 0.3–0.6 → 0.9–1.8 ms | |
| T8 | ZOH unstable pole | e^{40.76 × 0.003} = 1.1301 | s10 |
| T9 | Mass-only current ratio | √(42.137/39.288) = 1.0356 (3.6 %) | s07/s08 |
| T10 | Stand deficit as weight | (1 − 0.065/0.898)² = 0.860 → 14 %; with 58.5 mA: 12.6 % | N2 |
| T11 | Exp A set-point bound | i_ref = 0 with the integral at −0.30 A needs e < −(0.75 − 0.30)/151.2 = −2.98 mm → x_ref > 14.9 mm | s07 |
| T12 | Cascade outer stability floor | b Kp > a21 → Kp > 1661.4/24.59 = 67.6 A/m (deployed 151.2) | D, new; check in Stage G |
| T13 | M_s target meaning | M_s ≤ 2 ⇒ gain margin ≥ M_s/(M_s − 1) = 2, PM ≥ 2 arcsin(1/(2 M_s)) = 28.96° ≈ 29° | textbook (Skogestad) |
| T14 | Design bias point | i0 = 0.75 A on the s08 law (39 g): e^{x/λ} = 0.5625 × 3.2936 / 0.38542 = 4.8069 → x = 5.9046 × ln 4.8069 = 9.27 mm ≈ 9.3 mm (s07 law: 9.25 mm) | D; data/README says "≈ 9.2 mm" (Z10) |
| T15 | Inner loop vs coil | τ/τ_in = 27/3 = 9 ("about nine times faster") | D |

## U. Not obtained (N) and open items

| ID | Item | St | Note |
|---|---|---|---|
| U1 | Loop gain below 3 Hz (1.5–2.4 Hz too noisy); sine at 11 mm; 42 g sine | N | s17; 16-Nov README |
| U2 | Variant D from the lowered stand | N | no time |
| U3 | Static sensor sweep (stand moved in quarter turns) | N | dropped on 16-Nov |
| U4 | Mechanism of the stand-proximity effect | N | real upward force required; not shadowing alone; not shown to be rotation |
| U5 | Cause of the 2.4 Hz rocking | N | sensor-gain loss reproduces it in the model, not observed |
| U6 | Cause / placement of the loop delay | N | computation, PWM or current-sensor filter |
| U7 | Worst Ms ≤ 2 target | (missed: 2.23) | a result, not N; stated openly (R1) |
| U8 | Exp A set-point typo | unconfirmed | inferred from the data (I2) |
| U9 | Conversion of u (duty) to the manual's volts | unconfirmed | no file states it |
| U10 | Ramp to 11.6 mm with Linear interpolation | N | copy not made |
| U11 | Log sheet for 13-Nov | N | set points rebuilt from the data |

---

## Z. Discrepancies found while building the ledger (decide before Stage C)

| # | What | Where | Proposed handling |
|---|---|---|---|
| Z1 | D6 (16-Nov out-of-sample force-law check, ×0.994–1.011) exists only in AUDIT 4.14; no repo script prints it | AUDIT.md, 16-Nov README | **DECIDED 2026-11-17: not used, no new script.** Knock-on: the "×1.011 at 11.5 mm with the stand lowered" behind "H-force rejected" (s13 text, READMEs) comes from the same audit work. The report rejects H-force only with repo evidence: rocking gone with the stand lowered (N8, s14) and the spike moving with the stand (N5, N7, s17); the 13-Nov ×1.04–1.08 hold excess is then attributed to the stand, not quoted as a force-law value |
| Z2 | Interior coverage |δ|/W: s11 prints 0.77–0.88 per region, s19 prints 0.81 everywhere (different random sample) | s11, s19 | Quote s11's "≤ 0.88" |
| Z3 | s08 console: i-noise 0.018 A and "20× smaller" rocking | s08 printout | Not quoted; report uses 0.021 A and 14× / 19× |
| Z4 | Run-4 hover current at 10 mm: 0.830 A (force-law window) vs 0.824 A (hover window) | s06 | Quote 0.830 A (README), raw reading |
| Z5 | Braking-spike count: 16-Nov README said "9 spikes"; logs give 3 (13-Nov) + 6 (s16) + 2 (s17) = 11 | 16-Nov README | **DECIDED 2026-11-17: quote 11 (N5); README line corrected.** (AUDIT.md left as the audit record) |
| Z6 | s16 prints "POSITION-TIED"; superseded by s17 "STAND-TIED" | s16 console | Report uses stand-tied only |
| Z7 | Lift-off time has two definitions (x < rest − 0.2 mm: 27–45 ms; sweep clock started: 36–48 ms) | s06/s18 vs s09/s16/s17 | Name the definition next to every lift time |
| Z8 | p4_* and p5_* lab-vs-sim figures were simulated with d = 0 (simulator default; s07/s08 do not set d) | figs | State "d = 0" in the captions; quantitative comparisons use M1 (d 0.5) |
| Z9 | AUDIT 3.19 "third implementation within 0.005 mm" not re-run here | models/README | Drop, or cite as audit result |
| Z10 | Design bias point: data/README says i0 = 0.75 A is "≈ 9.2 mm"; the s08 law gives 9.27 mm, the s07 law 9.25 mm | data/README | Report says "about 9.3 mm" (T14) |

---

## Figure list (proposed)

All figures in `figs/` were viewed. Section names follow the instructor's section order (Introduction … Precautions);
the IEEE two-column layout is optional (prof, 2026-11-17), so the report uses a single-column layout with appendices.
"Use" = in the main text; "Appendix" = optional figure, placed in the appendices (decision 2026-11-17); "No" = not used.
Caption obligations are part of the decision.

| # | File | Section | Decision | Caption must say |
|---|---|---|---|---|
| 1 | lab_2026-11-12/screenshots/00_rig_photo_calibration_stand.jpeg or lab_2026-11-16/screenshots/01_rig_front_panel_photo.jpeg | IV Setup (Fig. "Experimental setup") | Use | Rig, stand, ball |
| 2 | (new) block diagram of the cascade loop: coil, ball, sensor, inner/outer loop, delay | III Theory / IV Setup ("Circuit diagram") | Use — **to be drawn** (TikZ in Stage C) | Sign convention e = x − x_ref |
| 3 | lab_2026-11-13/screenshots/01_cascade_top_level.png + 02_cascade_controller_inside.png | IV Setup | Use | Deployed lab model |
| 4 | p1_force_curves.png | III Theory | Appendix | Manual model, 57.1 g ball (benchmark) |
| 5 | p1_sweep.png | III Theory | Appendix | Manual model, u in volts (not our duty u) |
| 6 | p2_bode.png | III Theory | Use | Pre-lab, manual model; filters later found absent |
| 7 | p2_polemap.png | III Theory | Appendix | Pre-lab; (cosmetic: legend shown twice) |
| 8 | p2_nyquist.png | III Theory | Use | Reduced manual plant; one CCW encirclement needed |
| 9 | p9_delay.png | VI Obs. (identification) | Use | Extra delay d ≈ 0.5 sample |
| 10 | p3_inner_step.png | VI Obs. (design) | Appendix | Predicted inner-loop step |
| 11 | p3_lab_run3.png | VI Obs. (first levitation) | Use | Measured inner loop |
| 12 | p3_lab_run4.png | VI Obs. (first levitation) | Use | "simulation (Phase 3)" = pre-identification plant |
| 13 | p3_liftoff_sim.png | VI Obs. (design) | Appendix — **only as a labelled pre-lab check** | Force constants from a withdrawn premise (title says so) |
| 14 | p4_force_fit.png | — | No (superseded by #15) | |
| 15 | p5_force_fit_all.png | VI Obs. (identification) | Use | λ 5.90 mm, 42 visits; 11.5 mm points not fitted |
| 16 | p7_linear_coeffs.png | VI Obs. (uncertainty) | Use | Uncertainty band; 11.5 mm provisional |
| 17 | p7_plant_bode.png | VI Obs. (uncertainty) | Use | 192 corners at d 0.3/0.6 |
| 18 | p7_lin_vs_nl_overshoot.png | VII Calc. / VI Obs. | Appendix | Linearization is not the cause of the mismatch |
| 19 | p4_sweep_lab_vs_sim.png | VI Obs. (hardware) | Use | Exp A/B; sim with d = 0; "set point typo" is **inferred** |
| 20 | p5_sweeps_lab_vs_sim.png | VI Obs. (hardware) | Use | Sim with d = 0 (morning plant) |
| 21 | p4_kg_test.png | VI Obs. (robustness on hardware) | Use | kg is a hardware gain-margin test, not in the set |
| 22 | p4_42g_flip.png | VI Obs. (hardware) | Appendix | Ball turned over (rested at 12.13 mm) |
| 23 | p5_42g_roll.png | VI Obs. (hardware) | Use | Placement matters (hole-up roll) |
| 24 | p5_hold115_rocking.png | VI Obs. (stand effect) | Use | Title says "~20×": caption gives 14× (std) / 19× (band) |
| 25 | p8_margins.png | VI Obs. (robustness) | Use | Worst Ms 2.23 > 2 target |
| 26 | p8_WT.png | — | Appendix (subsumed by #27) | |
| 27 | p8_WT_options.png | VI Obs. (robustness) | Use | Options 1/2 added after the one-disk test failed |
| 28 | p8_clamp_fix.png | VI Obs. (design improvement → variant D) | Use | Simulation |
| 29 | p6_cases_corners.png | VI Obs. (simulation cases) | Use | Grey trace stuck at ~11.2 mm = clamp-limited corner (204 µm steady error) |
| 30 | p6_cases_special.png | VI Obs. (simulation cases) | Use | kg tests outside the set; stress cases at 11.5 mm |
| 31 | p10_overshoot_mismatch.png | VI Obs. (sim vs lab) | Use — **with its H-force curve labelled rejected** (legend already says so) | Panel (d) title "pass through 11 mm" predates the stand-tied finding |
| 32 | p11_rocking.png | VI Obs. (stand effect) | Use | Panel (d) "≥ 0.19" holds only for an unstructured error |
| 33 | p12_3a_steps.png | VI Obs. (stand effect) | Use | (cosmetic: two labels overlap in the lower-left panel) |
| 34 | p14_stand_proximity.png | VI Obs. (stand effect) | Use | Spike moves with the stand |
| 35 | p15_variantD_ramp.png | VI Obs. (variant D + static effect) | Use | n = 2 vs 3, normal stand |
| 36 | p16_liftoff_stand_height.png | VI Obs. (stand effect) | Use | Lift-offs too fast to test the zone (neither confirm nor refute) |
| 37 | p13_sine_loop.png | VI Obs. (sim vs lab) | Use | 1.5–2.4 Hz points too noisy |
| 38 | p17_pd_gain_grid.png | IX Discussion (why a cascade) | Use | s21 numbers (10.4 vs 1.99) |
| 39 | lab_2026-11-12/screenshots/07_scope_coil_test_0p3_0p6_1p0.png | IV Setup / VI Obs. | Appendix | Open-loop coil test |
| 40 | lab_2026-11-16/screenshots/04_sine_model_top_level.png, 05_variantD_model_top_level.png | IV Setup | Appendix | Test models |

Summary: 29 "Use" rows (2 of them lab screenshots/photos and 1 new block diagram), 10 "Appendix", 1 "No" (40 rows).
