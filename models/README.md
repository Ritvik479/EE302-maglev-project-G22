# models/

## Lab models [LAB] (copied from the lab PC `C:\Users\hp\Desktop\group_22` on 2026-11-16, MATLAB R2024a)
Build them on the lab PC only (target `mls1em_rtcon_usb2.tlc`, External mode, Hardware → Monitor & Tune) with
`SensorData` loaded (`load group22_sensor.mat`). They need the INTECO MLS toolbox, so they will not simulate off the lab PC.
Controller values in every cascade model: Kp 151.2, Ki 734, Kd 2.6, i0 0.75 A, integral clamp ±0.3 A, Kc 2.05,
feed-forward 1/2.44, i_ref 0..2 A, u 0..0.9 (variant D differs, see below). e = x − x_ref.

| File | Purpose | Used for |
|---|---|---|
| `my_driver.slx` | INTECO device driver example (copy, unmodified): constant command to the coil | coil tests, setting the stand (EM1 Control 0) |
| `my_pd_rt.slx`, `my_pid_rt.slx` | INTECO PD / PID examples (copies, unmodified) | 2026-11-12 runs; base of the cascade models |
| `my_cascade_rt.slx` | cascade controller, manual set point, test/run switch (i_test) | 2026-11-13 first levitation, Exp A/B |
| `my_cascade_kg_rt.slx` | as `my_cascade_rt` + constant `kg` multiplying u before the limit | 2026-11-13 Exp C (actuator-gain test) |
| `my_cascade_sweep_rt.slx` | gated sweep clock (tau counts while x < 11.5 mm) → lookup table 11→9→11 mm (Flat) + auto/manual switch | 2026-11-13 sweeps and holds, 2026-11-16 item 2. **Demo model** |
| `my_cascade_steps_rt.slx` | sweep model with table 11.0→10.8→11.1→10.6→11.0→10.5→11.0 mm | 2026-11-16 item 3a |
| `my_cascade_ramp_rt.slx` | sweep model with table 11→10.5→10.5→11.4→10.5→10.5 mm, **Linear** (0.2 mm/s ramp) | 2026-11-16 item 3b (only the rebuilt run `ramp_39g` ramped) |
| `my_cascade_ramp116_rt.slx` | ramp to 11.6 mm, lift threshold 12.0 mm (lowered stand only) | 2026-11-16 (ran Flat, see the data README) |
| `my_cascade_sine_rt.slx` | `my_cascade_rt` + injection d_inj = A_inj sin(2π f_inj t) added to u before the limit; logs u_c, d_inj, f_inj, A_inj | 2026-11-16 item 4 |
| `my_cascade_D_rt.slx` | **variant D**: i0 0.85 A, clamp ±0.45 A, integral held at 0 while `run` = 0 (Constant `run` → Switch; `run == 0` → level reset) | 2026-11-16 item 5. Save with `run` = 0 |
| `group22_sensor.mat` | `SensorData` sensor calibration (33 points, 06-Nov-2026 export) used for every lab build | all lab models |

**Check before trusting a copy:** the `.slx` files were copied after the last runs on 2026-11-16 and were not re-inspected
here. The ramp lesson applies: after changing a non-tunable setting (e.g. interpolation method), Save + Build before
Monitor & Tune, and confirm on the scope that the change is live.

## Build caches [LAB] `build_cache_2026-11-13/`
`*.slxc` of `my_cascade_rt`, `my_cascade_kg_rt`, `my_cascade_sweep_rt`, `my_driver`, `my_pd_rt`, built 2026-11-13 17:36
(OLDER than the `.slx` files above). Generated C code + compiled DLL; not openable as diagrams. `*_data.c` inside records the
parameters deployed on 2026-11-13. They were the source for `scripts/s15_rebuild_lab_models.m` (backup rebuilder, written when
the lab models were thought deleted; tested on the laptop with a stand-in plant, 33/0, never run on the lab PC). Keep for the
record; not needed to build anything.

## Simulation model [STANDALONE]
| File | What |
|---|---|
| `maglev_cl_sim.slx` | Closed-loop simulation for the nominal and uncertain cases (PS9 deliverable 2). Nonlinear plant (fitted force law, coil lag, stand and magnet limits), sensors (noise, current-zero offset and drift, optional tilt artifact), and the lab cascade controller block for block, including the gated sweep clock. **Do not edit by hand:** rebuilt by `scripts/build_maglev_cl_sim.m` every time `scripts/s09_sim_models.m` runs. Parameters come from the workspace structs `pl`, `C`, `L`, `sc`, defined in `scripts/maglev_cases.m` |

### How the simulation model is used
```matlab
run maglev_params.m;  [K, B, U] = maglev_cases(P);         % cases, base structs, uncertainty table
mdl = build_maglev_cl_sim('models');                        % (re)build the .slx
k = 1;                                                      % e.g. 'nominal 39 g'
in = Simulink.SimulationInput(mdl).setVariable('pl', K(k).pl).setVariable('C', B.C) ...
     .setVariable('L', B.L).setVariable('sc', K(k).sc);
out = sim(in);   plot(out.tt, out.x, out.tt, out.xref)      % logged: tt x xm it im u iref xref tau
```
Controller variant D in simulation: `[K, B] = maglev_cases(P, 'D')` gives i0 0.85 A, integral clamp ±0.45 A and the integral
reset to 0 at switch-on (`sc.zI = 0`). The default `'lab'` is the deployed controller, whose integral is wound up to the
clamp at switch-on. See `scripts/s11_robustness.m` (section 6) and `s09_sim_models.m` (section 5). Variant D was tested on
the hardware on 2026-11-16 (`data/lab_2026-11-16`, `scripts/s18_analyze_D_ramp.m`): lift-off closest approach 10.38–10.60 mm
measured vs ≥ 10.96 mm simulated (the simulation is optimistic for D).

**Loop delay (revised 2026-11-15).** The coil receives u delayed by d = `sc.nd + sc.ndSub/10` samples beyond the
normal ZOH step, through ONE Delay block at the solver step T0/10 (length `10*sc.nd + sc.ndSub`; exact because u
changes only every T0). The delay line starts holding `sc.uIC` (0 for a lift-off, the equilibrium command for a hover
start). `maglev_cases` sets the measured value from s12: nominal d = 0.5, corners at 0.3 and 0.6, plus reference cases
at d = 0 (the model before 2026-11-15) and d = 1 (stress). The logged `u` is the controller output before the delay,
as on the lab scope.

### Verification (s09, re-run 2026-11-15 with the measured delay)
- Agrees with the independent MATLAB simulation `scripts/maglev_cascade_sim.m` within 0.0001 mm (same delay in both),
  for d = 0, 0.3, 0.5, 0.6 and 1; and the delay is active (the undelayed run differs by 0.11 A in current).
- Reproduces the lab 39 g sweep: lift timing 36 vs 39 ms, step overshoot 0.14 mm rms, hover current 3.0 mA rms.
- Sign test: with e = x_ref − x the ball never lifts.
- 77 cases (73 in the uncertainty set + 4 delay references): ball never lost; 19 cases of the set come within 0.1 mm of
  the stand on the 10.5 → 11 mm down-step (CLEARANCE, model overpredicts that overshoot ~2×; 2026-11-16: that
  overprediction is the stand-proximity effect, see `data/lab_2026-11-16/README.md`).
- Variant D: agrees with the MATLAB simulation within 0.0001 mm. Over all 77 cases it never loses the ball, never clamps
  the integral, lifts within 321 ms, and its highest point at lift-off is ≥ 10.31 mm (lab controller: 7.10 mm worst).
