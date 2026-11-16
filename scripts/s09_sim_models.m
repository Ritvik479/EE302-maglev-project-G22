% s09_sim_models.m   [STANDALONE]
% =========================================================================
% PURPOSE   PS9 deliverable 2: "MATLAB/Simulink models for nominal and uncertain system cases".
%             1. build models/maglev_cl_sim.slx (scripts/build_maglev_cl_sim.m)
%             2. verify it: (a) same answer as the MATLAB simulation maglev_cascade_sim.m,
%                (b) reproduces the lab 39 g sweep, (c) a sign error makes it fail
%             3. run every nominal and uncertain case of scripts/maglev_cases.m
%             5. (added 2026-11-15) the same cases with controller variant D (simulation only, see s11)
% INPUTS    data/lab_2026-11-13/{sweeps_holds_results,exp_ABC_results}.mat, runs/sweep_39g_holeup_*.fig
% OUTPUTS   models/maglev_cl_sim.slx, console PASS/FAIL + case table,
%           data/sim_cases_results.mat, figs/p6_cases_corners.png, figs/p6_cases_special.png
% SIGNS     x = gap, DOWN = +.  e = x - x_ref; more current pulls the ball UP (x falls).
%           Section 2c flips the outer-loop signs (e = x_ref - x) and expects failure.
% SIM CACHE Simulink build files go to tempdir/maglev_slcache (keeps the project clean).
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
chk = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
cache = fullfile(tempdir, 'maglev_slcache');  if ~exist(cache, 'dir'), mkdir(cache); end
Simulink.fileGenControl('set', 'CacheFolder', cache, 'CodeGenFolder', cache);

%% ---- 1. build the model, load the cases ------------------------------------
mdl = build_maglev_cl_sim(P.dir.models);
[K, B, U] = maglev_cases(P);
fprintf('Built %s.slx; %d cases defined.\n', fullfile('models', mdl), numel(K));
fprintf('\nUncertainty set (evidence in maglev_cases.m):\n');
for u = U, fprintf('  %-38s nominal %-20s range %-26s | %s\n', u.param, u.nominal, u.range, u.evidence); end
runOne = @(pl, C, L, sc) sim(Simulink.SimulationInput(mdl).setVariable('pl', pl).setVariable('C', C) ...
                             .setVariable('L', L).setVariable('sc', sc));

%% ---- 2a. same answer as the MATLAB simulation (noise off) ------------------
fprintf('\n==== 2a. Simulink model vs maglev_cascade_sim.m (same plant, same controller) ====\n');
pl = B.pl39;  sc = B.sc;  sc.gate = 1;  sc.Tend = 6;              % gate = 1 m: clock = time
sc.bpT = [0 2 3.5 5] + 0.0015;  sc.bpT(1) = 0;  sc.bpX = [11 10 9 10.5]*1e-3;   % breakpoints between samples
o = runOne(pl, B.C, B.L, sc);
Cf = B.C;  Cf.zLim = B.C.iLim/B.C.Ki;
Lf = struct('T0', B.L.T0, 'ka', B.L.kaC, 'umax', B.L.umax);
plf = struct('m', pl.m, 'lam', pl.lam, 'c', pl.c, 'ioff', sc.iz0, 'tau', pl.tau, 'ka', pl.ka, 'ci', sc.iz0);
xrf = @(t) sc.bpX(find(sc.bpT <= t, 1, 'last'));
dS = sc.nd + sc.ndSub/10;                                     % the nominal measured loop delay (s12)
f = maglev_cascade_sim(Cf, Lf, plf, xrf, sc.Tend, struct('x0', pl.xStand, 'xStand', pl.xStand, 'i0s', sc.iz0, ...
                       'z0', Cf.zLim, 'd', dS));
f0 = maglev_cascade_sim(Cf, Lf, plf, xrf, sc.Tend, struct('x0', pl.xStand, 'xStand', pl.xStand, 'i0s', sc.iz0, ...
                        'z0', Cf.zLim, 'd', 0));
n = min(numel(o.x), numel(f.x));
dx = max(abs(o.x(1:n) - f.x(1:n)));  di = max(abs(o.it(1:n) + sc.iz0 - f.i(1:n)));
di0 = max(abs(o.it(1:n) + sc.iz0 - f0.i(1:n)));
fprintf('  loop delay d = %.1f sample in both; the MATLAB run WITHOUT the delay differs by %.3f A in current\n', dS, di0);
chk(di0 > 100*di, 'the delay is active in the Simulink model (it matches the delayed MATLAB run 100x better than the undelayed one)');
fprintf('  lift-off + steps 11 -> 10 -> 9 -> 10.5 mm, %d samples: max |x diff| %.4f mm, max |i diff| %.2f mA\n', n, 1e3*dx, 1e3*di);
fprintf('  min x: Simulink %.3f mm, MATLAB %.3f mm\n', 1e3*min(o.x), 1e3*min(f.x));
chk(dx < 0.02e-3, 'Simulink model and the MATLAB simulation agree within 0.02 mm (two independent implementations)');

