// Build the D6 presentation (Group 22, PS9). Run from slides/: node build_deck.js
// Output: build/deck_raw.pptx + build/eqs.json; then python -I inject_eq.py and render.ps1 (see README.md).
const fs = require("fs");
const path = require("path");
const pptxgen = require("pptxgenjs");
const { applyTheme } = require("./apply_theme.js");

const A = (f) => path.join(__dirname, "assets", f);
const BUILD = path.join(__dirname, "build");
fs.mkdirSync(BUILD, { recursive: true });

const THEME = {
  name: "Maglev G22",
  headFontFace: "Cambria",
  bodyFontFace: "Calibri",
  colors: {
    dk1: "1B2333", lt1: "FFFFFF", dk2: "14213D", lt2: "EEF2F7",
    accent1: "14213D", accent2: "E0A800", accent3: "C0392B", accent4: "2E7D32",
    accent5: "2F6DB5", accent6: "6B7789", hlink: "2F6DB5", folHlink: "6B7789",
  },
};
const HEX = { navy: "14213D", text: "1B2333", red: "C0392B", green: "2E7D32", grey: "6B7789", blue: "2F6DB5" };

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.333 x 7.5 in
pres.title = "Robust Control of a Magnetic Levitation System - Group 22";
pres.author = "Group 22";
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
const C = pres.SchemeColor;
const W = 13.333;

// ---------- layouts ----------
const FOOT = "Group 22  ·  Robust control of a magnetic levitation system";
pres.defineSlideMaster({
  title: "CONTENT",
  background: { color: C.background1 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 0.3, w: 12.1, h: 1.0, fontSize: 26, bold: true,
        color: C.text2, valign: "middle", align: "left", margin: 0 }, text: "" } },
    { text: { text: FOOT, options: { x: 0.6, y: 7.0, w: 8, h: 0.3, fontSize: 10, color: C.accent6, margin: 0 } } },
  ],
  slideNumber: { x: 12.2, y: 7.0, w: 0.5, h: 0.3, fontSize: 10, color: C.accent6, align: "right" },
});
pres.defineSlideMaster({
  title: "DARK",
  background: { color: C.text2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.8, y: 1.2, w: 11.7, h: 1.6, fontSize: 40, bold: true,
        color: C.background1, valign: "bottom", align: "left", margin: 0 }, text: "" } },
  ],
});

// ---------- helpers ----------
// mini markup for proper sub/superscripts in ordinary text: k_{a}, s^{-2}
function runs(str, base = {}) {
  const out = [];
  const re = /([_^])\{([^}]*)\}/g;
  let last = 0, m;
  while ((m = re.exec(str))) {
    if (m.index > last) out.push({ text: str.slice(last, m.index), options: { ...base } });
    out.push({ text: m[2], options: { ...base, [m[1] === "_" ? "subscript" : "superscript"]: true } });
    last = re.lastIndex;
  }
  if (last < str.length) out.push({ text: str.slice(last), options: { ...base } });
  return out;
}
// several paragraphs, each a markup string (or {t, opts})
function paras(list, base = {}) {
  const out = [];
  // paragraph-level options (bullet) go on the first run only: pptxgenjs starts a new paragraph at every run carrying them
  const { bullet, ...charBase } = base;
  list.forEach((p, k) => {
    const t = typeof p === "string" ? p : p.t;
    const o = typeof p === "string" ? {} : p.opts || {};
    const r = runs(t, { ...charBase, ...o });
    if (bullet) r[0].options.bullet = bullet;
    r[r.length - 1].options.breakLine = k < list.length - 1;
    out.push(...r);
  });
  return out;
}
function text(slide, content, opts) {
  const body = typeof content === "string" ? runs(content) : content;
  slide.addText(body, { isTextBox: true, fontSize: 15, color: C.text1, valign: "top", margin: 0, ...opts });
}
function card(slide, x, y, w, h, name, fill = C.background2) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, fill: { color: fill }, line: { type: "none" },
    rectRadius: 0.08, objectName: name });
}
function stat(slide, x, y, w, h, big, label, color = C.text2, name = "stat") {
  card(slide, x, y, w, h, name);
  text(slide, runs(big, { bold: true }), { x: x + 0.2, y: y + 0.12, w: w - 0.4, h: 0.62, fontSize: 28, color,
    fontFace: THEME.headFontFace, valign: "middle", objectName: name + "_value" });
  text(slide, label, { x: x + 0.2, y: y + 0.76, w: w - 0.4, h: h - 0.86, fontSize: 13, color: C.text1,
    objectName: name + "_label" });
}
function caption(slide, str, x, y, w, h = 0.3) {
  text(slide, str, { x, y, w, h, fontSize: 11, color: C.accent6, italic: true });
}
function title(slide, str) {
  slide.addText(runs(str), { placeholder: "title" });
}
// native PowerPoint equation: a text box now, replaced by OMML in inject_eq.py
const EQS = {};
function eq(slide, id, latex, x, y, w, h, sz = 20, color = HEX.text, align = "left") {
  if (EQS[id]) throw new Error("duplicate eq id " + id);
  EQS[id] = { latex, sz: Math.round(sz * 100), color, align };
  const plain = latex.replace(/\\(mathrm|text|hat|dot|ddot)\{([^}]*)\}/g, "$2").replace(/\\[a-zA-Z]+/g, " ")
    .replace(/[{}]/g, "").replace(/\s+/g, " ").trim();
  slide.addText(plain, { isTextBox: true, x, y, w, h, fontSize: sz, fontFace: "Cambria Math", color: C.text1,
    valign: "middle", margin: 0, objectName: "EQ_" + id });
}
function label(slide, str, x, y, w, color = C.accent6) {
  text(slide, runs(str, { bold: true }), { x, y, w, h: 0.3, fontSize: 13, color });
}
function img(slide, file, x, y, w, ratio, name) {
  slide.addImage({ path: A(file), x, y, w, h: w / ratio, objectName: name, altText: name });
}
function imgH(slide, file, x, y, h, ratio, name) {
  slide.addImage({ path: A(file), x, y, w: h * ratio, h, objectName: name, altText: name });
}

