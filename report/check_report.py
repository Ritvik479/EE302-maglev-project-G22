"""check_report.py -- self-check of the D6 report (Stage G, 2026-11-17).

Run from the report/ folder after compiling:   python -I check_report.py
Prints PASS/FAIL lines and a summary; exit code 0 only if every check passes.

Checks
  1. Compile log: no LaTeX errors, undefined references/citations, over/underfull boxes or rerun requests.
  2. Placeholders: no \\todo or \\capnote left; every figure file referenced by \\repfig / \\figbox exists.
  3. Number provenance: every number in the body text (cover page, preamble, TikZ drawing and bibliography
     excluded) is in the ledger numbers.md (exactly, or as a rounding of a ledger value), in the 17-Nov re-run
     logs, or in the short WHITELIST below (each entry with its reason).
  4. Hand calculations of Section 7: each result is recomputed here from its inputs and must match the
     value printed in the report.
  5. Decisions recorded in numbers.md / memory: forbidden statements absent, required statements present.
  6. Status labels: every \\st{...} uses only M, S, D, N, B.
"""
import glob
import math
import os
import re
import sys
from decimal import Decimal, ROUND_HALF_UP

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, 'main.tex')
LOG = os.path.join(HERE, 'main.log')
LEDGER = os.path.join(HERE, 'numbers.md')
LOGS = glob.glob(os.path.join(HERE, 'rerun_logs_2026-11-17', '*.log'))

n_pass = 0
n_fail = 0


def check(ok, text):
    global n_pass, n_fail
    print(('PASS: ' if ok else 'FAIL: ') + text)
    if ok:
        n_pass += 1
    else:
        n_fail += 1
    return ok


tex = open(TEX, encoding='utf8').read()
ledger = open(LEDGER, encoding='utf8').read()
logtext = ''.join(open(f, encoding='utf8', errors='ignore').read() for f in LOGS)

# ---------------------------------------------------------------- 1. compile log
print('==== 1. Compile log ====')
if not os.path.exists(LOG):
    check(False, 'main.log exists (compile first: latexmk -pdf main.tex)')
else:
    log = open(LOG, encoding='latin-1').read()
    check(os.path.getmtime(LOG) >= os.path.getmtime(TEX), 'main.log is newer than main.tex (log belongs to this source)')
    errs = re.findall(r'^! .*', log, re.M)
    check(not errs, 'no LaTeX errors' + ('' if not errs else ': ' + '; '.join(errs[:3])))
    undef = re.findall(r'(?:Reference|Citation) `[^\']*\' .*undefined', log)
    check(not undef, 'no undefined references or citations' + ('' if not undef else ': ' + '; '.join(undef[:3])))
    boxes = re.findall(r'^(?:Overfull|Underfull) \\[hv]box.*', log, re.M)
    check(not boxes, 'no overfull/underfull boxes' + ('' if not boxes else ': ' + '; '.join(boxes[:3])))
    check('Rerun to get' not in log and 'Label(s) may have changed' not in log, 'no rerun request (cross-references settled)')

# ---------------------------------------------------------------- 2. placeholders and figures
print('==== 2. Placeholders and figure files ====')
body_all = tex[tex.index('\\begin{document}'):]
todo_uses = re.findall(r'\\todo\{', body_all)
cap_uses = re.findall(r'\\capnote\{', body_all)
check(not todo_uses, 'no \\todo placeholders left (%d found)' % len(todo_uses))
check(not cap_uses, 'no \\capnote caption obligations left (%d found)' % len(cap_uses))
files = re.findall(r'\\repfig\{[^}]*\}\{([^}]*)\}', body_all) + re.findall(r'\\figbox\{([^}]*)\}', body_all)
missing = [f for f in files if not os.path.exists(os.path.normpath(os.path.join(HERE, f)))]
check(not missing, 'all %d figure files exist' % len(files) + ('' if not missing else ': missing ' + ', '.join(missing)))

