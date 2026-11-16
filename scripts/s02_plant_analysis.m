% s02_plant_analysis.m   (Phase 2)   [STANDALONE]
% =========================================================================
% PURPOSE   Build and inspect the plant models used for design:
%             G2  reduced second order      -K/(s^2 - a21)
%             G3  third order (current lag) -K/((s^2 - a21)(fi*s + 1))
%             + position filter, delay (Pade and exact) and sampled (ZOH) forms.
%           Show the open-loop pole map, Bode and Nyquist of the unstable
%           plant, and prove two facts:
%             (1) P-only control can NOT stabilize it (marginal at best on the
%                 reduced plant, unstable on the third-order plant);
%             (2) PD with Kp > a21/K and Kd > 0 stabilizes the REDUCED plant,
%                 but the same PD fails once filter and delay are added.
% INPUTS    maglev_params, maglev_equilibrium, maglev_plant
% OUTPUTS   data/phase2_results.mat  (P, eq0, M, scenario models, tests)
%           figs/p2_polemap.png, figs/p2_bode.png, figs/p2_nyquist.png
% CHECKED   PASS/FAIL table at the end ("OVERALL: PASS" expected).
%
% SIGNS     x1 = gap, increasing DOWN. e = x1 - x0, u = u0 + C(s)*e, C > 0.
%           Physical plant G has NEGATIVE gain. We design with Gs = -G
%           (positive gain) and L = Gs*C, T = feedback(L, 1). This is the
%           same loop as feedback(G*C, -1) (manual convention).
%           Nyquist/margin theory assumes this L (negative unity feedback).
%           Open-loop RHP poles: P = 1 (the +p pole).
% =========================================================================

%% 0. Bootstrap
root = fileparts(fileparts(mfilename('fullpath')));
if ~isfile(fullfile(root, 'maglev_params.m')), root = pwd; end
addpath(root, fullfile(root, 'scripts'));
maglev_params;
for d = {P.dir.models, P.dir.data, P.dir.figs}
    if ~isfolder(d{1}), mkdir(d{1}); end
end
P.plot.apply();
C  = P.plot.colors;
Ts = P.loop.Ts;

%% 1. Nominal operating point and models
eq0 = maglev_equilibrium(P, P.nom.m, P.nom.x10);
M   = maglev_plant(P, eq0);          % defaults: filter per P.loop, delay = Ts/2 (ZOH)

% Four fidelity scenarios (same operating point)
scen = struct( ...
    'name',    {'S0 third order only', 'S1 + position filter', ...
                'S2 + filter + hold delay Ts/2', 'S3 + filter + hold + 1 extra sample'}, ...
    'filters', {false, true, true, true}, ...
    'tau',     {0, 0, Ts / 2, 1.5 * Ts});
Ms = cell(1, numel(scen));
for k = 1:numel(scen)
    Ms{k} = maglev_plant(P, eq0, struct('filters', scen(k).filters, 'tauDelay', scen(k).tau));
end

% Demo PD gains (NOT a design, see maglev_params)
Kp   = P.demo.KpFactor * eq0.Kp_min;
Kd   = P.demo.Kd;
Cpd  = tf([Kd Kp], 1);

fprintf('\n=== Operating point: %.3f g ball, gap %.1f mm ===\n', 1e3 * eq0.m, 1e3 * eq0.x10);
fprintf('x30 = %.4f A, u0 = %.4f V, a21 = %.2f, p = %.3f rad/s, K = %.4f, Kp_min = %.2f V/m\n', ...
        eq0.x30, eq0.u0, eq0.a21, eq0.p, eq0.K, eq0.Kp_min);
fprintf('Demo PD: Kp = %.2f V/m (%.2f Kp_min), Kd = %.2f V s/m\n', Kp, P.demo.KpFactor, Kd);
fprintf('Default loop delay (hold Ts/2 + extras) = %.1f ms, position filter tau = %.1f ms (filters in path: %d)\n', ...
        1e3 * M.tauDelay, 1e3 * P.loop.tauPos, P.loop.filtersInPath);

