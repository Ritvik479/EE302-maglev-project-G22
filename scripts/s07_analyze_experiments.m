% s07_analyze_experiments.m   [STANDALONE]
% =========================================================================
% PURPOSE   Analyse lab experiments A, B, C of 2026-11-13 (cascade controller):
%             A  gap sweep, 39 g ball            (operating-point variation)
%             B  42 g ball: step runs 1, 2 and a sweep (parametric uncertainty)
%             C  actuator-gain test kg = 0.4..2.0, 39 g ball at 10 mm (robustness)
%           and compare every result with the model (simulation-vs-hardware).
% INPUTS    data/lab_2026-11-13/runs/exp*.fig   (scope "Print to Figure -> Save")
%           data/phase3_cascade.mat              (controller gains C, lab struct L)
% OUTPUTS   console PASS/FAIL + tables, data/lab_2026-11-13/exp_ABC_results.mat,
%           figs/p4_force_fit.png, figs/p4_sweep_lab_vs_sim.png,
%           figs/p4_kg_test.png, figs/p4_42g_flip.png
% MODEL     F = c (i - ioff)^2 exp(-x/lam), one lam for both balls, one c per
%           ball (different shapes), ioff = current-sensor reading at zero
%           current (measured on the stand with u = 0).
% SIGNS     x = gap, increasing downward. e = x - x_ref (manual convention).
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
chk = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
runDir = fullfile(P.dir.data, 'lab_2026-11-13', 'runs');
D = load(fullfile(P.dir.data, 'phase3_cascade.mat'));  C = D.C;  L = D.L;
T0 = L.T0;  g = P.g;
m39 = 0.039288;  m42 = 0.042137;

%% ---- 0. load runs (main scope: x, v, i, u ; i_ref scope: i, i_ref [, kg]) ----
names = {'A39', 'expA_39g_sweep', '', m39;  'B42s1', 'expB_42g_step', '1', m42;
         'B42s2', 'expB_42g_step', '2', m42; 'B42w', 'expB_42g_sweep', '', m42;
         'C39',  'expC_39g_kg', '', m39};
Rn = struct();
for k = 1:size(names, 1)
    mm = read_scope_fig(fullfile(runDir, [names{k,2} '_main' names{k,3} '.fig']));
    qq = read_scope_fig(fullfile(runDir, [names{k,2} '_iref' names{k,3} '.fig']));
    assert(numel(mm.t) == numel(qq.t) && max(abs(mm.t - qq.t)) < 1e-9, 'time bases differ: %s', names{k,2});
    r = struct('t', mm.t, 'x', mm.y(:,1), 'v', mm.y(:,2), 'i', mm.y(:,3), 'u', mm.y(:,4), ...
               'iref', qq.y(:,2), 'm', names{k,4});
    if size(qq.y, 2) >= 3, r.kg = qq.y(:,3); else, r.kg = ones(size(r.t)); end
    r.kOn = find(r.u > 0.01, 1);
    r.xStand = mean(r.x(1:r.kOn-1));
    r.ioff = mean(r.i(1:r.kOn-1));
    r.sigX = std(r.x(1:r.kOn-1));  r.sigI = std(r.i(1:r.kOn-1));
    Rn.(names{k,1}) = r;
    fprintf('%-6s %-26s %5.1f s, switch-on %5.2f s, ball on stand at %.3f mm, i(u=0) %.3f A\n', ...
            names{k,1}, [names{k,2} names{k,3}], r.t(end), r.t(r.kOn), 1e3*r.xStand, r.ioff);
end
ioff = mean([Rn.A39.ioff Rn.B42w.ioff Rn.C39.ioff]);
sigX = mean([Rn.A39.sigX Rn.B42w.sigX Rn.C39.sigX]);
sigI = mean([Rn.A39.sigI Rn.B42w.sigI Rn.C39.sigI]);
fprintf('Sensor noise on the stand: x %.4f mm, i %.4f A; current reading at u = 0: %.3f A\n', 1e3*sigX, sigI, ioff);

%% ---- 1. plateaus (hover segments) --------------------------------------
fprintf('\n==== 1. Hover plateaus ====\n');
for nm = {'A39', 'B42s1', 'B42s2', 'B42w'}
    Rn.(nm{1}).pl = plateaus(Rn.(nm{1}));
    fprintf('%s:\n', nm{1});
    print_plateaus(Rn.(nm{1}).pl);
end

%% ---- 2. anomalies -------------------------------------------------------
fprintf('\n==== 2. Anomalies ====\n');
r = Rn.A39;
kDrop = find(r.t > r.t(r.kOn) + 1 & r.iref < 0.01 & r.x < 0.0110, 1);
kBack = find(r.t > r.t(kDrop) & r.iref > 0.3, 1);
fprintf('Exp A: at %.2f s i_ref fell from %.2f A to 0 in ONE sample while the ball hovered at %.2f mm;\n', ...
        r.t(kDrop), r.iref(kDrop-1), 1e3*r.x(kDrop-1));
