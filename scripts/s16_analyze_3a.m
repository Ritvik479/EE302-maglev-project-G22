% s16_analyze_3a.m   [STANDALONE]
% =========================================================================
% PURPOSE   Lab 2026-11-16, item 3a (my_cascade_steps_rt): small set-point steps that pass 11.0 mm
%           at a different time after the step than the 10.5 -> 11 step does. Question from s13:
%           is the braking spike seen on 13-Nov tied to the POSITION (x ~ 11.0 mm) or to the TIMING
%           (~35 ms after a step)? And does the overshoot mismatch (lab ~half the model) repeat?
% INPUTS    data/lab_2026-11-16/runs/steps_{39g,42g}_{main,iref}.fig  (main: x v i u; iref: i i_ref x_ref tau)
%           (files renamed 2026-11-16 from runs_1116/3a_{39g,42g}_1{_main,}.fig; contents unchanged)
% NOTE      s17/s18 later showed the spike is tied to the DISTANCE FROM THE STAND (0.7-0.85 mm above it),
%           not to x = 11 mm as such; with the stand fixed the two cannot be told apart in this run.
%           data/lab_2026-11-13/sweeps_holds_results.mat (s08 force fit lam, cB),
%           data/lab_2026-11-13/exp_ABC_results.mat (s07 plant, used by s13 for the model overshoot),
%           data/phase3_cascade.mat (controller)
% METHOD    identical to s13: overshoot = 33 ms running mean beyond the new level after the 50 %
%           crossing; Newton residual r = x'' (stride h = 5 second difference) - acceleration implied
%           by the logged current through the force law; r < 0 = braked more than the current explains.
%           Model overshoot: s07 plant, loop delay d = 0.5 sample, start in hover at the old level.
% SIGNS     x = gap, increasing DOWNWARD. Down-step = to a larger gap. e = x - x_ref.
% OUTPUTS   console PASS/FAIL, figs/p12_3a_steps.png
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
nP = 0; nF = 0;
chkp = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
runDir = fullfile(P.dir.data, 'lab_2026-11-16', 'runs');
D = load(fullfile(P.dir.data, 'phase3_cascade.mat'));  C = D.C;  L = D.L;
M = load(fullfile(P.dir.data, 'lab_2026-11-13', 'exp_ABC_results.mat'));
S8 = load(fullfile(P.dir.data, 'lab_2026-11-13', 'sweeps_holds_results.mat'));
T0 = L.T0;  g = P.g;  m39 = 0.039288;  m42 = 0.042137;  dLoop = 0.5;  lam = S8.lam;  cB = S8.cB;
h = 5;  tri = [1:h, h-1:-1:1]'/h^2;

%% ---- 0. load + data quality -------------------------------------------------
rn = {'steps_39g', m39, 1, '39 g';  'steps_42g', m42, 2, '42 g'};
R = cell(2, 1);
fprintf('==== 0. Runs and data quality ====\n');
for q = 1:2
    a = read_scope_fig(fullfile(runDir, [rn{q,1} '_main.fig']));
    b = read_scope_fig(fullfile(runDir, [rn{q,1} '_iref.fig']));
    same = numel(a.t) == numel(b.t) && max(abs(a.y(:,3) - b.y(:,1))) == 0;   % both scopes log the current
    r = struct('t', b.t, 'x', a.y(:,1), 'i', a.y(:,3), 'u', a.y(:,4), 'iref', b.y(:,2), 'xr', b.y(:,3), ...
               'tau', b.y(:,4), 'm', rn{q,2}, 'c', cB(rn{q,3}), 'cM', M.cB(rn{q,3}), 'name', rn{q,4});
    r.kOn = find(r.u > 0.01, 1);  r.kOff = find(r.u > 0.01, 1, 'last');
    r.kLift = find(r.tau > 0, 1);
    r.xRest = median(r.x(r.t > 0.1 & r.t < r.t(r.kOn)));
    r.ioff = median(r.i(r.t > 0.1 & r.t < r.t(r.kOn)));
    pre = r.t > r.t(r.kOn) - 1 & r.t < r.t(r.kOn) - 0.05;
    r.irefPre = median(r.iref(pre));  r.irefExp = C.i0 + C.Kp*(r.xRest - 0.011) + 0.3;
    r.tail = r.t(end) - r.t(r.kOff);
    r.kc = find(diff(r.xr) ~= 0) + 1;
    tauSpan = r.tau(end) - r.tau(r.kLift);  tSpan = r.t(r.kOff) - r.t(r.kLift);
    fprintf(' %s: both scopes are the same samples: %d | record %.1f s | coil on at t = %.2f s, lift (tau > 0) %.0f ms later\n', ...
            r.name, same, r.t(end) - r.t(1), r.t(r.kOn), 1e3*(r.t(r.kLift) - r.t(r.kOn)));
    fprintf('    rest reading %.3f mm | current-sensor zero %.3f A | pre-lift i_ref %.3f A (expected %.3f)\n', ...
            1e3*r.xRest, r.ioff, r.irefPre, r.irefExp);
    fprintf('    coil off at t = %.2f s, tail %.2f s | %d set-point changes | tau advanced %.2f s in %.2f s of coil-on time\n', ...
            r.t(r.kOff), r.tail, numel(r.kc), tauSpan, tSpan);
    R{q} = r;