# ---------------------------------------------------------------- 3. number provenance
print('==== 3. Number provenance (body text vs ledger, logs, whitelist) ====')
body = body_all
body = re.sub(r'\\begin\{titlepage\}.*?\\end\{titlepage\}', ' ', body, flags=re.S)
body = re.sub(r'\\begin\{thebibliography\}.*?\\end\{thebibliography\}', ' ', body, flags=re.S)
body = re.sub(r'\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}', ' ', body, flags=re.S)
body = re.sub(r'(?<!\\)%.*', ' ', body)                                   # comments
body = re.sub(r'\\(?:ref|label|eqref|cite|code|pageref)\{[^}]*\}', ' ', body)
body = re.sub(r'\\repfig\{[^}]*\}\{[^}]*\}\{[^}]*\}', ' ', body)           # label, file, width (caption kept)
body = re.sub(r'\\figbox\{[^}]*\}\{[^}]*\}\{[^}]*\}', ' ', body)
body = re.sub(r'\\begin\{(?:subfigure|tabularx|longtable|tabular)\}(?:\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\})+', ' ', body)
body = re.sub(r'[pm]\{[\d.]+cm\}', ' ', body)                              # column widths
body = re.sub(r'[\d.]+\\(?:line|text)width', ' ', body)
body = re.sub(r'\\\\\[[^\]]*\]', ' ', body)                                # \\[4pt]
body = re.sub(r'\\(?:vspace|hspace|resizebox|setlength)\*?\{[^}]*\}', ' ', body)
body = re.sub(r'\\textsuperscript\{[^}]*\}', ' ', body)
body = re.sub(r'\\[a-zA-Z]+', ' ', body)                                   # remaining command names (e.g. \lambda)
body = re.sub(r'(?<=[A-Za-z_])\d+', ' ', body)                            # digits glued to names: s21, a21, p2, R1

nums = re.findall(r'(?<![\d.])\d+(?:\.\d+)?', body)


def as_set(text):
    out = set()
    for t in re.findall(r'(?<![\d.])\d+(?:\.\d+)?', text):
        out.add(Decimal(t))
    return out


led_set = as_set(ledger)
log_set = as_set(logtext)

# Numbers that are neither measurements nor results: physical/mathematical constants, calendar, document
# structure and arithmetic steps of the Section-7 hand calculations (which section 4 recomputes).
WHITELIST = {
    '9.81': 'g', '19.62': '2g', '2026': 'year', '12': 'date / constant', '13': 'date', '16': 'date', '17': 'date',
    '360': 'degrees per period', '180': '-180 deg phase crossover', '2': 'small integer', '1': 'small integer',
    '0': 'zero', '3': 'small integer', '4': 'small integer', '5': 'small integer', '9': 'PS number / T15',
    '0.6931': 'ln 2', '0.0015': '1.5 ms in s', '0.0059046': 'lambda in m', '0.039288': 'mass in kg',
    '0.00298': '2.98 mm in m', '0.1223': 'p*T0', '0.9276': '1-0.065/0.898', '1.0725': 'mass ratio',
    '1.5701': 'ln 4.8069', '672': '2*zeta*wn*wi', '1600': 'wn^2', '19200': 'wi*wn^2', '56': '2*zeta*wn',
    '68': 'wi+2*zeta*wn', '0.25': '1/(2 Ms)', '0.5625': '0.75^2', '0.1052': '1-a', '0.3679': 'e^-1',
    '2.0963': 'mg e^(x/lam)', '0.63646': 'i0^2', '5.4389': 'e^(10/lam)', '0.38542': 'mg',
}


def rounds_to(t, s):
    """True if some ledger/log value rounds (half-up) to t at t's number of decimals."""
    k = -t.as_tuple().exponent if t.as_tuple().exponent < 0 else 0
    if len(t.normalize().as_tuple().digits) < 2:      # one significant digit: too weak to call a rounding match
        return False
    q = Decimal(1).scaleb(-k)
    return any(v.quantize(q, rounding=ROUND_HALF_UP) == t for v in s if (-v.as_tuple().exponent) > k)


classes = {'ledger': set(), 'ledger, rounded': set(), 'logs': set(), 'whitelist': set(), 'UNSOURCED': set()}
for n in nums:
    d = Decimal(n)
    if d in led_set:
        classes['ledger'].add(n)
    elif rounds_to(d, led_set):
        classes['ledger, rounded'].add(n)
    elif d in log_set:
        classes['logs'].add(n)
    elif n in WHITELIST:
        classes['whitelist'].add(n)
    else:
        classes['UNSOURCED'].add(n)
