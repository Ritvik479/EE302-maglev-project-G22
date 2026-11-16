% s13_overshoot_mismatch.m   [STANDALONE]
% =========================================================================
% PURPOSE   Open item (c): why does the model overshoot ~2x more than the lab on the
%           10.5 -> 11 mm down-steps (ball moving AWAY from the magnet)? Tests the
%           hypotheses one by one with the data already recorded (no lab slot needed).
%             1. the pattern: lab vs model overshoot per step, by direction and end gap
%             2. H-lin   linearization                     (already rejected in s10; cited)
%             3. H-table kinks of the sensor calibration table (33 points, 0.7 mm apart)
%             4. Newton test per step: measured acceleration vs the acceleration the logged
%                current produces (force law). Where and when does the mismatch appear?
%             5. H-force the force decays more slowly than exp(-x/lam) beyond 11 mm:
%                5a static estimate (11.5 mm holds), 5b dynamic estimate (13 lift-offs, Newton
%                solved for the force), 5c what H-force WOULD explain if true (simulation)
%             6. what is left, and the lab test that separates the remaining hypotheses
% INPUTS    data/lab_2026-11-13/runs/sweep_*.fig (3 sweeps, 24 steps of 0.5 mm)
%           data/lab_2026-11-13/sweeps_holds_results.mat (s08: lab overshoots ST, hold table HD,
%             combined force fit lam, cB), exp_ABC_results.mat (s07 plant), phase3_cascade.mat,
%           data/delay_estimate.mat (via maglev_cases is NOT needed: d = 0.5 used directly),
%           models/group22_sensor.mat (sensor calibration table)
% OUTPUTS   console PASS/FAIL, data/overshoot_mismatch.mat, figs/p10_overshoot_mismatch.png
% SIGNS     x = gap, increasing DOWNWARD. "Down-step" = set point to a LARGER gap (ball moves
%           away from the magnet). Acceleration a = x'' > 0 means accelerating downward.
%           Force law: m x'' = m g - c fx(x) (i - i0)^2 exp(-x/lam), fx = 1 in the s07/s08 model.
%           Newton residual r = a_measured - a_from_current; r < 0 = the ball is braked (pushed
%           up / held) more than the current explains. Section 4 checks the sign on a control step.
% NOTE      Simulations use the measured loop delay d = 0.5 sample (s12); s08 used d = 0, so the
%           model overshoots here differ slightly from the s08 table.
% REVISED   2026-11-16 (AUDIT.md 4.6-4.9), text only; every number unchanged. The 16-Nov lab session answered
%           this script's open questions: (a) the braking spike is STAND-TIED (0.67-0.89 mm above the stand on
%           both stand heights, s16/s17), so section 4's "position and timing not separable" is superseded;
%           (b) H-force (section 5) is REJECTED: with the stand lowered the same ball hovers at 11.5 mm on the
%           force law within ~1 %, so the 11.5 mm hold deficit belongs to the stand. Section 6 is rewritten.
%           See data/lab_2026-11-16/README.md, 'Stand-proximity effect'. "[record]" checks state a result;
%           they are counted but cannot fail in a meaningful way.
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
nP = 0; nF = 0;
chkp = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
runDir = fullfile(P.dir.data, 'lab_2026-11-13', 'runs');
D = load(fullfile(P.dir.data, 'phase3_cascade.mat'));  C = D.C;  L = D.L;
M = load(fullfile(P.dir.data, 'lab_2026-11-13', 'exp_ABC_results.mat'));        % s07 plant (morning fit)
S8 = load(fullfile(P.dir.data, 'lab_2026-11-13', 'sweeps_holds_results.mat'));  % s08 results
T0 = L.T0;  g = P.g;  m39 = 0.039288;  m42 = 0.042137;  dLoop = 0.5;
lam = S8.lam;  cB = S8.cB;                       % combined force fit (s08): 5.90 mm, 3.29 / 3.02
ST = S8.ST;                                      % [run from to osLab osSim(d=0) tsLab tsSim], mm and ms

%% ---- 0. load the three sweeps --------------------------------------------
rn = {'sweep_39g_holeup', m39, 1, '39 g hole-up';
      'sweep_42g_holeup', m42, 2, '42 g hole-up';
      'sweep_42g_holedown', m42, 2, '42 g hole-down'};
R = cell(3, 1);
for q = 1:3
    mm = read_scope_fig(fullfile(runDir, [rn{q,1} '_main.fig']));
    qq = read_scope_fig(fullfile(runDir, [rn{q,1} '_iref.fig']));
    R{q} = struct('t', mm.t, 'x', mm.y(:,1), 'i', mm.y(:,3), 'u', mm.y(:,4), 'iref', qq.y(:,2), 'xr', qq.y(:,3), ...
                  'm', rn{q,2}, 'c', cB(rn{q,3}), 'cM', M.cB(rn{q,3}), 'name', rn{q,4});
    R{q}.kc = find(diff(R{q}.xr) ~= 0) + 1;      % first sample of each new set point