// ======================= 1. Title =======================
pres.addSection({ title: "Talk" });
let s = pres.addSlide({ masterName: "DARK", sectionTitle: "Talk" });
s.addText("Robust Control Design and Experimental Validation of a Magnetic Levitation System",
  { placeholder: "title" });
text(s, "Final Project · Problem Statement 9", { x: 0.8, y: 2.95, w: 6.4, h: 0.45, fontSize: 20, color: C.accent2,
  objectName: "subtitle" });
text(s, paras(["Neil Bakshi  B24344", "Ritvik Garg  B24349", "Saurabh Gopal  B24352", "Snehal Narendra Patil  B24353"]),
  { x: 0.8, y: 3.8, w: 5.6, h: 1.6, fontSize: 17, color: C.background1, paraSpaceAfter: 4, objectName: "team" });
text(s, "Group 22  ·  Instructor: Dr. Yanumula Venkata Karteek", { x: 0.8, y: 5.75, w: 6.4, h: 0.4, fontSize: 15,
  color: C.background2, objectName: "group" });
s.addImage({ path: A("rig_photo.jpg"), x: 7.45, y: 3.05, w: 5.3, h: 5.3 / 1.778, objectName: "rig photo",
  altText: "INTECO MLS1EM magnetic levitation rig" });

// ======================= 2. Problem =======================
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Talk" });
title(s, "The ball is open-loop unstable: any position error doubles every 17 ms");
img(s, "rig_photo.jpg", 0.6, 1.5, 6.9, 1.778, "rig photo");
caption(s, "INTECO MLS1EM: electromagnet, optical position sensor, hollow steel ball, calibration stand; interface box on the right",
  0.6, 5.42, 6.9, 0.5);
card(s, 0.6, 6.0, 6.9, 0.8, "goal");
text(s, [{ text: "Goal  ", options: { bold: true, color: C.text2 } },
  { text: "identify the plant and its uncertainty, design a robust controller, verify it in Simulink and on the hardware, compare the two",
    options: {} }], { x: 0.8, y: 6.05, w: 6.5, h: 0.7, fontSize: 14, valign: "middle", objectName: "goal text" });
stat(s, 8.0, 1.5, 4.7, 1.45, "17 ms", "time for a position error to double without control (unstable pole at 6.49 Hz)", C.accent3, "s_double");
stat(s, 8.0, 3.15, 4.7, 1.45, "3 ms", "controller sample time on the lab PC (Simulink external mode)", C.text2, "s_ts");
stat(s, 8.0, 4.8, 4.7, 1.45, "9–11 mm", "set-point range, two balls: 39 g and 42 g", C.text2, "s_range");