distinct = set(nums)
print('  %d number tokens, %d distinct: ' % (len(nums), len(distinct)) +
      ', '.join('%s %d' % (k, len(v)) for k, v in classes.items()))
print('  from the logs only (not yet in the ledger): ' + ', '.join(sorted(classes['logs'], key=float)))
print('  ledger values quoted rounded: ' + ', '.join(sorted(classes['ledger, rounded'], key=float)))
for n in sorted(classes['UNSOURCED'], key=float):
    m = re.search(r'.{0,50}(?<![\d.])' + re.escape(n) + r'(?![\d]).{0,20}', body.replace('\n', ' '))
    print('  UNSOURCED %s | %s' % (n, m.group(0) if m else ''))
check(not classes['UNSOURCED'], 'every number in the report is in the ledger, the re-run logs or the whitelist')

# ---------------------------------------------------------------- 4. hand calculations
print('==== 4. Hand calculations (Section 7) recomputed ====')
calc = tex[tex.index('\\section{Calculations}'):tex.index('\\section{Results}')]
g, T0, lam, c39, m39, ka = 9.81, 0.003, 5.9046e-3, 3.2936, 0.039288, 2.4321
i0 = math.sqrt(m39 * g * math.exp(10e-3 / lam) / c39)
p = math.sqrt(g / lam)
a = math.exp(-3 / 27)
bd = 2.44 * (1 - a)
b_des, a21_des = 2 * g / 0.75, 1684.7
Ms = 2
calcs = [
    ('T1 hover current i0 [A]', i0, '0.798'),
    ('T2 hover command u0', i0 / ka, '0.328'),
    ('T3 a21 = g/lambda [1/s^2]', g / lam, '1661.4'),
    ('T3 p [rad/s]', p, '40.76'),
    ('T3 f_p [Hz]', p / (2 * math.pi), '6.49'),
    ('T3 doubling time [ms]', 1000 * math.log(2) / p, '17.0'),
    ('T4 b = 2g/i0', 2 * g / i0, '24.59'),
    ('T8 sampled unstable pole', math.exp(p * T0), '1.1301'),
    ('T7 phase of d 0.5 at 10 Hz [deg]', 360 * 10 * 0.5 * T0, '5.4'),
    ('T6 a = e^(-T0/tau)', a, '0.8948'),
    ('T6 b_d', bd, '0.2566'),
    ('T6 Kc [1/A]', (a - math.exp(-1)) / bd, '2.054'),
    ('T15 tau/tau_in', 27 / 3, '9'),
    ('T5 Kd [A s/m]', (12 + 2 * 0.7 * 40) / b_des, '2.599'),
    ('T5 Kp [A/m]', (40 ** 2 + 2 * 0.7 * 40 * 12 + a21_des) / b_des, '151.25'),
    ('T5 Ki [A/(m s)]', 12 * 40 ** 2 / b_des, '733.9'),
    ('T5 design b = 2g/0.75', b_des, '26.16'),
    ('T12 minimum Kp [A/m]', (g / lam) / (2 * g / i0), '67.6'),
    ('T14 e^(x/lambda) at 0.75 A', 0.75 ** 2 * c39 / (m39 * g), '4.8069'),
    ('T14 design bias gap [mm]', 1000 * lam * math.log(0.75 ** 2 * c39 / (m39 * g)), '9.27'),
    ('T13 gain margin from Ms 2', Ms / (Ms - 1), '2'),
    ('T13 phase margin from Ms 2 [deg]', math.degrees(2 * math.asin(1 / (2 * Ms))), '28.96'),
    ('T9 mass-only current ratio', math.sqrt(42.137 / 39.288), '1.0356'),
    ('T10 coil share of the weight (65 mA)', (1 - 0.065 / 0.898) ** 2, '0.860'),
    ('T10 other share (58.5 mA) [%]', 100 * (1 - (1 - 0.0585 / 0.898) ** 2), '12.6'),
    ('T11 error bound [mm]', 1000 * (0.75 - 0.30) / 151.2, '2.98'),
]
for name, val, shown in calcs:
    k = len(shown.split('.')[1]) if '.' in shown else 0
    ok_val = Decimal(repr(val)).quantize(Decimal(1).scaleb(-k), rounding=ROUND_HALF_UP) == Decimal(shown)
    ok_txt = re.search(r'(?<![\d.])' + re.escape(shown) + r'(?![\d])', calc) is not None
    check(ok_val and ok_txt, '%s: computed %.6g, report shows %s%s' % (name, val, shown, '' if ok_txt else ' (NOT FOUND in Section 7)'))