%% ---- 2b. reproduces the lab: 39 g sweep (sweep_39g_holeup) ------------------
fprintf('\n==== 2b. Simulink model vs lab: 39 g sweep, run exactly as in the lab ====\n');
r = lab_run(fullfile(P.dir.data, 'lab_2026-11-13', 'runs'), 'sweep_39g_holeup');
pl = B.pl39;  pl.xStand = r.xStand;
sc = B.sc;  sc.x0 = r.xStand;  sc.bpT = [0 10 15 20 25 30 35 40 45];  sc.bpX = [11 10.5 10 9.5 9 9.5 10 10.5 11]*1e-3;
sc.Tend = r.t(r.kOff) - r.t(r.kOn);  sc.iz0 = r.ioff;  sc.izRate = -0.82e-3;
D = load(fullfile(P.dir.data, 'lab_2026-11-13', 'exp_ABC_results.mat'), 'sigX', 'sigI');
sc.sigX = D.sigX;  sc.sigI = D.sigI;
o = runOne(pl, B.C, B.L, sc);
tL = r.t - r.t(r.kOn);
kS = find(o.tau > 0, 1);  kL = find(r.tau > 0, 1);
fprintf('  sweep clock starts: sim %.3f s, lab %.3f s after switch-on | lowest point in lift-off: sim %.2f, lab %.2f mm\n', ...
        o.tt(kS), tL(kL), 1e3*min(o.x(o.tt < 1)), 1e3*min(r.x(tL > 0 & tL < 1)));
cS = find(diff(o.xref) ~= 0) + 1;  cL = find(diff(r.xr) ~= 0) + 1;
OS = zeros(numel(cL), 2);  IM = zeros(numel(cL) + 1, 2);
for j = 1:numel(cL)
    a = r.xr(cL(j) - 1);  z = r.xr(cL(j));
    OS(j, 1) = step_os(tL(cL(j)-167:cL(j)+667), r.x(cL(j)-167:cL(j)+667), a, z);
    OS(j, 2) = step_os(o.tt(cS(j)-167:cS(j)+667), o.xm(cS(j)-167:cS(j)+667), a, z);
end
eL = [cL; r.kOff];  eS = [cS; numel(o.tt)];
for j = 1:numel(eL)      % mean current reading in the last 2 s of each level
    IM(j, :) = [mean(r.i(eL(j)-667:eL(j)-1)), mean(o.im(eS(j)-667:eS(j)-1))];
end
fprintf('  overshoot per step [mm], lab: %s\n                        sim: %s\n', mat2str(round(OS(:,1)', 2)), mat2str(round(OS(:,2)', 2)));
fprintf('  current reading per level [A], lab: %s\n                              sim: %s\n', ...
        mat2str(round(IM(:,1)', 3)), mat2str(round(IM(:,2)', 3)));
fprintf('  overshoot rms difference %.2f mm; current rms difference %.1f mA\n', rms(OS(:,1) - OS(:,2)), 1e3*rms(IM(:,1) - IM(:,2)));
chk(abs(o.tt(kS) - tL(kL)) < 0.03 && rms(OS(:,1) - OS(:,2)) < 0.2 && rms(IM(:,1) - IM(:,2)) < 0.015, ...
    'Simulink model reproduces the lab sweep: lift timing within 30 ms, overshoot within 0.2 mm rms, current within 15 mA rms');
S2b = struct('o', o, 'r', r);

%% ---- 2c. sign test ------------------------------------------------------------
fprintf('\n==== 2c. Sign test: outer loop with e = x_ref - x (all outer gains negated) ====\n');
Cw = B.C;  Cw.Kp = -Cw.Kp;  Cw.Ki = -Cw.Ki;  Cw.Kd = -Cw.Kd;
sc = B.sc;  sc.Tend = 3;
o = runOne(B.pl39, Cw, B.L, sc);
fprintf('  wrong sign: x after 1-3 s spans %.2f..%.2f mm (set point 11 mm)\n', 1e3*min(o.x(o.tt > 1)), 1e3*max(o.x(o.tt > 1)));
chk(max(abs(o.x(o.tt > 1) - 0.011)) > 0.5e-3, 'wrong sign convention fails to levitate (the model catches a sign error)');

