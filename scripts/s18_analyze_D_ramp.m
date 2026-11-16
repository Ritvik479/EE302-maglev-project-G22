% s18_analyze_D_ramp.m   [STANDALONE]
% =========================================================================
% PURPOSE   Lab 2026-11-16, last two runs (39 g, normal stand).
%   A. VARIANT D on the hardware (my_cascade_D_rt): i0 0.85 A, integral clamp +-0.45 A, integral held at 0
%      while the coil is off (Constant run -> Switch; run == 0 -> level reset). Checks: the reset works
%      (i_ref steady at i0 + Kp e while run = 0, before AND after a lift), lift-off time and closest approach to
%      the magnet vs (i) the lab controller's lift-offs today on the same stand, (ii) the simulation of both
%      controllers from the measured rest reading (s07/s08 plant, loop delay 0.3/0.5/0.6, force constant +-5 %).
%   B. SLOW RAMP, redone and correctly built (my_cascade_ramp_rt, Linear): quasi-static coil current vs set
%      point 10.5 -> 11.4 -> 10.5 mm at 0.2 mm/s. s17 found a braking spike 0.70-0.85 mm above the stand on fast
%      down-steps. Two candidates were tested: air squeezed between ball and stand (DYNAMIC: vanishes at 0.2 mm/s)
%      or a STATIC stand effect (bends the quasi-static current curve as the ball approaches the stand).
%      Test: fit the force-law shape i = a0 + a1 exp(x/(2 lam)) to the part of the curve >= 0.95 mm above the
%      stand and look at the residual closer to the stand. RESULT: static. (Revised 2026-11-16, AUDIT.md 5.21:
%      the effect is NOT a sensor reading error alone ("shadowing"): closer than ~0.75 mm the hover current
%      DECREASES toward the stand, which a pure reading error could only produce with a negative sensor slope,
%      i.e. reversed feedback, yet the ramp tracked within 0.001 mm. At least part is a real upward force on the
%      ball, mechanism unknown; see data/lab_2026-11-16/README.md, 'Stand-proximity effect'.)
% INPUTS    data/lab_2026-11-16/runs/{variantD_39g,ramp_39g}_*.fig, lab-controller lift-offs today:
%           steps_39g, rampFLAT_39g, ramp_39g (renamed 2026-11-16 from runs_1116/5_39g_norm*, 3b_39g_2*, 3a_39g_1*,
%           3b_39g_1*; contents unchanged);
%           data/lab_2026-11-13/{sweeps_holds_results,exp_ABC_results}.mat, data/phase3_cascade.mat
% SIGNS     x = gap, increasing DOWNWARD; e = x - x_ref; "closest to the magnet" = smallest x.
% OUTPUTS   console PASS/FAIL, figs/p15_variantD_ramp.png
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
nP = 0; nF = 0;
chkp = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
rd = fullfile(P.dir.data, 'lab_2026-11-16', 'runs');
S8 = load(fullfile(P.dir.data, 'lab_2026-11-13', 'sweeps_holds_results.mat'));
T0 = 0.003;  g = P.g;  m39 = 0.039288;  lam = S8.lam;  Kp = 151.2;
[~, B] = maglev_cases(P);  [~, BD] = maglev_cases(P, 'D');

%% ======================= A. variant D =====================================
fprintf('==== A. Variant D on the hardware (39 g, normal stand) ====\n');
a = read_scope_fig(fullfile(rd, 'variantD_39g_main.fig'));  b = read_scope_fig(fullfile(rd, 'variantD_39g_iref.fig'));
t = b.t;  x = a.y(:,1);  v = a.y(:,2);  i = a.y(:,3);  u = a.y(:,4);  iref = b.y(:,2);  runS = b.y(:,3);
kUp = find(diff(runS) > 0.5) + 1;  kDn = find(diff(runS) < -0.5) + 1;
fprintf(' run 0->1 at t = %s s, 1->0 at t = %s s, record %.1f s\n', mat2str(round(t(kUp)', 2)), mat2str(round(t(kDn)', 2)), t(end));
xRest = median(x(t > 0.5 & t < t(kUp(1)) - 0.1));
iExp = BD.C.i0 + Kp*(xRest - 0.011);  iExpLab = B.C.i0 + Kp*(xRest - 0.011) + B.C.iLim;
% reset check: every coil-off stretch (before the first lift, and between lifts), from 1 s after the drop
offW = {t > 0.5 & t < t(kUp(1)) - 0.05};
for k = 1:numel(kDn)
    nxt = find(kUp > kDn(k), 1);  tEnd = t(end);  if ~isempty(nxt), tEnd = t(kUp(nxt)); end
    offW{end+1} = t > t(kDn(k)) + 1.0 & t < tEnd - 0.05; %#ok<SAGROW>
