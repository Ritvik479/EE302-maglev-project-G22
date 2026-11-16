# Lab session 2026-11-16 (group 22, INTECO MLS1EM USB2, lab PC R2024a)

Third and last planned slot. All runs use the cascade controller (Kp 151.2, Ki 734, Kd 2.6, i0 0.75 A,
integral clamp ±0.3 A, inner loop Kc 2.05 + feed-forward 1/2.44, u limited to 0..0.9) unless stated, sample time
T0 = 3 ms, sensor table `models/group22_sensor.mat`. Gap x is measured downward from the magnet (larger x = ball lower).
Analysis: `scripts/s16_analyze_3a.m`, `s17_analyze_1116.m`, `s18_analyze_D_ramp.m`; figures `figs/p12`–`p15`.

Morning: the rig did not respond (no position, no coil current). Cause: Windows did not recognise the RT-DAC/USB2
board ("Device Descriptor Request Failed", screenshots 02–03). The student fixed it by reconnecting; the exact fix was not recorded.

## Files
Each run was saved from the scopes with *Print to Figure → Save* (`.fig`). Read them with `scripts/read_scope_fig.m`
(`openfig` fails off the lab PC). The scope stores every sample twice (stairs); `read_scope_fig` removes that.

| Scope file | Channels (in order) |
|---|---|
| `*_main.fig` | Position [m], Velocity [m/s], Current [A], Control [V] (= command u sent to the rig, 0..0.9) |
| `*_iref.fig` (sweep-type models: steps, ramp, sweep) | Current [A], i_ref [A], x_ref [m], tau [s] (sweep clock: counts only while x < lift threshold) |
| `sine_*_iref.fig` | Current [A], i_ref [A] (labelled "Cascade controller/2") |
| `sine_*_sine.fig` | Position, Current, u_c (controller output before injection), Control (total u), d_inj, f_inj [Hz], A_inj |
| `variantD_*_iref.fig` | Current [A], i_ref [A] (labelled "Cascade controller/2"), run (0 = coil off, 1 = on) |

Renamed on 2026-11-16 (contents unchanged) from `data/runs_1116/`: `3a_*` → `steps_*`, `3b_39g_1*` → `rampFLAT_*`,
`3b116_*` → `ramp116FLAT_*`, `3b_39g_2*` → `ramp_*`, `4_39g_*` → `sine_39g_10mm_*`, `2_39g_*` → `sweep_39g_lowstand_*`,
`5_39g_norm_*` → `variantD_39g_*`.

## Runs (39 g = 39.288 g ball, 42 g = 42.137 g ball, both placed hole-up)

| Run | Model | Ball, stand (rest reading) | What was done | Notes |
|---|---|---|---|---|
| `steps_39g` | `my_cascade_steps_rt` | 39 g, normal (11.903 mm) | lift to 11 mm, table steps 11.0→10.8→11.1→10.6→11.0→10.5→11.0 mm every 5 s of tau | coil on at 7.5 s; tail only 0.44 s |
| `steps_42g` | `my_cascade_steps_rt` | 42 g, normal (11.887 mm) | same table | coil on at 13.4 s; **no coil-off tail** (record ends levitating); ball swung 8.8–11.9 mm for 2.5 s after lift |
| `rampFLAT_39g` | `my_cascade_ramp_rt` | 39 g, normal (11.85 mm) | intended slow ramp; **ran with Flat interpolation** (model not rebuilt) → x_ref jumped 11→10.5→**11.4**→10.5 mm | the 0.9 mm down-step came within **0.03 mm** of the stand |
| `ramp116FLAT_39g_lowstand` | `my_cascade_ramp116_rt` | 39 g, lowered (13.13 mm) | same problem: x_ref jumped 11→10.5→**11.6**→10.5 mm | lift threshold 12.0 mm |
| `ramp_39g` | `my_cascade_ramp_rt` (rebuilt, Linear) | 39 g, normal (11.854 mm) | **correct ramp**: 11→10.5 (0–5 s tau), hold, 10.5→11.4→10.5 mm at 0.2 mm/s (tau 10–19 s), hold | tracking error ~0.001 mm; tail 5.8 s |
| `sine_39g_10mm` | `my_cascade_sine_rt` | 39 g, normal (≈11.82 mm) | hover at 10 mm; sine added to u: f 1.5, 2, 2.4, 3, 4, 6, 8, 12, 20, 40 Hz; A 0.01 (0.02 at 12 Hz, 0.04 at 20 Hz, 0.08 at 40 Hz; lower-A segment first at 12/20/40 Hz) | one −5.4 A current glitch at t = 2.38 s (before switch-on); u touches its limits in < 1 % of samples (position-reading spikes) |
| `sweep_39g_lowstand` | `my_cascade_sweep_rt` | 39 g, lowered (13.19 mm) | lift, sweep 11→9→11 mm (0.5 mm per 5 s of tau), then manual 11.5 mm hold (t ≈ 59.8–71.4 s), back to 11 | tail 2.2 s |
| `variantD_39g` | `my_cascade_D_rt` | 39 g, normal (11.781 mm) | variant D (i0 0.85 A, clamp ±0.45 A, integral held at 0 while run = 0): run 0→1 at 7.89 s, 1→0 at 28.34 s, 0→1 at 32.87 s, 1→0 at 41.29 s; set point 11 mm, typed steps to 10.5 and back during the first lift | **x_ref is not logged** in this model; rest reading below the 11.87–12.00 mm tolerance |

Not done (no time): variant D from the lowered stand, sine at 11 mm, 42 g sine, the static sensor sweep (item 1, dropped).

## Main results (details and checks in the scripts)
- **Stand-proximity effect.** A braking spike on fast down-steps appears 0.70–0.85 mm above the stand on BOTH stand
  heights (s16, s17), and the slow ramp shows the quasi-static current falling below the force law from ~0.7 mm above
  the stand (−65 mA at 0.48 mm, 10 standard errors; s18). So the effect is static. It is equivalent to ~0.8 mm of reading
  error or ~15 % of the weight. Leading (unproven) explanation: the stand shadows the optical sensor.
  The 13-Nov overshoot mismatch goes with this effect (down-steps with a spike: lab/model 0.33–0.56; without: median 0.99).
- **11.5 mm hold with the stand lowered:** no 2.4 Hz rocking (x std 0.115 mm, peak 4.3 Hz) vs 0.253 mm at 2.43 Hz on
  13-Nov with the normal stand (one run each).
- **Loop gain by sine injection (39 g, 10 mm):** crossover ≈ 29 Hz (model 23.6), phase margin ≈ 47° (interpolated
  between 20 and 40 Hz), largest measured |S| 1.51 at 40 Hz (model 1.58); coil time constant fit 20.7 ms (model 27 ms);
  1.5–2.4 Hz points too noisy (> 20 % error).
- **Variant D works on the hardware:** reset holds i_ref at i0 + Kp e while the coil is off; lift-off closest approach
  10.38–10.60 mm vs 8.95–9.07 mm for the lab controller; settles in 0.14 s vs 0.27–0.52 s.
- **Lift-off from the lowered stand (13.1–13.2 mm), lab controller:** closest approach 8.59–8.65 mm (simulation 8.65–8.70).

## Screenshots
01 rig front panel photo · 02 Device Manager (USB descriptor request failed) · 03 "USB device not recognized" dialog ·
04 `my_cascade_sine_rt` top level · 05 `my_cascade_D_rt` top level · 06 ramp table, Algorithm tab (Linear point-slope;
the run `rampFLAT_*` shows this setting was not yet in the deployed build)
