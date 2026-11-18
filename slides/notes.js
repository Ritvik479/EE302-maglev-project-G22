// Speaker notes, one entry per slide (index = slide number - 1). Plain text; "\n" = new line.
// Numbers are from the report (main.tex); do not add numbers that are not there.
// SAY parts are sized to the time budget at about 140 words per minute; extra detail lives in IF ASKED lines (not read aloud).

const EVERYONE = "Everyone also reads: Abstract, 1, 3.1-3.2, 4.2 (Fig. 3), 4.5 (conventions), 8 (Results table), 9.5, 10, 11 (Precautions).";
const AVOID = "Never say the stand \"shadows\" the sensor or that the ball \"rotates\" - say the mechanism is still open.";

const BRIEF = {
  Neil: "NEIL - slides 1-4 (about 2 min). Read in the report: 3.3, 3.6, 6.1, 6.2, 7.1.\n" +
    "Your part in plain terms: what the rig is and why the ball falls without control; the two equations that describe the ball and " +
    "the coil; and what we measured in the lab that the manual got wrong (the coil is much slower, and there is a small extra delay).",
  Ritvik: "RITVIK - slides 5-8 (about 2.5 min), then you run the rig during the demo. Read: 6.3, 3.4-3.5, 6.4, 6.7, 7.2-7.3, 9.2-9.3.\n" +
    "Your part in plain terms: how much the plant can vary (the uncertainty set); why a simple position-only controller cannot cope " +
    "with that; how our two-loop controller works and how its gains were picked; and how robust it is, including the one target we missed.",
  Snehal: "SNEHAL - slides 9-11 (about 1.5 min) plus narrating the demo. Read: 6.5, 6.6, 6.8, 6.9.\n" +
    "Your part in plain terms: the controller tested in simulation on every plant variation; explaining the live demo while it runs; " +
    "and how closely the real rig matched the simulation.",
  Saurabh: "SAURABH - slides 12-14 (about 1.5 min), then you lead the questions. Read: 6.10-6.12, 9.6-9.7.\n" +
    "Your part in plain terms: the one effect the model does not explain (something acts on the ball close to the support stand); " +
    "the small controller change (variant D) that made lift-off gentler; and the summary of what worked, what was missed and what is still open.",
};

const TEAM =
  "TEAM BRIEF - 15 min in total: talk about 7.5 min, live demo about 4 min, questions about 3 min.\n\n" +
  BRIEF.Neil + "\n\n" + BRIEF.Ritvik + "\n\n" + BRIEF.Snehal + "\n\n" + BRIEF.Saurabh + "\n\n" +
  EVERYONE + "\n" + AVOID + "\n\n" +
  "Hand-overs: Neil -> Ritvik after slide 4; Ritvik -> Snehal after slide 8 (Ritvik walks to the rig PC while Snehal presents slide 9); " +
  "Snehal -> Saurabh after slide 11.\n" +
  "Timing: each SAY below fits its time at a normal pace. Rehearse with a stopwatch; if you run long, drop the last sentence, not the numbers.\n\n";

const N = [];

// 1 Title
N[0] = TEAM +
  "SPEAKER: Neil (about 15 s)\n" +
  "SAY: Good morning. We are Group 22. Our project is Problem Statement 9: robust control of a magnetic levitation rig. We go from " +
  "the model, to the controller, to the hardware, with a live demo in the middle.";

// 2 Problem
N[1] = "SPEAKER: Neil (about 35 s)\n" +
  "SAY: The rig holds a hollow ferromagnetic ball under an electromagnet; an optical sensor measures the gap x, measured downward. " +
  "The closer the ball gets, the stronger the pull, so hovering is unstable: without control, a position error doubles every 17 ms. " +
  "Our controller runs every 3 ms. The task: identify the plant and its uncertainty, design a robust controller, and verify it in " +
  "Simulink and on the hardware, for two balls between 9 and 11 mm.";

// 3 Model
N[2] = "SPEAKER: Neil (about 45 s)\n" +
  "SAY: The ball follows Newton's law: weight down, magnetic force up. The force grows with current squared and decays exponentially " +
  "with the gap, with decay length lambda. The coil is an inductance, so its current lags the command, with time constant tau. The " +
  "command u is a PWM duty fraction, not volts.\n" +
  "Linearised at the hover point, a21 acts like a negative spring, and b says how strongly current moves the ball; more current pulls " +
  "it up. For the 39 g ball at 10 mm the hover current is 0.798 A and the unstable pole is at 40.76 rad/s.\n" +
  "IF ASKED: a21 = g/lambda does not depend on the gap or the ball; only b = 2g/i0 changes with the operating point.";