%% 2. Tests list: each row = {name, value, expected, tolerance}
tests = cell(0, 4);

% 2a. Model consistency
polesG3  = sort(real(pole(M.G3)));
polesExp = sort([eq0.p; -eq0.p; -1 / P.act.fi]);
tests(end+1, :) = {'G3 poles = {+p, -p, -1/fi} (max rel. error)', ...
                   max(abs(polesG3 - polesExp)) / max(abs(polesExp)), 0, 1e-8};

wtest = [1, eq0.p, 100, 1000];
hss = squeeze(freqresp(M.Gss, wtest));
htf = squeeze(freqresp(M.G3,  wtest));
tests(end+1, :) = {'ss(A,B,C) and tf G3 agree at 4 frequencies (max rel. err.)', ...
                   max(abs(hss - htf) ./ abs(htf)), 0, 1e-8};
tests(end+1, :) = {'dcgain(G2) = +K/a21', dcgain(M.G2), eq0.K / eq0.a21, 1e-9};
ratio = abs(squeeze(freqresp(M.G3, eq0.p))) / abs(squeeze(freqresp(M.G2, eq0.p)));
tests(end+1, :) = {'|G3/G2| at w = p equals 1/sqrt(1+(p*fi)^2)', ratio, 1 / sqrt(1 + (eq0.p * P.act.fi)^2), 1e-9};
tests(end+1, :) = {'unstable pole time scale: ln2/p [s] (briefing: 16.9 ms)', log(2) / eq0.p, 0.0169, 1e-4};

% 2b. Sign test on the PHYSICAL plant: more voltage -> smaller gap
tt = linspace(0, 4e-3, 41);
yy = step(M.G3, tt);
tests(end+1, :) = {'sign: gap DEcreases after a +1 V step (1=yes)', double(yy(end) < 0), 1, 0};

% 2c. Delay, Pade and sampled models
tests(end+1, :) = {'default delay = Ts/2 [s]', M.tauDelay, Ts / 2, 1e-12};
hp = squeeze(freqresp(M.Hpade, 100));
tests(end+1, :) = {'Pade delay is all-pass: |H(j100)| = 1', abs(hp), 1, 1e-9};
tests(end+1, :) = {'Pade phase = -w*tau at w = 100 rad/s [rad]', angle(hp), -100 * M.tauDelay, 1e-3};
tests(end+1, :) = {'p*tau, hold only (Ts/2)', eq0.p * Ts / 2, 0.205, 1e-3};
tests(end+1, :) = {'p*tau, hold + 1 extra sample (briefing: ~0.6)', eq0.p * 1.5 * Ts, 0.6, 0.02};
pz = pole(M.Gs3z);
tests(end+1, :) = {'sampled plant: number of poles outside unit circle', sum(abs(pz) > 1), 1, 0};
tests(end+1, :) = {'sampled plant: unstable pole = exp(p*Ts)', max(abs(pz)), exp(eq0.p * Ts), 1e-6};
tests(end+1, :) = {'sampled plant: has pole exp(-p*Ts) (1=yes)', double(any(abs(pz - exp(-eq0.p * Ts)) < 1e-6)), 1, 0};

% 2d. P-only control cannot stabilize
mult = [0.5 1.5 3 10];
for k = 1:numel(mult)
    Kpk  = mult(k) * eq0.Kp_min;
    pr   = pole(feedback(Kpk * M.Gs2, 1));          % reduced plant
    pred = 0;
    if mult(k) < 1, pred = sqrt(eq0.a21 * (1 - mult(k))); end
    tests(end+1, :) = {sprintf('P-only, reduced, Kp = %.1f Kp_min: max Re(pole) [rad/s]', mult(k)), ...
                       max(real(pr)), pred, 1e-6};
    p3 = pole(feedback(Kpk * M.Gs3, 1));            % third-order plant
    tests(end+1, :) = {sprintf('P-only, third order, Kp = %.1f Kp_min: unstable (1=yes)', mult(k)), ...
                       double(max(real(p3)) > 0), 1, 0};