end
hf = {'hold115_39g_holeup', 'hold115_42g_holeup', 'hold115_39g_holedown'};   % same order as s08's HD rows
HR = cell(3, 1);
for q = 1:3
    mm = read_scope_fig(fullfile(runDir, [hf{q} '_main.fig']));
    HR{q} = struct('t', mm.t, 'x', mm.y(:,1), 'i', mm.y(:,3), 'u', mm.y(:,4));
end
liftRuns = {'cascade_run4', 1; 'expA_39g_sweep_main', 1; 'expB_42g_step_main1', 2; 'expB_42g_step_main2', 2;
            'expB_42g_sweep_main', 2; 'expC_39g_kg_main', 1; 'sweep_39g_holeup_main', 1; 'sweep_42g_holeup_main', 2;
            'sweep_42g_holedown_main', 2; 'hold115_39g_holeup_main', 1; 'hold115_42g_holeup_main', 2;
            'hold115_39g_holedown_main', 1; 'liftoff_39g_SUSPECT_main', 1};   % every lift-off recorded on 2026-11-13
LR = cell(size(liftRuns, 1), 1);
for q = 1:numel(LR)
    mm = read_scope_fig(fullfile(runDir, [liftRuns{q,1} '.fig']));
    LR{q} = struct('t', mm.t, 'x', mm.y(:,1), 'i', mm.y(:,3), 'u', mm.y(:,4), 'ball', liftRuns{q,2});
end
close all force;                                 % read_scope_fig can leave hidden figures behind
nSt = size(ST, 1);
down = ST(:,3) > ST(:,2);                        % to a larger gap = ball moves down
at = @(e) abs(ST(:,3) - e) < 1e-6;               % end gap == e [mm] (tolerant compare)
fprintf('Loaded 3 sweeps, %d set-point steps (%d down, %d up).\n', nSt, nnz(down), nnz(~down));