// 4 Identification
N[3] = "SPEAKER: Neil (about 45 s)\n" +
  "SAY: From 42 hover points on both balls we fitted lambda = 5.90 mm, against the manual's 5.82, so the manual's physics is right. " +
  "What it gets wrong is the loop around the physics. The coil time constant is 22 to 25 ms; the manual says 0.63. And there is an " +
  "extra delay of about half a 3 ms sample, found two independent ways. This slow coil sits in front of a pole that doubles the error " +
  "every 17 ms, so these two numbers decide stability.\n" +
  "HAND-OVER: \"Ritvik will now show how much the plant can vary, and our controller.\"\n" +
  "IF ASKED how the delay was found: backup slide 15 (B1).";

// 5 Uncertainty set
N[4] = BRIEF.Ritvik + "\n\n" +
  "SPEAKER: Ritvik (about 35 s)\n" +
  "SAY: No single model is exact, so we use a set: two balls, three gaps, and three values each of lambda, the force constant, the coil " +
  "time constant, the coil gain and the delay. That is 1458 plants. Each range covers what we measured, and all 42 measured hover " +
  "currents fall inside the set's prediction. The unstable pole barely moves, but the input gain varies by about minus 21 to plus 16 " +
  "percent. Every robustness number that follows is checked against these 1458 plants.";

// 6 PD vs cascade
N[5] = "SPEAKER: Ritvik (about 45 s)\n" +
  "SAY: Is a simple PD on position enough? The rig's own PD only lifted the ball into a 7 to 9 Hz oscillation hitting the stand. We " +
  "checked thousands of PD gains at the nine coil-and-delay corners. Our measure is M_s, the sensitivity peak: one over the Nyquist " +
  "curve's closest distance to minus one; the target is 2. The best single PD reaches 10.4, so a 10 percent error could destabilise " +
  "it, because it must create phase lead through the slow coil. Our cascade, which measures the current, has 1.99 at the same corners.\n" +
  "IF ASKED: 4860 gain pairs; only 74 are stable at all nine corners; the lab PD oscillated at 7.3-9.3 Hz.";

// 7 Controller
N[6] = "SPEAKER: Ritvik (about 45 s)\n" +
  "SAY: Two loops. The inner loop measures the coil current and makes it follow a reference: a feed-forward term plus K_c on the " +
  "error, tuned for a 3 ms time constant, nine times faster than the coil. So the outer loop sees an almost ideal current source.\n" +
  "The outer PID turns the position error and velocity into that current reference. We placed its poles at 40 rad/s, close to the " +
  "unstable pole, with damping 0.7. K_p is more than twice the minimum needed to beat the negative spring, and the integral is clamped. " +
  "These gains were deployed unchanged on all three lab days.\n" +
  "IF ASKED: integral pole 12 rad/s; minimum K_p = a21/b = 67.6 A/m; a fit on logged data recovered K_p 151.6 and K_d 2.53, confirming " +
  "gains and signs; arithmetic on backup slide 19 (B5).";

// 8 Robustness
N[7] = "SPEAKER: Ritvik (about 50 s)\n" +
  "SAY: Against all 1458 plants the loop is stable everywhere. Nominally M_s is 1.59 and the phase margin 45.4 degrees; over the whole " +
  "set the phase margin stays above 29 degrees and the delay margin above 2.8 ms.\n" +
  "But our target was M_s of at most 2, and the worst plant reaches 2.23, so we missed it, and we say so. It occurs at the largest delay " +
  "with the highest loop gain, where the delay costs the most phase. A lower bandwidth or a delay predictor could fix it; we did not " +
  "have time to try. The robust-stability test |WT| below 1 passes only with the set split into four regions.\n" +
  "HAND-OVER: \"Snehal will show the simulation while I go to the rig.\" Then walk to the rig PC.\n" +
  "IF ASKED: nominal gain range 0.292-3.95, delay margin 5.3 ms; one-disk |WT| = 1.11 (fails), four regions worst 0.997; backup 16 (B2).";

// 9 Simulink
N[8] = BRIEF.Snehal + "\n\n" +
  "SPEAKER: Snehal (about 30 s; Ritvik is walking to the rig)\n" +
  "SAY: Before the hardware, we ran the full nonlinear Simulink model in the lab scenario: lift-off from the stand, then steps from 11 " +
  "to 9 mm and back. In 77 nominal and uncertain cases the ball was never lost. The weak spot: some steps down to 11 mm overshoot to " +
  "within 0.1 mm of the stand. Now Ritvik will show the real rig.\n" +
  "IF ASKED: 51 of the 69 in-set cases met every check; the other 18 came within 0.1 mm of the stand on one step.";