fprintf('       the ball fell to the stand. i_ref = 0 with the integral at its -0.3 A clamp needs\n');
fprintf('       e < -(i0 - 0.3)/Kp = %.2f mm, i.e. a set point above %.1f mm.\n', ...
        -1e3*(C.i0 - 0.3)/C.Kp, 1e3*(r.xStand + (C.i0 - 0.3)/C.Kp));
eBack = (r.iref(kBack) - C.i0 + 0.3)/C.Kp;
fprintf('       At %.2f s the controller re-lifted: first i_ref %.3f A -> set point ~%.2f mm (integral at -0.3 A).\n', ...
        r.t(kBack), r.iref(kBack), 1e3*(r.x(kBack) - eBack));
fprintf('       => consistent with a mistyped set point (e.g. 0.09 for 0.009), then 0.0095. Not instability.\n');
dropOK = all(r.iref(kDrop:kBack-1) < 0.01);
chk(dropOK, 'Exp A drop: i_ref stayed exactly 0 until the re-lift (controller demanded zero current)');

r1 = Rn.B42s1;  r2 = Rn.B42s2;
w1 = r1.t > r1.t(r1.kOn) & r1.t < r1.t(r1.kOn) + 4;
jumps = abs(diff(r1.x(w1)));
fprintf('\nExp B run 1 (ball turned over): ball rested at %.3f mm (run 2: %.3f mm, sweep: %.3f mm).\n', ...
        1e3*r1.xStand, 1e3*r2.xStand, 1e3*Rn.B42w.xStand);
k1 = find(r1.t > r1.t(r1.kOn) + 0.3 & r1.t < r1.t(r1.kOn) + 6 & movstd(r1.x, 51) > 0.1e-3, 1, 'last');
fprintf('  sample-to-sample position jumps up to %.2f mm (normal hover: %.3f mm), reading spanned %.2f..%.2f mm,\n', ...
        1e3*max(jumps), 1e3*std(diff(r2.x(r2.t > r2.t(r2.kOn) + 2))), 1e3*min(r1.x(w1)), 1e3*max(r1.x(w1)));
fprintf('  last disturbed moment (51-sample std > 0.1 mm) %.2f s after switch-on. The controller never lost the ball.\n', ...
        r1.t(k1) - r1.t(r1.kOn));
hv = @(r, lev) mean(r.i(r.t > r.t(r.kOn) + 1 & abs(r.x - lev) < 0.15e-3 & abs(movmean(r.x, 201) - lev) < 0.05e-3));
fprintf('  after the turn, hover current at 11 / 10 mm: run 1 %.3f / %.3f A, run 2 %.3f / %.3f A\n', ...
        hv(r1, 0.011), hv(r1, 0.010), hv(r2, 0.011), hv(r2, 0.010));
fFlip = zc_freq(r1.t, r1.x, r1.t(r1.kOn) + 1.8, r1.t(r1.kOn) + 3.8);
pA = Rn.A39.pl;  k115 = find(abs([pA.lev] - 0.0115) < 1e-5 & [pA.hover], 1);
f115 = zc_freq(Rn.A39.t, Rn.A39.x, pA(k115).ta + 0.3, pA(k115).tb);
fprintf('  slow swing while turning over: %.1f Hz; Exp A 11.5 mm wobble: %.1f Hz; 1-D model modes: >= 6 Hz\n', fFlip, f115);
fprintf('  -> both look like the same ~2.5 Hz motion of the ball (rocking/rotation) that the vertical model lacks.\n');
chk(abs(hv(r1, 0.010) - hv(r2, 0.010)) < 0.015, ...
    'after turning over, run 1 hovers like run 2 (same current within 15 mA): the ball ended in its usual orientation');

%% ---- 3. sensor-zero drift, then the force law -----------------------------
% 3a. The hover current at a fixed gap reads lower later in a run. Is it the
% true current or the sensor? Test: the current reading with u = 0 (true
% current = 0, ball on the stand) at the START vs the END of each run.
fprintf('\n==== 3. Sensor-zero drift and force law ====\n');
rates = [];
for nm = fieldnames(Rn)'
    r = Rn.(nm{1});  kOff = find(r.u > 0.01, 1, 'last');  s2 = find(r.t > r.t(kOff) + 1.0);
    Rn.(nm{1}).rate = NaN;
    if numel(s2) < 100
        fprintf('  %-6s no u = 0 segment after switch-off (recording stopped)\n', nm{1});  continue;
    end
    dt = r.t(kOff) - r.t(r.kOn);
    di = mean(r.i(s2)) - r.ioff;  dx = mean(r.x(s2)) - r.xStand;
    Rn.(nm{1}).rate = di/dt;  rates(end+1) = di/dt; %#ok<AGROW>
    fprintf('  %-6s after %3.0f s of levitation: current zero %.4f -> %.4f A (%+.1f mA), stand reading %+.3f mm\n', ...
            nm{1}, dt, r.ioff, mean(r.i(s2)), 1e3*di, 1e3*dx);