%% ---- 3. all nominal and uncertain cases ------------------------------------------
fprintf('\n==== 3. Nominal and uncertain cases (%d), scenario: lift-off + 0.5 mm steps 11 -> 9 -> 11 mm ====\n', numel(K));
in = Simulink.SimulationInput.empty;
for k = 1:numel(K)
    in(k) = Simulink.SimulationInput(mdl).setVariable('pl', K(k).pl).setVariable('C', B.C) ...
            .setVariable('L', B.L).setVariable('sc', K(k).sc);
end
tic;  out = sim(in, 'ShowProgress', 'off', 'StopOnError', 'off');  fprintf('  %d runs in %.0f s\n', numel(K), toc);
M = struct('ok', {}, 'lift', {}, 'held', {}, 'merr', {}, 'ring', {}, 'os', {}, 'ts', {}, 'usat', {}, 'xstd', {}, ...
           'nlev', {}, 'clampLev', {}, 'unexpl', {}, 'why', {}, 'clear', {}, 'tClose', {}, 'xrClose', {}, 'lost', {});
for k = 1:numel(K), M(k) = case_metrics(out(k), K(k), B.C, B.L); end
fprintf('  %-46s | ok | lift [s] | max |mean e| [um] | ring [mm] | max OS [mm] | max settle [ms] | u at 0.9 [%%]\n', 'case');
for k = 1:numel(K)
    if startsWith(K(k).group, 'corner'), continue; end
    print_case(K(k).name, M(k));
end
for g = {'corner, d low', 'corner, d high'}
    sel = strcmp({K.group}, g{1});  Mg = M(sel);
    fprintf('  %-46s | %2d/%2d ok | lift <= %.2f s | |mean e| <= %.1f um | ring <= %.3f mm | OS %.2f-%.2f mm | settle <= %.0f ms | u sat <= %.1f %%\n', ...
            [g{1} ' (32 cases)'], nnz([Mg.ok]), numel(Mg), max([Mg.lift]), max([Mg.merr]), max([Mg.ring]), ...
            min([Mg.os]), max([Mg.os]), max([Mg.ts]), max([Mg.usat]));
    [~, kw] = max([Mg.os]);  idx = find(sel);  fprintf('      largest overshoot: %s\n', K(idx(kw)).name);
    for kf = idx(~[Mg.ok]), fprintf('      NOT OK: %-44s %s\n', K(kf).name, M(kf).why); end
end
for k = find(~[M.ok] & ~contains({K.group}, 'corner'))
    fprintf('  NOT OK: %-46s %s\n', K(k).name, M(k).why);
end
grp = {K.group};
inSet = ~strcmp(grp, 'delay ref');      % cases inside the uncertainty set (delay 0.3-0.6); refs: d = 0 and d = 1
close = find(~[M.held] & ~[M.lost] & inSet);
fprintf(['  Summary (%d cases in the set): %d fully ok | ball lost in %d | %d come within 0.1 mm of the stand ' ...
         '(at x_ref = 11 mm: %d) | integral clamped somewhere in %d\n'], nnz(inSet), nnz([M(inSet).ok]), ...
        nnz([M(inSet).lost]), numel(close), nnz(abs([M(close).xrClose] - 11) < 1e-6), ...
        nnz(~cellfun(@isempty, {M(inSet).clampLev})));
chk(~any([M(inSet).lost]), sprintf(['STABILITY: the ball is never lost in any of the %d cases of the set ' ...
    '(measured delay 0.3-0.6 sample included)'], nnz(inSet)));
chk(~any([M(~inSet).lost]), sprintf('STABILITY: nor in the %d reference cases (d = 0, and d = 1 as a stress case)', nnz(~inSet)));
chk(isempty(close), sprintf(['CLEARANCE: >= 0.1 mm to the stand after lift-off in every case of the set ' ...
    '(%d cases come closer; the model overpredicts the lab overshoot near 11 mm ~2x)'], numel(close)));
chk(~any([M.unexpl]), ['every level with a steady error above tolerance (20 um; 50 um with noise/tilt) has the ' ...
    'integral at its clamp: no unexplained offsets']);
chk(all([M(~cellfun(@(s) s.sigX > 0 || s.dxA > 0, {K.sc})).ring] < 0.02), ...
    'no sustained oscillation in any noise-free case (x std < 0.02 mm over the last 0.5 s of every level)');
