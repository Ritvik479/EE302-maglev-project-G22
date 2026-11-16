% s12_delay_estimate.m   [STANDALONE]
% =========================================================================
% PURPOSE   Estimate the loop delay beyond the normal one-sample ZOH step from data we already have.
%           Until now it was carried as "0 or +1 sample (not observable)". It matters: with +1 sample the
%           robust-stability test fails and the worst Ms is 5.0 (s11).
% DEFINITION The model (s05-s11): u[k] is computed from the samples at k and held over [k, k+1), so the
%           current sampled at k+1 already responds to u[k]. An EXTRA delay of d samples (d may be
%           fractional) holds u[k] over [k+d, k+1+d) instead. d = 0 is the model used so far; d = 1 is the
%           "+1 sample" case of s09/s11.
% DATA      run 3 of 2026-11-13 (cascade inner loop alone, ball on the stand, i_test 0.3 -> 0.5 A, 17.6 s,
%           with 4.1 s of coil-off record before switch-on) and the open-loop coil steps of 2026-11-12.
% METHODS   0. checks: every 3 ms sample is there; u and i are logged in the same sample.
%           A. output-error fit u -> i (first-order coil, ZOH, fractional input delay d), profile over d.
%           B. noise shaping: with the inner loop closed, measured current noise = S x sensor noise, so
%              PSD(loop on) / PSD(coil off) = |S|^2, whose shape above 20 Hz depends strongly on d.
%           C. the same output-error fit on the open-loop coil steps (weakly discriminating: in open loop d
%              and tau trade off, and the 0 -> 0.2 step starts where the coil gain is nonlinear).
% CRITERIA  (set before the run) a value of d is REJECTED by method A if its fit error exceeds the best one
%           by more than the 95 % likelihood-ratio limit (chi-square 3.84), with the sample count reduced
%           for the residual autocorrelation.
% OUTPUTS   console PASS/FAIL, data/delay_estimate.mat, figs/p9_delay.png
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
chk = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
T = 0.003;  Kc = 2.05;  kaC = 2.44;
r = read_scope_fig(fullfile(P.dir.data, 'lab_2026-11-13', 'runs', 'cascade_run3.fig'));
i = r.y(:,3);  u = r.y(:,4);  N = numel(i);
on = find(u > 0.01);  kOn = on(1);  kOff = on(end);

%% ---- 0. data checks -----------------------------------------------------------------
fprintf('==== 0. Data checks (run 3) ====\n');
dt = unique(round(diff(r.t)*1e6)/1e6);
fprintf('  sample spacing %s s, %d samples, coil on %.1f s, coil-off record before switch-on %.1f s\n', ...
        mat2str(dt), N, (kOff - kOn)*T, (kOn - 1)*T);
chk(isequal(dt, T), 'every 3 ms sample is in the record (no decimation by the scope)');
% i_test: 0.3 A, then 0.5 A; the step is where the command jumps after settling
itRec = (u + Kc*i)/(1/kaC + Kc);
kStep = kOn + 100 + find(abs(diff(movmedian(itRec(kOn+100:kOff), 31))) > 0.05, 1);
iTest = 0.3*ones(N, 1);  iTest(kStep:end) = 0.5;
fprintf('  i_test 0.3 A from sample %d, 0.5 A from sample %d\n', kOn, kStep);
% logging alignment: in steady segments u[k] = i_test(1/kaC + Kc) - Kc i[k+l] holds only for l = 0
st = [kOn+200:kStep-20, kStep+200:kOff-20]';
R2 = zeros(1, 3);
for l = -1:1
    A = [ones(numel(st), 1), (st >= kStep), i(st + l)];  c = A \ u(st);  res = u(st) - A*c;
    R2(l + 2) = 1 - sum(res.^2)/sum((u(st) - mean(u(st))).^2);
    fprintf('  u[k] vs i[k%+d]: slope %+.3f, R^2 %.4f\n', l, c(3), R2(l + 2));
