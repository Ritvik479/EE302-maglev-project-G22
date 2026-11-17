# Reference data from Group 22 (EE302 MagLev, IIT Mandi, Nov 2026)

Measurements of the **rig and the balls** (not of any particular controller design), to use as reference for your
own plant model. Please credit Group 22 if you use them. Start with `PARAMETERS.md`, which summarises the fitted values.

## Files
| File | What it is |
|---|---|
| `PARAMETERS.md` | fitted plant parameters (force law, coil, delay, sensor noise) and caveats |
| `coil_steps_0p2_0p3_0p4.fig` | **coil step test**, 12-Nov: INTECO driver model, ball resting on the stand at 12.9 mm. Command steps u = 0 → 0.2 → 0.3 → 0.4 → 0.2 gave current readings ≈ 0.06 → 0.44 → 0.67 → 0.92 → 0.44 A (end of each level; readings include the ≈ 0.06 A zero offset). At u = 0.4 the ball jumped to the magnet at a reading of 0.93 A (so the lift-off reading at 12.9 mm lies between 0.67 and 0.93 A). 25 s |
| `sweep_39g_holeup_main.fig`, `sweep_39g_holeup_iref.fig` | **levitation sweep, 39 g ball** (hole-up), 13-Nov: lift-off, then set point 11 → 10.5 → 10 → 9.5 → 9 → 9.5 → 10 → 10.5 → 11 mm (10 s at the first level, then 5 s per level, timed from lift-off), coil switched off at the end. 71.5 s |
| `sweep_42g_holedown_main.fig`, `sweep_42g_holedown_iref.fig` | same sweep, **42 g ball** (hole-down). Still levitating when the record ends. 75.1 s |
| `group22_sensor.mat` | `SensorData` sensor calibration (33 points, 0–22.4 mm) used for all these runs. Load it before building any model on the same rig |
| `read_scope_fig.m` | reader for the `.fig` files (see below) |

The sweeps were flown with a feedback controller in the loop. Use the **steady hover levels** (mean current at each
gap; controller-independent) and the coil test. The transients between levels reflect that controller, not yours.

## Screenshots (if the .fig files will not open)
`screenshots/` has one PNG per recording (same file name, `.png`): every scope channel against time over the full
record, position and x_ref in mm (magnet at the top of the axis), plus `group22_sensor_table.png` (the 33-point
sensor calibration with its values). They were drawn from the data in the `.fig` files, not captured from the scope
window. The velocity axis leaves out the driver's one-sample start-up spike at t = 0. For numbers (hover currents,
step times) use the data via `read_scope_fig.m` rather than reading them off the images.

## Reading the .fig files
They are Simulink scope plots saved with *Print to Figure → Save*. `openfig` usually fails on other PCs; use
```matlab
r = read_scope_fig('sweep_39g_holeup_main.fig');   % r.t (time, s), r.y (one column per channel), r.names
plot(r.t, r.y(:,1))                                % e.g. position [m]
```
Sample time 3 ms. The reader also drops any repeated time stamps (these files have none).

| File | Channels (columns of r.y, in order) |
|---|---|
| `coil_steps_*.fig` | Position [m], Velocity [m/s], EM1 Current [A], EM1 Control (= u, PWM duty fraction 0..1) |
| `*_main.fig` | Position [m], Velocity [m/s], Current [A], Control (= command u, a PWM duty fraction; the scope labels it [V]; this controller limits it to 0..0.9) |
| `*_iref.fig` | Current [A], i_ref [A] (current set point of that controller), x_ref [m] (position set point), tau [s] (sweep clock: counts only while the ball is lifted) |

Both scopes of a run share the same time stamps. Position is downward from the magnet (larger = lower).
The current reading has a ≈ 0.04 A zero offset (see `PARAMETERS.md`): subtract the reading taken with the coil off.
