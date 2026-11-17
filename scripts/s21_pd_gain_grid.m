% s21_pd_gain_grid.m   [STANDALONE]
% =========================================================================
% PURPOSE   FIXPLAN step 10b (AUDIT.md 2.15). Why a cascade and not a position-only PD? The report must not
%           say "the lab PD was predicted to oscillate at 7-9 Hz" (the linear model does not predict that).
%           The defensible statement is: a position-only PD acting directly on the coil command is at best
%           FRAGILE on this rig, and the lab PD sits on the stability boundary. This script gives the evidence:
%             1. the lab PD (Kp 35/40/45, Kr 450) on the linear model: stable or not, unstable mode frequency
%             2. full gain grid Kp x Kr: fraction stable and best Ms per (tau, d) corner
%                - audit corners (tau 22.5/27/29 ms, d 0/0.5/1): reproduce AUDIT 2.15 (best Ms 5.7-13, 1-4 % stable)
%                - project corners (tau 20/27/35 ms, d 0.3/0.5/0.6 = the robust set of s11)
%             3. the best ROBUST PD (stable at all 9 project corners, minimum worst-case Ms) vs the cascade's
%                worst Ms at the same 9 corners (data/robustness.mat, 39 g, 10 mm, nominal lam, c, ka)
% LOOP      deviation variables at 39 g, 10 mm (s10/s11 linear model: lam, c, ka from data/linear_model.mat):
%             x'' = a21 x - b i,   tau i' = ka u(t - d T0) - i,   a21 = g/lam, b = 2 g / i0
%           position-only PD exactly as the lab model my_pd_rt (e = x - x_ref, gains on e and on its first
%           difference, output = coil command u, PWM duty fraction):
%             u_c = Kp e[k] + Kr (e[k] - e[k-1])
%           Loop broken at u (as s11): L = -H, S = 1/(1+L), Ms = max |S| up to Nyquist (166.7 Hz).
%           Exact discretisation with the fractional delay (c2d with InputDelay, absorbDelay), as s11.
% SIGNS     positive Kp, Kr stabilise (ball lower -> more current); section 1 negates them and expects an
%           unstable loop for every gain pair.
% CHECKS    (declared before the run) sign test; fractional-delay loop at d = 1 equals a whole-sample delay
%           loop; audit reproduction ranges; [record] lab PD; [record] robust PD vs cascade.
% OUTPUTS   console PASS/FAIL, figs/p17_pd_gain_grid.png. Writes no .mat file.
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
nP = 0;  nF = 0;
chk = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
D = load(fullfile(P.dir.data, 'linear_model.mat'), 'LM');  LM = D.LM;
R = load(fullfile(P.dir.data, 'robustness.mat'), 'RB');  RB = R.RB;
g = P.g;  T = 0.003;  m39 = 0.039288;  x0 = 0.010;
lam = LM.lam;  c39 = LM.cB(1);  ka = LM.ka;
i0 = sqrt(m39*g*exp(x0/lam)/c39);
pl = struct('a21', g/lam, 'b', 2*g/i0, 'ka', ka);
wg = logspace(log10(2*pi*0.05), log10(0.999*pi/T), 1200);
fprintf('Plant 39 g at 10 mm: lam %.2f mm, c %.2f, ka %.2f A/unit, i0 %.3f A, a21 %.0f 1/s^2 (unstable pole %.2f Hz)\n', ...
        1e3*lam, c39, ka, i0, pl.a21, sqrt(pl.a21)/(2*pi));
KpG = logspace(log10(10), log10(300), 60);  KrG = linspace(0, 4000, 81);

%% ---- 1. loop checks and the lab PD ----------------------------------------------------
fprintf('\n==== 1. Loop checks and the lab PD (Kr 450) ====\n');
ok = true;
for tq = [0.0225 0.027 0.035], for dq = [0 0.5 1]
    for kp = [30 45 100], for kr = [0 450 2000]
        [~, Acl] = pd_loop(pl, tq, dq, T, -kp, -kr);  ok = ok && max(abs(eig(Acl))) >= 1;
    end, end