cn = strcmp(grp, 'corner, d low');  cd = strcmp(grp, 'corner, d high');
fprintf('  delay effect on the corners, d %.1f -> %.1f: worst overshoot %.2f -> %.2f mm, worst settle %.0f -> %.0f ms\n', ...
        B.dly.lo, B.dly.hi, max([M(cn).os]), max([M(cd).os]), max([M(cn).ts]), max([M(cd).ts]));

%% ---- 3b. two findings the scenario deliberately avoids ------------------------------
fprintf('\n==== 3b. Limits found while building the cases ====\n');
% (i) a 0.5 mm DOWN-step into 11.5 mm: only 0.42 mm of clearance to the stand
for b = [39 42]
    pl = B.(sprintf('pl%d', b));  sc = B.sc;  hv = hover0(pl, sc, B.C, 0.011);
    for f = fieldnames(hv)', sc.(f{1}) = hv.(f{1}); end
    sc.bpT = [0 1.0015];  sc.bpX = [11 11.5]*1e-3;  sc.gate = 1;  sc.Tend = 3;
    o = runOne(pl, B.C, B.L, sc);
    fprintf('  %d g, step 11 -> 11.5 mm from hover: overshoot %.2f mm, lowest point %.2f mm, stand at %.2f mm -> %s\n', ...
            b, 1e3*(max(o.x(o.tt > 1)) - 0.0115), 1e3*max(o.x(o.tt > 1)), 1e3*pl.xStand, ...
            subsref({'clear', 'TOUCHES THE STAND'}, substruct('{}', {1 + (max(o.x) >= pl.xStand - 1e-6)})));
end
fprintf('  Lab (Exp A, 39 g, same step): overshoot 0.34 mm, no contact. The model overpredicts down-step overshoot\n');
fprintf('  near 11 mm (s08), so this is pessimistic; still, 11.5 mm should be reached by lifting, not by a down-step.\n');
% (ii) kg = 0.4 cannot lift off from the stand (Exp C changed kg only while hovering)
pl = B.pl39;  sc = B.sc;  sc.kg = 0.4;  sc.Tend = 3;
o = runOne(pl, B.C, B.L, sc);
iref = min(B.C.i0 + B.C.Kp*(pl.xStand - 0.011) + B.C.iLim, 2);          % integral at its clamp
itSS = pl.ka*sc.kg*(iref/B.L.kaC + B.C.Kc*(iref - sc.iz0)) / (1 + pl.ka*sc.kg*B.C.Kc);   % i = ka kg (i_ref/kaC + Kc(i_ref - i - iz0))
itSS = min(itSS, pl.ka*B.L.umax);
iNeed = sqrt(pl.m*pl.g*exp(pl.xStand/pl.lam)/pl.c);
fprintf('  kg 0.4, ball on the stand: steady coil current %.3f A (integral clamped) vs %.3f A needed to lift -> %s; sim: %s\n', ...
        itSS, iNeed, subsref({'cannot lift', 'lifts'}, substruct('{}', {1 + (itSS > iNeed)})), ...
        subsref({'no lift in 3 s', 'lifted'}, substruct('{}', {1 + any(o.x < pl.xStand - 0.2e-3)})));
chk((itSS < iNeed) == ~any(o.x < pl.xStand - 0.2e-3), 'static hand calculation and simulation agree on lift-off at kg = 0.4');
% (iii) kg = 0.4 while hovering: needs integral authority; the clamp is +-0.3 A
rc = read_scope_fig(fullfile(P.dir.data, 'lab_2026-11-13', 'runs', 'expC_39g_kg_main.fig'));
qc = read_scope_fig(fullfile(P.dir.data, 'lab_2026-11-13', 'runs', 'expC_39g_kg_iref.fig'));
s4 = find(abs(qc.y(:,3) - 0.4) < 1e-6 & rc.y(:,4) > 0.01);  s4 = s4(round(end/2):end);
zLab = mean(qc.y(s4, 2)) - B.C.i0;               % at 10 mm, e ~ 0: i_ref - i0 = integral part
kh = find(strcmp({K.name}, '39 g, kg 0.4 (hover 10 mm, as Exp C)'));
zSim = mean(out(kh).iref(end-333:end)) - B.C.i0;
sc = B.sc;  hv = hover0(B.pl39, sc, B.C, 0.011, 0.4);  for f = fieldnames(hv)', sc.(f{1}) = hv.(f{1}); end
ie11 = sqrt(B.pl39.m*P.g*exp(0.011/B.pl39.lam)/B.pl39.c);
zNeed = (ie11/(B.pl39.ka*0.4) + B.C.Kc*(ie11 + sc.iz0))/(1/2.44 + B.C.Kc) - B.C.i0;
fprintf('  kg 0.4 at 11 mm needs an integral part of %.3f A for zero error (clamp 0.300): %s\n', zNeed, ...
        subsref({'within the clamp', 'NO zero-error equilibrium exists'}, substruct('{}', {1 + (zNeed > B.C.iLim)})));
