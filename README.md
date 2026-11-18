# Robust Control of a Magnetic Levitation System

Modelling, identification, robust controller design and hardware validation for the **INTECO MLS1EM** magnetic
levitation rig, a steel ball held below an electromagnet. Final project (Problem Statement 9) of EE302 Control Systems
Laboratory at IIT Mandi, Group 22.

📄 **[Project report (PDF)](report/G22_Project%20Report.pdf)** · 📊 **[Presentation](slides/G22_Presentation.pptx)** ·
🗒️ **[Speaker notes](slides/G22_Speaker_Notes.pdf)**

## The problem

The rig is nonlinear and open-loop unstable: without control, a position error doubles every 17 ms. The magnetic force
grows with the square of the coil current and decays exponentially with the gap, the coil lags the command, and the loop
has a small extra delay. The goal was a controller that stays stable over everything we could not pin down exactly: two
balls, a range of set points, and uncertain force, coil and delay parameters.

## What we did

1. **Identified the plant from lab data.** The manual's force law held (decay length λ = 5.90 mm, against the manual's
   5.82 mm), but its loop description did not: the coil time constant is 22–25 ms rather than 0.63 ms, and the loop
   has an extra delay of about half a 3 ms sample.
2. **Built an uncertainty set** of 1458 plants from the measured ranges (2 balls, 9–11 mm, force constants, coil and delay).
3. **Showed why a position-only PD is not enough.** The best PD over the coil and delay corners has a worst-case
   sensitivity peak of 10.4.
4. **Designed a cascade controller**: a 3 ms inner current loop inside an outer PID position loop placed by pole placement.
5. **Checked robustness** over the whole set, then ran nonlinear Simulink simulations and hardware experiments.

## Results

| | |
|---|---|
| Stability over the 1458-plant set | stable everywhere, phase margin ≥ 29.3°, delay margin ≥ 2.8 ms |
| Worst-case sensitivity peak M<sub>s</sub> | 2.23. **The target of 2 was missed.** |
| Robust stability \|WT\| < 1 | fails as one disk (1.11); passes with the set split into four regions (0.997) |
| Simulink, 77 nominal and uncertain cases | the ball was never lost |
| Hardware | both balls levitated at every set point from 9 to 11 mm; stable for actuator gains 0.4–2.0 |
| Simulation vs hardware | step overshoots within 0.10 mm rms; phase margin about 47° measured vs 45.4° predicted |

Close to the calibration stand we found an effect the model does not contain (a force deficit, a braking spike and a
2.4 Hz rocking, all of which move with the stand). Its mechanism is still open. The report lists everything that was not
obtained or could not be confirmed.

## Repository layout

| Path | Contents |
|---|---|
| `maglev_params.m` | Parameters of the manual's model (pre-lab) |
| `scripts/` | Analysis and design scripts `s01`–`s21` plus helpers (plant models, equilibrium, scope-file reader, nonlinear simulator) |
| `models/` | Simulink models: `maglev_cl_sim.slx` (closed-loop simulation) and the hardware models `my_*_rt.slx`. See [models/README.md](models/README.md) |
| `data/` | Raw lab recordings from three sessions (`lab_2026-11-*/runs/*.fig`), screenshots, and the `.mat` results of the scripts. See [data/README.md](data/README.md) |
| `figs/` | Figures produced by the scripts and used in the report |
| `report/` | Report source (`main.tex`) and the submitted PDF |
| `slides/` | Presentation, speaker notes, and the scripts that build them. See [slides/README.md](slides/README.md) |

## Running the code

**Requirements:** MATLAB with Simulink and the Control System Toolbox (developed on R2026a). No other toolboxes are
needed.

Open MATLAB in the repository root and run the scripts in `scripts/` in numeric order. Later scripts read the `.mat`
results of earlier ones. Every script prints `PASS`/`FAIL` self-checks, including a test that catches a wrong feedback
sign.

```matlab
cd scripts
s01_verify_model      % reproduces the manual's model and numbers
s05_cascade_design    % designs the cascade controller
s11_robustness        % margins and |WT| over the uncertainty set
```

> **Note:** the scripts overwrite their outputs in `data/*.mat` and `figs/` in place. To keep the committed results,
> run them on a copy of the repository.

Scripts tagged `[LAB]` (`s03`, `s04`, `s15`) and the `my_*_rt.slx` hardware models are for the lab PC. They need the
INTECO MLS toolbox and the RT-CON real-time target, so they will not run elsewhere. All other scripts are `[STANDALONE]`.

## Conventions

- The gap `x` is measured **downward** from the magnet: a larger `x` means the ball is lower.
- The error is `e = x − x_ref`. Positive controller gains raise the current when the ball is too low.
- The command `u` is a PWM duty fraction between 0 and 1, **not** volts (the lab scopes label it "[V]").

## Not included

The INTECO user's manual and the problem statement are third-party documents and are not distributed here. The
report cites them where they are used.

## Team

Group 22: Neil Bakshi, Ritvik Garg, Saurabh Gopal, Snehal Narendra Patil.
Instructor: Dr. Yanumula Venkata Karteek, IIT Mandi.