end
chk(R2(2) > 0.99 && R2(2) > max(R2([1 3])) + 0.1, ['u and i are logged in the same sample: the inner-loop law ' ...
    'holds exactly at lag 0 only (so a delay seen between logged u and logged i is a real loop delay)']);
n0 = i(1:kOn-5) - mean(i(1:kOn-5));
ac0 = autocorr1(n0, 3);
fprintf('  coil-off current noise: std %.4f A, autocorrelation at lags 1..3: %s\n', std(n0), mat2str(round(ac0, 3)));

%% ---- A. output-error fit on run 3 ---------------------------------------------------------
fprintf('\n==== A. Output-error fit u -> i, run 3 (inner loop closed) ====\n');
dg = 0:0.05:1.5;
seg = (kOn - 20:kOff)';
[sseA, parA] = profile_d(u(seg), i(seg), dg, T);
[sMinA, kA] = min(sseA);  dA = dg(kA);
eBest = oe_res(parA(kA, :), u(seg), i(seg), dA, T);
rho = autocorr1(eBest, 1);  nEff = numel(eBest)*(1 - rho)/(1 + rho);
lr = nEff*log(sseA/sMinA);                               % likelihood ratio vs the best d
okA = dg(lr <= 3.84);
fprintf('  best d = %.2f sample (tau %.1f ms, ka %.2f); residual rms %.4f A, lag-1 autocorrelation %.2f -> N_eff %.0f\n', ...
        dA, 1e3*parA(kA,1), parA(kA,2), rms(eBest), rho, nEff);
fprintf('  95 %% interval for d: %.2f .. %.2f sample\n', min(okA), max(okA));
for dd = [0 0.5 1 1.5], k = find(abs(dg - dd) < 1e-9);
    fprintf('    d = %.1f: fit error %.4f (+%.1f %%), likelihood ratio %.0f -> %s\n', dd, sseA(k), 100*(sseA(k)/sMinA - 1), ...
            lr(k), subsref({'rejected', 'not rejected'}, substruct('{}', {1 + (lr(k) <= 3.84)})));
end
% A2 (added on review): the switch-on starts from u = 0, where the coil gain is nonlinear. Refit WITHOUT the
% first 0.6 s after switch-on, so that the estimate cannot come from that transient.
segA2 = (kOn + 200:kOff)';
[sseA2, parA2] = profile_d(u(segA2), i(segA2), dg, T);
[sMinA2, kA2] = min(sseA2);
fprintf('  without the switch-on (from 0.6 s after it): best d = %.2f (tau %.1f ms, ka %.2f); fit error d = 0 / 1: +%.1f / +%.1f %%\n', ...
        dg(kA2), 1e3*parA2(kA2,1), parA2(kA2,2), 100*(sseA2(1)/sMinA2 - 1), 100*(sseA2(dg == 1)/sMinA2 - 1));
c = abs(dg(kA2) - dA) <= 0.15;
chk(c, sprintf('method A does not depend on the nonlinear switch-on (best d %.2f with it, %.2f without)', dA, dg(kA2)));

%% ---- B. noise shaping (spectrum) -------------------------------------------------------
fprintf('\n==== B. Noise shaping: PSD(inner loop on) / PSD(coil off) vs |S|^2 ====\n');
[P0, fq, n0w] = welch(n0, 128, T);
P1 = 0;  nW = 0;
for s = {kOn+200:kStep-20, kStep+200:kOff-20}
    x = i(s{1});  [Ps, ~, nw] = welch(x - mean(x), 128, T);  P1 = P1 + Ps*nw;  nW = nW + nw;
end
P1 = P1/nW;  Rm = P1./P0;
sel = fq >= 8;  z = exp(1j*2*pi*fq*T);
S2 = @(tau, ka, d) abs(1./(1 + Kc*coil_z(z, tau, ka, d, T))).^2;
gB = [];  dgB = 0:0.02:1.5;
for tau = [0.020 0.027 0.035], for ka = [2.2 2.44 2.7]
    cst = arrayfun(@(d) sum(log(Rm(sel)./pick(S2(tau, ka, d), sel)).^2), dgB);
    [cm, k] = min(cst);  gB(end+1, :) = [tau ka dgB(k) cm]; %#ok<AGROW>
