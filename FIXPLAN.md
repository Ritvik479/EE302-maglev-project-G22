# FIXPLAN — acting on AUDIT.md

Created 2026-11-16. Source: `AUDIT.md` (Stages 1–6; whole audit CRITICAL 2, MAJOR 6, MINOR 77, OK 59).
This file is the to-do list. `AUDIT.md` stays the evidence; item numbers below (e.g. 5.21) point into it.

Status legend: `[ ]` open, `[x]` done, `[~]` decided but waiting.

---

## Status

| Step | What | Status |
|---|---|---|
| 0 | Git snapshot of the audited state | [x] 2026-11-16 (baseline commit) |
| 1 | Decisions | [x] 2026-11-16, all final (table below) |
| 2 | Correct `group 28/PARAMETERS.md` (outward-facing) | [x] 2026-11-16 (zip rebuilt). **Student: send it if the old one was shared (D4)** |
| 3 | One canonical stand-zone paragraph, pasted everywhere | [x] 2026-11-16 (text only; scripts parse-checked, not re-run) |
| 4 | Text-only MAJOR fixes | [x] 2026-11-16 (comments/strings only; P values unchanged; nothing to re-run) |
| 5 | Code fixes in leaf scripts (s09, s14, s17, s18) | [ ] |
| 6 | Re-run in dependency order, compare with expectations | [ ] |
| 7 | README updates (robustness numbers, new counts) | [ ] |
| 8 | One value per quantity (text) | [ ] |
| 9 | Remaining MINOR stale text and figures | [ ] |
| 10 | Optional new analysis | [ ] |
| — | Then write D6 (report) | [ ] |

---

## Key fact: nothing upstream has to change

None of the CRITICAL/MAJOR fixes changes a fitted parameter, the controller gains or the data. All are wording,
labels, or code in scripts whose output no other script loads. Re-run chains are therefore short.

### Script dependency map (from the `load`/`save` calls)

```
s05 ──► phase3_cascade.mat ─────────► s06 s07 s08 s13 s16 s17
s07 ──► exp_ABC_results.mat ────────► s08 s09 s10 s13 s16 s17, maglev_cases
s08 ──► sweeps_holds_results.mat ───► s10 s13 s16 s17 s18, maglev_cases
maglev_cases (function, no file) ──► s09 s10 s11 s14 s18
s10 ──► linear_model.mat ───────────► s11 s12 s14
s11 ──► robustness.mat ─────────────► s14
s12 ──► delay_estimate.mat ─────────► maglev_cases   (loop: s10 → s12 → maglev_cases → s10)
Leaves (output loaded by nothing): s09, s13, s14, s16, s17, s18
```

### Do NOT do these (each triggers a large cascade)

| Tempting change | Why not |
|---|---|
| Nominal τ 27 → 22 ms | s05 designed the deployed gains with 27 ms; everything downstream changes. Keep 27 ms as "model nominal", fix the words |
| Overshoot comparisons s07 plant → s08 plant (6.1) | Every ratio in s13/s16/s17 shifts. Name the plant instead (1.6 % apart in λ) |
| Put lab values into `maglev_params.m` | All of s02 changes; s02 is meant to be the pre-lab prediction |
| Re-run s12, or trim the uncertainty set | s12 is in the loop above; trimming changes s11 grid, worst Ms, \|WT\|, s14, and reverses R1 |

---

## Step 1 — Decisions

| # | Question | Decision |
|---|---|---|
| D1 | 1.12: label `maglev_params.m` as manual/pre-lab, or update it | **Label** (final) |
| D2 | 3.16: relabel kg as "hardware gain-margin test", or trim the set with Exp C | **Relabel; R1 stands, no trimming** (final). Exp C cited in the report as evidence the set is conservative on the slow-coil side |
| D3 | 3.22: tilt case → rename "11.5 mm stress case", or scale tilt with gap | **Rename** (final) |
| D4 | Send corrected PARAMETERS.md to the other group if already shared | **Yes, if shared** (final; the student sends it, Claude does not) |