// ======================= 3. Plant model =======================
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Talk" });
title(s, "Model: the magnetic force falls with the gap, and the coil current lags the command");
label(s, "Ball (Newton's 2nd law; gap x measured downward)", 0.6, 1.5, 7);
eq(s, "newton", String.raw`m\ddot{x} = mg - c\,i^{2}e^{-x/\lambda}`, 0.6, 1.85, 7, 0.65, 24);
label(s, "Coil (first-order lag)", 0.6, 2.7, 7);
eq(s, "coil", String.raw`\tau\frac{di}{dt} = -i + k_{a}u`, 0.6, 3.05, 7, 0.75, 24);
label(s, "Linearized about the hover point (x_{0}, i_{0})", 0.6, 4.0, 7);
eq(s, "lin", String.raw`\delta\ddot{x} = a_{21}\,\delta x - b\,\delta i,\qquad a_{21} = \frac{g}{\lambda},\quad b = \frac{2g}{i_{0}}`,
  0.6, 4.35, 7, 0.8, 22);
label(s, "Plant from command to gap", 0.6, 5.3, 7);
eq(s, "tf", String.raw`G_{xu}(s) = \frac{-b}{s^{2} - a_{21}}\cdot\frac{k_{a}}{\tau s + 1}`, 0.6, 5.65, 7, 0.85, 22);
card(s, 8.2, 1.5, 4.5, 4.4, "nominal card");
label(s, "Nominal: 39 g ball at 10 mm", 8.45, 1.65, 4.1, C.text2);
eq(s, "i0", String.raw`i_{0} = 0.798\ \text{A}`, 8.45, 2.1, 4.1, 0.5, 20);
eq(s, "a21", String.raw`a_{21} = 1661\ \text{s}^{-2}`, 8.45, 2.65, 4.1, 0.5, 20);
eq(s, "b", String.raw`b = 24.59\ \text{m}\,\text{s}^{-2}\,\text{A}^{-1}`, 8.45, 3.2, 4.1, 0.5, 20);
eq(s, "poles", String.raw`s = \pm\sqrt{a_{21}} = \pm 40.76\ \text{rad/s}`, 8.45, 3.75, 4.1, 0.5, 20);
text(s, "The + pole is unstable: 6.49 Hz, error doubles in ln 2 / 40.76 = 17 ms", { x: 8.45, y: 4.35, w: 4.1, h: 0.75,
  fontSize: 14, objectName: "pole note" });
text(s, "Plus an extra loop delay of about half a sample (1.5 ms), found from the data", { x: 8.45, y: 5.1, w: 4.1, h: 0.7,
  fontSize: 14, objectName: "delay note" });
text(s, "x gap · i coil current · u command (PWM duty, 0–1) · c, λ force constants · k_{a} coil gain · τ coil time constant",
  { x: 8.2, y: 6.05, w: 4.5, h: 0.7, fontSize: 11, color: C.accent6, objectName: "symbols" });

// ======================= 4. Identification =======================
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Talk" });
title(s, "Lab data confirmed the manual's force law but not its coil: 22–25 ms, not 0.63 ms");
img(s, "force_fit.png", 0.6, 1.5, 6.6, 1.643, "force fit");
caption(s, "Hover current against gap, 42 hover visits, both balls: fitted λ = 5.90 mm, residual 5.9 mA rms", 0.6, 5.58, 6.6, 0.5);
{
  const hdr = (t) => ({ text: t, options: { bold: true, color: C.background1, fill: { color: C.text2 } } });
  const cell = (t, o = {}) => ({ text: runs(t), options: o });
  const hi = { fill: { color: "FFF3C4" }, bold: true };
  const rows = [
    [hdr("Parameter"), hdr("Identified"), hdr("Manual")],
    [cell("Force decay length λ"), cell("5.90 ± 0.15 mm"), cell("5.82 mm")],
    [cell("Force constant c (39 / 42 g)"), cell("3.29 / 3.02 N/A^{2}"), cell("3.01 N/A^{2}")],
    [cell("Coil gain k_{a}"), cell("2.43 A per unit"), cell("in volts")],
    [cell("Coil time constant τ", hi), cell("22–25 ms", hi), cell("0.63 ms", hi)],
    [cell("Extra loop delay d"), cell("≈ 0.5 sample (1.5 ms)"), cell("none")],
  ];
  s.addTable(rows, { x: 7.6, y: 1.5, w: 5.1, colW: [2.2, 1.65, 1.25], fontSize: 13, color: C.text1,
    border: { type: "solid", pt: 0.5, color: "C9D1DC" }, rowH: 0.48, valign: "middle", margin: 0.06,
    objectName: "param table" });
}
card(s, 7.6, 4.65, 5.1, 1.75, "consequence");
text(s, paras([{ t: "Why it matters", opts: { bold: true, color: C.text2 } },
  "A 22–25 ms coil lag sits in front of a pole that doubles the error every 17 ms. With a 0.63 ms coil this would not matter; here it decides stability."]),
  { x: 7.8, y: 4.75, w: 4.7, h: 1.55, fontSize: 14, paraSpaceAfter: 4, objectName: "consequence text" });