end, end
[~, kb] = min(gB(:,4));
fprintf('  windows: coil off %d, loop on %d (the coil-off reference is the noisier of the two)\n', n0w, nW);
fprintf('  best d per (tau, ka) of the uncertainty set: %.2f .. %.2f sample; overall best d %.2f (tau %.0f ms, ka %.2f)\n', ...
        min(gB(:,3)), max(gB(:,3)), gB(kb,3), 1e3*gB(kb,1), gB(kb,2));
fb = [10 20 30 40 50 65 80 100 130 160];
fprintf('  f [Hz]       %s\n', sprintf('%6.0f', fb));
fprintf('  measured     %s\n', sprintf('%6.2f', arrayfun(@(f) band(Rm, fq, f), fb)));
for dd = [0 gB(kb,3) 1]
    fprintf('  model d %.2f %s\n', dd, sprintf('%6.2f', arrayfun(@(f) band(S2(0.027, 2.44, dd), fq, f), fb)));
end
c0 = arrayfun(@(d) sum(log(Rm(sel)./pick(S2(gB(kb,1), gB(kb,2), d), sel)).^2), [0 1]);
fprintf('  spectral misfit (log^2 sum, f >= 8 Hz): d = 0: %.1f, d = %.2f: %.1f, d = 1: %.1f\n', c0(1), gB(kb,3), gB(kb,4), c0(2));

%% ---- C. open-loop coil steps (2026-11-12) ---------------------------------------------------
fprintf('\n==== C. Output-error fit, open-loop coil steps (my_driver, 2026-11-12) ====\n');
r2 = read_scope_fig(fullfile(P.dir.data, 'lab_2026-11-12', 'runs', 'coil_steps_0p2_0p3_0p4.fig'));
i2 = r2.y(:,3);  u2 = r2.y(:,4);  on2 = find(u2 > 0.01);
seg2 = (on2(1) - 20:min(on2(end) + 200, numel(u2)))';
[sseC, parC] = profile_d(u2(seg2), i2(seg2), dg, T);
[sMinC, kC] = min(sseC);
eC = oe_res(parC(kC, :), u2(seg2), i2(seg2), dg(kC), T);
rhoC = autocorr1(eC, 1);  nEffC = numel(eC)*(1 - rhoC)/(1 + rhoC);  lrC = nEffC*log(sseC/sMinC);
okC = dg(lrC <= 3.84);
fprintf('  best d = %.2f (tau %.1f ms, ka %.2f); 95 %% interval %.2f .. %.2f; fit error d = 0 / 0.5 / 1: +%.1f / +%.1f / +%.1f %%\n', ...
        dg(kC), 1e3*parC(kC,1), parC(kC,2), min(okC), max(okC), 100*(sseC(dg == 0)/sMinC - 1), ...
        100*(sseC(abs(dg - 0.5) < 1e-9)/sMinC - 1), 100*(sseC(dg == 1)/sMinC - 1));
% C2 (added after the first run, which found the coil steps alone favouring d = 0 with a tight interval):
% the same fit WITHOUT the 0 -> 0.2 step, which starts where the coil gain is nonlinear (1.9 instead of 2.4)
kj = find(abs(diff(u2)) > 0.05) + 1;
seg2b = (kj(1) + 130:numel(u2))';                        % from 0.39 s after the first step (coil settled at 0.2)
[sseC2, parC2] = profile_d(u2(seg2b), i2(seg2b), dg, T);
[sMinC2, kC2] = min(sseC2);
fprintf(['  without the 0 -> 0.2 step (u >= 0.2 only): best d = %.2f (tau %.1f ms); fit error d = 0 / 0.5 / 1: ' ...
         '+%.2f / +%.2f / +%.2f %%\n'], dg(kC2), 1e3*parC2(kC2,1), 100*(sseC2(1)/sMinC2 - 1), ...
        100*(sseC2(abs(dg - 0.5) < 1e-9)/sMinC2 - 1), 100*(sseC2(dg == 1)/sMinC2 - 1));