// 10 Demo
N[9] = "DEMO - Ritvik runs the rig, Snehal narrates (about 4 min including setup)\n\n" +
  "RITVIK - BEFORE THE SESSION: rig power supply on; Windows sees the RT-DAC/USB2 board; SensorData loaded; my_cascade_sweep_rt built " +
  "for monitoring and connected; one complete test run done.\n" +
  "RITVIK - AT THE DEMO:\n" +
  "1. 39 g ball, hole-up, on the normal stand. Check the rest reading is about 11.92 mm; if it is more than 0.1 mm off, reseat the ball.\n" +
  "2. Sweep selected (not manual). Scope recording.\n" +
  "3. Run switch ON. The ball lifts and the sweep runs by itself: 9 levels x 5 s, about 45 s.\n" +
  "4. Run switch OFF after the last level; keep recording a few seconds with the coil off.\n" +
  "FALLBACK: if the sweep misbehaves, switch to the manual set point and hold 11 mm (typed in metres: 0.011). If the ball does not lift " +
  "and the current stays near zero, check the rig power supply first. Keep hands out of the gap while the coil is on.\n\n" +
  "SNEHAL - NARRATION (short lines, said as things happen):\n" +
  "- Before: \"The ball rests on the calibration stand. When Ritvik switches on, the controller lifts it to 11 mm.\"\n" +
  "- Lift-off: \"It overshoots towards the magnet first. The integral wound up while the ball sat on the stand; Saurabh will show a fix.\"\n" +
  "- Sweep: \"Every 5 seconds the set point moves 0.5 mm, up to 9 mm and back. Watch the small overshoot on each step. At 9 mm the ball " +
  "is closest to the magnet, so it needs the least current.\"\n" +
  "- Down-steps to 11 mm: \"You may see a sharp dip here. That is the stand effect Saurabh will explain.\"\n" +
  "- End: \"The next slide shows this sweep recorded earlier, with the simulation on top.\"";

// 11 Hardware vs sim
N[10] = "SPEAKER: Snehal (about 45 s)\n" +
  "SAY: Here is the same sweep from an earlier session: blue is the lab, red the simulation. The model predicts the step overshoots " +
  "within 0.10 mm rms on 21 of 24 steps. Measured by sine injection, the phase margin is about 47 degrees, against 45.4 in the model. " +
  "Scaling the command by any gain from 0.4 to 2.0 kept the ball stable, inside the model's predicted range. Both balls held every set " +
  "point from 9 to 11 mm. The model is weaker at lift-off and close to the stand, which Saurabh covers.\n" +
  "IF ASKED: 0.18 mm rms on all 24 steps; model gain range 0.292-3.95; hover jitter 0.028-0.092 mm; sine injection = backup 17 (B3), " +
  "gain test = backup 18 (B4).";

// 12 Stand effect + variant D
N[11] = BRIEF.Saurabh + "\n\n" + AVOID + "\n\n" +
  "SPEAKER: Saurabh (about 50 s)\n" +
  "SAY: Within about 0.7 to 0.8 mm of the calibration stand, three things do not fit the model: the ball needs up to 13 to 14 percent " +
  "less magnetic force, a braking spike appears on down-steps, and a 2.4 Hz rocking appears. We moved the stand, and the spike moved " +
  "with it, while the rocking disappeared. So the effect is tied to the stand; its mechanism is still open, and our operating range " +
  "keeps the stand clear.\n" +
  "Variant D holds the integral at zero until switch-on, so it cannot wind up on the stand. Lift-off stayed about 1.5 mm further from " +
  "the magnet and settled faster, though in only two runs.\n" +
  "IF ASKED: closest approach 10.38-10.60 mm vs 8.95-9.07 mm; settling 0.14 s vs 0.27-0.52 s; 2 runs vs 3; margins unchanged because " +
  "bias and clamp are not in the linear loop; range keeps the stand at least about 0.85 mm below the set point.";

// 13 Conclusion
N[12] = "SPEAKER: Saurabh (about 35 s)\n" +
  "SAY: To sum up. We identified the plant from lab data, designed a cascade controller that is stable over all 1458 plants, never " +
  "lost the ball in 77 simulations, levitated both balls from 9 to 11 mm, and matched the lab within 0.10 mm. We missed one target: the " +
  "worst-case M_s is 2.23 instead of 2. Still open: the cause of the stand effect and of the small loop delay.";