end
c = all(cellfun(@(r) abs(r.irefPre - r.irefExp) < 0.03, R));
chkp(c, 'pre-lift i_ref matches i0 + Kp (x_rest - 11 mm) + 0.3 A (controller + set point as intended)');  nP = nP + c;  nF = nF + ~c;
c = all(cellfun(@(r) r.xRest > 0.01187 && r.xRest < 0.01200, R));
chkp(c, sprintf('stand within the 11.87-12.00 mm tolerance (rest %s mm)', mat2str(round(1e3*cellfun(@(r) r.xRest, R)', 3))));  nP = nP + c;  nF = nF + ~c;
c = all(cellfun(@(r) numel(r.kc) == 6, R));
chkp(c, sprintf('all 6 table steps present in every run (%s)', mat2str(cellfun(@(r) numel(r.kc), R)')));  nP = nP + c;  nF = nF + ~c;
for q = 1:2
    c = R{q}.tail >= 3;
    chkp(c, sprintf('%s: coil-off tail >= 3 s (%.2f s)', R{q}.name, R{q}.tail));  nP = nP + c;  nF = nF + ~c;
end

%% ---- 1. steps: lab vs model overshoot, clearance ----------------------------
fprintf('\n==== 1. Steps: lab vs model overshoot (model: s07 plant, d = %.1f), clearance to the stand ====\n', dLoop);
ST = [];   % [run from to osLab osModel peakx clearance tstep]
for q = 1:2, r = R{q};
    for j = 1:numel(r.kc)
        k0 = r.kc(j);  a = r.xr(k0 - 1);  z = r.xr(k0);
        k1 = min(k0 + round(1.5/T0), numel(r.t));  w = k0:k1;
        os = overshoot(r.t(w), r.x(w), a, z);
        ST(end+1, :) = [q, 1e3*a, 1e3*z, os, NaN, 1e3*max(r.x(w)), 1e3*(r.xRest - max(r.x(w))), r.t(k0)]; %#ok<SAGROW>
    end
end
ST(:,5) = sim_steps(C, L, M, ST, dLoop, g, m39, m42);
fprintf(' run  | step [mm]     | lab os | model os | lab/model | peak x | clearance to stand [mm]\n');
for k = 1:size(ST,1)
    fprintf(' %-4s | %4.1f -> %4.1f | %5.2f  | %5.2f    | %4.2f      | %5.2f  | %5.2f\n', R{ST(k,1)}.name, ST(k,2:5), ...
            ST(k,4)/ST(k,5), ST(k,6:7));
end
c = min(ST(:,7)) > 0.1;
chkp(c, sprintf('the ball never came within 0.1 mm of the stand (closest %.2f mm)', min(ST(:,7))));  nP = nP + c;  nF = nF + ~c;
dn = ST(:,3) > ST(:,2);  up = ~dn;
ref = dn & abs(ST(:,2) - 10.5) < 1e-6 & abs(ST(:,3) - 11.0) < 1e-6;
fprintf(' reference 10.5 -> 11 steps today: lab %s mm, model %s mm (13-Nov lab 0.25-0.32, model 0.64-0.73)\n', ...
        mat2str(round(ST(ref,4)', 2)), mat2str(round(ST(ref,5)', 2)));
c = all(ST(ref,4) < 0.55*ST(ref,5));
chkp(c, 'record: the 10.5 -> 11 mismatch repeats today (lab <= 0.55x model)');  nP = nP + c;  nF = nF + ~c;
fprintf(' lab/model ratio: down-steps %s | up-steps %s\n', mat2str(round(ST(dn,4)'./ST(dn,5)', 2)), mat2str(round(ST(up,4)'./ST(up,5)', 2)));

%% ---- 2. Newton test: where and when is the ball braked? ----------------------
fprintf('\n==== 2. Newton residual per step (h = %d): most negative r in 0-150 ms ====\n', h);
NS = zeros(size(ST,1), 5);   % [rmin, t_rmin ms, x_rmin mm, t when x first passes 11.0 mm (ms, NaN if never), rms r]
k = 0;
for q = 1:2, r = R{q};
    am = nan(size(r.x));  kk = h+1:numel(r.x)-h;  am(kk) = (r.x(kk+h) - 2*r.x(kk) + r.x(kk-h))/(h*T0)^2;
    xf = conv(r.x, tri, 'same');  itf = conv(r.i, tri, 'same');
    for j = 1:numel(r.kc)
        k = k + 1;  tc = r.t(r.kc(j));  pre = r.t > tc - 0.5 & r.t < tc;
        i0z = mean(r.i(pre)) - sqrt(r.m*g/r.c)*exp(mean(r.x(pre))/(2*lam));
        acur = g - r.c*max(itf - i0z, 0).^2.*exp(-xf/lam)/r.m;
        w = find(r.t >= tc & r.t <= tc + 0.15);  res = am(w) - acur(w);
        [rmin, kw] = min(res);
        a = ST(k,2)*1e-3;  z = ST(k,3)*1e-3;  p11 = NaN;
        if z > a && z >= 0.01099, kp = find(xf(w) >= 0.0110, 1); if ~isempty(kp), p11 = 1e3*(r.t(w(kp)) - tc); end, end
        NS(k,:) = [rmin, 1e3*(r.t(w(kw)) - tc), 1e3*xf(w(kw)), p11, rms(res)];
        R{q}.am = am;  R{q}.acur{j} = acur;
    end
end
fprintf(' run  | step [mm]     | most negative r [m/s^2] | at [ms] | x there [mm] | passes 11.0 mm at [ms]\n');
for k = 1:size(ST,1)
    fprintf(' %-4s | %4.1f -> %4.1f | %+5.2f                   | %3.0f     | %5.2f        | %s\n', R{ST(k,1)}.name, ST(k,2:3), ...
            NS(k,1:3), num2str(NS(k,4), '%.0f'));
end
% Control group (changed from s13 AFTER the first run of this script, whose output already showed every r value,
% so this is not a blind choice): the UP-steps, where the ball moves toward the magnet, away from 11 mm.
% s13's control (steps peaking below 10.8 mm) is empty today because every step starts or ends near 11 mm.
% Cross-check below with the stricter 13-Nov threshold (1.5 x -0.97 m/s^2) and strides h = 3, 10.
far = up;  reach = dn;
fprintf(' control = up-steps (%d): worst r %+.2f m/s^2 (13-Nov control worst -0.97) | down-steps (%d): r %s\n', ...
        nnz(far), min(NS(far,1)), nnz(reach), mat2str(round(NS(reach,1)', 2)));
c = median(NS(far,5)) < 0.45;
chkp(c, sprintf('control: on the up-steps the current explains the motion (rms r median %.2f m/s^2)', median(NS(far,5))));
nP = nP + c;  nF = nF + ~c;
% The decision table (s13 section 6): a spike at x ~ 11.0 mm whatever the time after the step = position-tied;
% a spike at ~35 ms whatever x = timing.
sp = reach & NS(:,1) < 1.5*min(NS(far,1));     % "spike" = more negative than 1.5x the worst control step
fprintf(' spikes (r < 1.5x worst up-step = %.2f): %d of %d down-steps\n', 1.5*min(NS(far,1)), nnz(sp), nnz(reach));
for k = find(reach)'
    fprintf('   %s %4.1f -> %4.1f: r %+5.2f at %3.0f ms, x %5.2f mm; passes 11.0 at %s ms (spike %s ms later) -> spike %s\n', ...
            R{ST(k,1)}.name, ST(k,2:3), NS(k,1:3), num2str(NS(k,4), '%.0f'), num2str(NS(k,2) - NS(k,4), '%.0f'), ...
            subsref({'NO','YES'}, substruct('{}', {1 + sp(k)})));
end
sp13 = reach & NS(:,1) < 1.5*(-0.97);
fprintf(' with the 13-Nov threshold (%.2f): %d spikes (%s)\n', 1.5*(-0.97), nnz(sp13), mat2str(round(NS(sp13,1)', 2)));
tS = NS(sp,2);  xS = NS(sp,3);  lagS = NS(sp,2) - NS(sp,4);
fprintf(' over the spikes: time after the step %.0f-%.0f ms (spread %.0f) | x %.2f-%.2f mm (spread %.2f) | after passing 11.0: %.0f-%.0f ms\n', ...
        min(tS), max(tS), max(tS) - min(tS), min(xS), max(xS), max(xS) - min(xS), min(lagS), max(lagS));
c = nnz(sp) >= 4 && max(tS) - min(tS) >= 20 && max(xS) - min(xS) <= 0.12;
chkp(c, ['POSITION-TIED: the spike time after the step varies by >= 20 ms while its position stays within 0.12 mm ' ...
         '(a fixed-timing cause would keep the time and move the position)']);  nP = nP + c;  nF = nF + ~c;
% robustness: repeat with strides h = 3 and 10 (as s13)
for hh = [3 10]
    trih = [1:hh, hh-1:-1:1]'/hh^2;  tq = [];  xq = [];  rq = [];  ru = [];  k = 0;
    for q = 1:2, r = R{q};
        am = nan(size(r.x));  kk = hh+1:numel(r.x)-hh;  am(kk) = (r.x(kk+hh) - 2*r.x(kk) + r.x(kk-hh))/(hh*T0)^2;
        xf = conv(r.x, trih, 'same');  itf = conv(r.i, trih, 'same');
        for j = 1:numel(r.kc)
            k = k + 1;  tc = r.t(r.kc(j));  pre = r.t > tc - 0.5 & r.t < tc;
            i0z = mean(r.i(pre)) - sqrt(r.m*g/r.c)*exp(mean(r.x(pre))/(2*lam));
            w = find(r.t >= tc & r.t <= tc + 0.15);
            [rm, kw] = min(am(w) - (g - r.c*max(itf(w) - i0z, 0).^2.*exp(-xf(w)/lam)/r.m));
            if dn(k), tq(end+1) = 1e3*(r.t(w(kw)) - tc); xq(end+1) = 1e3*xf(w(kw)); rq(end+1) = rm; else, ru(end+1) = rm; end %#ok<SAGROW>
        end
    end
    spq = rq < 1.5*min(ru);
    fprintf('   h = %2d: down-step r %s (threshold %.2f) | spike times %s ms | x %s mm\n', hh, mat2str(round(rq, 2)), ...
            1.5*min(ru), mat2str(round(tq(spq))), mat2str(round(xq(spq), 2)));
    c = nnz(spq) >= 4 && max(tq(spq)) - min(tq(spq)) >= 20 && max(xq(spq)) - min(xq(spq)) <= 0.15;
    chkp(c, sprintf('h = %d: same conclusion (time spread >= 20 ms, position spread <= 0.15 mm)', hh));  nP = nP + c;  nF = nF + ~c;
end

%% ---- 3. figure ---------------------------------------------------------------
fg = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1400 800]);
tl = tiledlayout(fg, 2, 2, 'TileSpacing', 'compact');
title(tl, 'Lab 2026-11-16, item 3a: small steps (my\_cascade\_steps\_rt)', 'Color', 'k');
for q = 1:2, r = R{q};
    ax = nexttile(tl);  hold(ax, 'on');
    on = r.t >= r.t(r.kOn) - 1;
    plot(ax, r.t(on), 1e3*r.x(on), 'Color', [0 0.45 0.9]);  plot(ax, r.t(on), 1e3*r.xr(on), 'Color', [0.9 0.2 0.1], 'LineWidth', 1.5);
    yline(ax, 1e3*r.xRest, '--', 'stand', 'Color', [0.2 0.6 0.2]);  set(ax, 'YDir', 'reverse');
    ylim(ax, [8.5 12.2]);  xlabel(ax, 't [s]');  ylabel(ax, 'gap x [mm] (magnet up)');
    title(ax, sprintf('%s: x and x_{ref}', r.name), 'Color', 'k');  legend(ax, 'x', 'x_{ref}', 'Location', 'northeast');
end
ax = nexttile(tl);  hold(ax, 'on');
cols = lines(6);
for k = 1:size(ST,1)
    mk = 'o';  if ST(k,1) == 2, mk = 's'; end
    plot(ax, ST(k,5), ST(k,4), mk, 'MarkerSize', 9, 'MarkerFaceColor', cols(mod(k-1,6)+1,:), 'Color', 'k');
    text(ax, ST(k,5) + 0.01, ST(k,4), sprintf('%.1f\\rightarrow%.1f', ST(k,2:3)), 'FontSize', 8);
end
plot(ax, [0 0.8], [0 0.8], 'k:');  plot(ax, [0 0.8], [0 0.4], 'k--');
xlabel(ax, 'model overshoot [mm]');  ylabel(ax, 'lab overshoot [mm]');
title(ax, 'Overshoot, lab vs model (circles 39 g, squares 42 g; dotted 1:1, dashed 1:2)', 'Color', 'k');
ax = nexttile(tl);  hold(ax, 'on');
for k = find(dn)'
    mk = 'o';  if ST(k,1) == 2, mk = 's'; end
    plot(ax, NS(k,2), NS(k,1), mk, 'MarkerSize', 9, 'MarkerFaceColor', [0.9 0.2 0.1]*sp(k) + [0.6 0.6 0.6]*~sp(k), 'Color', 'k');
    text(ax, NS(k,2) + 2, NS(k,1), sprintf('%.1f\\rightarrow%.1f, x %.2f', ST(k,2:3), NS(k,3)), 'FontSize', 8);
end
yline(ax, 1.5*min(NS(up,1)), '--', 'spike threshold', 'Color', 'k', 'LabelVerticalAlignment', 'bottom', ...
      'LabelHorizontalAlignment', 'center');
xlabel(ax, 'time of the most negative r after the step [ms]');  ylabel(ax, 'most negative r [m/s^2]');
title(ax, 'Down-steps: braking spike, when and where (red = spike)', 'Color', 'k');
exportgraphics(fg, fullfile(P.dir.figs, 'p12_3a_steps.png'), 'BackgroundColor', 'w');
close(fg);
fprintf('\nFigure: figs/p12_3a_steps.png\n');
fprintf('==== s16 summary: %d PASS / %d FAIL ====\n', nP, nF);

%% ======================= local functions ================================
function os = sim_steps(C, L, M, ST, d, g, m39, m42)
% as s13: simulate each step from hover at the old level (s07 plant, delay d)
os = zeros(size(ST, 1), 1);
for k = 1:size(ST, 1)
    b = ST(k,1);  a = ST(k,2)*1e-3;  z = ST(k,3)*1e-3;
    pq = struct('m', m39*(b==1) + m42*(b==2), 'lam', M.lam, 'c', M.cB(b), 'ioff', M.ioff, ...
                'tau', L.tau, 'ka', M.kaP, 'ci', M.ioff);
    ieq = pq.ioff + sqrt(pq.m*g/pq.c)*exp(a/(2*pq.lam));
    o = struct('x0', a, 'i0s', ieq, 'z0', min(max((ieq - C.i0)/C.Ki, -C.zLim), C.zLim), 'xStand', 0.0119, ...
               'd', d, 'uIC', (ieq - pq.ci)/pq.ka);
    s = maglev_cascade_sim(C, L, pq, @(t) a + (z - a)*(t >= 1.0), 2.0, o);
    os(k) = overshoot(s.t, s.x, a, z);
end
end

function os = overshoot(t, x, a, z)
d = z - a;  xs = movmean(x, 11);
k50 = find(sign(d)*(xs - (a + d/2)) > 0, 1);
if isempty(k50), os = NaN; return; end
os = max(1e3*max(sign(d)*(xs(k50:end) - z)), 0);
end