fprintf(['  -> the coil-step preference for d = 0 comes from the nonlinear first step. Away from it the open-loop\n' ...
         '     record is nearly flat in d (d and tau trade off: best tau %.1f -> %.1f ms as d goes 0 -> 1): it neither\n' ...
         '     supports nor contradicts the run-3 estimate.\n'], 1e3*parC2(1,1), 1e3*parC2(dg == 1, 1));
c = max(sseC2(dg <= 0.75))/sMinC2 - 1 < 0.005;
chk(c, 'coil steps with u >= 0.2: every d from 0 to 0.75 fits within 0.5 % of the best (no contradiction with run 3)');

%% ---- verdict ----------------------------------------------------------------------------
fprintf('\n==== Verdict ====\n');
dHat = dA;  dHi = max([max(okA), gB(kb,3)]);
c = all(lr(dg >= 1) > 3.84) && c0(2) > 2*gB(kb,4);
chk(c, 'a FULL extra sample (d = 1) is rejected by both run-3 methods');
c = lr(1) > 3.84 && c0(1) > 2*gB(kb,4);
chk(c, 'NO extra delay (d = 0) is also rejected by both run-3 methods: there is a fractional extra lag');
c = abs(dA - gB(kb,3)) <= 0.2;
chk(c, sprintf('the two run-3 methods agree within 0.2 sample (A: %.2f, B: %.2f)', dA, gB(kb,3)));
dLo = min([gB(:,3); min(okA)]);  dHi = max([gB(:,3); max(okA)]);
fprintf(['  ESTIMATE: extra loop delay d = %.2f sample (%.1f ms), method A. Method A''s own 95 %% interval (%.2f .. %.2f)\n' ...
         '  assumes the first-order coil model is exact and is too narrow; the spread over methods and over the tau/ka\n' ...
         '  uncertainty is d = %.2f .. %.2f sample (%.1f .. %.1f ms): use THIS range. Cause not separable from these data:\n' ...
         '  computation time inside the 3 ms step, PWM, or a filter in the current-sensing path look the same to the loop.\n'], ...
        dHat, 1e3*dHat*T, min(okA), max(okA), dLo, dHi, 1e3*dLo*T, 1e3*dHi*T);

% context: nominal margins (39 g, 10 mm) with this delay (loop broken at u, as s11)
LM = load(fullfile(P.dir.data, 'linear_model.mat'), 'LM');  LM = LM.LM;
fprintf('  nominal loop (39 g, 10 mm) margins vs extra delay:\n');
MG = [];
for dd = unique([0 dLo dHat dHi 1])
    M = nom_margins(LM, dd, T, kaC);  MG(end+1, :) = [dd M]; %#ok<AGROW>
    fprintf('    d = %.2f: Ms %.2f, gain range [%.3f, %.2f], PM %.1f deg, DM %.1f ms\n', dd, M);
end

%% ---- figure ---------------------------------------------------------------------------------
col = P.plot.colors;
f1 = figure('Position', [80 80 1150 820]);
tiledlayout(2, 2, 'TileSpacing', 'compact');
nexttile; hold on; grid on;
plot(dg, 100*(sseA/sMinA - 1), 'o-', 'Color', col(1,:));  plot(dg, 100*(sseA2/sMinA2 - 1), '--', 'Color', col(1,:));
plot(dg, 100*(sseC/sMinC - 1), 's-', 'Color', col(2,:));  plot(dg, 100*(sseC2/sMinC2 - 1), '--', 'Color', col(2,:));
xline(dA, ':', 'Color', col(1,:));
xlabel('extra delay d [samples of 3 ms]');  ylabel('fit error above its minimum [%]');
legend({'run 3 (inner loop closed)', 'run 3 without the switch-on', 'coil steps (open loop)', ...
        'coil steps, u \geq 0.2 only'}, 'Location', 'north');