// 14 Questions
N[13] = "SPEAKER: Saurabh leads the questions and passes each one to the right person.\n" +
  "SAY: Thank you. We are happy to take questions.\n\n" +
  "WHO ANSWERS WHAT (backup slide in brackets):\n" +
  "- How was the delay found / why half a sample? -> Neil (slide 15)\n" +
  "- Why does the |WT| test fail when every grid point is stable? -> Ritvik (slide 16)\n" +
  "- How did you get the gains / minimum K_p? -> Ritvik (slide 19)\n" +
  "- Why not a PD / why a cascade? -> Ritvik (slide 6)\n" +
  "- How was the phase margin measured on the hardware? -> Snehal (slide 17)\n" +
  "- Gain margin on the hardware? -> Snehal (slide 18)\n" +
  "- What causes the stand effect? -> Saurabh: it is tied to the stand (it moves with it), it is static and needs an extra upward " +
  "force within about 0.7 mm of the stand; the mechanism is open. " + AVOID + "\n" +
  "- Why only 9-11 mm? -> Neil: the validated range for both balls, keeping the stand about 0.85 mm below the set point.\n" +
  "- Anything you could not confirm? -> anyone: the Experiment A drop is inferred to be a mistyped set point (no log sheet), and the " +
  "conversion from the duty u to the manual's volts is not documented, so lab gains are not compared with the manual's.\n" +
  "- How would you meet M_s <= 2? -> Ritvik: lower the outer bandwidth, or add a one-step predictor to compensate the delay.";

// Backups
N[14] = "BACKUP B1 - Neil answers.\n" +
  "ANSWER: Two independent methods agree. (A) Fitting the coil model to the inner-loop run with different extra delays: the fit error " +
  "is smallest near d = 0.5. (B) The inner loop shapes the current-sensor noise, and the measured noise spectrum matches the model " +
  "with d = 0.5, not 0 or 1. Measured d is 0.32 to 0.55 sample; the uncertainty set uses 0.3 to 0.6. A 1.5 ms delay costs 5.4 degrees " +
  "of phase at 10 Hz. Its cause (computation, the PWM stage, or a filter in the current measurement) cannot be separated with our data.";
N[15] = "BACKUP B2 - Ritvik answers.\n" +
  "ANSWER: The test describes every plant as the nominal times (1 + Delta), with |Delta| bounded by a weight W. It is sufficient, not " +
  "necessary: the disk also contains plants that do not exist, so it can fail although every real plant is stable. One disk around " +
  "39 g at 10 mm gives 1.11 and fails. Splitting the set into four regions (each ball times half of the gap range) gives at worst " +
  "0.997 and passes. The room left for unmodelled error is 22 % below 2 Hz, 0 % from 2 to 10 Hz, 2 % from 10 to 30 Hz and 13 % from " +
  "30 to 166 Hz. Strong evidence, not proof.";
N[16] = "BACKUP B3 - Snehal answers.\n" +
  "ANSWER: We added a sine to the coil command while the 39 g ball levitated at 10 mm, and measured the loop gain L at each frequency. " +
  "The measured phase margin is about 47 degrees against 45.4 in the model, and the measured model error |Delta T| is at most 0.74 from " +
  "3 to 40 Hz. Below 3 Hz the estimate is too noisy (open markers), so the loop gain there was not obtained.";
N[17] = "BACKUP B4 - Snehal answers.\n" +
  "ANSWER: While levitating the 39 g ball at 10 mm, we multiplied the controller output by k_g and stepped it from 1 down to 0.4 and " +
  "up to 2.0. The loop stayed stable throughout, inside the model's predicted range of 0.292 to 3.95. The hover jitter rises at low " +
  "k_g, as the model predicts.";
N[18] = "BACKUP B5 - Ritvik answers.\n" +
  "ANSWER: The design used the plant known after session 1: the manual's lambda (a21 = 1684.7) and a bias current of 0.75 A " +
  "(b = 26.16), coil tau 27 ms. Inner loop: K_c places the sampled coil pole at e^(-T0/tau_in) with tau_in = 3 ms, giving 2.054. Outer " +
  "loop: matching the characteristic polynomial to the chosen poles gives K_d 2.599, K_p 151.25 and K_i 733.9. Minimum K_p at the " +
  "nominal point is a21/b = 67.6 A/m; we use more than twice that. The robustness analysis re-checks the deployed gains against the " +
  "identified set, so the design values did not need to be exact.";

module.exports = { NOTES: N };