// ======================= 5. Uncertainty set =======================
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Talk" });
title(s, "The uncertainty set: 1458 plants built from the measured ranges");
{
  const hdr = (t) => ({ text: t, options: { bold: true, color: C.background1, fill: { color: C.text2 } } });
  const cell = (t) => ({ text: runs(t), options: {} });
  const rows = [
    [hdr("Parameter"), hdr("Range"), hdr("Levels")],
    [cell("Ball mass m"), cell("39.3 / 42.1 g"), cell("2")],
    [cell("Gap x_{0}"), cell("9–11 mm"), cell("3")],
    [cell("Decay length λ"), cell("± 5 %"), cell("3")],
    [cell("Force constant c"), cell("± 5 %"), cell("3")],
    [cell("Coil time constant τ"), cell("20–35 ms"), cell("3")],
    [cell("Coil gain k_{a}"), cell("2.2–2.7 A/unit"), cell("3")],
    [cell("Extra delay d"), cell("0.3–0.6 sample"), cell("3")],
  ];
  s.addTable(rows, { x: 0.6, y: 1.5, w: 5.4, colW: [2.4, 2.0, 1.0], fontSize: 14, color: C.text1,
    border: { type: "solid", pt: 0.5, color: "C9D1DC" }, rowH: 0.47, valign: "middle", margin: 0.06, objectName: "set table" });
}
text(s, paras([{ t: "2 × 3^{6} = 1458 grid plants", opts: { bold: true, color: C.text2 } },
  "Every range covers the measured values with margin; all 42 measured hover currents fall inside the band the set predicts."]),
  { x: 0.6, y: 5.45, w: 5.4, h: 1.3, fontSize: 14, paraSpaceAfter: 4, objectName: "set note" });
img(s, "plant_bode_mag.png", 6.5, 1.5, 6.2, 2.855, "plant bode");
caption(s, "Plant gain |G_{xu}| over the set (grey) and the two nominal plants", 6.5, 3.75, 6.2);
stat(s, 6.5, 4.3, 2.95, 1.6, "6.33–6.66 Hz", "unstable pole across the set", C.text2, "s_pole");
stat(s, 9.75, 4.3, 2.95, 1.6, "−21 / +16 %", "spread of the input gain b about nominal", C.text2, "s_b");

// ======================= 6. Why cascade =======================
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Talk" });
title(s, "No position-only PD is robust on this plant; feeding back the coil current fixes it");
imgH(s, "pd_vs_cascade.png", 0.6, 1.5, 4.95, 1.179, "pd vs cascade");
caption(s, "Worst-case M_{s} at the nine coil/delay corners (τ in ms / d in samples): best PD per corner (red) vs the deployed cascade (blue)",
  0.6, 6.48, 6.1, 0.5);
label(s, "Sensitivity peak: the robustness measure used throughout", 7.2, 1.5, 5.5);
eq(s, "ms", String.raw`M_{s} = \underset{\omega}{\text{max}}\,|S(j\omega)| = \frac{1}{\underset{\omega}{\text{min}}\,|1 + L(j\omega)|}`, 7.2, 1.8, 5.5, 1.0, 20);
text(s, "Smaller M_{s} = Nyquist curve farther from −1. Target M_{s} ≤ 2 (gain margin ≥ 2, phase margin ≥ 29°).",
  { x: 7.2, y: 2.8, w: 5.5, h: 0.65, fontSize: 14, objectName: "ms note" });