sc.bpT = [0 1];  sc.bpX = [11 11]*1e-3;  sc.Tend = 4;
o = runOne(B.pl39, B.C, B.L, sc);
fprintf(['  kg 0.4 hovering at 10 mm: integral part of i_ref = %.3f A in the lab (Exp C), %.3f A in the model ' ...
         '(clamp 0.300)\n'], zLab, zSim);
fprintf('  kg 0.4 hovering at 11 mm (never tried in the lab): the model %s (end x %.2f mm)\n', ...
        subsref({'holds it', 'LOSES THE BALL: the integral needs more than 0.3 A'}, ...
        substruct('{}', {1 + (o.x(end) > B.pl39.xStand - 0.1e-3)})), 1e3*o.x(end));
chk(abs(zLab - zSim) < 0.03, 'model reproduces how close the lab kg 0.4 test was to the integral clamp (within 30 mA)');

%% ---- 5. controller variant D (SIMULATION ONLY, added 2026-11-15) ------------------------
% D = i0 0.85 A, clamp +-0.45 A, integral reset to 0 at switch-on (s11 section 6). Not on the hardware:
% the lab-model change is deferred to the next lab slot. Same model, same 75 cases, same metrics.
fprintf('\n==== 5. Controller variant D (simulation only): i0 0.85 A, clamp 0.45 A, integral reset at switch-on ====\n');
[KD, BD] = maglev_cases(P, 'D');
% 5a. Simulink = MATLAB simulation for variant D (as 2a)
pl = BD.pl39;  sc = BD.sc;  sc.gate = 1;  sc.Tend = 6;
sc.bpT = [0 2 3.5 5] + 0.0015;  sc.bpT(1) = 0;  sc.bpX = [11 10 9 10.5]*1e-3;
o = runOne(pl, BD.C, BD.L, sc);
CfD = BD.C;  CfD.zLim = BD.C.iLim/BD.C.Ki;
plf = struct('m', pl.m, 'lam', pl.lam, 'c', pl.c, 'ioff', sc.iz0, 'tau', pl.tau, 'ka', pl.ka, 'ci', sc.iz0);
xrf = @(t) sc.bpX(find(sc.bpT <= t, 1, 'last'));
f = maglev_cascade_sim(CfD, Lf, plf, xrf, sc.Tend, struct('x0', pl.xStand, 'xStand', pl.xStand, 'i0s', sc.iz0, 'z0', 0, ...
                       'd', sc.nd + sc.ndSub/10));
n = min(numel(o.x), numel(f.x));  dxD = max(abs(o.x(1:n) - f.x(1:n)));
fprintf('  Simulink vs MATLAB simulation, variant D: max |x diff| %.4f mm\n', 1e3*dxD);
chk(dxD < 0.02e-3, 'variant D: Simulink model and the MATLAB simulation agree within 0.02 mm');
% 5b. all cases
inD = Simulink.SimulationInput.empty;
for k = 1:numel(KD)
    inD(k) = Simulink.SimulationInput(mdl).setVariable('pl', KD(k).pl).setVariable('C', BD.C) ...
             .setVariable('L', BD.L).setVariable('sc', KD(k).sc);
end
tic;  outD = sim(inD, 'ShowProgress', 'off', 'StopOnError', 'off');  fprintf('  %d runs in %.0f s\n', numel(KD), toc);
MD = struct('ok', {}, 'lift', {}, 'held', {}, 'merr', {}, 'ring', {}, 'os', {}, 'ts', {}, 'usat', {}, 'xstd', {}, ...
            'nlev', {}, 'clampLev', {}, 'unexpl', {}, 'why', {}, 'clear', {}, 'tClose', {}, 'xrClose', {}, 'lost', {});
