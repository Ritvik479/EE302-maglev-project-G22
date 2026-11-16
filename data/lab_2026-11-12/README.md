# Lab session 2026-11-12 (group 22)

Lab PC: MATLAB R2024a, models in `C:\Users\hp\Desktop\group_22` (`my_driver`, `my_pd_rt`, `my_pid_rt` = copies of the INTECO examples).
Ball: 39.288 g. Sensor table: `SensorData` from the 06-Nov-2026 calibration file (saved on lab PC as `group22_sensor.mat`; copy in `models/` since 2026-11-13).

## discovery/
Output of `scripts/s03_lab_discovery.m` for the three models.
Findings: T0 = 3 ms (ode3, external mode), no driver filters, velocity = (x[k]-x[k-1])/T0,
lab PD: Kp 35, Kd 450 on Δe (= 1.35 V·s/m), u0 0.282; lab PID: P 40, I 40, D 2, U0 0.344.

## runs/  (read with load(file,'-mat'); openfig fails on laptop)
| File | What | Result |
|---|---|---|
| `run4_pd_oscillation_39g.fig` | PD, Kp 45. u0 0.30 at 0 s, 0.32 at ~5 s, 0.34 at ~12 s; Kp→40 at ~16 s | Sustained 7-9 Hz oscillation, up to 9 mm p-p, ball hits the stand every cycle |
| `coil_steps_0p2_0p3_0p4.fig` | `my_driver`, EM1 Control 0→0.2→0.3→0.4→0.2, ball on stand at 12.9 mm | Coil: I ≈ 2.4-2.6 × u, first-order τ ≈ 25-29 ms, no extra dead time. Ball jumped to the magnet at u = 0.4 (0.93 A) |
| `run4_quicklook.png` | Quick plot of run 4 (not report style) | |

## screenshots/
00 rig photo · 01-04 model diagrams · 05 PD with the ball on the stand at 8.4 mm (no lift: above the setpoint) ·
06-07 open-loop coil test (0.3/0.6/1.0 → 0.68/1.40/2.45 A) · 08 PD with the stand at 11.8 mm (no lift: 0.87 A too low).

## unusable/
Logs that saved only 1 sample (workspace logging problem), an empty trace file, and a zero-control run. Kept only for the record.