stat(s, 7.2, 3.6, 2.6, 1.5, "10.4", "best position-only PD, worst corner", C.accent3, "s_pd");
stat(s, 10.1, 3.6, 2.6, 1.5, "1.99", "cascade, worst of the same corners", C.accent4, "s_casc");
text(s, "In the lab, the supplied PD (K_{p} 35–45) only lifted the 39 g ball into a 7.3–9.3 Hz oscillation that hit the stand every cycle.",
  { x: 7.2, y: 5.3, w: 5.5, h: 0.9, fontSize: 14, objectName: "lab pd note" });

// ======================= 7. Controller =======================
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Talk" });
title(s, "Cascade controller: a 3 ms current loop inside a PID position loop placed by pole placement");
img(s, "blockdiag.png", 0.5, 1.45, 7.6, 2.158, "block diagram");
label(s, "Inner loop (feed-forward + P on current error)", 8.75, 1.45, 4.0);
eq(s, "inner", String.raw`u = \frac{i_{\text{ref}}}{\hat{k}_{a}} + K_{c}\,(i_{\text{ref}} - i)`, 8.75, 1.78, 4.0, 0.75, 18);
label(s, "Outer loop (PID on e = x − x_{ref})", 8.75, 2.7, 4.0);
eq(s, "outer", String.raw`i_{\text{ref}} = i_{0}^{c} + K_{p}e + K_{d}v + K_{i}\int e\,dt`, 8.75, 3.03, 4.0, 0.6, 18);
label(s, "Closed loop, ideal inner loop", 8.75, 3.8, 4.0);
eq(s, "charpoly", String.raw`s^{3} + bK_{d}s^{2} + (bK_{p} - a_{21})s + bK_{i} = 0`, 8.75, 4.13, 4.0, 0.55, 17);
label(s, "Poles placed at", 8.75, 4.85, 4.0);
eq(s, "poles_pl", String.raw`\omega_{n} = 40\ \text{rad/s},\; \zeta = 0.7,\; \omega_{i} = 12\ \text{rad/s}`, 8.75, 5.18, 4.0, 0.5, 17);
const gains = [["K_{c} = 2.05 A^{-1}", "inner loop τ_{in} = 3 ms, 9× faster than the coil"], ["K_{p} = 151.2 A/m", "more than twice the minimum 67.6 A/m"],
  ["K_{d} = 2.6 A·s/m", "on the measured velocity"], ["K_{i} = 734 A/(m·s)", "clamped to ± 0.30 A (anti-windup)"]];
gains.forEach(([g, d], k) => {
  const x = 0.5 + k * 1.95;
  card(s, x, 5.2, 1.82, 1.55, "gain " + k);
  text(s, runs(g, { bold: true }), { x: x + 0.12, y: 5.3, w: 1.6, h: 0.45, fontSize: 15, color: C.text2, objectName: "gain value " + k });
  text(s, runs(d), { x: x + 0.12, y: 5.8, w: 1.6, h: 0.85, fontSize: 12, objectName: "gain note " + k });
});

// ======================= 8. Robustness =======================
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Talk" });
title(s, "Stable at all 1458 plants, but the worst M_{s} is 2.23: the target of 2 was missed");
imgH(s, "sens_grid.png", 0.6, 1.5, 4.7, 1.316, "sensitivity over grid");
caption(s, "|S| for every grid plant (grey) and the nominal loop (blue)", 0.6, 6.25, 6.2);
const rob = [["1.59", "nominal M_{s}", C.text2], ["45.4°", "nominal phase margin", C.text2], ["2.23", "worst M_{s} (target ≤ 2)", C.accent3],
  ["≥ 29.3°", "phase margin, whole set", C.text2], ["≥ 2.8 ms", "delay margin, whole set", C.text2], ["0.292–3.95", "stable gain range, nominal", C.text2]];
