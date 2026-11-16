# Reference data from Group 22 (EE302 MagLev, IIT Mandi, Nov 2026)

Measurements of the **rig and the balls** (not of any particular controller design), to use as reference for your
own plant model. Please credit Group 22 if you use them. Start with `PARAMETERS.md`, which summarises the fitted values.

## Files
| File | What it is |
|---|---|
| `PARAMETERS.md` | fitted plant parameters (force law, coil, delay, sensor noise) and caveats |
| `coil_steps_0p2_0p3_0p4.fig` | **coil step test**, 12-Nov: INTECO driver model, ball resting on the stand at 12.9 mm. Command steps u = 0 → 0.2 → 0.3 → 0.4 → 0.2 gave current ≈ 0.06 → 0.44 → 0.69 → 0.93 → 0.44 A. At u = 0.4 the ball jumped to the magnet (the lift-off current at 12.9 mm lies between 0.69 and 0.93 A). 25 s |
| `sweep_39g_holeup_main.fig`, `sweep_39g_holeup_iref.fig` | **levitation sweep, 39 g ball** (hole-up), 13-Nov: lift-off, then set point 11 → 10.5 → 10 → 9.5 → 9 → 9.5 → 10 → 10.5 → 11 mm (10 s at the first level, then 5 s per level, timed from lift-off), coil switched off at the end. 71.5 s |
| `sweep_42g_holedown_main.fig`, `sweep_42g_holedown_iref.fig` | same sweep, **42 g ball** (hole-down). Still levitating when the record ends. 75.1 s |
| `group22_sensor.mat` | `SensorData` sensor calibration (33 points, 0–22.4 mm) used for all these runs. Load it before building any model on the same rig |
| `read_scope_fig.m` | reader for the `.fig` files (see below) |

The sweeps were flown with a feedback controller in the loop. Use the **steady hover levels** (mean current at each
gap; controller-independent) and the coil test. The transients between levels reflect that controller, not yours.

## Reading the .fig files
They are Simulink scope plots saved with *Print to Figure → Save*. `openfig` usually fails on other PCs; use
```matlab
r = read_scope_fig('sweep_39g_holeup_main.fig');   % r.t (time, s), r.y (one column per channel), r.names
plot(r.t, r.y(:,1))                                % e.g. position [m]
```
Each sample is stored twice by the scope (stair plot); the reader removes the duplicates. Sample time 3 ms.

| File | Channels (columns of r.y, in order) |
|---|---|
| `coil_steps_*.fig` | Position [m], Velocity [m/s], EM1 Current [A], EM1 Control (= u) |
| `*_main.fig` | Position [m], Velocity [m/s], Current [A], Control [V] (= command u, 0..0.9) |
| `*_iref.fig` | Current [A], i_ref [A] (current set point of that controller), x_ref [m] (position set point), tau [s] (sweep clock: counts only while the ball is lifted) |

Both scopes of a run share the same time stamps. Position is downward from the magnet (larger = lower).
The current reading has a ≈ 0.04 A zero offset (see `PARAMETERS.md`): subtract the reading taken with the coil off.