title('A/C: output-error fit u \rightarrow i vs extra delay', 'Color', 'k');
nexttile; hold on; grid on;
semilogy(fq(2:end), Rm(2:end), 'k.-', 'MarkerSize', 10);
for q = 1:3
    dd = [0 gB(kb,3) 1];  plot(fq(2:end), pick(S2(gB(kb,1), gB(kb,2), dd(q)), 2:numel(fq)), '-', 'Color', col(q,:));
end
set(gca, 'YScale', 'log');  xlim([0 167]);  xlabel('frequency [Hz]');  ylabel('PSD on / PSD off  (= |S|^2)');
legend({'measured', 'd = 0', sprintf('d = %.2f', gB(kb,3)), 'd = 1'}, 'Location', 'northwest');
title(sprintf('B: noise shaping by the inner loop (\\tau %.0f ms, k_a %.2f)', 1e3*gB(kb,1), gB(kb,2)), 'Color', 'k');
nexttile([1 2]); hold on; grid on;
% i_test step 0.3 -> 0.5 A (linear region). Each model starts from the measured mean level just before the
% step and is driven by the logged command (fitted parameters of method A2 for that d).
k0 = kStep - 10;  w = k0:kStep + 30;  tt = (w - kStep)*T*1e3;
plot(tt, i(w), 'ko-', 'MarkerFaceColor', 'k', 'MarkerSize', 4);
dd = [0 dg(kA2) 1];
for q = 1:3
    k = find(abs(dg - dd(q)) < 1e-9);
    xs = oe_sim(parA2(k, :), u, dd(q), T, k0, mean(i(kStep-40:kStep-10)), w(end));
    plot(tt, xs, '-', 'Color', col(q,:));