rob.forEach(([v, l, c], k) => {
  const x = 7.05 + (k % 2) * 2.85, y = 1.5 + Math.floor(k / 2) * 1.35;
  stat(s, x, y, 2.7, 1.2, v, l, c, "rob" + k);
});
label(s, "Robust-stability test (multiplicative uncertainty W)", 7.05, 5.6, 5.6);
eq(s, "wt", String.raw`|W(j\omega)\,T(j\omega)| < 1\quad \forall\,\omega`, 7.05, 5.95, 3.2, 0.5, 18);
text(s, "one disk: 1.11, fails; set split into 4 regions: 0.997, passes", { x: 10.3, y: 5.9, w: 2.4, h: 0.85, fontSize: 13,
  objectName: "wt note" });

// ======================= 9. Simulink =======================
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Talk" });
title(s, "Simulink: 77 nominal and uncertain cases, and the ball was never lost");
img(s, "cases_corners.png", 1.4, 1.4, 10.5, 2.74, "simulink corners");
caption(s, "Lift-off from the stand, then steps 11 → 9 → 11 mm. Grey: corners of the set; colour: nominal (39 g left, 42 g right)",
  1.4, 5.27, 10.5);
stat(s, 0.6, 5.7, 3.85, 1.15, "77 / 77", "cases kept the ball levitated", C.accent4, "sim0");
stat(s, 4.74, 5.7, 3.85, 1.15, "51 of 69", "in-set cases met every check", C.text2, "sim1");
stat(s, 8.87, 5.7, 3.85, 1.15, "18 of 69", "came within 0.1 mm of the stand on one step", C.text2, "sim2");

// ======================= 10. Demo =======================
s = pres.addSlide({ masterName: "DARK", sectionTitle: "Talk" });
s.addText("Live demo", { placeholder: "title" });
text(s, "Ritvik Garg", { x: 0.8, y: 2.95, w: 6, h: 0.45, fontSize: 20, color: C.accent2, objectName: "presenter" });
text(s, paras(["Lift-off from the calibration stand", "Steady hover at 11 mm", "Set-point steps 11 → 10 → 9 mm and back",
  "Coil current and command on the live scope"], { bullet: true }),
  { x: 0.8, y: 3.75, w: 8, h: 2.2, fontSize: 20, color: C.background1, paraSpaceAfter: 8, objectName: "demo plan" });

// ======================= 11. Hardware vs simulation =======================
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Talk" });
title(s, "On the hardware the model predicts the step overshoots to within 0.10 mm rms");
img(s, "sweep_39g.png", 0.6, 1.4, 12.1, 4.129, "sweep lab vs sim");
caption(s, "39 g ball, automatic sweep 11 → 9 → 11 mm: lab (blue), simulation (red), set point (dashed)", 0.6, 4.35, 12.1);
const hw = [["9–11 mm", "both balls levitated at every set point"], ["0.10 mm", "rms overshoot error, 21 of 24 steps (0.18 mm on all 24)"],
  ["47° vs 45.4°", "phase margin: measured by sine injection vs predicted"], ["0.4–2.0", "actuator gains held on the rig (model: 0.292–3.95)"]];
hw.forEach(([v, l], k) => stat(s, 0.6 + k * 3.08, 4.9, 2.85, 1.85, v, l, C.text2, "hw" + k));

// ======================= 12. Beyond the model =======================
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Talk" });
title(s, "Close to the stand we found an effect outside the model; Variant D softened lift-off");
label(s, "Stand-proximity effect", 0.6, 1.4, 7.3, C.text2);
img(s, "stand_runs.png", 0.6, 1.75, 7.3, 3.401, "stand runs");
caption(s, "Braking spike on down-steps: moves with the stand (normal stand left, lowered stand middle and right)", 0.6, 3.92, 7.3, 0.5);
text(s, paras(["Within about 0.7–0.8 mm of the stand: up to 13–14 % less force needed, a braking spike, a 2.4 Hz rocking",
  "All three move when the stand is moved, so they follow the stand, not the gap",
  "Mechanism still open; the claimed range keeps the stand at least about 0.85 mm below the set point"], { bullet: true }),
  { x: 0.6, y: 4.5, w: 7.3, h: 2.3, fontSize: 14, paraSpaceAfter: 6, objectName: "stand bullets" });