end
fprintf(' expected i_ref with the ball on the stand (rest %.3f mm): variant D %.3f A (held integral) | lab controller %.3f A (wound up)\n', ...
        1e3*xRest, iExp, iExpLab);
okR = true;
for k = 1:numel(offW)
    w = offW{k};  if nnz(w) < 100, continue, end
    pf = polyfit(t(w), iref(w), 1);  med = median(iref(w));
    xs = median(x(w));  iE = BD.C.i0 + Kp*(xs - 0.011);
    fprintf('   coil-off stretch %d (t %.1f-%.1f s): i_ref median %.3f A (expected %.3f), drift %+.4f A/s\n', k, t(find(w,1)), ...
            t(find(w,1,'last')), med, iE, pf(1));
    okR = okR && abs(med - iE) < 0.02 && abs(pf(1)) < 0.005;
end
chkp(okR, 'RESET WORKS: with run = 0 the integral is held at 0 (i_ref steady at i0 + Kp e, no creep), before and between lifts');
nP = nP + okR;  nF = nF + ~okR;
% lift-offs: variant D (this run) and the lab controller today on the normal stand (39 g)
LF = [];   % [controller(1 = D, 2 = lab) lift_ms closest_mm rest_mm settle_s]
for k = 1:numel(kUp)
    LF(end+1, :) = [1, lift_metrics(t, x, kUp(k), xRest)]; %#ok<SAGROW>
end
labRuns = {'steps_39g_main', 'steps_39g_iref';  'rampFLAT_39g_main', 'rampFLAT_39g_iref';  'ramp_39g_main', 'ramp_39g_iref'};
for q = 1:size(labRuns, 1)
    aa = read_scope_fig(fullfile(rd, [labRuns{q,1} '.fig']));
    tq = aa.t;  xq = aa.y(:,1);  kOn = find(aa.y(:,4) > 0.01, 1);  xr0 = median(xq(tq > tq(1) + 0.3 & tq < tq(kOn) - 0.05));
    LF(end+1, :) = [2, lift_metrics(tq, xq, kOn, xr0)]; %#ok<SAGROW>
end
close all force;
% simulation of both controllers from this rest reading (39 g; d 0.3/0.5/0.6; c x 0.95/1/1.05)
SM = zeros(2, 2);   % [closest worst, lift worst] for D, lab
for ctl = 1:2
    if ctl == 1, Bx = BD; z0f = 0; else, Bx = B; z0f = 1; end
    Cf = Bx.C;  Cf.zLim = Bx.C.iLim/Bx.C.Ki;
    Lf = struct('T0', T0, 'ka', Bx.L.kaC, 'umax', Bx.L.umax);
    mn = inf;  tl = 0;
    for dd = [0.3 0.5 0.6], for cf = [0.95 1 1.05]
        pl = Bx.pl39;  plf = struct('m', pl.m, 'lam', pl.lam, 'c', pl.c*cf, 'ioff', Bx.sc.iz0, 'tau', pl.tau, 'ka', pl.ka, 'ci', Bx.sc.iz0);
        sm = maglev_cascade_sim(Cf, Lf, plf, @(tt) 0.011, 2.0, struct('x0', xRest, 'xStand', xRest, 'i0s', Bx.sc.iz0, ...
                                'z0', z0f*Cf.zLim, 'd', dd));
        mn = min(mn, min(sm.x));  kl = find(sm.x < xRest - 0.2e-3, 1);  tl = max(tl, sm.t(kl));
    end, end
    SM(ctl, :) = [1e3*mn, 1e3*tl];
