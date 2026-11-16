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
| Parameter | Value | Evidence |
|---|---|---|
| Static gain | 2.43 A per unit of u | hover and step data |
| Time constant | 25–29 ms | step test (`coil_steps_0p2_0p3_0p4.fig`) |
| Time constant at 12–40 Hz | ≈ 21 ms | frequency response by sine injection |
| Low-end nonlinearity | gain ≈ 1.9 A/unit for steps starting at u = 0 | step test |
| Extra loop delay | 0.3–0.6 sample (≈ 1–2 ms) beyond the normal one-sample hold | estimated from levitation data |

## Sensors (as delivered by the INTECO driver block)
| Signal | Notes |
|---|---|
| Position | from the optical sensor via the 33-point table `group22_sensor.mat` (`SensorData`); noise ≈ 0.011 mm rms |
| Velocity | (x[k] − x[k−1]) / T0, unfiltered; one large spike at start-up (memory starts at 0) |
| Current | noise ≈ 0.021 A rms; **zero offset ≈ 0.04 A** that drifts by about −0.5 to −1.3 mA/s while levitating: TRUE current ≈ reading − offset (measure the offset with u = 0 before each run) |

## Caveats
- **Stand proximity.** Within about 0.7–1.0 mm of the calibration stand (the threaded rod under the ball), the readings
  depart from the force law: the current needed falls by up to ~65 mA at 0.5 mm. The likely cause is the stand
  shadowing the optical sensor (not proven). Keep the stand ≥ 1 mm below your lowest operating point, or exclude
  near-stand data.
- **Ball orientation matters.** Balls have a hole; seat them hole-up. The 42 g ball tends to roll to hole-down (its rest
  reading then drops ~0.2 mm). The 42 g sweep file in this folder was recorded hole-down.
- **Rig-specific.** The sensor table and the force constants belong to this rig unit and these balls. On a different
  rig, re-measure the sensor calibration (INTECO identification tool) and check the hover currents.
- Driver Saturation Control is 0..5; the coil saturates well before that (u = 1 gives ≈ 2.4 A).