card(s, 8.3, 1.4, 4.4, 5.4, "variant D card");
label(s, "Variant D: integral held at zero until switch-on", 8.5, 1.5, 4.0, C.text2);
imgH(s, "variantD_lift.png", 8.5 + (4.0 - 2.75 * 0.869) / 2, 1.9, 2.75, 0.869, "variant D lift-off");
text(s, paras(["Closest approach at lift-off: 10.38–10.60 mm vs 8.95–9.07 mm",
  "Settling: 0.14 s vs 0.27–0.52 s", { t: "Small test: 2 lifts vs 3", opts: { color: C.accent6, italic: true } }], { bullet: true }),
  { x: 8.5, y: 4.8, w: 4.0, h: 1.9, fontSize: 14, paraSpaceAfter: 4, objectName: "variant D bullets" });

// ======================= 13. Conclusion =======================
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Talk" });
title(s, "Robust levitation designed, simulated and validated; one design target missed");
const cols = [
  ["Achieved", C.accent4, ["Model identified: λ = 5.90 mm, τ = 22–25 ms, d ≈ 0.5 sample",
    "Cascade stable over all 1458 plants, PM ≥ 29.3°", "77 Simulink cases, ball never lost",
    "Both balls held at 9–11 mm; gains 0.4–2.0", "Model matches the lab within 0.10 mm rms"]],
  ["Missed", C.accent3, ["Worst-case M_{s} 2.23 against the target of 2",
    "One-disk |WT| test 1.11; passes only with the set split into four regions"]],
  ["Open", C.accent6, ["Mechanism of the stand effect and the 2.4 Hz rocking", "Cause of the half-sample loop delay",
    "Loop gain below 3 Hz not measured", "Variant D tested on two lifts only"]],
];
cols.forEach(([h, c, items], k) => {
  const x = 0.6 + k * 4.1;
  card(s, x, 1.5, 3.85, 5.25, "col " + h);
  s.addShape(pres.shapes.OVAL, { x: x + 0.25, y: 1.72, w: 0.3, h: 0.3, fill: { color: c }, line: { type: "none" }, objectName: "dot " + h });
  text(s, runs(h, { bold: true }), { x: x + 0.7, y: 1.65, w: 2.9, h: 0.45, fontSize: 20, color: c, fontFace: THEME.headFontFace,
    valign: "middle", objectName: "head " + h });
  text(s, paras(items, { bullet: true }), { x: x + 0.25, y: 2.4, w: 3.4, h: 4.2, fontSize: 18, paraSpaceAfter: 12, objectName: "list " + h });
});

// ======================= 14. Questions =======================
s = pres.addSlide({ masterName: "DARK", sectionTitle: "Talk" });
s.addText("Thank you. Questions?", { placeholder: "title" });
text(s, "Group 22  ·  Neil Bakshi · Ritvik Garg · Saurabh Gopal · Snehal Narendra Patil", { x: 0.8, y: 3.0, w: 11.5, h: 0.5,
  fontSize: 18, color: C.background2, objectName: "team line" });
text(s, "Backup slides follow", { x: 0.8, y: 6.4, w: 6, h: 0.4, fontSize: 14, color: C.accent2, italic: true, objectName: "backup hint" });

// ======================= Backup =======================
pres.addSection({ title: "Backup" });
// B1 delay
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Backup" });
title(s, "Backup: the extra loop delay, about half a sample, found two independent ways");
imgH(s, "delay.png", 0.6, 1.4, 5.4, 1.317, "delay identification");
text(s, paras(["A: output-error fit of the coil model to run 3, minimum at d ≈ 0.5",
  "B: noise shaping by the inner loop, the measured spectrum matches d = 0.5, not 0 or 1",
  "Measured d = 0.32–0.55 sample; set range 0.3–0.6",
  "A delay of 1.5 ms costs 5.4° of phase at 10 Hz"], { bullet: true }),
  { x: 8.0, y: 1.6, w: 4.7, h: 4.5, fontSize: 15, paraSpaceAfter: 8, objectName: "delay notes" });

// B2 WT
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Backup" });
title(s, "Backup: robust-stability test |WT| < 1 for three ways of drawing the uncertainty");
img(s, "wt_options.png", 0.6, 1.4, 8.4, 1.866, "WT options");
label(s, "Multiplicative uncertainty", 9.35, 1.5, 3.4);
eq(s, "multunc", String.raw`G_{p} = G\,(1 + \Delta),\quad |\Delta| \le |W|`, 9.35, 1.85, 3.4, 0.55, 18);
text(s, paras(["Sufficient, not necessary: the disk also contains plants that do not exist",
  "One disk around 39 g, 10 mm: 1.11 (fails)", "Four regions (ball × half of the gap range): worst 0.997 (passes)",
  "Room left for unmodelled error: 22 % (< 2 Hz), 0 % (2–10 Hz), 2 % (10–30 Hz), 13 % (30–166 Hz)"], { bullet: true }),
  { x: 9.35, y: 2.6, w: 3.4, h: 4.1, fontSize: 14, paraSpaceAfter: 6, objectName: "wt notes" });