end
stairs(tt, u(w), ':', 'Color', [0.4 0.4 0.4]);
xlabel('time after the i_{test} step 0.3 \rightarrow 0.5 A [ms]');  ylabel('current [A]  /  command u');
legend({'measured i', 'model d = 0', sprintf('model d = %.2f', dd(2)), 'model d = 1', 'command u'}, 'Location', 'southeast');
title('Step 0.3 \rightarrow 0.5 A of run 3: models started from the measured level, driven by the logged command', 'Color', 'k');
exportgraphics(f1, fullfile(P.dir.figs, 'p9_delay.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

DE = struct('dHat', dHat, 'range', [dLo dHi], 'ciA_modelExact', [min(okA) max(okA)], 'sseC2', sseC2, 'dSpectral', gB, 'dCoil', dg(kC), 'ciCoil', [min(okC) max(okC)], ...
            'sseA', sseA, 'sseA2', sseA2, 'sseC', sseC, 'dGrid', dg, 'margins', MG, 'marginCols', {{'d', 'Ms', 'kLow', 'kHigh', 'PM', 'DM_ms'}});
save(fullfile(P.dir.data, 'delay_estimate.mat'), 'DE');
fprintf('\nSaved data/delay_estimate.mat, figs/p9_delay.png\n');

%% ======================= local functions ================================
function [sse, par] = profile_d(u, i, dg, T)
% best (tau, ka, offset) for every extra delay d on the grid
sse = zeros(size(dg));  par = zeros(numel(dg), 3);  p0 = [0.027 2.44 0];
opt = optimset('MaxFunEvals', 6000, 'MaxIter', 6000, 'TolX', 1e-7, 'TolFun', 1e-10);
for k = 1:numel(dg)
    p = fminsearch(@(p) sum(oe_res(p, u, i, dg(k), T).^2), p0, opt);
    par(k, :) = p;  sse(k) = sum(oe_res(p, u, i, dg(k), T).^2);
end
end

function [e, xs] = oe_res(p, u, i, d, T)
% first-order coil i' = (ka u(t - d T) - i)/tau + offset, exact ZOH discretization with fractional delay
% (modified z-transform): i[k+1] = a i[k] + b1 u[k-m] + b2 u[k-m-1] + (1-a) off,  m = floor(d)
tau = max(p(1), 1e-4);  a = exp(-T/tau);  m = floor(d);  f = d - m;
b1 = p(2)*(1 - a^(1 - f));  b2 = p(2)*(a^(1 - f) - a);
Nn = numel(u);  ub = [zeros(m + 1, 1); u(:)];  xs = zeros(Nn, 1);  xs(1) = i(1);
for k = 1:Nn - 1
    xs(k + 1) = a*xs(k) + b1*ub(k + 1) + b2*ub(k) + (1 - a)*p(3);
end
e = i(m + 3:end) - xs(m + 3:end);                         % skip the start-up samples of the delay line
end

function xs = oe_sim(p, u, d, T, k0, x0, kEnd)
% the same coil model, started at sample k0 with value x0, driven by the full logged command u
a = exp(-T/max(p(1), 1e-4));  m = floor(d);  f = d - m;
b1 = p(2)*(1 - a^(1 - f));  b2 = p(2)*(a^(1 - f) - a);
xs = zeros(kEnd - k0 + 1, 1);  xs(1) = x0;
for k = k0:kEnd - 1
    xs(k - k0 + 2) = a*xs(k - k0 + 1) + b1*u(k - m) + b2*u(k - m - 1) + (1 - a)*p(3);
end
end

function L = coil_z(z, tau, ka, d, T)
m = floor(d);  f = d - m;  a = exp(-T/tau);
L = (ka*(1 - a^(1 - f)) + ka*(a^(1 - f) - a)./z)./(z - a).*z.^(-m);
end

function M = nom_margins(LM, d, T, kaC)
% loop broken at u, nominal 39 g at 10 mm, controller as deployed; extra delay d (fractional) on u
Kp = 151.2;  Kd = 2.6;  Ki = 734;  Kc = 2.05;
Ac = [0 1 0; LM.nom.a21 0 -LM.nom.b; 0 0 -1/LM.tau];  Bc = [0; 0; LM.ka/LM.tau];
G = ss(Ac, Bc, eye(3), 0);  G.InputDelay = d*T;
Gd = absorbDelay(c2d(G, T, 'zoh'));
z = tf('z', T);  Cx = Kp + Kd*(1 - z^-1)/T + Ki*T*z^-1/(1 - z^-1);
L = -minreal(ss([(1/kaC + Kc)*Cx, -Kc])*Gd([1 3], :), [], false);
S = allmargin(L);  gm = S.GainMargin;
w = logspace(log10(2*pi*0.05), log10(0.999*pi/T), 3000);
Ms = max(abs(1./(1 + squeeze(freqresp(L, w)))));
if ~isstable(feedback(L, 1)), Ms = Inf; end
M = [Ms, max([gm(gm < 1), 0]), min([gm(gm > 1), Inf]), min(S.PhaseMargin), 1e3*min(S.DelayMargin)*T];
end

function r = autocorr1(x, nl)
x = x(:) - mean(x);  r = arrayfun(@(l) sum(x(1:end-l).*x(1+l:end))/sum(x.^2), 1:nl);
end

function [Pw, f, nw] = welch(x, L, T)
% Welch PSD, Hann window, 50 % overlap (Signal Processing Toolbox not installed)
x = x(:);  w = 0.5 - 0.5*cos(2*pi*(0:L-1)'/L);  st = 1:L/2:numel(x) - L + 1;  Pw = zeros(L/2 + 1, 1);
for s = st, X = fft(w.*x(s:s + L - 1));  Pw = Pw + abs(X(1:L/2 + 1)).^2; end
nw = numel(st);  Pw = Pw/nw/sum(w.^2)*T;  f = (0:L/2)'/(L*T);
end

function v = band(R, fq, f)
[~, j] = min(abs(fq - f));  v = mean(R(max(j - 1, 1):min(j + 1, end)));
end

function y = pick(x, s)
y = x(s);
end