end

% 2e. PD on the reduced plant: closed loop s^2 + K*Kd*s + (K*Kp - a21)
pdCases = {sprintf('%.2f Kp_min, Kd = %.2f', P.demo.KpFactor, P.demo.Kd), P.demo.KpFactor, P.demo.Kd, 1; ...
           '1.05 Kp_min, Kd = 0.5',   1.05,  0.5, 1; ...
           '0.95 Kp_min, Kd = 0.5',   0.95,  0.5, 0; ...
           '1.5 Kp_min, Kd = -0.5',   1.5,  -0.5, 0; ...
           '1.5 Kp_min, Kd = 0',      1.5,   0,   0};
for k = 1:size(pdCases, 1)
    Kpk = pdCases{k, 2} * eq0.Kp_min;   Kdk = pdCases{k, 3};
    Tp  = pole(feedback(M.Gs2 * tf([Kdk Kpk], 1), 1));
    rp  = roots([1, eq0.K * Kdk, eq0.K * Kpk - eq0.a21]);
    stable = max(real(Tp)) < -1e-6;
    tests(end+1, :) = {sprintf('PD reduced [%s]: stable (1=yes)', pdCases{k, 1}), double(stable), pdCases{k, 4}, 0};
    tests(end+1, :) = {sprintf('PD reduced [%s]: max Re(pole) vs formula', pdCases{k, 1}), ...
                       max(real(Tp)), max(real(rp)), 1e-6};
end

% 2f. Wrong-convention test: PHYSICAL plant with positive gains and negative feedback
pw  = pole(feedback(M.G2 * Cpd, 1));
tests(end+1, :) = {'WRONG sign feedback(G*C,+1) is unstable (1=yes)', double(max(real(pw)) > 0), 1, 0};
pe1 = pole(feedback(M.G2  * Cpd, -1));              % manual convention, physical plant
pe2 = pole(feedback(M.Gs2 * Cpd,  1));              % sign-absorbed plant
tests(end+1, :) = {'feedback(G*C,-1) and feedback(Gs*C,1) same poles (max Re diff)', ...
                   abs(max(real(pe1)) - max(real(pe2))), 0, 1e-6};

% 2g. Same PD as the fidelity ladder grows (cross-check against an independent
%     polynomial calculation; valid for the default P: 39.288 g, 9 mm, demo gains,
%     tauPos = 5 ms, Pade order 3)
mrRed = max(real(pole(feedback(M.Gs2 * Cpd, 1))));
refMr = [-3.438, -2.654, 3.497, 8.992, 16.313];     % reduced, S0, S1, S2, S3
tests(end+1, :) = {'[regression] PD on reduced plant: max Re(pole)', mrRed, refMr(1), 0.01};
mr = zeros(1, numel(scen));
for k = 1:numel(scen)
    mr(k) = max(real(pole(feedback(Ms{k}.Gs3f * Cpd, 1))));
    tests(end+1, :) = {sprintf('[regression] PD on %s: max Re(pole)', scen(k).name), mr(k), refMr(k + 1), 0.01};
end

fprintf('\n=== Same demo PD, growing model fidelity (max Re of closed-loop poles) ===\n');
fprintf('%-42s %10s %14s %8s\n', 'model', 'delay [ms]', 'max Re [rad/s]', 'stable');
if mrRed < 0, st = 'yes'; else, st = 'NO'; end
fprintf('%-42s %10.1f %14.3f %8s\n', 'reduced second order', 0, mrRed, st);
for k = 1:numel(scen)
    if mr(k) < 0, st = 'yes'; else, st = 'NO'; end
    fprintf('%-42s %10.1f %14.3f %8s\n', scen(k).name, 1e3 * scen(k).tau, mr(k), st);
