# MagLev rig and ball parameters (measured by Group 22, EE302, Nov 2026)

Rig: INTECO MLS1EM USB2, lab PC (MATLAB R2024a). Sample time T0 = 3 ms (fixed step, ode3, External mode).
Gap x is measured from the magnet face, **downward positive** (larger x = ball lower).
Please credit Group 22 if you use these numbers or the data files.

## Balls
| Ball | Mass |
|---|---|
| "39 g" | 39.288 g |
| "42 g" | 42.137 g |

## Force law (fitted to 42 steady hover points, 9–11 mm, both balls)
F = c · i² · exp(−x / λ)   (upward),   with i = TRUE coil current

| Parameter | Value |
|---|---|
| λ (decay length) | 5.90 mm |
| c, 39 g ball | 3.29 N/A² |
| c, 42 g ball | 3.02 N/A² |

Equilibrium current: i_eq = sqrt(m g / c) · exp(x / (2λ)). Examples (true current):

| Gap | 39 g | 42 g |
|---|---|---|
| 9 mm | 0.73 A | 0.79 A |
| 10 mm | 0.80 A | 0.86 A |
| 11 mm | 0.87 A | 0.94 A |

Linearised at 10 mm, 39 g ball: x'' = a21 Δx − b Δi with a21 = g/λ ≈ 1661 s⁻² (unstable pole √a21 ≈ 40.8 rad/s
≈ 6.5 Hz) and b = 2g/i_eq ≈ 24.6 m s⁻² A⁻¹.

## Coil (command u → current i)
The command u is a **PWM duty fraction, 0..1** (the driver scales it to 0..4095 counts). The scope labels it "[V]",
but it is not a voltage.

| Parameter | Value | Evidence |
|---|---|---|
| Static gain | 2.43 A per unit of u | hover and step data |
| Time constant | ≈ 22–25 ms | step test with the ball resting on the stand (22.5–25 ms, `coil_steps_0p2_0p3_0p4.fig`); sine injection at 12–40 Hz while levitating gives ≈ 22 ms if the extra delay is 0.5 sample. Steps taken with the ball stuck at the magnet give up to 29 ms |
| Low-end nonlinearity | gain ≈ 1.9 A/unit for steps starting at u = 0 | step test |
| Extra loop delay | 0.3–0.6 sample (≈ 1–2 ms), best estimate ≈ 0.5, beyond the normal one-sample hold | fit of a current-loop step (ball resting on the stand) and sine injection while levitating; both give ≈ 0.5. Time constant and delay trade off against each other in the fits |

## Sensors (as delivered by the INTECO driver block)
| Signal | Notes |
|---|---|
| Position | from the optical sensor via the 33-point table `group22_sensor.mat` (`SensorData`); noise ≈ 0.011 mm rms |
| Velocity | (x[k] − x[k−1]) / T0, unfiltered; one large spike at start-up (memory starts at 0) |
| Current | noise ≈ 0.021 A rms. **Zero offset**: typically 0.03–0.06 A at the start of a session, and it keeps falling while the coil is on, by about 0.3–1.2 mA per second (on one day it reached −0.02 A). TRUE current ≈ reading − offset: measure the offset with u = 0 **before and after** each run and interpolate linearly between the two |

## Caveats
- **Stand proximity.** Within about 0.7–0.9 mm of the calibration stand (the threaded rod under the ball), the ball
  does not follow the force law. The current needed to hover falls below the law: on one day by about 60 mA at 0.5 mm
  above the stand (13–14 % of the ball's weight). The size changes steeply with distance and varied between days, so
  treat the onset (~0.7–0.8 mm) as the reliable number. Closer than ~0.75 mm, the current even **decreases** as the
  ball moves toward the stand. A position-sensor error alone cannot do that: it would need the reading to move
  opposite to the ball, which reverses the feedback and would make the loop unstable, yet the ball tracked its set
  point within 0.001 mm. So at least part of the effect is a **real upward force** on the ball. We do not know its
  cause. Near the stand we also saw a braking jolt when the ball approached it quickly, and a 2.4 Hz oscillation while
  hovering 0.4 mm above it. All of these moved with the stand or vanished when we lowered it (one session). Keep the
  stand at least ~1 mm below your lowest operating point, or exclude near-stand data.
- **Ball orientation matters.** Balls have a hole; seat them hole-up. The 42 g ball tends to roll to hole-down (its rest
  reading then drops ~0.2 mm). The 42 g sweep file in this folder was recorded hole-down.
- **Rig-specific.** The sensor table and the force constants belong to this rig unit and these balls. On a different
  rig, re-measure the sensor calibration (INTECO identification tool) and check the hover currents.
- Driver Saturation Control is 0..5; the coil saturates well before that (u = 1, i.e. 100 % duty, gives ≈ 2.4 A).
