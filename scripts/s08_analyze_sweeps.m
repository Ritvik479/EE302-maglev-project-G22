% s08_analyze_sweeps.m   [STANDALONE]
% =========================================================================
% PURPOSE   Analyse the 2026-11-13 AFTERNOON lab runs (model my_cascade_sweep_rt):
%             S  three automatic set-point sweeps 11 -> 9 -> 11 mm
%                (39 g hole-up, 42 g hole-up [rolled], 42 g hole-down)
%             H  three 11.5 mm holds (39 g hole-up, 42 g hole-up, 39 g hole-down)
%           and compare them with the model fitted to the morning runs (s07).
%           EXCLUDED: liftoff_39g_SUSPECT_* (the stand was not really lowered;
%           to be redone at the next lab slot).
% INPUTS    data/lab_2026-11-13/runs/{sweep,hold115}_*.fig
%           data/phase3_cascade.mat                 (controller gains C, lab struct L)
%           data/lab_2026-11-13/exp_ABC_results.mat (morning fit: lam, cB, ioff, kaP, F)
% OUTPUTS   console PASS/FAIL + tables, data/lab_2026-11-13/sweeps_holds_results.mat,
%           figs/p5_sweeps_lab_vs_sim.png, figs/p5_force_fit_all.png,
%           figs/p5_hold115_rocking.png, figs/p5_42g_roll.png
% MODEL     F = c (i - ioff)^2 exp(-x/lam); one lam, one c per ball (as s07).
% SIGNS     x = gap, increasing downward. e = x - x_ref (manual convention), so a
%           ball that sits too LOW (e > 0) must get MORE current: i_ref rises with
%           +Kp e. Section 1 checks this sign directly from the logged signals.
% SWEEP     tau(k+1) = tau(k) + T0 * [x(k) < 11.5 mm]   (Forward Euler, verified in
%           the generated C code), x_ref = table(tau), Flat interpolation, Clip.
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
chk = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
runDir = fullfile(P.dir.data, 'lab_2026-11-13', 'runs');
D = load(fullfile(P.dir.data, 'phase3_cascade.mat'));  C = D.C;  L = D.L;
M = load(fullfile(P.dir.data, 'lab_2026-11-13', 'exp_ABC_results.mat'));   % morning fit (s07)
T0 = L.T0;  g = P.g;  m39 = 0.039288;  m42 = 0.042137;
xGate = 0.0115;
bpT = [0 10 15 20 25 30 35 40 45];  bpX = [11 10.5 10 9.5 9 9.5 10 10.5 11]*1e-3;
tableX = @(tau) bpX(max(1, sum(tau(:) >= bpT, 2)));     % Flat (hold left value), Clip
restHoleUp39 = 0.011923;  restHoleDown42 = 0.011684;    % rest readings, ball on the stand

%% ---- 0. load runs ------------------------------------------------------
% main scope: x, v, i, u    i_ref scope: i, i_ref, x_ref, tau
runs = {'S39u', 'sweep_39g_holeup',    m39, 'sweep',  '39 g sweep, placed hole-up';
        'S42u', 'sweep_42g_holeup',    m42, 'sweep',  '42 g sweep, placed hole-up (rolled)';
        'S42d', 'sweep_42g_holedown',  m42, 'sweep',  '42 g sweep, placed hole-down';
        'H39u', 'hold115_39g_holeup',  m39, 'hold',   '39 g 11.5 mm hold, hole-up';
        'H42u', 'hold115_42g_holeup',  m42, 'hold',   '42 g 11.5 mm hold, hole-up';
        'H39d', 'hold115_39g_holedown',m39, 'hold',   '39 g 11.5 mm hold, hole-down'};
fprintf('NOTE: liftoff_39g_SUSPECT_* is excluded (stand not really lowered; redo at next lab slot).\n\n');
R = struct();
fprintf('run  | record | switch-on | lift (x<11.5) | coil off | tail  | rest before / after [mm] | i at u=0 [A]\n');
for k = 1:size(runs, 1)
    mm = read_scope_fig(fullfile(runDir, [runs{k,2} '_main.fig']));
    qq = read_scope_fig(fullfile(runDir, [runs{k,2} '_iref.fig']));
    assert(numel(mm.t) == numel(qq.t) && max(abs(mm.t - qq.t)) < 1e-9, 'time bases differ: %s', runs{k,2});
    r = struct('t', mm.t, 'x', mm.y(:,1), 'v', mm.y(:,2), 'i', mm.y(:,3), 'u', mm.y(:,4), ...
               'iref', qq.y(:,2), 'xr', qq.y(:,3), 'tau', qq.y(:,4), 'm', runs{k,3}, ...
               'kind', runs{k,4}, 'desc', runs{k,5}, 'file', runs{k,2});
    r.kOn  = find(r.u > 0.01, 1);
    r.kOff = find(r.u > 0.01, 1, 'last');
    r.kLift = r.kOn - 1 + find(r.x(r.kOn:end) < xGate, 1);
    r.xStand = mean(r.x(1:r.kOn-1));
    r.ioff = mean(r.i(1:r.kOn-1));
    r.sigX = std(r.x(1:r.kOn-1));  r.sigI = std(r.i(1:r.kOn-1));
    r.tail = r.t(end) - r.t(r.kOff);
    s2 = find(r.t > r.t(r.kOff) + 1.0);
    if numel(s2) >= 100, r.xAfter = mean(r.x(s2)); r.iAfter = mean(r.i(s2)); else, r.xAfter = NaN; r.iAfter = NaN; end
    R.(runs{k,1}) = r;
    fprintf('%s | %5.1f s | %6.2f s  | %6.2f s      | %6.2f s | %4.1f s | %.3f / %6.3f          | %.4f\n', ...
            runs{k,1}, r.t(end), r.t(r.kOn), r.t(r.kLift), r.t(r.kOff), r.tail, 1e3*r.xStand, 1e3*r.xAfter, r.ioff);