end, end
c = ok;  chk(c, 'sign test: negated gains give an unstable loop at every tested (tau, d, Kp, Kr)');  nP = nP + c;  nF = nF + ~c;
dev = 0;
for kp = [30 45 100], for kr = [0 450 2000]
    [La, Aa] = pd_loop(pl, 0.027, 1, T, kp, kr);  [Lb, Ab] = pd_loop_int(pl, 0.027, 1, T, kp, kr);
    ea = sort(abs(eig(Aa)));  eb = sort(abs(eig(Ab)));  ea = ea(ea > 1e-9);  eb = eb(eb > 1e-9);
    hd = max(abs(squeeze(freqresp(La, wg(1:50:end))) - squeeze(freqresp(Lb, wg(1:50:end)))));
    dev = max([dev, abs(max(ea) - max(eb)), hd]);
end, end
c = dev < 1e-9;  chk(c, sprintf('fractional-delay loop at d = 1 = explicit one-sample-delay loop (largest difference %.1e)', dev));
nP = nP + c;  nF = nF + ~c;
fprintf('  lab PD on the linear model: max|eig| (unstable-mode frequency if > 1)\n');
fprintf('  tau [ms] d   | Kp 35          | Kp 40          | Kp 45\n');
LAB = [];
for tq = [0.0225 0.027 0.029], for dq = [0 0.5 1]
    row = '';
    for kp = [35 40 45]
        [~, Acl] = pd_loop(pl, tq, dq, T, kp, 450);  ev = eig(Acl);  [rr, j] = max(abs(ev));
        fz = abs(angle(ev(j)))/(2*pi*T);  LAB(end+1, :) = [tq dq kp rr fz]; %#ok<AGROW>
        row = [row, sprintf(' | %.3f %s', rr, ternary(rr >= 1, sprintf('%4.1f Hz', fz), '  stable'))]; %#ok<AGROW>
    end
    fprintf('  %4.1f     %.1f%s\n', 1e3*tq, dq, row);
end, end
u45 = LAB(LAB(:,3) == 45, :);
chk(true, sprintf(['[record] lab PD Kp 45 / Kr 450 (tau 22.5-29 ms, d 0-1): max|eig| %.3f-%.3f, unstable mode %.1f-%.1f Hz ' ...
    '(lab: sustained 7.3-9.3 Hz cycle hitting the stand); Kp 40, d 0: %.3f'], min(u45(:,4)), max(u45(:,4)), ...
    min(u45(u45(:,4) >= 1, 5)), max(u45(u45(:,4) >= 1, 5)), LAB(LAB(:,3) == 40 & LAB(:,2) == 0 & abs(LAB(:,1) - 0.0225) < 1e-9, 4)));