%% ---- 1. the pattern --------------------------------------------------------
fprintf('\n==== 1. The mismatch: lab vs model overshoot (model: s07 plant, d = %.1f) ====\n', dLoop);
osM0 = sim_steps(C, L, M, ST, [], dLoop, g, m39, m42);
fprintf(' direction, end gap | lab overshoot [mm] (3 runs) | model | lab - model\n');
for e = [9.5 10 10.5 11]
    s = down & at(e);
    fprintf(' down -> %4.1f mm     | %s        | %.2f  | %+.2f\n', e, mat2str(round(ST(s,4)', 2)), mean(osM0(s)), mean(ST(s,4) - osM0(s)));
end
for e = [9 9.5 10 10.5]
    s = ~down & at(e);
    fprintf(' up   -> %4.1f mm     | %s        | %.2f  | %+.2f\n', e, mat2str(round(ST(s,4)', 2)), mean(osM0(s)), mean(ST(s,4) - osM0(s)));
end
labDn = arrayfun(@(e) mean(ST(down & at(e), 4)), [9.5 10 10.5 11]);
modDn = arrayfun(@(e) mean(osM0(down & at(e))), [9.5 10 10.5 11]);
fprintf(' rms(lab - model), all 24 steps: %.2f mm; without the 3 steps ending at 11 mm: %.2f mm\n', ...
        rms(ST(:,4) - osM0), rms(ST(~(down & at(11)), 4) - osM0(~(down & at(11)))));
c = all(diff(labDn) < 0) && modDn(end) > modDn(1);
chkp(c, sprintf(['[record] lab down-step overshoot FALLS with the end gap (%.2f -> %.2f mm) while the model''s ' ...
     'RISES (%.2f -> %.2f mm)'], labDn(1), labDn(end), modDn(1), modDn(end)));  nP = nP + c;  nF = nF + ~c;
s11 = down & at(11);
c = all(ST(s11,4) < 0.55*osM0(s11));
chkp(c, sprintf('[record] on the 10.5 -> 11 mm steps the lab overshoot is about half the model''s or less in all 3 runs (%s vs %s mm, ratio %s)', ...
     mat2str(round(ST(s11,4)', 2)), mat2str(round(osM0(s11)', 2)), mat2str(round(ST(s11,4)'./osM0(s11)', 2))));  nP = nP + c;  nF = nF + ~c;

%% ---- 2. H-lin --------------------------------------------------------------
fprintf('\n==== 2. H-lin (linearization error) ====\n');
fprintf('  Already rejected in s10: the NONLINEAR model has the same mismatch (linear vs nonlinear 0.026 mm).\n');
fprintf('  -> REJECTED (no new computation).\n');

%% ---- 3. H-table: kinks of the sensor calibration table ----------------------
% The lab converts the sensor voltage to x by linear interpolation in a 33-point table (0.7 mm apart)
% (ASSUMED: the interpolation method of the lab's lookup block was not checked; linear is the default).
% If the true sensor curve is smooth, the table's slope changes at each breakpoint put kinks in the
% reading. Test (revised on verification; the first version used a rough analytic bound): take the
% model's 10.5 -> 11 mm step, pass its smooth true x through a smooth sensor curve (polynomial fits of
% degree 4 and 6 through the table, 6-16 mm) and back through the table, and compute the fake
% acceleration of the reading with the same estimator as section 4, for strides h = 3, 5, 10.
fprintf('\n==== 3. H-table: kinks of the sensor calibration table ====\n');
SD = load(fullfile(P.dir.models, 'group22_sensor.mat'));  SD = SD.SensorData;
xd = SD.Distance_mm(:);  Vd = SD.Sensor_V(:);  sl = diff(Vd)./diff(xd);  xm = xd(1:end-1) + diff(xd)/2;
inR = xm > 9.5 & xm < 12.5;
kink = abs(diff(sl))./abs(sl(1:end-1));  kinkR = kink(xm(1:end-1) > 9.5 & xm(1:end-1) < 12.5);
fprintf('  breakpoints every %.1f mm; segment slopes 9.5-12.5 mm: %s V/mm\n', mean(diff(xd)), mat2str(round(sl(inR)', 3)));
fprintf('  largest slope jump between segments (9.5-12.5 mm): %.0f %%\n', 100*max(kinkR));
selS = xd >= 6 & xd <= 16;  ppS = {polyfit(xd(selS), Vd(selS), 4), polyfit(xd(selS), Vd(selS), 6)};
pq = struct('m', m39, 'lam', M.lam, 'c', M.cB(1), 'ioff', M.ioff, 'tau', L.tau, 'ka', M.kaP, 'ci', M.ioff);
ieq = pq.ioff + sqrt(pq.m*g/pq.c)*exp(0.0105/(2*pq.lam));
sK = maglev_cascade_sim(C, L, pq, @(t) 0.0105 + 0.0005*(t >= 1.0), 1.6, struct('x0', 0.0105, 'i0s', ieq, ...
     'z0', min(max((ieq - C.i0)/C.Ki, -C.zLim), C.zLim), 'xStand', 0.0119, 'd', dLoop, 'uIC', (ieq - pq.ci)/pq.ka));
hList = [3 5 10];  aKinkH = zeros(size(hList));
for jh = 1:numel(hList), hh = hList(jh);
    for pk = 1:2
        dx = 1e-3*interp1(Vd, xd, polyval(ppS{pk}, 1e3*sK.x), 'linear') - sK.x;   % reading error
        ad = nan(size(dx));  kk = hh+1:numel(dx)-hh;  ad(kk) = (dx(kk+hh) - 2*dx(kk) + dx(kk-hh))/(hh*T0)^2;
        aKinkH(jh) = max(aKinkH(jh), max(abs(ad(sK.t > 0.95 & sK.t < 1.4))));
    end
end
aKink = aKinkH(hList == 5);
fprintf('  fake acceleration from the table kinks on a 10.5 -> 11 mm step: %s m/s^2 for h = %s\n', ...
        mat2str(round(aKinkH, 3)), mat2str(hList));
h = 5;  tri = [1:h, h-1:-1:1]'/h^2;

%% ---- 4. Newton test per step ------------------------------------------------
% For each step: a_meas = x'' (stride-h second difference), a_cur = g - c (i - i0)^2 exp(-x/lam)/m with
% x and i passed through the same triangle filter. i0 (current-sensor zero, drifts slowly) is set so that
% the 0.5 s of hover BEFORE the step is in balance. r = a_meas - a_cur; most negative r in 0..150 ms.
fprintf('\n==== 4. Newton test per step (measured acceleration vs acceleration from the logged current) ====\n');
NS = zeros(nSt, 6);   % [rmin, t_rmin ms, x_rmin mm, peak x mm, rms r 0..150 ms, sustained mean r 0.1..0.5 s]
k = 0;
for q = 1:3, r = R{q};
    am = nan(size(r.x));  kk = h+1:numel(r.x)-h;  am(kk) = (r.x(kk+h) - 2*r.x(kk) + r.x(kk-h))/(h*T0)^2;
    xf = conv(r.x, tri, 'same');  itf = conv(r.i, tri, 'same');
    for j = 1:numel(r.kc)
        k = k + 1;  tc = r.t(r.kc(j));  pre = r.t > tc - 0.5 & r.t < tc;
        i0z = mean(r.i(pre)) - sqrt(r.m*g/r.c)*exp(mean(r.x(pre))/(2*lam));
        acur = g - r.c*max(itf - i0z, 0).^2.*exp(-xf/lam)/r.m;
        w = find(r.t >= tc & r.t <= tc + 0.15);  res = am(w) - acur(w);
        [rmin, kw] = min(res);
        w2 = r.t >= tc + 0.1 & r.t <= tc + 0.5;
        NS(k, :) = [rmin, 1e3*(r.t(w(kw)) - tc), 1e3*xf(w(kw)), 1e3*max(r.x(w)), rms(res), mean(am(w2) - acur(w2))];
        R{q}.am = am;  R{q}.acur{j} = acur;
    end
end
fprintf(' run            | step [mm]    | most negative r [m/s^2] at [ms], x [mm] | peak x [mm] | mean r 0.1-0.5 s\n');
for k = 1:nSt
    fprintf(' %-14s | %4.1f -> %4.1f | %+5.2f at %3.0f ms, x %5.2f            | %5.2f       | %+5.2f\n', ...
            rn{ST(k,1),4}, ST(k,2), ST(k,3), NS(k,1:4), NS(k,6));
end
reach11 = NS(:,4) >= 10.95;   far = NS(:,4) < 10.8;
fprintf(' steps whose peak stays below 10.8 mm (%d): most negative r median %+.2f, worst %+.2f m/s^2\n', ...
        nnz(far), median(NS(far,1)), min(NS(far,1)));
fprintf(' steps reaching >= 10.95 mm (%d): most negative r median %+.2f, worst %+.2f m/s^2\n', ...
        nnz(reach11), median(NS(reach11,1)), min(NS(reach11,1)));
% sign / method check on the control steps: away from 11 mm the model explains the motion
% (thresholds set AFTER a first look at the data: the control steps' worst spike is -0.97 m/s^2)
c = median(NS(far,5)) < 0.45;
chkp(c, sprintf(['control: on steps that stay below 10.8 mm the current explains the measured acceleration ' ...
     '(rms r median %.2f m/s^2; most negative r median %.2f, worst %.2f)'], median(NS(far,5)), median(NS(far,1)), min(NS(far,1))));  nP = nP + c;  nF = nF + ~c;
c = all(NS(s11,1) < 1.5*min(NS(far,1))) && all(abs(NS(s11,3) - 11.0) < 0.1) && all(NS(s11,2) > 25 & NS(s11,2) < 45);
chkp(c, sprintf(['10.5 -> 11 mm, all 3 runs (2 balls, both orientations): a braking spike of %s m/s^2 at %s ms, ' ...
     'always at x = %s mm (>= 1.5x the worst control step)'], mat2str(round(NS(s11,1)', 1)), mat2str(round(NS(s11,2)')), mat2str(round(NS(s11,3)', 2))));
nP = nP + c;  nF = nF + ~c;
% robustness (added on verification): the spike's SIZE depends on the estimator's stride h, so repeat
% with h = 3 and 10 and compare with the control steps and the kink artefact at the same h.
fprintf(' estimator stride h | 10.5 -> 11 spikes [m/s^2] | worst control step | ratio | table-kink artefact\n');
okH = true;  okK = true;
for jh = 1:numel(hList)
    rmH = newton_min(R, hList(jh), lam, g, T0);
    ratio = min(abs(rmH(s11)))/max(abs(rmH(far)));
    fprintf('   %2d               | %s          | %+.2f              | %.1f   | %.2f\n', hList(jh), ...
            mat2str(round(rmH(s11)', 2)), min(rmH(far)), ratio, aKinkH(jh));
    okH = okH && ratio > 1.5;  okK = okK && aKinkH(jh) < 0.2*min(abs(rmH(s11)));
end
c = okH;
chkp(c, 'the 10.5 -> 11 mm spike is > 1.5x the worst control step for every stride h (not a filter artefact)');  nP = nP + c;  nF = nF + ~c;
c = okK;
chkp(c, 'H-table REJECTED: for every h the table-kink artefact is < 20 % of the smallest 10.5 -> 11 spike');  nP = nP + c;  nF = nF + ~c;
% Position or timing? All three 10.5 -> 11 steps pass 11.0 mm at the same time after the step, so
% "at x = 11.0 mm" and "35 ms after the step" are confounded. The only other fast downward passes through
% 11 mm are in the 42 g roll (S42u). They are evidence only if the roll is otherwise quiet in r.
r = R{2};  kOn = find(r.u > 0.01, 1);  kLf = kOn - 1 + find(r.x(kOn:end) < 0.0115, 1);
am = nan(size(r.x));  kk = h+1:numel(r.x)-h;  am(kk) = (r.x(kk+h) - 2*r.x(kk) + r.x(kk-h))/(h*T0)^2;
xf = conv(r.x, tri, 'same');  itf = conv(r.i, tri, 'same');  vf = nan(size(r.x));  vf(kk) = (r.x(kk+h) - r.x(kk-h))/(2*h*T0);
wR = r.t > r.t(kLf) + 0.6 & r.t < r.t(kLf) + 2.6;
i0z = mean(r.i(wR)) - mean(sqrt(r.m*g/r.c)*exp(r.x(wR)/(2*lam)));
rr = am - (g - r.c*max(itf - i0z, 0).^2.*exp(-xf/lam)/r.m);
zc = find(xf(1:end-1) < 0.011 & xf(2:end) >= 0.011 & vf(1:end-1) > 0.010 & wR(1:end-1));
nearZ = false(size(r.t));  for kz = zc', nearZ(kz-15:kz+25) = true; end
fracBig = mean(rr(wR & ~nearZ) < -2);
fprintf(' 42 g roll (0.6-2.6 s after lift): %d fast downward passes of 11 mm, min r there %.2f m/s^2; but r < -2 m/s^2\n', ...
        numel(zc), min(rr(nearZ & wR)));
fprintf('   also %.0f %% of the time AWAY from them -> the roll cannot separate position from timing.\n', 100*fracBig);
c = fracBig > 0.05;
chkp(c, sprintf(['[record] position (x = 11.0 mm) and timing (~35 ms after a step from 10.5 mm) are NOT separable ' ...
     'with these data (roll residual large everywhere: %.0f %% of the time < -2 m/s^2); SUPERSEDED 2026-11-16: the ' ...
     'spike is stand-tied (s16/s17)'], 100*fracBig));  nP = nP + c;  nF = nF + ~c;
fprintf(['  (Only the TABLE kinks are excluded; a sensor feature finer than the table, e.g. a local flat spot,\n' ...
         '   is not excluded by size: the raw reading reverses 0.08 mm within 12 ms at ~11.1 mm.)\n']);

%% ---- 5. H-force: force decays more slowly than exp(-x/lam) beyond 11 mm -------
fprintf('\n==== 5. H-force: weaker decay of the magnet force beyond 11 mm ====\n');
fprintf([' (SUPERSEDED 2026-11-16: H-force REJECTED. With the stand lowered the same ball hovers at 11.5 mm on the\n' ...
         '  force law within ~1 %%; the hold deficit below belongs to the stand. Kept for the record.)\n']);
fprintf(' 5a. static estimate: the 11.5 mm holds\n');
% the 11.5 mm holds (s08 table HD, column 7 = drift-corrected true current)
hm = [m39 m42 m39];  hb = [1 2 1];  hn = {'39 g hole-up', '42 g hole-up', '39 g hole-down'};
iLaw = arrayfun(@(q) sqrt(hm(q)*g/cB(hb(q)))*exp(0.0115/(2*lam)), 1:3);
iHold = S8.HD(:,7)';
fx115 = (iLaw./iHold).^2;                        % force multiplier needed to hold at 11.5 mm
for q = 1:3
    fprintf('  hold 11.5 mm, %-15s: true current %.3f A, force law needs %.3f A -> force x%.3f\n', hn{q}, iHold(q), iLaw(q), fx115(q));
end
% NOT USED (removed on verification): the 2026-11-12 stand-lift threshold at 12.9 mm. The 2026-11-13 README
% already records that lift thresholds from the stand are not a clean static equilibrium (they once gave the
% wrong "lam > 8.25 mm"), so they cannot bound the force law.
% one-parameter shape: fx = exp(kf (x - 11 mm)) beyond 11 mm, 1 below (the 9-11 mm fit is unchanged)
kf = mean(log(fx115))/0.5;                       % [1/mm], fitted to the holds only
lamLoc = 1/(1/(1e3*lam) - kf);                   % local decay length beyond 11 mm [mm] (kf is per mm)
fprintf('  holds-only shape: force x exp(kf (x - 11 mm)) beyond 11 mm, kf = %.3f /mm (local decay length %.0f mm vs %.2f)\n', ...
        kf, lamLoc, lam*1e3);
% sensitivity to the current-sensor zero (added on verification): s08's drift-corrected zero (HD), the
% zero read before switch-on, and that zero drifted at the fastest measured rate (-0.85 mA/s)
fprintf('  zero sensitivity: force multiplier at 11.5 mm with zero = s08 / at switch-on / switch-on - 0.85 mA/s * t / 0 (extreme)\n');
fxZ = zeros(3, 4);
for q = 1:3, y = HR{q};  kO = find(y.u > 0.01, 1);  kE = find(y.u > 0.01, 1, 'last');
    kLq = kO - 1 + find(y.x(kO:end) < 0.0115, 1);  w = y.t > y.t(kLq) + 2 & y.t < y.t(kE) - 0.1;
    iraw = mean(y.i(w));  z0 = mean(y.i(1:kO-1));  tm = mean(y.t(w)) - y.t(kO);
    zz = [iraw - iHold(q), z0, z0 - 0.00085*tm, 0];
    fxZ(q, :) = (iLaw(q)./(iraw - zz)).^2;
    fprintf('    %-15s: %s\n', hn{q}, mat2str(round(fxZ(q,:), 3)));
end
c = all(all(fxZ(:, 1:3) > 1.03));
chkp(c, sprintf('hold evidence robust to the plausible current zeros (x%.3f-%.3f; only a zero of 0 A, never observed, removes it)', ...
     min(min(fxZ(:,1:3))), max(max(fxZ(:,1:3)))));  nP = nP + c;  nF = nF + ~c;
c = all(fx115 > 1.03);
chkp(c, sprintf(['5a static: hovering at 11.5 mm, 0.43 mm above the normal stand, needs x%.2f-%.2f the force exp(-x/lam) ' ...
     'extrapolates (2026-11-16: a stand effect, not the force law)'], min(fx115), max(fx115)));
nP = nP + c;  nF = nF + ~c;

% 5b. dynamic estimate (added 2026-11-15 on the student's request to refine the fit). In every lift-off the
% ball passes 9-12 mm with a large, well-known current; solve Newton for the force multiplier per sample:
%   fx = m (g - x'') / ( c (i - i_z)^2 exp(-x/lam) ),   i_z = current reading with the coil off just before.
% Samples: 0-0.3 s after switch-on, ball >= 0.1 mm off its rest reading, i - i_z > 0.3 A. The same samples
% at 10.3-10.9 mm (where the static law is known to hold) give each lift-off's own baseline.
% Coil-off falls were tried and rejected: their usable samples are the first few ms after switch-off, with
% the current collapsing and the ball barely moving (fx scattered x1-5).
fprintf(' 5b. dynamic estimate: Newton solved for the force in the %d lift-offs (stride h = 3 and 5)\n', numel(LR));
mb = [m39 m42];  FX = zeros(numel(LR), 3, 2);   % [10.3-10.9, 11.0-11.3, 11.4-11.8] x [h3 h5]
lagSlope = 0;
for jh = 1:2
    hh = 2*jh + 1;  Ev = liftoff_fx(LR, hh, lam, cB, mb, g, T0);
    for q = 1:numel(LR)
        md = @(lo, hi) median(Ev(Ev(:,1) == q & Ev(:,2) >= lo & Ev(:,2) < hi, 3));
        FX(q, :, jh) = [md(10.3, 10.9), md(11.0, 11.3), md(11.4, 11.8)];
    end
    if hh == 3   % lag check: fx must not trend with (di/dt)/i where the law is known to hold
        sB = Ev(:,2) >= 9.5 & Ev(:,2) < 10.75;  pL = polyfit(Ev(sB,4)./Ev(sB,5), Ev(sB,3), 1);  lagSlope = 1e3*pL(1);
    end
end
fprintf('   lift-off                    | h=3: 10.3-10.9 | 11.0-11.3 | 11.4-11.8 || h=5: same\n');
for q = 1:numel(LR)
    fprintf('   %-27s | %.3f          | %.3f     | %.3f     || %.3f  %.3f  %.3f\n', liftRuns{q,1}, FX(q,:,1), FX(q,:,2));
end
relD = squeeze(FX(:,3,:)./FX(:,1,:));            % 11.4-11.8 relative to the lift-off's own baseline
mRel = mean(relD);  seRel = std(relD)/sqrt(numel(LR));
fprintf('   11.4-11.8 mm relative to the own baseline: mean x%.3f +- %.3f (h=3), x%.3f +- %.3f (h=5)  [+- = std. error]\n', ...
        mRel(1), seRel(1), mRel(2), seRel(2));
fprintf('   current-to-force lag check: slope of fx on (di/dt)/i at 9.5-10.75 mm = %+.1f ms (0 = no lag)\n', lagSlope);
c = abs(lagSlope) < 3;
chkp(c, sprintf('5b method: no detectable lag between measured current and force (slope %+.1f ms)', lagSlope));  nP = nP + c;  nF = nF + ~c;
c = all(mRel + 2*seRel < min(fx115));
chkp(c, sprintf(['[record] CONFLICT. Lift-offs passing 11.4-11.8 mm show NO stronger force (x%.2f / x%.2f vs own ' ...
     'baseline), the holds at 11.5 mm need x%.2f-%.2f -> H-force is NOT confirmed'], mRel, min(fx115), max(fx115)));
nP = nP + c;  nF = nF + ~c;
fprintf(['   (The pooled 11.0-11.3 mm bin is not used: per lift-off it ranges %.2f-%.2f, and it mixes the passage\n' ...
         '    with the ball settling at its 11 mm set point.)\n'], min(FX(:,2,1)), max(FX(:,2,1)));
fprintf(' 5c. what H-force WOULD explain if the holds are right (simulation)\n');
% simulate the 24 steps with this force shape. The simulation uses the s07 plant (lam, c from the morning
% fit), so kf is refitted relative to THAT law (added on verification; the first version reused the s08 kf).
iLaw07 = arrayfun(@(q) sqrt(hm(q)*g/M.cB(hb(q)))*exp(0.0115/(2*M.lam)), 1:3);
kf07 = mean(log((iLaw07./iHold).^2))/0.5;
fprintf('  kf relative to the s07 plant used in the simulation: %.3f /mm (s08 law: %.3f /mm)\n', kf07, kf);
fxF = @(x) exp(kf07*1e3*max(x - 0.011, 0));
osMF = sim_steps(C, L, M, ST, fxF, dLoop, g, m39, m42);
fprintf(' direction, end gap | lab  | model | model + H-force\n');
for e = [9.5 10 10.5 11]
    s = down & at(e);
    fprintf(' down -> %4.1f mm     | %.2f | %.2f  | %.2f\n', e, mean(ST(s,4)), mean(osM0(s)), mean(osMF(s)));
end
fprintf(' up   (all 12)       | %.2f | %.2f  | %.2f\n', mean(ST(~down,4)), mean(osM0(~down)), mean(osMF(~down)));
e0 = rms(ST(:,4) - osM0);  eF = rms(ST(:,4) - osMF);
gap11 = [mean(osM0(s11) - ST(s11,4)), mean(osMF(s11) - ST(s11,4))];
fprintf(' rms(lab - model): %.2f -> %.2f mm; 10.5 -> 11 mm gap: %.2f -> %.2f mm (%.0f %% explained)\n', ...
        e0, eF, gap11, 100*(1 - gap11(2)/gap11(1)));
c = eF < e0 && gap11(2) < gap11(1);
chkp(c, 'IF H-force holds (holds-only fit, no step data used), it moves the model toward the lab');  nP = nP + c;  nF = nF + ~c;
c = gap11(2) < 0.1;
chkp(c, sprintf(['H-force ALONE would explain the 10.5 -> 11 mm overshoot (remaining gap %.2f mm < 0.1) ' ...
     '[a FAIL here is the finding: at best it explains part]'], gap11(2)));  nP = nP + c;  nF = nF + ~c;
% regression check of the simulator change: fx = 1 must reproduce the unchanged model exactly
osChk = sim_steps(C, L, M, ST(1:2,:), @(x) 1, dLoop, g, m39, m42);
c = max(abs(osChk - osM0(1:2))) < 1e-9;
chkp(c, 'maglev_cascade_sim: fx = @(x) 1 gives exactly the unchanged model (new option is backward compatible)');
nP = nP + c;  nF = nF + ~c;

%% ---- 6. summary ------------------------------------------------------------------
fprintf('\n==== 6. Summary of hypotheses ====\n');
fprintf('  H-lin    linearization                         REJECTED (s10)\n');
fprintf('  H-table  calibration-table kinks               REJECTED (<= %.2f m/s^2 vs a %.1f m/s^2 spike at h = 5)\n', aKink, min(abs(NS(s11,1))));
fprintf(['  H-force  force decays slower beyond 11 mm      REJECTED 2026-11-16: with the stand lowered the same ball\n' ...
         '           hovers at 11.5 mm on the force law within ~1 %%; the x%.2f-%.2f of the 13-Nov holds (0.43 mm above\n' ...
         '           the stand) belongs to the stand. The ~%.0f %% "explained" of 5c must not be used.\n'], ...
        min(fx115), max(fx115), 100*(1 - gap11(2)/gap11(1)));
fprintf(['  SPIKE    braking spike on the 10.5 -> 11 steps  STAND-TIED (2026-11-16, s16/s17): 0.67-0.89 mm above the\n' ...
         '           stand on both stand heights; gone when the same step stays > 0.9 mm above a lowered stand.\n' ...
         '           Not a calibration-table feature (it moves with the stand), not contact/friction (no up/down\n' ...
         '           hysteresis on the slow ramp, s18). Part of a stand-proximity effect whose mechanism is open:\n' ...
         '           data/lab_2026-11-16/README.md, ''Stand-proximity effect''.\n']);
fprintf(['  LAB TESTS a-f proposed here were run on 2026-11-16 (b, the static sensor sweep, was dropped; f confirmed\n' ...
         '           linear interpolation from the saved lab models).\n']);

%% ---- 7. figure -------------------------------------------------------------------
col = P.plot.colors;
f = figure('Position', [40 40 1300 900]);
try, theme(f, 'light'); catch, end
tl = tiledlayout(f, 2, 2, 'TileSpacing', 'compact');
% (a) overshoot vs end gap, down-steps
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
eg = [9.5 10 10.5 11];
for q = 1:3, s = down & ST(:,1) == q;
    plot(ax, ST(s,3), ST(s,4), 'o', 'Color', col(1,:), 'MarkerFaceColor', col(1,:), 'HandleVisibility', 'off'); end
plot(ax, eg, labDn, '-', 'Color', col(1,:), 'LineWidth', 2.5);
plot(ax, eg, modDn, '-s', 'Color', col(2,:), 'LineWidth', 2);
plot(ax, eg, arrayfun(@(e) mean(osMF(down & at(e))), eg), '--d', 'Color', col(3,:), 'LineWidth', 2);
xlabel(ax, 'end gap of the down-step [mm]');  ylabel(ax, 'overshoot [mm]');
legend(ax, 'lab (dots: 3 runs, line: mean)', sprintf('model (d = %.1f)', dLoop), 'model + H-force (rejected 2026-11-16)', 'Location', 'southwest');
title(ax, '(a) Down-step overshoot: lab falls with gap, model does not', 'Color', 'k');
% (b), (c) measured vs current-implied acceleration, 39 g run, control step and 10.5 -> 11 step
r = R{1};
for j = [7 8]
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    tc = r.t(r.kc(j));  w = r.t > tc - 0.1 & r.t < tc + 0.5;
    plot(ax, 1e3*(r.t(w) - tc), r.am(w), '-', 'Color', col(1,:), 'LineWidth', 1.4);
    plot(ax, 1e3*(r.t(w) - tc), r.acur{j}(w), '-', 'Color', col(2,:), 'LineWidth', 2);
    yline(ax, 0, 'k-');
    xlabel(ax, 'time after the set-point step [ms]');  ylabel(ax, 'acceleration x'''' [m/s^2] (down +)');
    legend(ax, 'measured (from the sensor)', 'from the logged current (force law)', 'Location', 'northeast');
    title(ax, sprintf('(%s) 39 g, step %.1f -> %.1f mm', char('a' + (j - 6)), 1e3*r.xr(r.kc(j) - 1), 1e3*r.xr(r.kc(j))), 'Color', 'k');
end
% (d) braking spike vs where the step peaked
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
plot(ax, NS(~s11,4), NS(~s11,1), 'o', 'Color', col(1,:), 'MarkerFaceColor', col(1,:));
plot(ax, NS(s11,4), NS(s11,1), 's', 'Color', col(2,:), 'MarkerFaceColor', col(2,:), 'MarkerSize', 9);
xline(ax, 11.0, 'k--', '11.0 mm');
xlabel(ax, 'largest gap reached in the step [mm]');  ylabel(ax, 'most negative Newton residual [m/s^2]');
legend(ax, 'other 21 steps', '10.5 -> 11 mm steps', 'Location', 'southwest');
title(ax, '(d) Strong braking only on the steps that pass through 11 mm', 'Color', 'k');
exportgraphics(f, fullfile(P.dir.figs, 'p10_overshoot_mismatch.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

save(fullfile(P.dir.data, 'overshoot_mismatch.mat'), 'ST', 'osM0', 'osMF', 'NS', 'kf', 'kf07', 'fx115', 'fxZ', 'FX', 'relD', 'aKinkH', 'hList', 'dLoop');
fprintf('\nSaved data/overshoot_mismatch.mat, figs/p10_overshoot_mismatch.png\n');
fprintf('SUMMARY: %d PASS / %d FAIL\n', nP, nF);

%% ======================= local functions ================================
function Ev = liftoff_fx(LR, h, lam, cB, mb, g, T0)
% Force multiplier per sample during every lift-off (section 5b).
% rows of Ev: [run, x mm, fx, di/dt A/s, i - i_z A]
tri = [1:h, h-1:-1:1]'/h^2;  g0 = round(0.3/T0);  Ev = [];
for q = 1:numel(LR), r = LR{q};  m = mb(r.ball);  c = cB(r.ball);
    am = nan(size(r.x));  kk = h+1:numel(r.x)-h;  am(kk) = (r.x(kk+h) - 2*r.x(kk) + r.x(kk-h))/(h*T0)^2;
    xf = conv(r.x, tri, 'same');  itf = conv(r.i, tri, 'same');  di = [0; diff(itf)]/T0;
    off = double(r.u <= 0.01);                                  % coil off; gaps < 0.3 s are merged
    on = ~(movmin(off, [g0-1 0]) == 1 | movmin(off, [0 g0-1]) == 1);
    for kon = (find(diff(on) == 1) + 1)'
        if kon < 50, continue, end
        rest = mean(r.x(kon-40:kon-5));  iz = mean(r.i(kon-40:kon-5));
        w = kon:min(kon + round(0.3/T0), numel(r.x) - h);
        sel = w(xf(w) < rest - 0.1e-3 & itf(w) - iz > 0.3);
        fx = m*(g - am(sel))./(c*(itf(sel) - iz).^2.*exp(-xf(sel)/lam));
        Ev = [Ev; q*ones(numel(sel), 1), 1e3*xf(sel), fx, di(sel), itf(sel) - iz]; %#ok<AGROW>
    end
end
end

function rmin = newton_min(R, h, lam, g, T0)
% Most negative Newton residual in 0..150 ms after every set-point step (same method as section 4).
tri = [1:h, h-1:-1:1]'/h^2;  rmin = [];
for q = 1:numel(R), r = R{q};
    am = nan(size(r.x));  kk = h+1:numel(r.x)-h;  am(kk) = (r.x(kk+h) - 2*r.x(kk) + r.x(kk-h))/(h*T0)^2;
    xf = conv(r.x, tri, 'same');  itf = conv(r.i, tri, 'same');
    for j = 1:numel(r.kc)
        tc = r.t(r.kc(j));  pre = r.t > tc - 0.5 & r.t < tc;
        i0z = mean(r.i(pre)) - sqrt(r.m*g/r.c)*exp(mean(r.x(pre))/(2*lam));
        w = r.t >= tc & r.t <= tc + 0.15;
        rmin(end+1, 1) = min(am(w) - (g - r.c*max(itf(w) - i0z, 0).^2.*exp(-xf(w)/lam)/r.m)); %#ok<AGROW>
    end
end
end

function os = sim_steps(C, L, M, ST, fx, d, g, m39, m42)
% Simulate each step of ST from hover at the old level (s07 plant, delay d). Overshoot as s08.
os = zeros(size(ST, 1), 1);
for k = 1:size(ST, 1)
    q = ST(k,1);  b = 1 + (q > 1);  a = ST(k,2)*1e-3;  z = ST(k,3)*1e-3;
    pq = struct('m', m39*(b==1) + m42*(b==2), 'lam', M.lam, 'c', M.cB(b), 'ioff', M.ioff, ...
                'tau', 0, 'ka', M.kaP, 'ci', M.ioff);
    pq.tau = L.tau;
    f1 = 1;  if ~isempty(fx), f1 = fx(a); end
    ieq = pq.ioff + sqrt(pq.m*g/(pq.c*f1))*exp(a/(2*pq.lam));
    o = struct('x0', a, 'i0s', ieq, 'z0', min(max((ieq - C.i0)/C.Ki, -C.zLim), C.zLim), 'xStand', 0.0119, ...
               'd', d, 'uIC', (ieq - pq.ci)/pq.ka, 'fx', fx);
    s = maglev_cascade_sim(C, L, pq, @(t) a + (z - a)*(t >= 1.0), 2.0, o);
    os(k) = overshoot(s.t, s.x, a, z);
end
end

function os = overshoot(t, x, a, z)
% Overshoot beyond the new level z [mm] (33 ms running mean, after the 50 % crossing), as s07/s08.
d = z - a;  xs = movmean(x, 11);
k50 = find(sign(d)*(xs - (a + d/2)) > 0, 1);
if isempty(k50), os = NaN; return; end
os = max(1e3*max(sign(d)*(xs(k50:end) - z)), 0);
end