end
rate = mean(rates);
fprintf('  mean current-zero drift %.2f mA/s while levitating\n', 1e3*rate);
for nm = fieldnames(Rn)', if isnan(Rn.(nm{1}).rate), Rn.(nm{1}).rate = rate; end, end
izero = @(r, t) r.ioff + r.rate*(t - r.t(r.kOn));         % current-sensor zero during the run (linear model)

% Repeat visits to the same gap: raw scatter vs scatter after removing the zero drift
fprintf('3b. Hover current at a repeated gap: raw reading vs drift-corrected\n');
dRaw = []; dCor = [];
for nm = {'A39', 'B42w'}
    r = Rn.(nm{1});  pl = r.pl([r.pl.hover]);
    for x0 = unique(round([pl.lev]*2e4)/2e4)
        sel = find(abs([pl.lev] - x0) < 1e-5);
        if numel(sel) < 2, continue; end
        ir = [pl(sel).i];  ic = ir - arrayfun(@(p) izero(r, p.tm), pl(sel));
        dRaw = [dRaw, ir - mean(ir)]; dCor = [dCor, ic - mean(ic)]; %#ok<AGROW>
        fprintf('  %s %4.1f mm: raw %.3f -> %.3f A | corrected %.3f -> %.3f A (visits %.0f s apart), u %.3f -> %.3f\n', ...
                nm{1}, 1e3*x0, ir(1), ir(end), ic(1), ic(end), pl(sel(end)).tm - pl(sel(1)).tm, pl(sel(1)).u, pl(sel(end)).u);
    end
end
fprintf('  repeat-visit scatter: raw %.1f mA rms, after zero-drift correction %.1f mA rms\n', 1e3*rms(dRaw), 1e3*rms(dCor));
chk(rms(dCor) < 0.5*rms(dRaw), ...
    'the measured sensor-zero drift explains the hover-current drift (true current unchanged; integral absorbs it)');

% 3c. Force law from every hover visit, drift-corrected:
%   i_true = i_reading - izero(t) = sqrt(m g / c_b) exp(x/(2 lam))
% Excluded: 39 g at 11.5 mm (one 2 s visit with the unmodelled 2.4 Hz rocking, section 2).
F = struct('x', {}, 'i', {}, 'itrue', {}, 'u', {}, 'ball', {}, 'used', {});
for b = 1:2
    if b == 1, r = Rn.A39; else, r = Rn.B42w; end
    pl = r.pl([r.pl.hover]);
    for p = pl
        used = ~(b == 1 && abs(p.lev - 0.0115) < 1e-5);
        F(end+1) = struct('x', p.lev, 'i', p.i, 'itrue', p.i - izero(r, p.tm), 'u', p.u, 'ball', b, 'used', used); %#ok<SAGROW>
    end
end
U = [F.used];  X = [F(U).x];  I = [F(U).itrue];  B = [F(U).ball];
A = [X(:)/2, (B(:) == 1), (B(:) == 2)];
th = A \ log(I(:));
lam = 1/th(1);
cB = [m39*g/exp(2*th(2)), m42*g/exp(2*th(3))];
itrueFit = @(x, b) sqrt((m39*(b==1) + m42*(b==2))*g/cB(b)) .* exp(x/(2*lam));
ifit = @(x, b) ioff + itrueFit(x, b);                      % as the sensor reads it at the start of a run
res = I - arrayfun(@(k) itrueFit(X(k), B(k)), 1:numel(X));
fprintf('3c. Fit (%d visits, drift-corrected): lam = %.2f mm (manual P2 %.2f mm)\n', numel(X), 1e3*lam, 1e3*P.Fem.P2);
fprintf('    c = %.2f (39 g), %.2f (42 g) N/A^2 (manual P1/P2 = %.2f); residuals rms %.1f mA, max %.1f mA\n', ...
        cB(1), cB(2), P.Fem.P1/P.Fem.P2, 1e3*rms(res), 1e3*max(abs(res)));
eqM = maglev_equilibrium(P, m39, 0.010);
fprintf('    true hover current at 10 mm, 39 g: fit %.3f A, manual model %.3f A (%+.1f %%)\n', ...
        itrueFit(0.010, 1), eqM.x30, 100*(eqM.x30/itrueFit(0.010, 1) - 1));
ex = F(~U);
for k = 1:numel(ex)
    fprintf('    excluded 39 g at 11.5 mm: corrected %.3f A vs fit %.3f A (%+.0f mA)\n', ex(k).itrue, ...
            itrueFit(ex(k).x, 1), 1e3*(ex(k).itrue - itrueFit(ex(k).x, 1)));