end
sigX = mean(structfun(@(r) r.sigX, R));  sigI = mean(structfun(@(r) r.sigI, R));
fprintf('Sensor noise on the stand (mean of 6 runs): x %.4f mm, i %.4f A\n', 1e3*sigX, sigI);

%% ---- 1. the sweep machinery and the sign convention --------------------
fprintf('\n==== 1. Sweep clock, set-point table, sign convention ====\n');
okTab = true; okStart = true; okGate = true;
for nm = {'S39u', 'S42u', 'S42d'}
    r = R.(nm{1});
    eTab = max(abs(r.xr - tableX(r.tau)'));
    kTau = find(r.tau > 0, 1);
    dTau = diff(r.tau);  want = T0*(r.x(1:end-1) < xGate);
    match = mean(abs(dTau - want) < 1e-6);
    paused = sum(dTau < 1e-6 & (1:numel(dTau))' > r.kLift & (1:numel(dTau))' < r.kOff)*T0;
    fprintf('%s: |x_ref - table(tau)| max %.1e m | tau starts %d sample(s) after x first < 11.5 mm | ', ...
            nm{1}, eTab, kTau - r.kLift);
    fprintf('dtau = T0*[x<11.5] in %.3f %% of samples | clock paused %.2f s while levitating\n', 100*match, paused);
    okTab = okTab && eTab < 1e-9;  okStart = okStart && abs(kTau - r.kLift) <= 1;  okGate = okGate && match > 0.999;
    R.(nm{1}).paused = paused;
end
chk(okTab,   'logged x_ref = lookup table(tau) at every sample (Flat, Clip) in all 3 sweeps');
chk(okStart, 'sweep clock starts within 1 sample of lift-off (first x < 11.5 mm)');
chk(okGate,  'sweep clock advances by T0 exactly when x < 11.5 mm (Forward Euler gate), > 99.9 % of samples');
% Sign: regress logged i_ref on [1, t, e, v] in a quiet 3 s window (39 g, 10 mm, first visit).
% The constant and the t-term absorb i0 and the slowly varying integral.
r = R.S39u;  w = r.t > 23.0 & r.t < 26.0;
e = r.x(w) - r.xr(w);
th = [ones(nnz(w),1), r.t(w) - mean(r.t(w)), e, r.v(w)] \ r.iref(w);
fprintf('Regression i_ref ~ Kp e + Kd v (+ const + slope): Kp %+.1f A/m (design %+.1f), Kd %+.3f A s/m (design %+.3f)\n', ...
        th(3), C.Kp, th(4), C.Kd);
chk(abs(th(3)/C.Kp - 1) < 0.1 && abs(th(4)/C.Kd - 1) < 0.1, ...
    'SIGN: logged i_ref = +Kp(x - x_ref) + Kd v (wrong convention e = x_ref - x would give Kp < 0)');

%% ---- 2. plateaus of the sweeps -----------------------------------------
fprintf('\n==== 2. Sweep plateaus (window: 1.5 s after each set-point change to the next change) ====\n');
for nm = {'S39u', 'S42u', 'S42d'}
    r = R.(nm{1});
    kc = [r.kLift; find(diff(r.xr) ~= 0) + 1];
    tEnd = [r.t(kc(2:end)); r.t(r.kOff) - 0.1];
    pl = struct('lev', {}, 'ta', {}, 'tb', {}, 'tm', {}, 'err', {}, 'sx', {}, 'i', {}, 'iref', {}, 'u', {}, ...
                'brock', {}, 'fpk', {});
    for j = 1:numel(kc)
        ta = r.t(kc(j)) + 1.5 + 1.5*(j == 1);          % first visit: also skip the lift-off transient
        s = r.t >= ta & r.t < tEnd(j);
        if nnz(s) < 300, continue; end
        [f, Pw] = psd_welch(r.x(s), T0, 1024);
        pl(end+1) = struct('lev', r.xr(kc(j)), 'ta', ta, 'tb', tEnd(j), 'tm', mean(r.t(s)), ...
            'err', 1e6*mean(r.x(s) - r.xr(s)), 'sx', 1e3*std(r.x(s)), 'i', mean(r.i(s)), ...
            'iref', mean(r.iref(s)), 'u', mean(r.u(s)), 'brock', 1e3*band_rms(f, Pw, 1.5, 3.5), ...
            'fpk', peak_in(f, Pw, 1, 30)); %#ok<SAGROW>
    end
    R.(nm{1}).pl = pl;
    fprintf('%s (%s):\n', nm{1}, r.desc);
    fprintf('   level | window [s]    | mean err [um] | x std [mm] | 1.5-3.5 Hz rms [mm] | peak [Hz] | i [A]  | u\n');
    for p = pl
        fprintf('   %4.1f  | %5.1f-%5.1f   | %+6.1f        | %.3f      | %.3f               | %4.1f      | %.3f  | %.3f\n', ...
                1e3*p.lev, p.ta, p.tb, p.err, p.sx, p.brock, p.fpk, p.i, p.u);
    end
end
allPl = [R.S39u.pl, R.S42u.pl, R.S42d.pl];
chk(numel(allPl) == 27 && all(abs([allPl.err]) < 20) && all([allPl.sx] < 0.15), ...
    sprintf('all 27 plateaus held: |mean error| <= %.1f um (< 20), x std <= %.3f mm (< 0.15)', ...
            max(abs([allPl.err])), max([allPl.sx])));
chk(any(abs([R.S39u.pl.lev] - 0.009) < 1e-6), '39 g ball held 9.0 mm (first time; Exp A never reached it)');

%% ---- 3. sensor-zero drift, hover current, force law ---------------------
fprintf('\n==== 3. Current-sensor zero drift and force law ====\n');
rates = [];
for nm = fieldnames(R)'
    r = R.(nm{1});  R.(nm{1}).rate = NaN;
    if isnan(r.iAfter), fprintf('  %s: no coil-off tail >= 1.3 s (rate assigned below)\n', nm{1}); continue; end
    dt = r.t(r.kOff) - r.t(r.kOn);  R.(nm{1}).rate = (r.iAfter - r.ioff)/dt;  rates(end+1) = R.(nm{1}).rate; %#ok<SAGROW>
    fprintf('  %s: after %4.1f s on, zero %.4f -> %.4f A (%+5.1f mA, %+.2f mA/s); rest reading %+.3f mm\n', ...
            nm{1}, dt, r.ioff, r.iAfter, 1e3*(r.iAfter - r.ioff), 1e3*R.(nm{1}).rate, 1e3*(r.xAfter - r.xStand));
end
rate = mean(rates);
fprintf('  mean drift %.2f mA/s (morning: about -0.52 mA/s)\n', 1e3*rate);
% S42d has no tail. It ran directly after S42u with the same ball (and started with the
% zero not yet recovered: 0.034 vs 0.039 A), so it takes S42u's measured rate, not the mean.
% (Decided after a first run with the mean rate failed check 3b; see the README.)
R.S42d.rate = R.S42u.rate;
fprintf('  S42d uses S42u''s measured rate (%.2f mA/s): same ball, run directly before\n', 1e3*R.S42u.rate);
for nm = fieldnames(R)', if isnan(R.(nm{1}).rate), R.(nm{1}).rate = rate; end, end
izero = @(r, t) r.ioff + r.rate*(t - r.t(r.kOn));

% 3a. Prediction test: morning fit (39 g never went below 9.5 mm) vs this afternoon
itrueM = @(x, b) sqrt((m39*(b==1) + m42*(b==2))*g/M.cB(b)) .* exp(x/(2*M.lam));
% A plateau with rocking-band (1.5-3.5 Hz) rms > rockMax is flagged: rocking raises the mean
% current (s07: the rocking 39 g 11.5 mm visit sat above the fit), so it is kept out of the
% force fit (3c) and the repeatability test (3b), but stays in the prediction test (3a).
rockMax = 0.04;   % [mm]; quiet plateaus: 0.011-0.033 mm
NF = struct('x', {}, 'itrue', {}, 'u', {}, 'ball', {}, 'run', {}, 'visit', {}, 'rock', {});
for nm = {'S39u', 'S42u', 'S42d'}
    r = R.(nm{1});  b = 1 + (r.m == m42);
    for j = 1:numel(r.pl)
        p = r.pl(j);
        NF(end+1) = struct('x', p.lev, 'itrue', p.i - izero(r, p.tm), 'u', p.u, 'ball', b, 'run', nm{1}, ...
                           'visit', j, 'rock', p.brock > rockMax); %#ok<SAGROW>
    end
end
for q = find([NF.rock])
    fprintf('  flagged (rocking band > %.2f mm): %s visit %d at %.1f mm\n', rockMax, NF(q).run, NF(q).visit, 1e3*NF(q).x);
end
pred = arrayfun(@(q) itrueM(q.x, q.ball), NF);
resM = [NF.itrue] - pred;
fprintf('3a. Morning model predicts the afternoon hover currents: residual rms %.1f mA, mean %+.1f mA (%d plateaus)\n', ...
        1e3*rms(resM), 1e3*mean(resM), numel(NF));
k9 = find(strcmp({NF.run}, 'S39u') & abs([NF.x] - 0.009) < 1e-6);
fprintf('    39 g at 9.0 mm (extrapolated, never seen in the morning): measured %.3f A, predicted %.3f A (%+.1f mA)\n', ...
        mean([NF(k9).itrue]), mean(pred(k9)), 1e3*mean(resM(k9)));
chk(all(abs(resM(k9)) < 0.015), '39 g at 9 mm predicted by the morning force law within 15 mA');
chk(rms(resM) < 0.015, 'morning force law predicts all 27 afternoon plateaus within 15 mA rms');

% 3b. Repeatability: both 42 g sweeps hovered hole-down (the hole-up one rolled at lift-off).
% Same visit sequence in both runs, so compare visit by visit.
lv = unique([NF.x]);
nu = NF(strcmp({NF.run}, 'S42u'));  nd = NF(strcmp({NF.run}, 'S42d'));
d42 = [nu.itrue] - [nd.itrue];  ok42 = ~[nu.rock] & ~[nd.rock];
fprintf('3b. 42 g, sweep "hole-up" (rolled) minus sweep hole-down, per visit [mA]:\n    ');
for j = 1:numel(d42)
    if ok42(j), fprintf('%.1f mm %+.1f | ', 1e3*nu(j).x, 1e3*d42(j));
    else, fprintf('%.1f mm %+.1f (flagged) | ', 1e3*nu(j).x, 1e3*d42(j)); end
end
fprintf('\n');
chk(max(abs(d42(ok42))) < 0.010, sprintf(['42 g: the two sweeps need the same current within 10 mA at every ' ...
    'unflagged visit (max %.1f mA, %d of %d visits)'], 1e3*max(abs(d42(ok42))), nnz(ok42), numel(d42)));

% 3c. Combined fit: morning visits (used) + afternoon plateaus
FM = M.F([M.F.used]);  NU = NF(~[NF.rock]);
X = [[FM.x], [NU.x]];  I = [[FM.itrue], [NU.itrue]];  B = [[FM.ball], [NU.ball]];
A = [X(:)/2, (B(:) == 1), (B(:) == 2)];
th = A \ log(I(:));
lam = 1/th(1);  cB = [m39*g/exp(2*th(2)), m42*g/exp(2*th(3))];
itrueFit = @(x, b) sqrt((m39*(b==1) + m42*(b==2))*g/cB(b)) .* exp(x/(2*lam));
res = I - arrayfun(@(k) itrueFit(X(k), B(k)), 1:numel(X));
fprintf('3c. Combined fit (%d morning + %d afternoon visits): lam = %.2f mm (morning %.2f, manual %.2f)\n', ...
        numel(FM), numel(NU), 1e3*lam, 1e3*M.lam, 1e3*P.Fem.P2);
for q = find([NF.rock])
    fprintf('    flagged %s visit %d (%.1f mm): %+.1f mA from the fit (not fitted)\n', NF(q).run, NF(q).visit, ...
            1e3*NF(q).x, 1e3*(NF(q).itrue - itrueFit(NF(q).x, NF(q).ball)));
end
fprintf('    c = %.2f (39 g), %.2f (42 g) N/A^2 (morning %.2f / %.2f); residual rms %.1f mA, max %.1f mA\n', ...
        cB(1), cB(2), M.cB(1), M.cB(2), 1e3*rms(res), 1e3*max(abs(res)));
fprintf('    42 g needs %.1f %% more current than 39 g at the same gap (mass alone: %.1f %%)\n', ...
        100*(sqrt(m42/cB(2))/sqrt(m39/cB(1)) - 1), 100*(sqrt(m42/m39) - 1));
chk(rms(res) < 0.010, 'combined force law fits all hover visits within 10 mA rms');
chk(abs(lam/M.lam - 1) < 0.05, 'lam unchanged by the new data (within 5 % of the morning value)');

%% ---- 4. steps: lab vs simulation (morning-fitted plant) -----------------
fprintf('\n==== 4. Set-point steps: lab vs simulation (plant fitted in the MORNING, s07) ====\n');
plantM = @(b) struct('m', m39*(b==1) + m42*(b==2), 'lam', M.lam, 'c', M.cB(b), 'ioff', M.ioff, ...
                     'tau', L.tau, 'ka', M.kaP, 'ci', M.ioff);
ST = [];   % [run# from to osLab osSim tsLab tsSim]
rn = {'S39u', 'S42u', 'S42d'};
for q = 1:3
    r = R.(rn{q});  b = 1 + (r.m == m42);  kc = find(diff(r.xr) ~= 0) + 1;
    for j = 1:numel(kc)
        a = r.xr(kc(j) - 1);  z = r.xr(kc(j));  tc = r.t(kc(j));
        w = r.t > tc - 0.5 & r.t < tc + 2.0;
        [osL, tsL] = step_metrics(r.t(w), r.x(w), a, z);
        pq = plantM(b);  ieq = pq.ioff + sqrt(pq.m*g/pq.c)*exp(a/(2*pq.lam));
        o = struct('x0', a, 'i0s', ieq, 'z0', min(max((ieq - C.i0)/C.Ki, -C.zLim), C.zLim), 'xStand', 0.0119);
        s = maglev_cascade_sim(C, L, pq, @(t) a + (z - a)*(t >= 1.0), 3.0, o);
        [osS, tsS] = step_metrics(s.t, s.x, a, z);
        ST(end+1, :) = [q, 1e3*a, 1e3*z, osL, osS, tsL, tsS]; %#ok<SAGROW>
    end
end
fprintf(' run  | step [mm]    | overshoot lab / sim [mm] | settle +-0.25 mm lab / sim [ms]\n');
for k = 1:size(ST, 1)
    fprintf(' %s | %4.1f -> %4.1f | %5.2f / %5.2f            | %4.0f / %4.0f\n', rn{ST(k,1)}, ST(k,2:7));
end
dOS = ST(:,4) - ST(:,5);  up = ST(:,3) < ST(:,2);
fprintf('Overshoot lab - sim: mean %+.2f mm, rms %.2f mm (%d steps); UP steps lab %.2f / sim %.2f, DOWN lab %.2f / sim %.2f mm\n', ...
        mean(dOS), rms(dOS), numel(dOS), mean(ST(up,4)), mean(ST(up,5)), mean(ST(~up,4)), mean(ST(~up,5)));
fprintf('Settling: lab median %.0f ms (max %.0f), sim median %.0f ms\n', median(ST(:,6)), max(ST(:,6)), median(ST(:,7)));
chk(rms(dOS) < 0.2, 'morning-fitted model predicts the afternoon step overshoots within 0.2 mm rms');
chk(all(ST(:,6) < 400), 'every afternoon step settles (+-0.25 mm) within 400 ms');

%% ---- 5. the 42 g roll at lift-off -----------------------------------------
fprintf('\n==== 5. 42 g placed hole-up: the roll at lift-off ====\n');
LO = [];
for nm = {'S39u', 'S42u', 'S42d'}
    r = R.(nm{1});  t0 = r.t(r.kLift);
    w = r.t > t0 + 0.6 & r.t < t0 + 4.0;               % after the lift transient (settles < 0.6 s)
    % last disturbed moment: last time (0.6-6 s after lift) the 0.3 s running std exceeds 0.1 mm (as s07)
    w6 = find(r.t > t0 + 0.6 & r.t < t0 + 6.0);  sd = movstd(r.x, 101);
    kq = w6(find(sd(w6) > 0.1e-3, 1, 'last'));  tq = 0.6;  if ~isempty(kq), tq = r.t(kq) - t0; end
    LO(end+1, :) = [1e3*min(r.x(r.kLift:r.kLift + round(0.5/T0))), 1e3*(max(r.x(w)) - min(r.x(w))), ...
                    tq, r.paused]; %#ok<SAGROW>
    fprintf('  %s: min x in lift %.2f mm | 0.6-4 s after lift: x p-p %.2f mm | last disturbed (0.3 s std > 0.1 mm) %.2f s after lift | clock paused %.2f s\n', ...
            nm{1}, LO(end,:));
end
r = R.S42u;  t0 = r.t(r.kLift);
w = find(r.t > t0 + 0.6 & r.t < t0 + 8);  xs = movmean(r.x, 11);
fprintf('  S42u: x %.2f..%.2f mm in 0.6-4 s; last excursion > 0.5 mm from 11 mm at %.2f s after lift. Motion irregular:\n', ...
        1e3*min(r.x(r.t > t0 + 0.6 & r.t < t0 + 4)), 1e3*max(r.x(r.t > t0 + 0.6 & r.t < t0 + 4)), ...
        r.t(w(find(abs(xs(w) - 0.011) > 0.5e-3, 1, 'last'))) - t0);
fprintf('        no single frequency is quoted (zero-crossing estimates vary 3-7 Hz with the window).\n');
fprintf('  Rest readings: S42u before %.3f, after %.3f mm; S42d (placed hole-down) before %.3f mm\n', ...
        1e3*r.xStand, 1e3*r.xAfter, 1e3*R.S42d.xStand);
chk(abs(r.xAfter - R.S42d.xStand) < 0.03e-3 && abs(r.xStand - R.S42d.xStand) > 0.15e-3, ...
    '42 g placed hole-up came back to the stand reading of a hole-down ball (it rolled over)');
chk(LO(2,2) > 3*max(LO([1 3],2)), '42 g hole-up lift-off is disturbed (roll) while the 39 g and 42 g hole-down lift-offs are quiet');

%% ---- 6. the 11.5 mm holds: rocking ---------------------------------------
fprintf('\n==== 6. 11.5 mm holds: the ~2.4 Hz rocking ====\n');
HD = [];   hn = {'H39u', 'H42u', 'H39d'};
for q = 1:3
    r = R.(hn{q});  s = r.t > r.t(r.kLift) + 2.0 & r.t < r.t(r.kOff) - 0.1;
    [f, Pw] = psd_welch(r.x(s), T0, 2048);  [fi, Pi] = psd_welch(r.i(s), T0, 2048);
    fpk = peak_in(f, Pw, 1, 6);
    HD(end+1, :) = [r.t(r.kOff) - r.t(r.kLift) - 2.1, 1e6*mean(r.x(s) - r.xr(s)), 1e3*std(r.x(s)), ...
                    1e3*band_rms(f, Pw, 1.5, 3.5), fpk, band_rms(fi, Pi, 1.5, 3.5), mean(r.i(s)) - izero(r, mean(r.t(s))), ...
                    1e3*r.xStand, 1e3*r.xAfter]; %#ok<SAGROW>
    R.(hn{q}).spec = struct('f', f, 'Px', Pw);
end
fprintf(' run  | window | mean err | x std  | 1.5-3.5 Hz x rms | x peak | 1.5-3.5 Hz i rms | true i  | rest before / after\n');
for q = 1:3
    fprintf(' %s | %4.1f s | %+5.0f um | %.3f  | %.3f mm         | %.2f Hz| %.4f A         | %.3f A | %.3f / %.3f mm\n', hn{q}, HD(q,:));
end
% Rocking in the sweeps as a function of gap (1.5-3.5 Hz band rms per plateau)
fprintf('Rocking band (1.5-3.5 Hz) rms per gap in the sweeps [mm]:\n   gap    S39u   S42u   S42d\n');
for x0 = lv
    v3 = arrayfun(@(nm) mean([R.(nm{1}).pl(abs([R.(nm{1}).pl.lev] - x0) < 1e-6).brock]), rn);
    fprintf('   %4.1f   %.3f  %.3f  %.3f\n', 1e3*x0, v3);
end
% Is 2.4 Hz a mode of the vertical loop? Linear model at 11.5 mm, 39 g (combined fit).
ieq = itrueFit(0.0115, 1);  a21 = g/lam;  bb = 2*g/ieq;
ev = cl_eig(C, L, T0, L.tau, M.kaP, a21, bb);
fev = abs(log(ev))/(2*pi*T0);  fOsc = fev(imag(ev) > 1e-6);
fprintf('Vertical closed-loop model at 11.5 mm: oscillatory modes at %s Hz (natural frequencies)\n', mat2str(round(fOsc', 1)));
chk(HD(1,4) > 0.1 && HD(3,4) > 0.05 && all(abs(HD([1 3],5) - 2.4) < 0.25), ...
    sprintf('39 g rocks at 11.5 mm in BOTH orientations (%.2f / %.2f Hz)', HD(1,5), HD(3,5)));
chk(HD(2,4) < 0.03, sprintf(['42 g barely rocks at 11.5 mm: the same %.2f Hz peak is there but %.0fx smaller ' ...
    '(band rms %.3f mm), i.e. the mode exists for both balls; damped for 42 g, self-sustained for 39 g'], ...
    HD(2,5), HD(1,4)/HD(2,4), HD(2,4)));
chk(HD(3,4) < 0.7*HD(1,4), sprintf('39 g rocking is smaller hole-down (%.3f vs %.3f mm rms)', HD(3,4), HD(1,4)));
chk(all(fOsc > 4), 'the vertical model has no closed-loop mode below 4 Hz: the 2.4 Hz rocking is NOT a vertical-loop mode');

% 6b. Newton test: is the measured x motion pure VERTICAL motion?
% If the ball's centre really moves as the sensor says, Newton + the force law fix the current:
%   m x'' = m g - c i_true^2 exp(-x/lam)   =>   i_need = sqrt( m (g - x'') exp(x/lam) / c )
% x'' = stride-h second difference (h = 10 samples = 30 ms; it is a triangle-weighted average of the
% true acceleration), so x and i_true get the same triangle filter. Regress i_true on i_need:
% slope 1 = consistent with pure vertical motion. Control case: the 24 set-point steps.
fprintf('6b. Newton test: slope of measured true current vs the current the measured motion needs\n');
h = 10;  tri = [1:h, h-1:-1:1]'/h^2;
nt = {};
for q = 1:3, r = R.(rn{q}); kc = find(diff(r.xr) ~= 0) + 1;
    for j = 1:numel(kc), nt(end+1, :) = {rn{q}, r.t(kc(j)) - 0.3, r.t(kc(j)) + 0.7}; end, end %#ok<SAGROW>
for q = [1 3], r = R.(hn{q}); nt(end+1, :) = {hn{q}, r.t(r.kLift) + 2, r.t(r.kOff) - 0.1}; end %#ok<SAGROW>
NT = zeros(size(nt, 1), 2);
for q = 1:size(nt, 1)
    r = R.(nt{q,1});  b = 1 + (r.m == m42);
    it = r.i - izero(r, r.t);
    am = nan(size(r.x));  kk = h+1:numel(r.x)-h;  am(kk) = (r.x(kk+h) - 2*r.x(kk) + r.x(kk-h))/(h*T0)^2;
    ineed = sqrt(max(r.m*(g - am).*exp(conv(r.x, tri, 'same')/lam)/cB(b), 0));
    itf = conv(it, tri, 'same');
    s = find(r.t >= nt{q,2} & r.t <= nt{q,3});  s = s(s > h & s <= numel(r.x) - h);
    th = [ineed(s) - mean(ineed(s)), ones(numel(s), 1)] \ itf(s);  cr = corrcoef(ineed(s), itf(s));
    NT(q, :) = [th(1), cr(1,2)];
end
nS = size(nt, 1) - 2;  sl = sort(NT(1:nS, 1));
fprintf('  24 steps (control): slope median %.2f (middle half %.2f..%.2f), correlation median %.2f\n', ...
        median(sl), sl(round(0.25*nS)), sl(round(0.75*nS)), median(NT(1:nS, 2)));
fprintf('  steps 10.5 -> 11 mm (last down-step): slopes %s (the steps the simulation overshoots most)\n', ...
        mat2str(round(NT(8:8:nS, 1)', 2)));
fprintf('  H39u rocking: slope %.2f (corr %.2f) | H39d rocking: slope %.2f (corr %.2f)\n', NT(nS+1, :), NT(nS+2, :));
chk(abs(median(NT(1:nS, 1)) - 1) < 0.1, 'control: during steps the measured x motion and current obey Newton + force law (slope ~1)');
chk(all(NT(nS+1:end, 1) > 1.4) && all(NT(nS+1:end, 2) > 0.9), sprintf(['rocking: the coil current swings %.1fx more than ' ...
    'pure vertical motion of the measured size needs -> the 2.4 Hz reading is NOT pure up-down motion'], mean(NT(nS+1:end, 1))));

%% ---- 7. figures ----------------------------------------------------------
col = P.plot.colors;
% 7a sweeps lab vs simulation (x_ref = the LOGGED set point)
f1 = figure('Position', [60 60 1150 900]);
tiledlayout(3, 1, 'TileSpacing', 'compact');
for q = 1:3
    r = R.(rn{q});  b = 1 + (r.m == m42);  t0 = r.t(r.kOn);
    xrF = @(t) r.xr(max(1, min(numel(r.t), round((t + t0 - r.t(1))/T0) + 1)));
    o = struct('x0', r.xStand, 'xStand', r.xStand, 'i0s', M.ioff, 'z0', C.zLim, 'sigX', sigX, 'sigI', sigI, 'seed', 3);
    s = maglev_cascade_sim(C, L, plantM(b), xrF, r.t(r.kOff) - t0, o);
    nexttile; hold on; grid on;
    plot(r.t, 1e3*r.x, 'Color', col(1,:), 'LineWidth', 1);
    plot(s.t + t0, 1e3*s.xm, 'Color', col(2,:), 'LineWidth', 1);
    plot(r.t, 1e3*r.xr, 'k--', 'LineWidth', 1);
    set(gca, 'YDir', 'reverse'); ylim([7.9 12.3]); xlim([r.t(r.kOn) - 2, r.t(r.kOff) + 1]); ylabel('gap x [mm]');
    title(r.desc, 'Color', 'k');
    if q == 1, legend('lab', 'simulation (morning-fitted plant + sensor noise)', 'set point x_{ref} (logged)', ...
                      'Location', 'south', 'NumColumns', 3); end
end
xlabel('time [s]');
exportgraphics(f1, fullfile(P.dir.figs, 'p5_sweeps_lab_vs_sim.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

% 7b force law, all data
f2 = figure('Position', [60 60 850 540]); hold on; grid on;
xx = linspace(8.8e-3, 11.7e-3, 100);  hL = gobjects(0);  lt = {};
for b = 1:2
    Fb = FM([FM.ball] == b);  Nb = NU([NU.ball] == b);  Nx = NF([NF.ball] == b & [NF.rock]);
    plot(1e3*[Nx.x], [Nx.itrue], 's', 'Color', col(b,:), 'MarkerSize', 9, 'LineWidth', 1.2);   % flagged: open
    hL(end+1) = plot(1e3*[Fb.x], [Fb.itrue], 'o', 'Color', col(b,:), 'MarkerSize', 8, 'LineWidth', 1.5); %#ok<SAGROW>
    hL(end+1) = plot(1e3*[Nb.x], [Nb.itrue], 's', 'Color', col(b,:), 'MarkerFaceColor', col(b,:), 'MarkerSize', 7); %#ok<SAGROW>
    hL(end+1) = plot(1e3*xx, itrueFit(xx, b), '-', 'Color', col(b,:)); %#ok<SAGROW>
    lt = [lt, {sprintf('%d g morning', 39 + 3*(b==2)), sprintf('%d g afternoon sweeps', 39 + 3*(b==2)), ...
               sprintf('%d g fit', 39 + 3*(b==2))}]; %#ok<AGROW>
end
for q = [1 3]
    hL(end+1) = plot(11.5, HD(q,7), 'x', 'Color', col(1,:), 'MarkerSize', 12, 'LineWidth', 2); %#ok<SAGROW>
end
hL(end+1) = plot(11.5, HD(2,7), 'x', 'Color', col(2,:), 'MarkerSize', 12, 'LineWidth', 2);
lt = [lt, {'39 g 11.5 mm holds (rocking, not fitted)', '', '42 g 11.5 mm hold (not fitted)'}];
legend(hL([1:6 7 9]), lt([1:6 7 9]), 'Location', 'northwest');
xlabel('gap x [mm]'); ylabel('true hover current (drift-corrected) [A]');
title(sprintf('Force law, %d hover visits (open squares: rocking, not fitted): \\lambda = %.2f mm, residual %.1f mA rms', numel(X), 1e3*lam, 1e3*rms(res)), ...
      'Color', 'k');
exportgraphics(f2, fullfile(P.dir.figs, 'p5_force_fit_all.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

% 7c holds: time traces + spectra
f3 = figure('Position', [60 60 1150 750]);
tiledlayout(2, 3, 'TileSpacing', 'compact');
for q = 1:3
    r = R.(hn{q});  nexttile; hold on; grid on;
    s = r.t > r.t(r.kLift) + 2 & r.t < r.t(r.kLift) + 7;
    plot(r.t(s) - r.t(r.kLift), 1e3*r.x(s), 'Color', col(q,:), 'LineWidth', 1);
    yline(11.5, 'k--'); set(gca, 'YDir', 'reverse'); ylim([10.6 12.4]);
    xlabel('time after lift-off [s]'); ylabel('gap x [mm]');
    title(sprintf('%s: std %.3f mm', r.desc, HD(q,3)), 'Color', 'k', 'FontSize', 10);
end
nexttile([1 3]); hold on; grid on;
for q = 1:3
    sp = R.(hn{q}).spec;  plot(sp.f, 1e3*sqrt(sp.Px), 'Color', col(q,:), 'LineWidth', 1.5);
end
xlim([0.5 15]); set(gca, 'YScale', 'log');
xlabel('frequency [Hz]'); ylabel('x amplitude spectrum [mm/\surdHz]');
legend(arrayfun(@(q) sprintf('%s (peak %.2f Hz)', R.(hn{q}).desc, HD(q,5)), 1:3, 'UniformOutput', false), ...
       'Location', 'northeast');
title('Position spectra at 11.5 mm: same ~2.4 Hz mode in both balls, ~20x larger for the 39 g ball', 'Color', 'k');
exportgraphics(f3, fullfile(P.dir.figs, 'p5_hold115_rocking.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

% 7d 42 g roll at lift-off vs the quiet lift-offs
f4 = figure('Position', [60 60 1000 480]); hold on; grid on;
for q = 1:3
    r = R.(rn{q});  s = r.t > r.t(r.kOn) - 0.3 & r.t < r.t(r.kOn) + 5;
    plot(r.t(s) - r.t(r.kOn), 1e3*r.x(s), 'Color', col(q,:), 'LineWidth', 1.2);
end
yline(11, 'k--'); set(gca, 'YDir', 'reverse');
xlabel('time after switch-on [s]'); ylabel('gap x [mm] (sensor reading)');
legend(sprintf('39 g hole-up (rest %.2f mm)', 1e3*R.S39u.xStand), ...
       sprintf('42 g placed hole-up (rest %.2f -> %.2f mm): rolled', 1e3*R.S42u.xStand, 1e3*R.S42u.xAfter), ...
       sprintf('42 g placed hole-down (rest %.2f mm)', 1e3*R.S42d.xStand), 'set point', 'Location', 'northeast');
title('Sweep lift-offs: the 42 g ball placed hole-up rolls over in the first ~3 s', 'Color', 'k');
exportgraphics(f4, fullfile(P.dir.figs, 'p5_42g_roll.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

save(fullfile(P.dir.data, 'lab_2026-11-13', 'sweeps_holds_results.mat'), 'lam', 'cB', 'NF', 'ST', 'HD', 'LO', ...
     'rate', 'sigX', 'sigI', 'fOsc', 'resM', 'NT');
fprintf('\nSaved data/lab_2026-11-13/sweeps_holds_results.mat and figs/p5_*.png\n');

%% ======================= local functions ================================
function [os, ts] = step_metrics(t, x, a, z)
% Overshoot beyond the new level z [mm]; settling time [ms] from the 50 % crossing
% until the 33 ms running mean stays within +-0.25 mm of z for 300 ms (as s07).
d = z - a;  xs = movmean(x, 11);  nHold = round(0.3/(t(2) - t(1)));
k50 = find(sign(d)*(xs - (a + d/2)) > 0, 1);
if isempty(k50), os = NaN; ts = NaN; return; end
after = k50:numel(x);
os = max(1e3*max(sign(d)*(xs(after) - z)), 0);
inb = double(abs(xs(after) - z) <= 0.25e-3);
if numel(inb) < nHold, ts = NaN; return; end
held = movsum(inb, [0 nHold-1], 'Endpoints', 'discard');
kk = find(held == nHold, 1);
if isempty(kk), ts = NaN; else, ts = 1e3*(t(after(kk)) - t(k50)); end
end

function [f, Pw] = psd_welch(x, T0, n)
% One-sided Welch power spectral density [unit^2/Hz], Hann window, 50 % overlap.
x = x(:) - mean(x);  if numel(x) < n, n = 2^floor(log2(numel(x))); end
w = 0.5 - 0.5*cos(2*pi*(0:n-1)'/(n-1));
st = 1:n/2:numel(x)-n+1;  Pw = zeros(n,1);
for k = st, seg = x(k:k+n-1); seg = seg - mean(seg); Pw = Pw + abs(fft(seg.*w)).^2; end
Pw = Pw/numel(st)/(sum(w.^2)/T0);           % two-sided density
f = (0:n/2)'/(n*T0);  Pw = Pw(1:n/2+1);  Pw(2:end-1) = 2*Pw(2:end-1);
end

function a = band_rms(f, Pw, fa, fb)
s = f >= fa & f <= fb;  a = sqrt(sum(Pw(s))*(f(2) - f(1)));
end

function fp = peak_in(f, Pw, fa, fb)
% Peak frequency in [fa, fb], refined by a parabola through the 3 top bins (log power).
s = find(f >= fa & f <= fb);  [~, k] = max(Pw(s));  k = s(k);  fp = f(k);
if k > 1 && k < numel(f)
    y = log(Pw(k-1:k+1));  den = y(1) - 2*y(2) + y(3);
    if den < 0, fp = f(k) + 0.5*(y(1) - y(3))/den*(f(2) - f(1)); end
end
end

function f = zc_freq(t, x, ta, tb)
% Dominant slow frequency from upward zero crossings of the 45 ms running mean.
s = t >= ta & t <= tb;  xm = movmean(x(s) - mean(x(s)), 15);
zc = find(xm(1:end-1) < 0 & xm(2:end) >= 0);  ts = t(s);
if numel(zc) < 2, f = NaN; else, f = (numel(zc) - 1)/(ts(zc(end)) - ts(zc(1))); end
end

function ev = cl_eig(C, L, T, tau, ka, a21, b)
% Discrete closed-loop eigenvalues: linearized plant (ZOH) + cascade controller (as s07).
Ac = [0 1 0; a21 0 -b; 0 0 -1/tau];  Bc = [0; 0; ka/tau];
sysd = c2d(ss(Ac, Bc, eye(3), 0), T, 'zoh');
Ri = [C.Kp + C.Kd/T, 0, 0, -C.Kd/T, C.Ki];
Ru = (1/L.ka + C.Kc)*Ri - C.Kc*[0 0 1 0 0];
A = zeros(5);  A(1:3,1:3) = sysd.A;  A(4,1) = 1;  A(5,[1 5]) = [T 1];
A(1:3,:) = A(1:3,:) + sysd.B*Ru;
ev = eig(A);
end