for k = 1:numel(KD), MD(k) = case_metrics(outD(k), KD(k), BD.C, BD.L); end
liftCase = ~strcmp({K.group}, 'actuator');               % kg cases start hovering, no lift-off
hiPt = @(oo) 1e3*min(oo.x(oo.tt < 1.0));                  % highest point (smallest gap) in the first second
xL = arrayfun(@(k) hiPt(out(k)), find(liftCase));  xD = arrayfun(@(k) hiPt(outD(k)), find(liftCase));
pkL = arrayfun(@(k) max(out(k).it), 1:numel(K));  pkD = arrayfun(@(k) max(outD(k).it), 1:numel(KD));
lfL = [M(liftCase).lift];  lfD = [MD(liftCase).lift];
nClL = nnz(~cellfun(@isempty, {M.clampLev}));  nClD = nnz(~cellfun(@isempty, {MD.clampLev}));
clL = nnz(~[M.held] & ~[M.lost]);  clD = nnz(~[MD.held] & ~[MD.lost]);
fprintf('  %-52s | lab controller | variant D\n', '');
fprintf('  %-52s | %5d / %2d     | %5d / %2d\n', 'cases fully ok', nnz([M.ok]), numel(M), nnz([MD.ok]), numel(MD));
fprintf('  %-52s | %8d       | %8d\n', 'ball lost', nnz([M.lost]), nnz([MD.lost]));
fprintf('  %-52s | %8d       | %8d\n', 'integral at its clamp somewhere', nClL, nClD);
fprintf('  %-52s | %8d       | %8d\n', 'within 0.1 mm of the stand after lift-off', clL, clD);
fprintf('  %-52s | %8.2f       | %8.2f\n', 'lift-off: highest point, worst case [mm]', min(xL), min(xD));
fprintf('  %-52s | %8.2f       | %8.2f\n', 'lift-off: highest point, median [mm]', median(xL), median(xD));
fprintf('  %-52s | %8.0f       | %8.0f\n', 'lift-off: time to lift, worst case [ms]', 1e3*max(lfL), 1e3*max(lfD));
fprintf('  %-52s | %8.2f       | %8.2f\n', 'peak coil current, worst case [A]', max(pkL), max(pkD));
fprintf('  %-52s | %8.2f       | %8.2f\n', 'step overshoot, worst case [mm]', max([M.os]), max([MD.os]));
iLc = find(liftCase);  [~, wL] = min(xL);  [~, wD] = min(xD);
fprintf('  worst lift-off: lab controller %.2f mm in "%s" | D %.2f mm in "%s"\n', xL(wL), K(iLc(wL)).name, ...
        xD(wD), KD(iLc(wD)).name);
fprintf('  lab controller, lift-off closer than 8 mm to the magnet in %d of %d cases\n', nnz(xL < 8), numel(xL));
for k = find(~[MD.ok]), fprintf('    D NOT OK: %-44s %s\n', KD(k).name, MD(k).why); end
chk(~any([MD.lost]), sprintf('variant D: the ball is never lost in any of the %d cases', numel(MD)));
chk(min(xD) >= 8, sprintf('variant D: lift-off never comes closer than 8 mm to the magnet (worst %.2f mm)', min(xD)));
chk(nClD == 0, 'variant D: the integral never reaches its clamp (no offset from clamping in any case)');
chk(max(lfD) < 0.5, sprintf('variant D: every case lifts off within 0.5 s (worst %.0f ms)', 1e3*max(lfD)));
fprintf('  NOTE: D does not change the step overshoot, so the CLEARANCE finding (section 3) is unchanged by it.\n');

%% ---- 4. figures ---------------------------------------------------------------------
col = P.plot.colors;  gry = [0.65 0.65 0.65];
f1 = figure('Position', [60 60 1150 800]);  tiledlayout(2, 2, 'TileSpacing', 'compact');
for gi = 1:2
    for b = [39 42]
        nexttile; hold on; grid on;
        if gi == 1, sel = find(cn & [K.ball] == b); ttl = sprintf('d %.1f', B.dly.lo);
        else, sel = find(cd & [K.ball] == b); ttl = sprintf('d %.1f', B.dly.hi); end
        nomName = sprintf('nominal %d g', b);                    % nominal: d = B.dly.nom
        for k = sel, plot(out(k).tt, 1e3*out(k).x, 'Color', gry, 'LineWidth', 0.8); end
        kn = find(strcmp({K.name}, nomName));
        plot(out(kn).tt, 1e3*out(kn).x, 'Color', col(1 + (b == 42),:), 'LineWidth', 1.8);
        plot(out(kn).tt, 1e3*out(kn).xref, 'k--', 'LineWidth', 1);
        set(gca, 'YDir', 'reverse');  ylim([8 12.2]);  xlabel('time [s]');  ylabel('gap x [mm]');
        title(sprintf('%d g, corners at %s (grey), nominal d %.1f', b, ttl, B.dly.nom), 'Color', 'k', 'FontSize', 11);
    end