end
chk(rms(res) < 0.01, 'force law fits every drift-corrected hover visit within 10 mA rms');
chk(abs(lam - P.Fem.P2)/P.Fem.P2 < 0.15, 'fitted lam within 15 % of the manual P2');
fprintf('    The 42 g ball needs %.1f %% more current than the 39 g ball at the same gap; mass alone explains %.1f %%.\n', ...
        100*(sqrt(m42/cB(2))/sqrt(m39/cB(1)) - 1), 100*(sqrt(m42/m39) - 1));

%% ---- 4. simulation vs hardware: every set-point step ---------------------
fprintf('\n==== 4. Steps: lab vs simulation (fitted plant, same controller) ====\n');
kaP = mean([F(U).itrue]./[F(U).u]);            % static coil gain: true current per unit command
plant = @(b) struct('m', m39*(b==1) + m42*(b==2), 'lam', lam, 'c', cB(b), 'ioff', ioff, ...
                    'tau', L.tau, 'ka', kaP, 'ci', ioff);
fprintf('Plant for simulation: lam %.2f mm, c per ball, tau %.0f ms, static coil gain %.2f A/unit (from hover data)\n', ...
        1e3*lam, 1e3*L.tau, kaP);
ST = [];   % [ball from to labOS simOS labTs simTs]
for b = 1:2
    if b == 1, r = Rn.A39; else, r = Rn.B42w; end
    pl = r.pl;
    for k = 1:numel(pl)-1
        if pl(k+1).ta - pl(k).tb > 0.5 || ~pl(k).hover || ~pl(k+1).hover, continue; end
        a = pl(k).lev; z = pl(k+1).lev; d = z - a;
        w = r.t > pl(k).tb - 1 & r.t < min(pl(k+1).tb, pl(k).tb + 1.5);
        [osL, tsL] = step_metrics(r.t(w), r.x(w), a, z);
        q = plant(b);
        ieq = ioff + sqrt(q.m*g/q.c)*exp(a/(2*lam));
        o = struct('x0', a, 'i0s', ieq, 'z0', min(max((ieq - C.i0)/C.Ki, -C.zLim), C.zLim), ...
                   'xStand', 0.0119);
        s = maglev_cascade_sim(C, L, q, @(t) a + d*(t >= 1.0), 2.5, o);
        [osS, tsS] = step_metrics(s.t, s.x, a, z);
        ST(end+1, :) = [b, 1e3*a, 1e3*z, osL, osS, tsL, tsS]; %#ok<SAGROW>
    end
end
fprintf(' ball | step [mm]     | overshoot lab / sim [mm] | settle (+-0.25 mm) lab / sim [ms]\n');
for k = 1:size(ST, 1)
    fprintf('  %2d g | %4.1f -> %4.1f | %5.2f / %5.2f            | %5.0f / %5.0f\n', ...
            39 + 3*(ST(k,1) == 2), ST(k,2), ST(k,3), ST(k,4), ST(k,5), ST(k,6), ST(k,7));
end
dOS = ST(:,4) - ST(:,5);
fprintf('Overshoot lab - sim: mean %+.2f mm, rms %.2f mm (%d steps)\n', mean(dOS), rms(dOS), numel(dOS));
up = ST(:,3) < ST(:,2);
fprintf('  steps UP (toward magnet): lab %.2f mm, sim %.2f mm | steps DOWN: lab %.2f mm, sim %.2f mm (means)\n', ...
        mean(ST(up,4)), mean(ST(up,5)), mean(ST(~up,4)), mean(ST(~up,5)));
chk(rms(dOS) < 0.2, 'simulated overshoot matches the lab within 0.2 mm rms');

%% ---- 5. hover jitter: lab vs simulation with the measured sensor noise ----
fprintf('\n==== 5. Hover jitter vs gap (lab) and vs sensor-noise-only simulation ====\n');
JT = [];
for b = 1:2
    if b == 1, r = Rn.A39; else, r = Rn.B42w; end
    pl = r.pl([r.pl.hover]);
    for x0 = unique(round([pl.lev]*2e4)/2e4)
        sel = abs([pl.lev] - x0) < 1e-5;
        q = plant(b);  ieq = ioff + sqrt(q.m*g/q.c)*exp(x0/(2*lam));
        o = struct('x0', x0, 'i0s', ieq, 'z0', min(max((ieq - C.i0)/C.Ki, -C.zLim), C.zLim), ...
                   'sigX', sigX, 'sigI', sigI, 'seed', 7, 'xStand', 0.0119);
        s = maglev_cascade_sim(C, L, q, @(t) x0, 6, o);
        JT(end+1, :) = [b, 1e3*x0, mean([pl(sel).sx]), 1e3*std(s.xm(s.t > 1)), max([pl(sel).fpk])]; %#ok<SAGROW>
    end