// B3 sine injection
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Backup" });
title(s, "Backup: loop gain measured by sine injection agrees with the model");
imgH(s, "sine_loop.png", 0.6, 1.4, 5.35, 1.648, "sine injection");
text(s, paras(["Sine added at the coil command, 39 g ball at 10 mm", "Measured phase margin about 47°, model 45.4°",
  "Measured model error |ΔT| ≤ 0.74 at 3–40 Hz", "Below 3 Hz the estimate is too noisy (open markers)"], { bullet: true }),
  { x: 9.6, y: 1.6, w: 3.1, h: 4.8, fontSize: 14, paraSpaceAfter: 8, objectName: "sine notes" });

// B4 kg test
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Backup" });
title(s, "Backup: hardware gain test, stable for every actuator gain from 0.4 to 2.0");
imgH(s, "kg_test.png", 0.6, 1.4, 5.35, 1.432, "kg test");
text(s, paras(["Command u multiplied by k_{g} while levitating (39 g, 10 mm)", "Model's stable range 0.292–3.95 contains the tested 0.4–2.0",
  "Jitter rises at low k_{g} as the model predicts"], { bullet: true }),
  { x: 8.6, y: 1.6, w: 4.1, h: 4.5, fontSize: 15, paraSpaceAfter: 8, objectName: "kg notes" });

// B5 arithmetic
s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Backup" });
title(s, "Backup: gain arithmetic (design plant a_{21} = 1684.7 s^{-2}, b = 26.16)");
label(s, "Inner loop (coil τ = 27 ms, estimated k_{a} = 2.44, T_{0} = 3 ms, target τ_{in} = 3 ms)", 0.6, 1.45, 9);
eq(s, "kc", String.raw`K_{c} = \frac{e^{-T_{0}/\tau} - e^{-T_{0}/\tau_{\text{in}}}}{\hat{k}_{a}(1 - e^{-T_{0}/\tau})} = \frac{0.8948 - 0.3679}{0.2566} = 2.054\ \text{A}^{-1}`,
  0.6, 1.8, 12, 0.95, 20);
label(s, "Outer loop (ω_{n} = 40 rad/s, ζ = 0.7, ω_{i} = 12 rad/s)", 0.6, 2.95, 8);
eq(s, "kd", String.raw`K_{d} = \frac{\omega_{i} + 2\zeta\omega_{n}}{b} = \frac{68}{26.16} = 2.599\ \text{A}\,\text{s/m}`, 0.6, 3.3, 12, 0.8, 20);
eq(s, "kp", String.raw`K_{p} = \frac{\omega_{n}^{2} + 2\zeta\omega_{n}\omega_{i} + a_{21}}{b} = \frac{3956.7}{26.16} = 151.25\ \text{A/m}`, 0.6, 4.15, 12, 0.8, 20);
eq(s, "ki", String.raw`K_{i} = \frac{\omega_{i}\,\omega_{n}^{2}}{b} = \frac{19200}{26.16} = 733.9\ \text{A/(m}\,\text{s)}`, 0.6, 5.0, 12, 0.8, 20);
label(s, "Minimum stabilizing gain at the nominal point", 0.6, 5.95, 8);
eq(s, "kpmin", String.raw`K_{p} > \frac{a_{21}}{b} = \frac{1661.4}{24.59} = 67.6\ \text{A/m}`, 0.6, 6.25, 12, 0.6, 18);

// ---------- write ----------
(async () => {
  const out = path.join(BUILD, "deck_raw.pptx");
  await pres.writeFile({ fileName: out });
  await applyTheme(out, THEME);
  fs.writeFileSync(path.join(BUILD, "eqs.json"), JSON.stringify(EQS, null, 1));
  console.log("wrote", out, "with", Object.keys(EQS).length, "equations");
})();