**Basis for D2 (checked 2026-11-16 from `data/robustness.mat`, read-only):**
- Worst Ms 2.230 sits at 39 g, 9 mm, λ +5 %, c +5 %, **τ 20 ms, k_a 2.70, d 0.6**: fast coil, high gain, long delay.
- Worst Ms per level: τ 20/27/35 ms → 2.23/1.89/2.01; d 0.3/0.5/0.6 → 1.71/1.97/2.23; k_a 2.2/2.43/2.7 → 2.01/2.04/2.23.
- All 64 points with Ms > 2 are at d = 0.6.
- Trimming with Exp C (drop points unstable at kg 0.4) removes 260 of 1458 points (τ 27/35 ms only) and leaves
  worst Ms **2.230 unchanged**; PM min rises 29.3° → 31.3°. AUDIT 3.16's remark "would also lower the worst Ms" is
  **not true** for Ms.
- Not yet checked: whether trimming lowers the Option-2 \|WT\| peak (0.997), which depends on the envelope W.
  Needs an s11 run on a scratch copy.
- The measured data support the worst corner itself: τ ≈ 22 ms (sine, 5.11), d 0.5–0.6 (sine, 5.11).

---

## Step 2 — Outward-facing fix first: `group 28/PARAMETERS.md` (DONE)

- [ ] 5.21: replace "likely cause is the stand shadowing the optical sensor" with the canonical stand-zone wording
      (Step 3); drop "≈ 0.8 mm reading error"; "≈ 14 % of the weight at 0.5 mm".
- [ ] 5.27: τ row → "τ ≈ 22–25 ms (step test, ball on the stand; sine injection 12–40 Hz assuming d = 0.5)".
- [ ] 5.26: delay source → "inner-loop step fit (ball on the stand) and sine injection while levitating".
- [ ] 6.2: current zero → "typically 0.03–0.06 A at the start of a session, falling by 0.3–1.2 mA per second of
      coil-on time; measure with u = 0 before and after each run". Never "−1.3 mA/s".
- [ ] 5.28: `group 28/README.md` coil currents "0.67 / 0.92 A (0.93 A at lift-off)"; drop "each sample stored twice".
- [x] Also: u labelled as a PWM duty fraction (2.19); `read_scope_fig.m` "stored twice" comment fixed in both
      copies (2.17; copies still byte-identical).
- [x] Rebuilt `group 28.zip` (same layout, verified byte-identical to the folder).
- [ ] Send it, if the old version was already shared (D4) — the student's action.

## Step 3 — Canonical stand-zone paragraph (fixes 5.21 + 4.12 together) (DONE)