end
fprintf(' ball | gap [mm] | x std lab [mm] | x std sim, noise only [mm] | lab spectral peak [Hz]\n');
for k = 1:size(JT,1)
    fprintf('  %2d g | %5.1f    | %.3f          | %.3f                      | %.1f\n', ...
            39 + 3*(JT(k,1) == 2), JT(k,2), JT(k,3), JT(k,4), JT(k,5));
end
ratio = JT(:,3)./JT(:,4);
fprintf('-> lab / noise-only simulation: median %.2f, range %.2f..%.2f\n', median(ratio), min(ratio), max(ratio));
for k = find(ratio > 2)'
    fprintf('   OUTLIER: %d g at %.1f mm has %.1fx the predicted jitter (not explained by sensor noise)\n', ...
            39 + 3*(JT(k,1) == 2), JT(k,2), ratio(k));
end
chk(median(ratio) < 1.5, 'measured sensor noise explains the hover jitter (median ratio < 1.5)');
% Which sensor's noise drives it? (39 g at 10 mm)
q = plant(1);  x0 = 0.010;  ieq = ioff + sqrt(q.m*g/q.c)*exp(x0/(2*lam));
base = struct('x0', x0, 'i0s', ieq, 'z0', min(max((ieq - C.i0)/C.Ki, -C.zLim), C.zLim), 'seed', 7, 'xStand', 0.0119);
oX = base; oX.sigX = sigX;  oI = base; oI.sigI = sigI;
sX = maglev_cascade_sim(C, L, q, @(t) x0, 6, oX);  sI = maglev_cascade_sim(C, L, q, @(t) x0, 6, oI);
jX = 1e3*std(sX.xm(sX.t > 1));  jI = 1e3*std(sI.xm(sI.t > 1));
fprintf('Noise split at 10 mm: position-sensor noise alone -> %.3f mm, current-sensor noise alone -> %.3f mm\n', jX, jI);

%% ---- 6. experiment C: kg test ------------------------------------------
fprintf('\n==== 6. Experiment C: actuator gain kg ====\n');
r = Rn.C39;
kgL = unique(r.kg(r.t > r.t(r.kOn)))';
q = plant(1);  x0 = 0.010;  ieq = ioff + sqrt(q.m*g/q.c)*exp(x0/(2*lam));
a21 = g/lam;  bb = 2*g/(ieq - ioff);
KG = [];
kgGrid = 0.1:0.01:4;
rhoG = arrayfun(@(k) max(abs(cl_eig(C, L, T0, q.tau, kaP*k, a21, bb))), kgGrid);
stab = kgGrid(rhoG < 1);
fprintf('Linear model at 10 mm (fitted plant): stable for %.2f < kg < %.2f\n', min(stab), max(stab));
for kg = kgL
    segs = find_runs(r.kg == kg & r.t > r.t(r.kOn) + 1 & abs(movmean(r.x, 201) - x0) < 0.3e-3);
    xs = []; f = [];
    for j = 1:size(segs, 1)
        idx = segs(j,1) + round(0.5/T0):segs(j,2);   % drop 0.5 s after each change
        if numel(idx) < 600, continue; end
        xs = [xs; r.x(idx) - mean(r.x(idx))]; %#ok<AGROW>
        f(end+1) = peak_freq(r.x(idx), T0); %#ok<AGROW>
    end
    if isempty(xs), continue; end
    ev = cl_eig(C, L, T0, q.tau, kaP*kg, a21, bb);
    evc = ev(imag(ev) > 1e-6);  [~, kk] = max(abs(evc));  zd = evc(kk);
    fM = angle(zd)/(2*pi*T0);  zeta = -log(abs(zd))/hypot(log(abs(zd)), angle(zd));
    o = struct('x0', x0, 'i0s', ieq, 'z0', min(max((ieq - C.i0)/C.Ki, -C.zLim), C.zLim), ...
               'sigX', sigX, 'sigI', sigI, 'seed', 7, 'kg', kg, 'xStand', 0.0119);
    s = maglev_cascade_sim(C, L, q, @(t) x0, 6, o);
    KG(end+1, :) = [kg, 1e3*std(xs), 1e3*(max(xs) - min(xs)), mean(f), fM, zeta, 1e3*std(s.xm(s.t > 1))]; %#ok<SAGROW>
end
fprintf('  kg  | x std lab [mm] | p-p lab [mm] | lab peak [Hz] | model: slowest oscill. pole [Hz], damping | sim std (noise only)\n');
for k = 1:size(KG,1)
    fprintf('  %.2f | %.3f          | %.2f         | %4.1f          | %5.1f Hz, zeta %.2f                      | %.3f\n', KG(k,:));
end
chk(all(KG(:,2) < 0.3) && all(r.x(r.t > r.t(r.kOn) + 1 & r.t < r.t(find(r.u > 0.01, 1, 'last'))) < 0.0118), ...
    'levitation held for every kg from 0.4 to 2.0 (x std < 0.3 mm, never back on the stand)');
