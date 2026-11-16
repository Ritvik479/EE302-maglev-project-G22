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
- **Stand-proximity effect** (revised 2026-11-16 after the audit, AUDIT.md 4.12, 5.21; this is the reference text,
  other files point here). Within about 0.7–0.9 mm of the calibration stand the rig departs from the plant model;
  further away it agrees (with the stand lowered, the 13-Nov force law predicts today's hover currents at 9–11.5 mm
  within ~1 %). Three observations:
  1. *Static* (slow ramp, s18): the drift-corrected hover current falls below the force law from ~0.7–0.8 mm above the
     stand, to −58 … −65 mA at 0.48 mm (two methods; 10 standard errors), i.e. ≈ 13–14 % of the weight is carried by
     something other than the magnet. Closer than ~0.75 mm the current even **decreases** as the set point moves
     toward the stand (−35 mA over the last 0.35 mm, where the force law needs +27 mA).
  2. *Fast approach* (s16, s17): a braking spike in the acceleration 0.67–0.89 mm above the stand (9 spikes, both balls,
     13-Nov and 16-Nov, normal and lowered stand).
  3. *Hover 0.4 mm above the stand* (13-Nov, 39 g at 11.5 mm): a 2.4 Hz limit cycle (1.5–3.5 Hz band rms 0.25 mm).

  All three move with the stand or vanish when it is lowered (one lowered-stand session). What it is not, and what is
  open:
  - **Not a sensor reading error alone** ("the stand shadows the optical sensor", stated here before). To explain
    observation 1 with an unchanged force, the true ball would have to rise ~0.45 mm while the reading moved down
    0.35 mm: a negative sensor slope, which reverses the feedback sign. Yet the ramp tracked within 0.001 mm. So at least
    part of the effect is a **real upward force** on the ball; its mechanism is unknown. ("~0.8 mm of reading error",
    stated here before, is therefore not a physical equivalent.)
  - **The 2.4 Hz mode is not shown to be a rotation of the ball.** In the linear model, a loss of position-sensor gain
    near the stand (the reading moving only 0.45–0.6× the true motion) makes the vertical loop itself oscillate at
    2.4–3.1 Hz, and it matches s08's Newton slope 1.7 and the limit-cycle character (the gain loss exists only near the
    stand). But such a gain loss does not explain observation 1, nor why the 42 g ball barely rocks at the same height,
    and it was not observed directly. So: two effects, or one mechanism not yet identified.
  - Lift-offs that pass the same heights quickly show no extra force (s13 §5b; unresolved).
  - Size: it changes steeply with distance (~200 mA/mm near the stand) and so between days (13-Nov hold at 0.43 mm:
    −30 … −39 mA; this ramp at 0.48 mm: −58 … −65 mA). Quote the onset (~0.7–0.8 mm), not one size.

  Consequence for the claimed range: set points 9–11 mm, both balls, with the stand reading at least ~0.85 mm below
  the set point; 11.5 mm on the normal stand is excluded; transients that come within ~0.8 mm of the stand (e.g. the
  10.5 → 11 mm overshoots) are outside the model. The overshoot mismatch goes with this effect: today's down-steps
  with a spike have lab/model 0.33–0.48 (s16; 0.56 for the lowered-stand 10.5 → 11.6 jump, s17), those without
  0.61–1.20 (median 0.99); the 13-Nov 10.5 → 11 mismatch (lab 0.25–0.32 vs model 0.64–0.73) is the same pattern.
- **11.5 mm hold with the stand lowered:** no 2.4 Hz rocking: 1.5–3.5 Hz band rms 0.048 mm vs 0.25 mm on 13-Nov with
  the normal stand (one run each). Its x std 0.115 mm is ordinary for that run (9–11 mm plateaus 0.055–0.120 mm).
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