end
exportgraphics(f1, fullfile(P.dir.figs, 'p6_cases_corners.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

f2 = figure('Position', [60 60 1150 800]);  tiledlayout(3, 1, 'TileSpacing', 'compact');
spec = {{'39 g, kg 0.4 (hover 10 mm, as Exp C)', '39 g, kg 2.0 (hover 10 mm, as Exp C)'}, {'39 g, sensor noise', '39 g, zero drift'}, ...
        {'39 g, tilt artifact', '39 g, lab-like (noise + drift + tilt)'}};
for t = 1:3
    nexttile; hold on; grid on;  kn = find(strcmp({K.name}, 'nominal 39 g'));
    plot(out(kn).tt, 1e3*out(kn).x, 'Color', gry, 'LineWidth', 2.5);
    for j = 1:2
        k = find(strcmp({K.name}, spec{t}{j}));
        plot(out(k).tt, 1e3*out(k).x, 'Color', col(j + 2*(t-1) - (t == 3)*0,:), 'LineWidth', 1);
    end
    plot(out(kn).tt, 1e3*out(kn).xref, 'k--', 'LineWidth', 1);
    set(gca, 'YDir', 'reverse');  ylim([8 12.2]);  ylabel('true gap x [mm]');
    legend(['nominal 39 g', spec{t}, {'set point'}], 'Location', 'south', 'NumColumns', 4);
end
xlabel('time [s]');
sgtitle('Actuator, sensor and unmodelled-dynamics cases (39 g ball)', 'Color', 'k', 'FontWeight', 'bold');
exportgraphics(f2, fullfile(P.dir.figs, 'p6_cases_special.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

caseNames = {K.name};  caseGroups = {K.group};
save(fullfile(P.dir.data, 'sim_cases_results.mat'), 'M', 'caseNames', 'caseGroups', 'U', 'B', 'MD', 'BD');   % MD, BD: variant D (sec. 5)
fprintf('\nSaved models/maglev_cl_sim.slx, data/sim_cases_results.mat, figs/p6_cases_*.png\n');
close_system(mdl, 0);

%% ======================= local functions ================================
function r = lab_run(runDir, nm)
a = read_scope_fig(fullfile(runDir, [nm '_main.fig']));  b = read_scope_fig(fullfile(runDir, [nm '_iref.fig']));
r = struct('t', a.t, 'x', a.y(:,1), 'i', a.y(:,3), 'u', a.y(:,4), 'xr', b.y(:,3), 'tau', b.y(:,4));
r.kOn = find(r.u > 0.01, 1);  r.kOff = find(r.u > 0.01, 1, 'last');
r.xStand = mean(r.x(1:r.kOn-1));  r.ioff = mean(r.i(1:r.kOn-1));
end

function os = step_os(t, x, a, z)
% overshoot beyond the new level [mm], 33 ms running mean (as s07/s08)
d = z - a;  xs = movmean(x, 11);  k50 = find(sign(d)*(xs - (a + d/2)) > 0, 1);
if isempty(k50), os = NaN; else, os = max(1e3*max(sign(d)*(xs(k50:end) - z)), 0); end
end

function m = case_metrics(o, k, C, L)
% held = lifted within 1 s and never back on the stand (x < xStand - 0.1 mm) or at the magnet
%        after lift + 0.5 s.
% Per level (last 1 s; with a tilt artifact: a whole number of its cycles):
%   steady error = |mean(xm - x_ref)| of the MEASURED position (what the controller regulates),
%   tolerance 20 um (50 um with noise or tilt);  ringing = std of true x, last 0.5 s.
%   integral part = i_ref - i0 - Kp e - Kd v, rebuilt from the logged signals; "clamped" if
%   its mean is within 1 mA of +-0.3 A.
% ok     = held, every level reached, steady error within tolerance, no ringing (noise-free).
% unexpl = a level is out of tolerance although its integral is NOT clamped.
t = o.tt;  x = o.x;  xr = o.xref;  sc = k.sc;
if isempty(t), m = struct('ok', false, 'lift', Inf, 'held', false, 'merr', NaN, 'ring', NaN, 'os', NaN, ...
                          'ts', NaN, 'usat', NaN, 'xstd', NaN, 'nlev', 0, 'clampLev', [], 'unexpl', true, ...
                          'why', 'simulation failed', 'clear', NaN, 'tClose', NaN, 'xrClose', NaN, 'lost', true); return; end
m.lift = t(find(o.tau > 0, 1));  if isempty(m.lift), m.lift = Inf; end
after = t > m.lift + 0.5;
[xmax, kx] = max(x .* after);
m.clear = 1e3*(k.pl.xStand - xmax);                       % closest approach to the stand after lift [mm]
m.tClose = t(kx);  m.xrClose = 1e3*xr(kx);
m.held = isfinite(m.lift) && m.clear >= 0.1 && all(x(after) > 1e-3);
v = [0; diff(o.xm)]/L.T0;
zint = o.iref - C.i0 - C.Kp*(o.xm - xr) - C.Kd*v;
noisy = sc.sigX > 0 || sc.dxA > 0;  tol = 20 + 30*noisy;
nW = 333;  if sc.dxA > 0, nW = round(floor(1.0*sc.dxF)/sc.dxF/L.T0); end
kc = [find(t >= m.lift, 1); find(diff(xr) ~= 0) + 1; numel(t) + 1];
nLev = 1 + nnz(diff(sc.bpX) ~= 0);  E = nan(numel(kc) - 1, 3);  OS = [];  TS = [];
for j = 1:numel(kc) - 1
    s = max(kc(j), kc(j+1) - nW):kc(j+1) - 1;   s5 = max(kc(j), kc(j+1) - 167):kc(j+1) - 1;
    E(j, :) = [1e6*abs(mean(o.xm(s) - xr(s))), 1e3*std(x(s5)), abs(mean(zint(s))) > C.iLim - 1e-3];
    if j > 1
        w = kc(j) - 100:min(kc(j+1) - 1, kc(j) + 333);
        [os, ts] = step_ms(t(w), x(w), xr(kc(j) - 1), xr(kc(j)));  OS(end+1) = os; TS(end+1) = ts; %#ok<AGROW>
    end
end
m.merr = max(E(:,1));  m.ring = max(E(:,2));  m.os = max(OS);  m.ts = max(TS);
m.usat = 100*mean(o.u(after) >= 0.9 - 1e-9);  m.xstd = mean(E(:,2));  m.nlev = numel(kc) - 1;
bad = E(:,1) >= tol;  lev = 1e3*xr(kc(1:end-1));
m.clampLev = lev(logical(E(:,3)) & bad)';
m.unexpl = any(bad & ~E(:,3));
m.lost = ~(isfinite(m.lift) && m.nlev >= nLev && x(end) < k.pl.xStand - 0.1e-3);
m.ok = m.held && m.nlev >= nLev && ~any(bad) && (noisy || m.ring < 0.02);
why = {};
if m.lost, why{end+1} = 'BALL LOST'; end
if ~m.held && ~m.lost, why{end+1} = sprintf('came within %.2f mm of the stand at %.2f s (x_ref %.1f mm)', m.clear, m.tClose, m.xrClose); end
if m.nlev < nLev, why{end+1} = sprintf('reached %d of %d levels', m.nlev, nLev); end
if any(bad), why{end+1} = sprintf('steady error %.0f um; integral clamped at %s mm', m.merr, mat2str(m.clampLev)); end
if m.unexpl, why{end+1} = 'UNEXPLAINED offset (integral not clamped)'; end
if ~noisy && m.ring >= 0.02, why{end+1} = sprintf('ringing %.3f mm', m.ring); end
m.why = strjoin(why, '; ');
end

function ov = hover0(pl, sc, C, x0, kg)
% hover initial state at x0 with actuator gain error kg (same as maglev_cases/hover_start)
if nargin < 5, kg = 1; end
ieq = sqrt(pl.m*pl.g*exp(x0/pl.lam)/pl.c);
iref = (ieq/(pl.ka*kg) + C.Kc*(ieq + sc.iz0))/(1/2.44 + C.Kc);
ov = struct('x0', x0, 'i0s', ieq, 'zI', min(max(iref - C.i0, -C.iLim), C.iLim), 'kg', kg, ...
            'uIC', ieq/pl.ka);                  % delay line starts holding the equilibrium command
end

function [os, ts] = step_ms(t, x, a, z)
d = z - a;  xs = movmean(x, 11);  k50 = find(sign(d)*(xs - (a + d/2)) > 0, 1);
if isempty(k50), os = NaN; ts = NaN; return; end
after = k50:numel(x);  os = max(1e3*max(sign(d)*(xs(after) - z)), 0);
inb = double(abs(xs(after) - z) <= 0.25e-3);  nH = 100;
if numel(inb) < nH, ts = NaN; return; end
held = movsum(inb, [0 nH-1], 'Endpoints', 'discard');  kk = find(held == nH, 1);
if isempty(kk), ts = NaN; else, ts = 1e3*(t(after(kk)) - t(k50)); end
end

function print_case(name, m)
fprintf('  %-46s | %s | %5.2f    | %6.1f            | %.3f     | %.2f        | %5.0f           | %4.1f\n', ...
        name, subsref({'NO', 'ok'}, substruct('{}', {1 + m.ok})), m.lift, m.merr, m.ring, m.os, m.ts, m.usat);
end