chk(min(stab) < 0.4 && max(stab) > 2.0, 'model also predicts stability over the whole tested range');
[~, iLo] = min(KG(:,1));  [~, i1] = min(abs(KG(:,1) - 1));
chk(KG(iLo,2) > KG(i1,2), sprintf('jitter grows as kg falls (lab: %.3f mm at kg %.1f vs %.3f at kg 1)', KG(iLo,2), KG(iLo,1), KG(i1,2)));

%% ---- 7. figures --------------------------------------------------------
col = P.plot.colors;
% 7a force fit
f1 = figure('Position', [60 60 820 520]); hold on; grid on;
xx = linspace(8.8e-3, 11.7e-3, 100);
mk = {'o', 's'};
for b = 1:2
    Fb = F([F.ball] == b);
    plot(1e3*[Fb([Fb.used]).x], [Fb([Fb.used]).itrue], mk{b}, 'Color', col(b,:), 'MarkerFaceColor', col(b,:), 'MarkerSize', 8);
    plot(1e3*xx, itrueFit(xx, b), '-', 'Color', col(b,:));
    mb = m39*(b==1) + m42*(b==2);
    plot(1e3*xx, sqrt(mb*g*P.Fem.P2/P.Fem.P1)*exp(xx/(2*P.Fem.P2)), '--', 'Color', col(b,:), 'LineWidth', 1.2);
end
Fx = F(~[F.used]);
plot(1e3*[Fx.x], [Fx.itrue], 'x', 'Color', col(1,:), 'MarkerSize', 12, 'LineWidth', 2);
xlabel('gap x [mm]'); ylabel('true hover current (sensor reading - drifting zero) [A]');
legend('39 g: hover visits', sprintf('39 g fit (\\lambda = %.2f mm)', 1e3*lam), '39 g manual model', ...
       '42 g: hover visits', '42 g fit', '42 g manual model', '39 g at 11.5 mm (rocking, excluded)', ...
       'Location', 'northwest');