# ---------------------------------------------------------------- 5. decisions
print('==== 5. Recorded decisions ====')
text = re.sub(r'(?<!\\)%.*', '', body_all)
forbidden = [
    (r'shadow', 'no claim that the stand "shadows" the sensor'),
    (r'rotation', 'no claim that the rocking is a ball rotation'),
    (r'0\.994|1\.011', 'no audit-only cross-day force-law check (x0.994-1.011, decision Z1)'),
    (r'5\.7--13|5\.7.{0,3}13', 'no audit PD range "5.7-13" (s21: not reproduced)'),
    (r'(?<!1)9 spikes|nine spikes', 'spike count is not quoted as 9 (decision Z5)'),
    (r'0\.018\\?,?\s*A|0\.824', 'stale s08 noise 0.018 A and hover-window 0.824 A not quoted (Z3, Z4)'),
    (r'POSITION-TIED|position-tied', 'superseded "position-tied" wording not used (Z6)'),
]
for pat, what in forbidden:
    hits = [m.group(0) for m in re.finditer(pat, text)]
    check(not hits, what + ('' if not hits else ' -- found: ' + ', '.join(hits[:3])))
abstract = tex[tex.index('\\begin{abstract}'):tex.index('\\end{abstract}')]
required = [
    (abstract, r'2\.23', 'abstract states the worst Ms 2.23 (target missed, decision R1)'),
    (text, r'\\textbf\{not met\}', 'robustness section says the Ms target was not met'),
    (text, r'11 spikes', 'spike count 11 stated (Z5)'),
    (text, r'0\.67\$?--\$?0\.89', 'spike position 0.67-0.89 mm above the stand stated'),
    (text, r'10\.4.{0,200}1\.99', 'PD-vs-cascade comparison quotes 10.4 vs 1.99 (s21)'),
    (text, r'0\.9973', 'Experiment-C trimming leaves |WT| 0.9973 (s19)'),
    (text, r'\\emph\{untrimmed\}', 'robust stability reported for the untrimmed set (R1)'),
    (text, r'inferred from the data, not\s+confirmed', 'Exp A set-point typo stated as inferred, not confirmed'),
    (text, r'No file states the conversion', 'u-to-volts conversion stated as unverified'),
    (text, r'neither confirm nor refute', 's20: lift-offs neither confirm nor refute the static effect'),
    (text, r'51 are fully OK', 'case counts: 51 fully OK in the set'),
    (text, r'18 come within \$0\.1\$', 'case counts: 18 within 0.1 mm of the stand'),
    (text, r'\\emph\{outside\} the simulated range', 'both lowered-stand lift-offs outside the simulated range'),
]
for where, pat, what in required:
    check(re.search(pat, where, re.S) is not None, what)
for lab in ('expAB', 'sweeps'):
    cap = re.search(r'\\repfig\{' + lab + r'\}\{[^}]*\}\{[^}]*\}\{(.*?)\}\n', tex, re.S)
    check(cap is not None and re.search(r'd\s*=\s*0', cap.group(1)) is not None,
          'caption of fig:%s says the simulation used d = 0 (Z8)' % lab)

# ---------------------------------------------------------------- 6. status labels
print('==== 6. Status labels ====')
labels = re.findall(r'\\st\{([^}]*)\}', body_all)
bad = sorted({l for l in labels if not re.fullmatch(r'[MSDNB](?:/[MSDNB])*', l)})
check(not bad, '%d status labels, all of M, S, D, N, B or combinations' % len(labels) + ('' if not bad else ': bad ' + ', '.join(bad)))

print('==== SUMMARY: %d PASS, %d FAIL ====' % (n_pass, n_fail))
sys.exit(1 if n_fail else 0)