nP = nP + 1;
% (added after the first run) AUDIT 2.15 quotes, for the lab PD: Kp 45 max|eig| 1.004-1.011, Kp 40 d 0 stable 0.995,
% unstable pole 5.2-5.6 Hz. Those are the tau = 27 ms values; check them exactly (same loop model as the audit's).
e27 = @(kp, dd) LAB(LAB(:,3) == kp & abs(LAB(:,2) - dd) < 1e-9 & abs(LAB(:,1) - 0.027) < 1e-9, 4:5);
a = [e27(45, 0); e27(45, 0.5); e27(40, 0)];
c = abs(round(a(1,1), 3) - 1.004) < 1e-9 && abs(round(a(2,1), 3) - 1.011) < 1e-9 && abs(round(a(3,1), 3) - 0.995) < 1e-9 ...
    && min(a(1:2,2)) >= 5.15 && max(a(1:2,2)) <= 5.65;
chk(c, sprintf('lab PD at tau 27 ms = AUDIT 2.15 to 3 decimals (Kp 45: %.3f / %.3f at %.1f / %.1f Hz; Kp 40, d 0: %.3f)', ...
    a(1,1), a(2,1), a(1,2), a(2,2), a(3,1)));  nP = nP + c;  nF = nF + ~c;

%% ---- 2. the gain grid ------------------------------------------------------------------
fprintf('\n==== 2. Gain grid: Kp %.0f-%.0f (%d, log), Kr %.0f-%.0f (%d) ====\n', KpG(1), KpG(end), numel(KpG), KrG(1), KrG(end), numel(KrG));
setA = struct('name', 'audit', 'tau', [0.0225 0.027 0.029], 'd', [0 0.5 1]);
setB = struct('name', 'project', 'tau', [0.020 0.027 0.035], 'd', [0.3 0.5 0.6]);
MS = struct();
for S = [setA setB]
    fprintf('  %s corners:\n', S.name);
    msAll = zeros(numel(KpG), numel(KrG), numel(S.tau)*numel(S.d));  q = 0;  best = [];
    for tq = S.tau, for dq = S.d
        q = q + 1;  M = inf(numel(KpG), numel(KrG));  PD = plant_d(pl, tq, dq, T);
        for a = 1:numel(KpG), for b = 1:numel(KrG)
            [L, Acl] = pd_close(PD, T, KpG(a), KrG(b));
            if max(abs(eig(Acl))) < 1, M(a, b) = max(abs(1./(1 + squeeze(freqresp(L, wg))))); end
        end, end
        msAll(:, :, q) = M;  [mb, k] = min(M(:));  [a, b] = ind2sub(size(M), k);
        best(end+1, :) = [tq dq 100*mean(isfinite(M(:))) mb KpG(a) KrG(b)]; %#ok<AGROW>
        fprintf('    tau %4.1f ms, d %.1f: %4.1f %% stable | best Ms %6.2f at Kp %5.1f, Kr %4.0f\n', 1e3*tq, dq, best(end, 3:6) .* [1 1 1 1]);
    end, end
    MS.(S.name) = struct('ms', msAll, 'best', best);
end
bA = MS.audit.best;
% Declared before the run with the audit's numbers. FIRST RUN: FAIL, best Ms 4.8-12.7 and 1.1-8.8 % stable. The lab-PD
% values above match the audit exactly, so the loop model is the same; the audit's grid script was not kept and its
% grid spacing is unknown (the gap is at d = 0, where this 60 x 81 grid finds lower Ms). Kept as an honest FAIL;
% the report quotes THIS script's numbers.
c = min(bA(:,4)) > 5 && max(bA(:,4)) < 15 && max(bA(:,3)) < 6;
chk(c, sprintf('audit corners reproduce AUDIT 2.15 (best Ms %.1f-%.1f, %.1f-%.1f %% of the grid stable; audit: 5.7-13, 1-4 %%)', ...
    min(bA(:,4)), max(bA(:,4)), min(bA(:,3)), max(bA(:,3))));  nP = nP + c;  nF = nF + ~c;

%% ---- 3. best robust PD vs the cascade ---------------------------------------------------
fprintf('\n==== 3. Best PD stable at ALL 9 project corners vs the cascade ====\n');
wc = max(MS.project.ms, [], 3);                       % worst-case Ms over the 9 corners (Inf if unstable at any)
nRob = nnz(isfinite(wc));
[mR, k] = min(wc(:));  [a, b] = ind2sub(size(wc), k);
% refine around the best grid point (log Kp, Kr), keeping all 9 corners
cost = @(z) pd_worst(pl, setB, T, exp(z(1)), z(2), wg);
if isfinite(mR)
    z = fminsearch(cost, [log(KpG(a)), KrG(b)], optimset('Display', 'off', 'TolX', 1e-3, 'TolFun', 1e-4, 'MaxFunEvals', 400));
    mRf = cost(z);  kpR = exp(z(1));  krR = z(2);
else
    mRf = Inf;  kpR = NaN;  krR = NaN;
end
G = RB.grid;  cc = @(n) strcmp(RB.gridCols, n);
sel = G(:,cc('ball')) == 1 & abs(G(:,cc('x0')) - x0) < 1e-9 & G(:,cc('fl')) == 1 & G(:,cc('fc')) == 1 & ...
      abs(G(:,cc('ka')) - ka) < 1e-9;
casc = G(sel, :);
fprintf('  cascade (s11 grid, 39 g, 10 mm, nominal lam, c, ka): %d corners, Ms %.2f-%.2f\n', size(casc, 1), ...
        min(casc(:,cc('Ms'))), max(casc(:,cc('Ms'))));
fprintf('  PD stable at all 9 corners: %d of %d grid points; best worst-case Ms %.2f (grid, Kp %.1f, Kr %.0f), refined %.2f (Kp %.1f, Kr %.0f)\n', ...
        nRob, numel(wc), mR, KpG(a), KrG(b), mRf, kpR, krR);
c = size(casc, 1) == 9;  chk(c, sprintf('cascade comparison uses the same 9 (tau, d) corners from robustness.mat (found %d)', size(casc,1)));
nP = nP + c;  nF = nF + ~c;
chk(true, sprintf(['[record] best position-only PD over the project corners: worst-case Ms %.2f (%d of %d grid gains ' ...
    'stable at all 9) vs the cascade %.2f at the same corners (%.2f over the full 1458-point set)'], mRf, nRob, numel(wc), ...
    max(casc(:,cc('Ms'))), max(G(:,cc('Ms')))));
nP = nP + 1;

%% ---- 4. figure --------------------------------------------------------------------------
col = P.plot.colors;
fg = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1400 560]);
tl = tiledlayout(fg, 1, 2, 'TileSpacing', 'compact');
title(tl, 'Position-only PD (u = K_p e + K_r \Delta e) on the linear model, 39 g at 10 mm', 'Color', 'k', 'FontWeight', 'bold');
ax = nexttile(tl);  q5 = find(abs(setB.tau - 0.027) < 1e-9)*0 + 5;          % corner 5 = tau 27 ms, d 0.5
Mn = MS.project.ms(:, :, q5);  Mp = log10(Mn);  Mp(~isfinite(Mp)) = NaN;
im = imagesc(ax, KrG, log10(KpG), Mp);  set(im, 'AlphaData', isfinite(Mp));  set(ax, 'YDir', 'normal', 'Color', 'w');
colormap(ax, turbo);  cb = colorbar(ax);  cb.Label.String = 'M_s (peak |S|)';  cb.Color = 'k';  cb.Label.Color = 'k';
tk = [2 5 10 20 50 100];  cb.Ticks = log10(tk);  cb.TickLabels = string(tk);  clim(ax, log10([2 100]));
yt = [20 25 30 40 50 60];  set(ax, 'YTick', log10(yt), 'YTickLabel', string(yt));  xlim(ax, [0 1500]);  ylim(ax, log10([20 65]));
hold(ax, 'on');
plot(ax, [450 450 450], log10([35 40 45]), 'kx', 'MarkerSize', 12, 'LineWidth', 2.5);
[~, k5] = min(Mn(:));  [a5, b5] = ind2sub(size(Mn), k5);
plot(ax, KrG(b5), log10(KpG(a5)), 'kp', 'MarkerSize', 16, 'MarkerFaceColor', 'w', 'LineWidth', 1.5);
text(ax, 60, log10(51), {'lab PD', '(K_p 35/40/45, K_r 450)'}, 'Color', 'k', 'FontSize', 11, 'VerticalAlignment', 'bottom');
text(ax, KrG(b5) + 330, log10(KpG(a5)) - 0.03, sprintf('best M_s %.1f', Mn(a5, b5)), 'Color', 'k', 'FontSize', 11, 'BackgroundColor', 'w');
xlabel(ax, 'K_r  (gain on e[k] - e[k-1])');  ylabel(ax, 'K_p  (gain on e, per metre)');
title(ax, sprintf('\\tau 27 ms, d 0.5: stable for %.1f %% of the grid (white = unstable)', 100*mean(isfinite(Mn(:)))), 'Color', 'k');
ax2 = nexttile(tl);  hold(ax2, 'on');  grid(ax2, 'on');
bB = MS.project.best;  lbl = arrayfun(@(k) sprintf('%.0f/%.1f', 1e3*bB(k,1), bB(k,2)), 1:size(bB,1), 'UniformOutput', false);
cM = zeros(size(bB,1), 1);
for k = 1:size(bB,1)
    r = casc(abs(casc(:,cc('tau')) - bB(k,1)) < 1e-9 & abs(casc(:,cc('d')) - bB(k,2)) < 1e-9, :);  cM(k) = r(1, cc('Ms'));