title('Hover current vs gap (drift-corrected): lab, fitted force law, manual model', 'Color', 'k');
exportgraphics(f1, fullfile(P.dir.figs, 'p4_force_fit.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

% 7b sweeps lab vs sim (full sequence, set point rebuilt from the plateaus)
f2 = figure('Position', [60 60 1100 750]);
tiledlayout(2, 1, 'TileSpacing', 'compact');
for b = 1:2
    if b == 1, r = Rn.A39; ttl = 'Exp A: 39 g ball, gap sweep'; else, r = Rn.B42w; ttl = 'Exp B: 42 g ball, gap sweep'; end
    [xrF, tChange] = setpoint_profile(r, C);
    q = plant(b);
    t0 = r.t(r.kOn);
    o = struct('x0', r.xStand, 'xStand', r.xStand, 'i0s', ioff, 'z0', C.zLim, 'sigX', sigX, 'sigI', sigI, 'seed', 3);
    s = maglev_cascade_sim(C, L, q, @(t) xrF(t + t0), r.t(end) - t0, o);
    nexttile; hold on; grid on;
    plot(r.t, 1e3*r.x, 'Color', col(1,:), 'LineWidth', 1);
    plot(s.t + t0, 1e3*s.xm, 'Color', col(2,:), 'LineWidth', 1);
    plot(r.t, 1e3*arrayfun(xrF, r.t), 'k--', 'LineWidth', 1);
    set(gca, 'YDir', 'reverse'); ylim([7.9 12.2]); ylabel('gap x [mm]');
    title(ttl, 'Color', 'k');
    if b == 1
        legend('lab', 'simulation (fitted plant + measured sensor noise)', 'set point (rebuilt from data)', ...
               'Location', 'north', 'NumColumns', 3);
        if ~isempty(tChange)
            text(tChange(1), 9.0, '  set point typo \rightarrow ball dropped', 'Color', 'k', 'FontSize', 10);
        end
    end
end
xlabel('time [s]');
exportgraphics(f2, fullfile(P.dir.figs, 'p4_sweep_lab_vs_sim.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

% 7c kg test
f3 = figure('Position', [60 60 1100 750]);
tiledlayout(2, 2, 'TileSpacing', 'compact');
r = Rn.C39;
nexttile([1 2]); hold on; grid on;
yyaxis left; plot(r.t, 1e3*r.x, 'Color', col(1,:), 'LineWidth', 1); set(gca, 'YDir', 'reverse');
ylabel('gap x [mm]'); ylim([8.5 12.2]); set(gca, 'YColor', col(1,:));
yyaxis right; stairs(r.t, r.kg, 'Color', col(4,:), 'LineWidth', 2); ylabel('k_g [-]'); ylim([0 2.2]);
set(gca, 'YColor', col(4,:));
xlabel('time [s]'); title('Exp C: 39 g ball at 10 mm, command scaled by k_g', 'Color', 'k');
nexttile; hold on; grid on;
plot(KG(:,1), KG(:,2), 'o-', 'Color', col(1,:), 'MarkerFaceColor', col(1,:));
plot(KG(:,1), KG(:,7), 's--', 'Color', col(2,:));
xlabel('k_g [-]'); ylabel('x std [mm]'); legend('lab', 'simulation, sensor noise only', 'Location', 'northeast');
title('Hover jitter vs k_g', 'Color', 'k');
nexttile; hold on; grid on;
plot(KG(:,1), KG(:,4), 'o-', 'Color', col(1,:), 'MarkerFaceColor', col(1,:));
plot(KG(:,1), KG(:,5), 's--', 'Color', col(2,:));
xlabel('k_g [-]'); ylabel('frequency [Hz]');
legend('lab: spectral peak of x', 'model: slowest oscillatory closed-loop pole', 'Location', 'northwest');
title('Wobble frequency vs k_g', 'Color', 'k');
exportgraphics(f3, fullfile(P.dir.figs, 'p4_kg_test.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

% 7d 42 g flip
f4 = figure('Position', [60 60 1000 450]); hold on; grid on;
for k = 1:2
    if k == 1, r = Rn.B42s1; else, r = Rn.B42s2; end
    s = r.t > r.t(r.kOn) - 0.3 & r.t < r.t(r.kOn) + 5;
    plot(r.t(s) - r.t(r.kOn), 1e3*r.x(s), 'Color', col(k,:), 'LineWidth', 1.2);
end
yline(11, 'k--'); set(gca, 'YDir', 'reverse');
xlabel('time after switch-on [s]'); ylabel('gap x [mm] (sensor reading)');
legend(sprintf('run 1: rested at %.2f mm, ball turned over', 1e3*Rn.B42s1.xStand), ...
       sprintf('run 2: rested at %.2f mm, normal lift-off', 1e3*Rn.B42s2.xStand), 'set point', 'Location', 'southeast');
title('Exp B, 42 g ball: lift-off with the ball turning over (run 1) vs normal (run 2)', 'Color', 'k');
exportgraphics(f4, fullfile(P.dir.figs, 'p4_42g_flip.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

save(fullfile(P.dir.data, 'lab_2026-11-13', 'exp_ABC_results.mat'), 'lam', 'cB', 'ioff', 'kaP', 'sigX', 'sigI', ...
     'F', 'ST', 'JT', 'KG', 'stab');
fprintf('\nSaved data/lab_2026-11-13/exp_ABC_results.mat and figs/p4_*.png\n');

%% ======================= local functions ================================
function pl = plateaus(r)
% Segments where the 0.6 s running median of x sits on one 0.5 mm level.
T0 = 0.003;
xm = movmedian(r.x, 201);
lev = round(xm*2000)/2000;  lev(1:r.kOn) = NaN;
ch = [r.kOn; r.kOn + find(diff(lev(r.kOn:end)) ~= 0 & ~isnan(diff(lev(r.kOn:end))))];
pl = struct('ta', {}, 'tb', {}, 'tm', {}, 'lev', {}, 'x', {}, 'sx', {}, 'i', {}, 'iref', {}, 'u', {}, ...
            'hover', {}, 'fpk', {});
for s = 1:numel(ch)
    a = ch(s); b = numel(r.t); if s < numel(ch), b = ch(s+1) - 1; end
    if r.t(b) - r.t(a) < 1.0, continue; end
    seg = a + round(0.3*(b - a)):b;
    hov = mean(r.i(seg)) > 0.3 && mean(r.u(seg)) > 0.05;
    fpk = NaN; if hov && numel(seg) > 600, fpk = peak_freq(r.x(seg), T0); end
    pl(end+1) = struct('ta', r.t(a), 'tb', r.t(b), 'tm', mean(r.t(seg)), 'lev', lev(a), 'x', mean(r.x(seg)), ...
        'sx', 1e3*std(r.x(seg)), 'i', mean(r.i(seg)), 'iref', mean(r.iref(seg)), 'u', mean(r.u(seg)), ...
        'hover', hov, 'fpk', fpk); %#ok<AGROW>
end
end

function print_plateaus(pl)
for k = 1:numel(pl)
    p = pl(k);
    if p.hover, tag = ''; else, tag = '   <- on the stand'; end
    fprintf('  %6.2f-%6.2f s  %4.1f mm | x %.3f mm, std %.3f | i %.3f A | i_ref %.3f | u %.3f%s\n', ...
            p.ta, p.tb, 1e3*p.lev, 1e3*p.x, p.sx, p.i, p.iref, p.u, tag);
end
end

function [os, ts] = step_metrics(t, x, a, z)
% Overshoot beyond the new level z [mm], and settling time [ms] = time from the
% 50 % crossing until the 33 ms running mean of x first stays within +-0.25 mm
% of z for 300 ms (a single noise spike later does not count as "unsettled").
d = z - a;  xs = movmean(x, 11);  nHold = round(0.3/(t(2) - t(1)));
k50 = find(sign(d)*(x - (a + d/2)) > 0, 1);
if isempty(k50), os = NaN; ts = NaN; return; end
after = k50:numel(x);
os = max(1e3*max(sign(d)*(x(after) - z)), 0);
inb = double(abs(xs(after) - z) <= 0.25e-3);
if numel(inb) < nHold, ts = NaN; return; end
held = movsum(inb, [0 nHold-1], 'Endpoints', 'discard');
kk = find(held == nHold, 1);
if isempty(kk), ts = NaN; else, ts = 1e3*(t(after(kk)) - t(k50)); end
end

function f = peak_freq(x, T0)
% Frequency of the largest peak (1-30 Hz) of a Welch-averaged spectrum.
x = x(:) - mean(x);  n = 512;  if numel(x) < n, n = 2^floor(log2(numel(x))); end
w = 0.5 - 0.5*cos(2*pi*(0:n-1)'/(n-1));
st = 1:n/2:numel(x)-n+1;  Pw = zeros(n,1);
for k = st, seg = x(k:k+n-1); seg = seg - mean(seg); Pw = Pw + abs(fft(seg.*w)).^2; end
fr = (0:n-1)'/(n*T0);  sel = fr >= 1 & fr <= 30;
[~, kk] = max(Pw(sel));  fs = fr(sel);  f = fs(kk);
end

function f = zc_freq(t, x, ta, tb)
% Dominant slow frequency [Hz] from upward zero crossings of the 45 ms running
% mean of x (mean removed) between ta and tb.
s = t >= ta & t <= tb;
xm = movmean(x(s) - mean(x(s)), 15);
zc = find(xm(1:end-1) < 0 & xm(2:end) >= 0);
ts = t(s);
if numel(zc) < 2, f = NaN; else, f = (numel(zc) - 1)/(ts(zc(end)) - ts(zc(1))); end
end

function R = find_runs(mask)
d = diff([0; mask(:); 0]);
R = [find(d == 1), find(d == -1) - 1];
end

function ev = cl_eig(C, L, T, tau, ka, a21, b)
% Eigenvalues of the discrete closed loop (linearized plant, ZOH, cascade
% controller), plant coil gain ka (the controller keeps 1/L.ka).
Ac = [0 1 0; a21 0 -b; 0 0 -1/tau];  Bc = [0; 0; ka/tau];
sysd = c2d(ss(Ac, Bc, eye(3), 0), T, 'zoh');
Ri = [C.Kp + C.Kd/T, 0, 0, -C.Kd/T, C.Ki];
Ru = (1/L.ka + C.Kc)*Ri - C.Kc*[0 0 1 0 0];
A = zeros(5);  A(1:3,1:3) = sysd.A;  A(4,1) = 1;  A(5,[1 5]) = [T 1];
A(1:3,:) = A(1:3,:) + sysd.B*Ru;
ev = eig(A);
end

function [f, tTypo] = setpoint_profile(r, C)
% Rebuild x_ref(t) from the plateaus. Each change is placed 20 ms before the
% ball crosses 10 % of the step. Exp A's drop (i_ref = 0 for ~5 s) is modelled
% as a set point of 0.09 m (the inferred typo).
pl = r.pl;  tk = r.t(r.kOn);  vals = pl(1).lev;  tTypo = [];
for k = 2:numel(pl)
    a = vals(end);
    if ~pl(k).hover
        kd = find(r.t > pl(k-1).tm & r.iref < 0.01, 1);
        if ~isempty(kd) && r.t(kd) < pl(k).tb - 1        % typo: i_ref = 0 while levitated
            tk(end+1) = r.t(kd); vals(end+1) = 0.09; tTypo = r.t(kd); %#ok<AGROW>
            kb = find(r.t > r.t(kd) & r.iref > 0.3, 1);
            tk(end+1) = r.t(kb); vals(end+1) = pl(k+1).lev; %#ok<AGROW>
        end
        continue;
    end
    z = pl(k).lev;  if abs(z - a) < 1e-6 || a > 0.05, continue; end
    xs = movmean(r.x, 11);                       % 33 ms mean: hover noise cannot cross 50 % of a 0.5 mm step
    k50 = find(r.t > pl(k).ta - 1.0 & sign(z - a)*(xs - (a + 0.5*(z - a))) > 0, 1);
    tk(end+1) = r.t(k50) - 0.03; vals(end+1) = z; %#ok<AGROW>   % sim reaches 50 % ~30 ms after a step
end
f = @(t) vals(find(tk <= t, 1, 'last') + 0*isempty(find(tk <= t, 1))) ;
f = @(t) pick(tk, vals, t);
end

function v = pick(tk, vals, t)
k = find(tk <= t, 1, 'last'); if isempty(k), k = 1; end
v = vals(k);
end