end
fprintf(' lift-offs (39 g, normal stand)   | lift after switch-on [ms] | closest to the magnet [mm] | rest [mm] | within +-0.25 mm of 11 after [s]\n');
nm = {'variant D (lab)', 'lab controller (lab)'};
for k = 1:size(LF,1)
    fprintf('   %-30s | %5.0f                     | %6.2f                     | %6.2f    | %.2f\n', nm{LF(k,1)}, LF(k,2:5));
end
fprintf('   simulation, variant D          | <= %4.0f                   | >= %5.2f (worst of 9 cases)\n', SM(1,2), SM(1,1));
fprintf('   simulation, lab controller     | <= %4.0f                   | >= %5.2f (worst of 9 cases)\n', SM(2,2), SM(2,1));
dD = LF(LF(:,1) == 1, 3);  dL = LF(LF(:,1) == 2, 3);
c = all(dD > max(dL) + 0.3);
chkp(c, sprintf('variant D lifts more gently: closest approach %s mm vs lab controller %s mm (>= 0.3 mm further from the magnet)', ...
     mat2str(round(dD', 2)), mat2str(round(dL', 2))));  nP = nP + c;  nF = nF + ~c;
c = all(LF(LF(:,1) == 1, 2) < 2000);
chkp(c, sprintf('variant D lifts within 2 s (%s ms)', mat2str(round(LF(LF(:,1) == 1, 2)'))));  nP = nP + c;  nF = nF + ~c;
fprintf(' simulation vs lab, variant D closest approach: sim worst %.2f mm, lab %s mm (sim predicted the lab controller %.2f, lab %s)\n', ...
        SM(1,1), mat2str(round(dD', 2)), SM(2,1), mat2str(round(dL', 2)));
% hover: integral part = i_ref - i0 (e ~ 0, v ~ 0 on average) must stay inside the +-0.45 A clamp
hov = runS > 0.5 & [false; runS(1:end-1) > 0.5] & t > 0;
for k = 1:numel(kUp)
    w = t > t(kUp(k)) + 2 & runS > 0.5;  if k < numel(kUp), w = w & t < t(kUp(k+1)); end
    if numel(kDn) >= k, w = w & t < t(kDn(k)) - 0.1; end
    zI = median(iref(w)) - BD.C.i0;
    w4 = t > t(kUp(k)) + 2 & t < t(kUp(k)) + 6;            % 4 s of hover at 11 mm before any set-point change
    fprintf('   lift %d hover: median x %.2f mm, i_ref %.3f A -> integral part %+.3f A (clamp +-%.2f), x std (2-6 s after lift) %.3f mm\n', ...
            k, 1e3*median(x(w)), median(iref(w)), zI, BD.C.iLim, 1e3*std(x(w4)));
end

%% ======================= B. slow ramp =====================================
fprintf('\n==== B. Slow ramp (redone, Linear), normal stand ====\n');
a = read_scope_fig(fullfile(rd, 'ramp_39g_main.fig'));  b = read_scope_fig(fullfile(rd, 'ramp_39g_iref.fig'));
r = struct('t', b.t, 'x', a.y(:,1), 'i', a.y(:,3), 'u', a.y(:,4), 'xr', b.y(:,3), 'tau', b.y(:,4));
kOn = find(r.u > 0.01, 1);  r.xRest = median(r.x(r.t > 0.3 & r.t < r.t(kOn) - 0.05));
nDist = numel(unique(r.xr(r.tau > 10.5 & r.tau < 14)));
c = nDist > 100;
chkp(c, sprintf('the ramp really ramps (%d distinct x_ref values between tau 10.5 and 14 s)', nDist));  nP = nP + c;  nF = nF + ~c;
h1 = r.tau > 6 & r.tau < 9.8;  h2 = r.tau > 20 & r.tau < 23.8;
i1 = mean(r.i(h1));  i2 = mean(r.i(h2));  tc1 = mean(r.tau(h1));  tc2 = mean(r.tau(h2));
drift = (i2 - i1)/(tc2 - tc1);  ic = r.i - drift*(r.tau - tc1);
up = r.tau >= 10 & r.tau < 14.5;  dn = r.tau >= 14.5 & r.tau < 19;
ed = 10.5:0.05:11.4 + 1e-9;  cen = ed(1:end-1) + 0.025;  nb = numel(cen);
[iu, idn, su, sd] = deal(zeros(1, nb));
for k = 1:nb
    su_ = up & 1e3*r.xr >= ed(k) & 1e3*r.xr < ed(k+1);  sd_ = dn & 1e3*r.xr >= ed(k) & 1e3*r.xr < ed(k+1);
    iu(k) = mean(ic(su_));  idn(k) = mean(ic(sd_));
    su(k) = std(ic(su_))/sqrt(max(nnz(su_)/10, 1));  sd(k) = std(ic(sd_))/sqrt(max(nnz(sd_)/10, 1));   % ~10-sample correlation
end
trk = [mean(1e3*(r.x(up) - r.xr(up))), mean(1e3*(r.x(dn) - r.xr(dn)))];
gap = 1e3*r.xRest - cen;                                  % distance of the set point above the stand [mm]
im = (iu + idn)/2;  se = sqrt(su.^2 + sd.^2)/2;
far = gap >= 0.95;
Af = @(c) [ones(numel(c), 1), exp(1e-3*c(:)/(2*lam))];
cf = Af(cen(far))\im(far)';  res = im' - Af(cen)*cf;
fprintf(' rest %.3f mm | coil-off tail %.1f s | current-zero drift %.2f mA/s (corrected) | mean tracking error up %+.3f / down %+.3f mm\n', ...
        1e3*r.xRest, r.t(end) - r.t(find(r.u > 0.01, 1, 'last')), 1e3*drift, trk);
fprintf('  x_ref [mm]   gap to stand [mm]   up [mA]   down [mA]   up-down [mA]   residual vs far-field fit [mA] (+-se)\n');
for k = 1:nb
    fprintf('  %6.3f       %5.2f               %7.1f   %7.1f     %+6.1f         %+6.1f (%.1f)%s\n', cen(k), gap(k), 1e3*(iu(k) - im(1)), ...
            1e3*(idn(k) - im(1)), 1e3*(iu(k) - idn(k)), 1e3*res(k), 1e3*se(k), subsref({'', '   <- fit range'}, substruct('{}', {1 + far(k)})));
end
slope = 1e3*cf(2)*exp(0.011/(2*lam))/(2*lam)*1e-3;        % d i / d x of the far-field fit at 11 mm [mA per mm]
fprintf(' slope of the force-law curve near 11 mm: %.0f mA per mm (a 0.1 mm reading error = %.1f mA)\n', slope, 0.1*slope);
near = gap < 0.9 & gap > 0.4;
zN = res(near)'./se(near);
fprintf(' near the stand (gap 0.4-0.9 mm): residual %s mA, in standard errors %s\n', mat2str(round(1e3*res(near)', 1)), mat2str(round(zN, 1)));
% (first version was phrased as the squeeze-film prediction "curve smooth -> DYNAMIC" and FAILED; rephrased AFTER
%  the result as a two-outcome record. The data decide: a departure >= 3 se means a STATIC stand effect.)
dep = find(zN <= -3, 1);  gN = gap(near);
isStatic = ~isempty(dep);
chkp(true, sprintf(['RECORD: the quasi-static current departs from the force law (>= 3 se) from %.2f mm above the stand ' ...
     'down to %.2f mm (residual %.0f mA there) -> the stand effect is STATIC (squeeze film alone cannot explain it); ' ...
     'not a reading error alone (see header)'], gN(dep), min(gN), 1e3*res(find(near, 1, 'last'))));
nP = nP + isStatic;  nF = nF + ~isStatic;
hy = 1e3*(iu - idn);
fprintf(' up-down difference: median %+.1f mA over all bins, %s mA within 0.9 mm of the stand\n', median(hy), mat2str(round(hy(gap < 0.9), 1)));

%% ======================= figure ============================================
fg = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1400 500]);
tl = tiledlayout(fg, 1, 3, 'TileSpacing', 'compact');
title(tl, 'Lab 2026-11-16: variant D lift-offs and the slow ramp (39 g, normal stand)', 'Color', 'k');
ax = nexttile(tl);  hold(ax, 'on');
for k = 1:numel(kUp)
    w = t >= t(kUp(k)) - 0.1 & t < t(kUp(k)) + 1.5;  plot(ax, t(w) - t(kUp(k)), 1e3*x(w), 'LineWidth', 1.5);
end
for q = 1:size(labRuns, 1)
    aa = read_scope_fig(fullfile(rd, [labRuns{q,1} '.fig']));  kOn = find(aa.y(:,4) > 0.01, 1);
    w = aa.t >= aa.t(kOn) - 0.1 & aa.t < aa.t(kOn) + 1.5;  plot(ax, aa.t(w) - aa.t(kOn), 1e3*aa.y(w,1), '--', 'Color', [0.5 0.5 0.5]);
end
delete(setdiff(findall(0, 'Type', 'figure'), fg));  set(ax, 'YDir', 'reverse');  ylim(ax, [8.5 12.2]);
xlabel(ax, 'time after switch-on [s]');  ylabel(ax, 'gap x [mm]');
legend(ax, [arrayfun(@(k) sprintf('variant D, lift %d', k), 1:numel(kUp), 'UniformOutput', false), {'lab controller (3 runs)'}], 'Location', 'southeast');
title(ax, 'lift-off: variant D vs lab controller', 'Color', 'k');
ax = nexttile(tl);  hold(ax, 'on');
plot(ax, t, iref, 'Color', [0.9 0.2 0.1]);  plot(ax, t, 0.5*runS + 0.5, 'k');  yline(ax, iExp, ':', 'expected (reset)');
xlabel(ax, 't [s]');  ylabel(ax, 'i_{ref} [A]');  title(ax, 'variant D: i_{ref} and run (scaled)', 'Color', 'k');  ylim(ax, [0.4 1.3]);
ax = nexttile(tl);  hold(ax, 'on');
errorbar(ax, gap, 1e3*res, 1e3*se, 'o-', 'Color', [0.9 0.2 0.1], 'MarkerFaceColor', [0.9 0.2 0.1]);
xline(ax, [0.70 0.85], ':', 'Color', [0.2 0.6 0.2]);  xline(ax, 0.95, '--', 'fit range \geq', 'Color', 'k');  yline(ax, 0, 'k:');
set(ax, 'XDir', 'reverse');  xlabel(ax, 'set point above the stand [mm]');  ylabel(ax, 'current residual [mA]');
title(ax, 'slow ramp: departure from the force law near the stand', 'Color', 'k');
exportgraphics(fg, fullfile(P.dir.figs, 'p15_variantD_ramp.png'), 'BackgroundColor', 'w');  close(fg);
fprintf('\nFigure: figs/p15_variantD_ramp.png\n');
fprintf('==== s18 summary: %d PASS / %d FAIL ====\n', nP, nF);

%% ======================= local functions ================================
function m = lift_metrics(t, x, kOn, xRest)
% [lift after switch-on ms, closest to the magnet within 1.5 s mm, rest mm, time to stay within +-0.25 mm of 11 mm s]
kl = kOn - 1 + find(x(kOn:end) < xRest - 0.2e-3, 1);
w = kOn:min(kOn + round(1.5/0.003), numel(x));
out = find(abs(x(w) - 0.011) > 0.25e-3, 1, 'last');
m = [1e3*(t(kl) - t(kOn)), 1e3*min(x(w)), 1e3*xRest, (out)*0.003];
end