end

%% 3. Figure 1: open-loop pole map
S2   = Ms{3};
pS2  = pole(S2.Gs3f);   zS2 = zero(S2.Gs3f);
pG2  = pole(M.Gs2);     pG3  = pole(M.Gs3);
fig1 = figure('Name', 'Phase 2: pole map', 'Position', [100 100 1200 480]);
tl1  = tiledlayout(fig1, 1, 2, 'TileSpacing', 'compact');
title(tl1, sprintf('Open-loop poles and zeros, %.3f g ball at %.1f mm', 1e3 * eq0.m, 1e3 * eq0.x10), 'Color', 'k');
for v = 1:2
    nexttile; hold on;
    plot(real(pG2), imag(pG2), 'x', 'MarkerSize', 13, 'LineWidth', 2.4, 'Color', C(1, :), 'DisplayName', 'reduced 2nd order, poles');
    plot(real(pG3), imag(pG3), '+', 'MarkerSize', 13, 'LineWidth', 2.4, 'Color', C(2, :), 'DisplayName', 'third order, poles');
    plot(real(pS2), imag(pS2), 'd', 'MarkerSize', 9, 'LineWidth', 1.8, 'Color', C(3, :), 'DisplayName', 'third + filter + Pade delay, poles');
    plot(real(zS2), imag(zS2), 'o', 'MarkerSize', 9, 'LineWidth', 1.8, 'Color', C(4, :), 'DisplayName', 'Pade delay, zeros (right half-plane)');
    xline(0, 'k:', 'HandleVisibility', 'off');   yline(0, 'k:', 'HandleVisibility', 'off');
    grid on; box on;
    xlabel('Real part (rad/s)'); ylabel('Imaginary part (rad/s)');
    if v == 1
        title('Full view', 'Color', 'k');
    else
        xlim([-260 80]); ylim([-120 120]);
        title({'Zoom near the origin', '(+p unstable, -p mirror, -200 filter pole)'}, 'Color', 'k');
    end
    legend('Location', 'best');
end

%% 4. Figure 2: Bode of the sign-absorbed plant -G(s)
w    = P.freq.w;
sysB = {M.Gs2, M.Gs3, Ms{3}.Gs3d, Ms{4}.Gs3d};
lblB = {'reduced 2nd order', 'third order', ...
        sprintf('third + filter + %.0f ms delay', 1e3 * Ms{3}.tauDelay), ...
        sprintf('third + filter + %.0f ms delay', 1e3 * Ms{4}.tauDelay)};
fig2 = figure('Name', 'Phase 2: Bode', 'Position', [120 120 900 750]);
tl2  = tiledlayout(fig2, 2, 1, 'TileSpacing', 'compact');
title(tl2, 'Bode diagram of the sign-absorbed plant -G(s) = K/(s^2 - a_{21}) and its refinements', 'Color', 'k');
axM = nexttile; hold on;
axP = nexttile; hold on;
% Line styles: the two delayed models have IDENTICAL magnitude (a pure delay
% only adds phase), so the last one is dashed to keep the one below it visible.
styB = {'-', '-', '-', '--'};
for k = 1:numel(sysB)
    h  = squeeze(freqresp(sysB{k}, w));
    ph = unwrap(angle(h));
    ph = (ph - 2 * pi * round((ph(1) + pi) / (2 * pi))) * 180 / pi;   % start the phase at -180 deg
    plot(axM, w, 20 * log10(abs(h)), styB{k}, 'Color', C(k, :), 'DisplayName', lblB{k});
    plot(axP, w, ph, styB{k}, 'Color', C(k, :), 'DisplayName', lblB{k});