Done 2026-11-16. The reference text is the "Stand-proximity effect" bullet in `data/lab_2026-11-16/README.md`
(Main results); other files carry one corrected sentence and point there. The 13-Nov README keeps the old claims
struck through with a dated "[Superseded 2026-11-16]" note. Edited: 16-Nov README, 13-Nov README (4 places),
`group 28/PARAMETERS.md` (plain-language version), s18 header + RECORD message (no "reading error", no "% of
weight"), s14 header §4 + §4 check message + §6 "nature", s07 line 96, s08 §6 check message + §6b comment, s10
unmodelled table row, `maglev_cases` U row ("x artifact at 2.45 Hz (11.5 mm stress case)"). Case names in
`maglev_cases`/s09 ('tilt artifact', 'lab-like') are NOT renamed yet: that is Step 5 (s09 looks them up by name).
Console text of s07/s08/s10/s14/s18 changed in wording only; numbers untouched.

Original plan for this step:

These two must be written as ONE text: both describe the zone ~0.7–0.9 mm above the stand. Content (AUDIT 6D 1–2):
- Within ~0.7–0.8 mm of the stand the hover current falls below the force law; closer than ~0.75 mm it even
  **decreases** as the ball approaches the stand (−35 mA over 0.35 mm while the law needs +27 mA). A reading error
  alone would need a negative sensor slope (reversed feedback), yet the ramp tracked within 0.001 mm → at least part
  is a **real upward force**; mechanism unknown.
- Size varies steeply with distance (~200 mA/mm) and between days; quote the onset, not one size (5.23).
- 2.4 Hz limit cycle at 11.5 mm (0.4 mm above the stand): "ball rotation" is unsupported. A loss of position-sensor
  gain to ~0.45–0.6 near the stand reproduces 2.4 Hz in the linear model, s08's Newton slope 1.7 and the limit-cycle
  character, but not the static current deficit and not why the 42 g ball barely rocks. Not observed directly.
- Both vanish with the stand lowered (one session, 4.18). Lift-offs passing the same heights show no extra force (4.8).
- Operating range: set points 9–11 mm, both balls, stand reading ≥ ~0.85 mm below the set point (6.4).

Paste into: 16-Nov README (Main results), `group 28/PARAMETERS.md`, s18 header (line 12), s14 §4–5 text
(lines 162, 209), s07 line 96, s08 §6b, 13-Nov README (3 places), s10 unmodelled-effects table, `maglev_cases`
U "tilt artifact" row.

## Step 4 — Text-only MAJOR fixes (no re-run needed) (DONE)

Done 2026-11-16. `maglev_params.m`, `maglev_equilibrium.m`, s01, s02, s05: comment lines only (verified: 0
non-comment lines changed), so P, `phase1/2_results.mat` and the s01/s02 consoles are unchanged. `maglev_cases`:
kg row "[NOT in the robust set]" with the 33/243 evidence; gap range 9-11 mm (11.5 = stress case); tau evidence
22-25 ms measured / 27 ms design; header "D tested on the hardware 16-Nov". Still 77 cases. Also done here:
1.14 (57.1 g provenance), 1.16 (s02 PURPOSE (2) + SCOPE note), 1.18 (file names), 1.19 (Fig 45/46), 2.19 in the
12-Nov and 16-Nov READMEs (u = PWM duty fraction; "1.35 s/m effective" instead of "V·s/m").

Original plan for this step:

- [ ] 1.12 `maglev_params.m` header: P.loop / P.act are "manual / pre-lab, used only by s01–s02"; drop "the ONE place".
- [ ] 1.13 / 2.19: state everywhere that lab u is a **PWM duty fraction 0..1** (driver Gain 4095), not volts;
      manual model u is volts; conversion ≈ 4.5 unverified. Drop "V·s/m". (If a print line is added to s01/s02,
      re-run: expect 36/36, 39/39.)
- [ ] 2.15 s05 header (line 13): replace "predicted (and was observed) to oscillate at 7-9 Hz" with: linear model puts
      the lab PD on the stability boundary (unstable pole ~5.5 Hz); the observed 7–9 Hz is a large-amplitude cycle
      hitting the stand; a position-only PD is at best fragile (best Ms 5.7–13 over a full gain grid) → cascade for
      robustness.
- [ ] 3.16 `maglev_cases` line 69: kg row labelled per D2. Same file: header line 18 "D = SIMULATION ONLY" → tested
      on hardware 16-Nov; "9–11.5 mm validated" → 9–11 mm; τ evidence wording (22–25 ms measured).

## Step 5 — Code fixes in leaf scripts

- [ ] **s09** — 3.22: ringing test for noisy/tilt cases (e.g. 1.5–3.5 Hz band of the true x vs a limit); rename
      "lab-like" → "11.5 mm stress case" (D3); `lost` also catches x ≈ 0; count 53 of 73, not 54. Also 3.26 (kg 0.4
      line hidden in `p6_cases_special.png`: draw on top/dashed), "same 75 cases" → 77 (line 192), "SIMULATION ONLY"
      (line 190), CLEARANCE/3b explanation → "model lacks the stand effect" (3.23, 3.24).
- [ ] **s17** — 5.15: compute the lowered-stand lift-off sim from the measured rest readings (13.13 / 13.19 mm),
      nominal + the 9 corners as s18 does, instead of the hard-coded "8.65–8.70" (line 202). Expected: nominal
      8.89–8.90, corners 8.68–9.14; lab 8.59–8.65 = 0.25–0.3 mm higher than nominal, 13.19 mm run outside all 9.
      Also 5.13 (`p13` phase wrapping, sort by frequency, flag noisy points), 5.12 wording.
- [ ] **s14** — 4.12: add the sensor-gain scan (s = 1 … 0.4 on the outer loop) and the stand-spring scan
      (a21_eff down to −10 000 s⁻²) to §4; expect s ≈ 0.45 → unstable 2.4 Hz, spring → modes 12–22 Hz. Reword §4–5;
      drop "most likely a rotation"; add the lowered-stand hold to §1 (band rms 0.050 mm).
- [ ] **s18** — 5.22: `chkp(isStatic, …)` instead of `chkp(true, …)`; header per Step 3.

## Step 6 — Re-run order and expectations

| # | Script | Expect |
|---|---|---|
| 0 | s07, s08 (optional) | wording-only changes; re-run only to refresh console logs; `.mat` must be identical |
| 1 | s10 | 12/0; `LM` identical (`isequaln` vs git); only `U` changes |
| 2 | s11 | 12/4; `robustness.mat` identical (sanity) |
| 3 | s14 | 8 PASS + new scan checks |
| 4 | s09 | "fully ok" 53 (or what the new ringing test gives); total may change — explain any new FAIL |
| 5 | s17 | 10/1 + new lift-off lines |
| 6 | s18 | 5/0 |

Do NOT re-run s05–s08 or s12. Compare every rewritten `.mat` with the git baseline.

## Step 7 — READMEs

- [ ] 3.14: write the robustness numbers into a README: grid 1458 points all stable; worst Ms 2.23 (target ≤ 2
      **missed**; 1.97 at d 0.5); Option-2 \|WT\| peak 0.997 (42 g, 10–11 mm); PM ≥ 29°; gain range [0.54, 2.23];
      delay margin ≥ 2.8 ms; ~0 room for unmodelled error at 2–10 Hz.
- [ ] New s09 count; lowered-stand lift-off numbers (5.15); "simulation optimistic for D" vs which envelope (6.6);
      D lift time sim ≤ 90 vs lab 30–33 ms (5.19).

## Step 8 — One value per quantity (text only)

| Quantity | Use everywhere |
|---|---|
| Extra loop delay d | 0.5 sample (range 0.3–0.6); drop 0.55 as "nominal" |
| Coil τ | measured 22–25 ms; model nominal 27 ms; range 20–35 ms |
| Current noise | 0.021 A (not 0.018) |
| λ | 5.90 ± 0.15 mm (systematic) |
| "The model" | s08 plant for robustness / Simulink; s07 plant for overshoot comparisons (say so) |
| Nominal point | gains designed for i0 0.75 A; analysis 39 g at 10 mm; manual comparison 9 mm |
| Lift-off time | one definition ("x < rest − 0.2 mm") or name both |
| Operating range | as in Step 3 |

## Step 9 — Remaining MINOR stale text and figures

- [ ] s13 §5–6 and 13-Nov README H-force paragraphs (4.6, 4.7); "Partly explained by s13"; `[record]` labels (4.9).
- [ ] s12 header "worst Ms 5.0" (3.6); s02 PURPOSE (2) wording (1.16); file names (1.18).
- [ ] Figures: don't use `p3_liftoff_sim.png` (2.21), `p10`/`p11` (stale interpretation) without fixes;
      `p2_polemap.png` legend (1.17); `p12`/`p15` label overlaps (5.30).
- [ ] `models/README.md`: `my_cascade_ramp116_rt` still saved Flat; steps model first level 8 s; demo model saved
      with x_ref 11.5 mm (5.5).

## Step 10 — Optional

- [ ] s13 §5b redone, binned by height above the stand, with the lowered-stand lift-offs (4.8).
- [ ] Position-only PD gain-grid figure (2.15).
- [ ] D2 follow-up: does Exp C trimming lower the Option-2 \|WT\| peak? (scratch s11 run)