end
hb = bar(ax2, [bB(:,4), cM], 'grouped');  hb(1).FaceColor = col(2,:);  hb(2).FaceColor = col(1,:);
yline(ax2, 2, 'k--', 'M_s = 2 target', 'LabelHorizontalAlignment', 'left');
set(ax2, 'XTick', 1:size(bB,1), 'XTickLabel', lbl, 'YScale', 'log');  ylim(ax2, [1 30]);
ylabel(ax2, 'M_s');  xlabel(ax2, 'corner: \tau [ms] / extra delay d [samples]');
legend(ax2, {'best PD for this corner alone', 'deployed cascade'}, 'Location', 'northwest');
title(ax2, sprintf('Per corner (\\tau, d). One PD for all 9: worst M_s %.1f; cascade %.2f', mRf, max(cM)), 'Color', 'k');
exportgraphics(fg, fullfile(P.dir.figs, 'p17_pd_gain_grid.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');
close(fg);

fprintf('\nTOTAL: %d PASS, %d FAIL\n', nP, nF);

%% ======================= local functions ================================
function [L, Acl] = pd_loop(p, tau, d, T, Kp, Kr)
% Discrete loop broken at u, fractional input delay d (samples), exact ZOH discretisation (as s11 loop_u).
% Controller state: xp = x[k-1].  u_c = Kp x + Kr (x - xp).  Returns L = -H and Acl (closed loop).
[L, Acl] = pd_close(plant_d(p, tau, d, T), T, Kp, Kr);
end

function PD = plant_d(p, tau, d, T)
Ac = [0 1 0; p.a21 0 -p.b; 0 0 -1/tau];  Bc = [0; 0; p.ka/tau];
Gc = ss(Ac, Bc, eye(3), 0);  Gc.InputDelay = d*T;
Gd = absorbDelay(c2d(Gc, T, 'zoh'));
[PD.A, PD.B, Cp] = ssdata(Gd);  PD.Cx = Cp(1, :);
end

function [L, Acl] = pd_close(PD, T, Kp, Kr)
np = size(PD.A, 1);
A = blkdiag(PD.A, 0);  A(np + 1, 1:np) = PD.Cx;  B = [PD.B; 0];
Cu = [(Kp + Kr)*PD.Cx, -Kr];
L = ss(A, B, -Cu, 0, T);  Acl = A + B*Cu;
end

function [L, Acl] = pd_loop_int(p, tau, nd, T, Kp, Kr)
% Independent reference: whole-sample delay nd built explicitly as a shift register.
Ac = [0 1 0; p.a21 0 -p.b; 0 0 -1/tau];  Bc = [0; 0; p.ka/tau];
sd = c2d(ss(Ac, Bc, eye(3), 0), T, 'zoh');
n = 4 + nd;  A = zeros(n);  B = zeros(n, 1);
A(1:3, 1:3) = sd.A;  A(4, 1) = 1;
if nd == 0, B(1:3) = sd.B; else, B(5) = 1;  for j = 6:n, A(j, j-1) = 1; end;  A(1:3, n) = sd.B; end
Cu = [(Kp + Kr), 0, 0, -Kr, zeros(1, nd)];
L = ss(A, B, -Cu, 0, T);  Acl = A + B*Cu;
end

function w = pd_worst(p, S, T, Kp, Kr, wg)
% worst-case Ms over all (tau, d) corners of S; Inf if any corner is unstable
w = 0;
if Kp <= 0 || Kr < 0, w = Inf; return; end
for tq = S.tau, for dq = S.d
    [L, Acl] = pd_loop(p, tq, dq, T, Kp, Kr);
    if max(abs(eig(Acl))) >= 1, w = Inf; return; end
    w = max(w, max(abs(1./(1 + squeeze(freqresp(L, wg))))));
end, end
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end