end
ylim(axP, [-720 -90]);  yticks(axP, -720:90:-90);   % the useful range; the delays keep falling below
for ax = [axM, axP]
    set(ax, 'XScale', 'log'); grid(ax, 'on'); box(ax, 'on');
    xline(ax, eq0.p,   'k--', 'HandleVisibility', 'off');
    xline(ax, pi / Ts, 'k:',  'HandleVisibility', 'off');
end
text(axM, eq0.p * 1.08, max(ylim(axM)) - 4, 'p', 'Color', 'k');
text(axM, pi / Ts * 1.08, max(ylim(axM)) - 4, '\pi/T_s', 'Color', 'k');
ylabel(axM, 'Magnitude (dB)');  legend(axM, 'Location', 'southwest');
xlabel(axP, 'Frequency (rad/s)'); ylabel(axP, 'Phase (deg)');
title(axM, 'Magnitude (a pure delay leaves it unchanged, so the last two curves overlap)', 'Color', 'k');  title(axP, 'Phase (starts at -180 deg: the plant is unstable)', 'Color', 'k');

%% 5. Figure 3: Nyquist, P-only versus PD (reduced plant)
wN   = P.freq.wNyq;
Lset = {Kp * M.Gs2, M.Gs2 * Cpd};
Lnm  = {sprintf('P-only, Kp = %.1f V/m', Kp), sprintf('PD, Kp = %.1f V/m, Kd = %.2f V s/m', Kp, Kd)};
fig3 = figure('Name', 'Phase 2: Nyquist', 'Position', [140 140 900 520]);
hold on;
for k = 1:2
    h = squeeze(freqresp(Lset{k}, wN));
    plot(real(h),  imag(h), '-',  'Color', C(k, :), 'DisplayName', Lnm{k});
    plot(real(h), -imag(h), '--', 'Color', C(k, :), 'HandleVisibility', 'off');   % negative frequencies
end
plot(-1, 0, '+', 'MarkerSize', 16, 'LineWidth', 2.6, 'Color', 'k', 'DisplayName', 'critical point -1');
xlim([-2 0.5]); ylim([-0.15 0.15]); grid on; box on;
xlabel('Re L(j\omega)'); ylabel('Im L(j\omega)');
title({'Nyquist plot of L = G_s C, reduced plant', ...
       'open-loop RHP poles P = 1, so one counter-clockwise encirclement of -1 is required'}, 'Color', 'k');
legend('Location', 'northwest');
text(-1.95, -0.11, 'solid: \omega > 0, dashed: \omega < 0', 'Color', 'k');

exportgraphics(fig1, fullfile(P.dir.figs, 'p2_polemap.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'white');
exportgraphics(fig2, fullfile(P.dir.figs, 'p2_bode.png'),    'Resolution', P.plot.res, 'BackgroundColor', 'white');
exportgraphics(fig3, fullfile(P.dir.figs, 'p2_nyquist.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'white');

%% 6. Report PASS/FAIL
fprintf('\n=== Self-checks ===\n');
nFail = 0;
for k = 1:size(tests, 1)
    ok = abs(tests{k, 2} - tests{k, 3}) <= tests{k, 4};
    if ok, tag = 'PASS'; else, tag = 'FAIL'; nFail = nFail + 1; end
    fprintf('[%s] %-72s got % .6g, expected % .6g (tol %.3g)\n', tag, tests{k, 1}, ...
            tests{k, 2}, tests{k, 3}, tests{k, 4});
end
if nFail == 0
    fprintf('\nOVERALL: PASS  (%d/%d checks)\n', size(tests, 1), size(tests, 1));
else
    fprintf('\nOVERALL: FAIL  (%d of %d checks failed)\n', nFail, size(tests, 1));
end

%% 7. Save for later scripts
save(fullfile(P.dir.data, 'phase2_results.mat'), 'P', 'eq0', 'M', 'Ms', 'scen', 'Kp', 'Kd', 'tests');
fprintf('Saved data/phase2_results.mat and 3 PNG files in figs/.\n');
