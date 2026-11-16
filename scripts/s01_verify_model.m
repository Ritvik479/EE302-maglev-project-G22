% s01_verify_model.m   (Phase 1)   [STANDALONE]
% =========================================================================
% PURPOSE   Prove that maglev_params + maglev_equilibrium reproduce every
%           number we were given (manual and briefing), for
%             (1) the manual's 57.1 g ball at 9 mm,
%             (2) the two balls of this project (provisional),
%             (3) the 36 g ball at 10 mm (manual Fig. 46 sanity check),
%           then sweep the gap 7-11 mm for three balls.
% INPUTS    maglev_params (struct P), maglev_equilibrium
% OUTPUTS   data/phase1_results.mat   (P, S sweep, e57, e39, e42, e36, tests)
%           figs/p1_sweep.png, figs/p1_force_curves.png
% CHECKED   PASS/FAIL table printed at the end ("OVERALL: PASS" expected).
%
% SIGNS     x1 = gap, increasing DOWN. e = x1 - x0, u = u0 + Kp*e (+Kd*de/dt),
%           plant gain a23*ki < 0. Sign tests are in section 5.
% =========================================================================

%% 0. Bootstrap (same 3 lines at the top of every script)
root = fileparts(fileparts(mfilename('fullpath')));
if ~isfile(fullfile(root, 'maglev_params.m')), root = pwd; end   % fallback: run from project root
addpath(root, fullfile(root, 'scripts'));
maglev_params;                                   % creates struct P
for d = {P.dir.models, P.dir.data, P.dir.figs}
    if ~isfolder(d{1}), mkdir(d{1}); end
end

P.plot.apply();                                  % white background, black text, bright colours
C = P.plot.colors;

ballmass = @(n) P.ball(strcmp({P.ball.name}, n)).m;   % mass [kg] by ball name

%% 1. Equilibrium + linearization for the four cases
e57    = maglev_equilibrium(P, ballmass('manual_big'),   9e-3);
e39    = maglev_equilibrium(P, ballmass('mine_39g'),     9e-3);
e42    = maglev_equilibrium(P, ballmass('mine_42g'),     9e-3);
e36    = maglev_equilibrium(P, ballmass('manual_small'), 10e-3);
e39_10 = maglev_equilibrium(P, ballmass('mine_39g'),     10e-3);

cases = {'57.1 g @ 9 mm', e57; '39.288 g @ 9 mm', e39; ...
         '42.137 g @ 9 mm', e42; '36 g @ 10 mm', e36};
fprintf('\n=== Equilibrium and linearization ===\n');
fprintf('%-18s %8s %7s %9s %8s %8s %9s %8s %9s %8s\n', 'case', 'x30[A]', 'u0[V]', ...
        'a21', 'p[rad/s]', 'a23', 'a33', 'b3', 'K', 'Kp_min');
for k = 1:size(cases, 1)
    e = cases{k, 2};
    fprintf('%-18s %8.4f %7.4f %9.2f %8.3f %8.3f %9.2f %8.2f %9.4f %8.2f\n', cases{k, 1}, ...
            e.x30, e.u0, e.a21, e.p, e.a23, e.a33, e.b3, e.K, e.Kp_min);
end

%% 2. Tests list: each row = {name, value, expected, tolerance}
tests = cell(0, 4);

% 2a. Manual's 57.1 g ball at 9 mm
fn = fieldnames(P.test.ref57);
for k = 1:numel(fn)
    tests(end+1, :) = {sprintf('57.1 g @ 9 mm: %s', fn{k}), e57.(fn{k}), ...
                       P.test.ref57.(fn{k}), P.test.tol57.(fn{k})};
end

% 2b. My two balls (provisional numbers from the briefing)
tests(end+1, :) = {'39.288 g: x30 [A]',    e39.x30,    P.test.mine.x30_39,   P.test.minetol.x30};
tests(end+1, :) = {'39.288 g: u0 [V]',     e39.u0,     P.test.mine.u0_39,    P.test.minetol.u0};
tests(end+1, :) = {'39.288 g: Kp_min [V/m]', e39.Kp_min, P.test.mine.Kpmin_39, P.test.minetol.Kpmin};
tests(end+1, :) = {'42.137 g: x30 [A]',    e42.x30,    P.test.mine.x30_42,   P.test.minetol.x30};
tests(end+1, :) = {'42.137 g: u0 [V]',     e42.u0,     P.test.mine.u0_42,    P.test.minetol.u0};
tests(end+1, :) = {'42.137 g: Kp_min [V/m]', e42.Kp_min, P.test.mine.Kpmin_42, P.test.minetol.Kpmin};

% 2c. Fig. 46 sanity check: 36 g at 10 mm
tests(end+1, :) = {'Fig.46, 36 g @ 10 mm: x30 [A]', e36.x30, P.test.fig46.x30, P.test.fig46.tolx30};
tests(end+1, :) = {'Fig.46, 36 g @ 10 mm: u0 [V]',  e36.u0,  P.test.fig46.u0,  P.test.fig46.tolu0};

% 2d. Internal consistency (independent routes to the same number)
tests(end+1, :) = {'force balance residual (all cases)', ...
                   max([e57.resid, e39.resid, e42.resid, e36.resid]), 0, 1e-9};
tests(end+1, :) = {'a21 (from dFem/dx1) = g/FemP2', e57.a21, P.g / P.Fem.P2, 1e-6};
tests(end+1, :) = {'a23 (from dFem/dx3) = -2g/x30', e57.a23, -2 * P.g / e57.x30, 1e-6};
tests(end+1, :) = {'x30 ratio 42.137/39.288 = sqrt(mass ratio)', e42.x30 / e39.x30, ...
                   sqrt(ballmass('mine_42g') / ballmass('mine_39g')), 1e-9};
tests(end+1, :) = {'x30 growth per +1 mm gap (briefing: ~+9%)', e39_10.x30 / e39.x30, 1.09, 0.002};

% 2e. Headroom numbers (briefing sec.3)
u_at_x3max = (P.lim.x3max - P.act.ci) / P.act.ki;
tests(end+1, :) = {'u at current saturation 2.345 A [V] (~4.25)', u_at_x3max, 4.25, 0.02};
tests(end+1, :) = {'Fem(2.345 A, 9 mm)/(m g), 57.1 g (~6.3)', ...
                   e57.Fem(9e-3, P.lim.x3max) / (e57.m * P.g), 6.3, 0.05};

% 2f. Force curves vs manual Figs. 42-43 (readings of plots, approximate)
tests(end+1, :) = {'Fem(x1=0, x30) [N] (Fig.42: ~2.6)', e57.Fem(0, e57.x30), 2.63, 0.03};
tests(end+1, :) = {'Fem(2.3 A, 9 mm) [N] (Fig.43: ~3.4)', e57.Fem(9e-3, 2.3), 3.4, 0.15};

%% 3. Gap sweep 7-11 mm for three balls
nb = numel(P.sweep.balls);   ng = numel(P.sweep.gap);
S.gap = P.sweep.gap;   S.balls = P.sweep.balls;
[S.x30, S.u0, S.K, S.Kpmin, S.p, S.a21, S.a23] = deal(zeros(nb, ng));
S.ok = false(nb, ng);   S.okSensor = false(nb, ng);
lbl = cell(1, nb);
for ib = 1:nb
    mb = ballmass(P.sweep.balls{ib});
    lbl{ib} = sprintf('%s (%.3f g)', P.sweep.balls{ib}, 1e3 * mb);
    for ig = 1:ng
        e = maglev_equilibrium(P, mb, P.sweep.gap(ig));
        S.x30(ib, ig) = e.x30;     S.u0(ib, ig)    = e.u0;
        S.K(ib, ig)   = e.K;       S.Kpmin(ib, ig) = e.Kp_min;
        S.p(ib, ig)   = e.p;       S.a21(ib, ig)   = e.a21;
        S.a23(ib, ig) = e.a23;
        S.ok(ib, ig)  = e.inLimits.all;
        S.okSensor(ib, ig) = e.inLimits.x1sensor;
    end
end
tests(end+1, :) = {'sweep: all x30,u0,x1 inside limits (1=yes)', double(all(S.ok(:))), 1, 0};
tests(end+1, :) = {'sweep: all gaps inside assumed sensor range (1=yes)', double(all(S.okSensor(:))), 1, 0};
tests(end+1, :) = {'sweep: p spread over mass and gap [rad/s]', max(S.p(:)) - min(S.p(:)), 0, 1e-9};
tests(end+1, :) = {'sweep: K decreases with gap (1=yes)', double(all(all(diff(S.K, 1, 2) < 0))), 1, 0};

%% 4. Plots
fig1 = figure('Name', 'Phase 1: sweep', 'Position', [100 100 1100 800]);
tl = tiledlayout(fig1, 2, 2, 'TileSpacing', 'compact');
title(tl, 'Equilibrium and linearization versus operating gap', 'Color', 'k');
gmm = 1e3 * S.gap;
panels = {S.x30,   'Equilibrium current x_{30} (A)',        'Equilibrium current';
          S.u0,    'Equilibrium command u_0 (V)',           'Equilibrium command';
          S.K,     'Reduced-plant gain K = |a_{23}| k_i (m/s^2/V)', 'Plant gain K';
          S.Kpmin, 'Minimum stabilizing K_p = a_{21}/K (V/m)', 'Minimum proportional gain'};
for k = 1:4
    nexttile; hold on;
    for ib = 1:nb
        plot(gmm, panels{k, 1}(ib, :), '-o', 'Color', C(ib, :), 'DisplayName', lbl{ib});
    end
    grid on; box on;
    xlabel('Gap x_1 (mm)'); ylabel(panels{k, 2}); title(panels{k, 3}, 'Color', 'k');
    legend('Interpreter', 'none', 'Location', 'best');
end

xg = linspace(0, P.lim.x1max, 201);
x3v = linspace(0, 2.3, 231);
fig2 = figure('Name', 'Phase 1: force curves', 'Position', [150 150 1100 450]);
tl2 = tiledlayout(fig2, 1, 2, 'TileSpacing', 'compact');
title(tl2, 'Electromagnetic force, manual 57.1 g ball (compare manual Figs. 42-43)', 'Color', 'k');
nexttile; hold on;
plot(1e3 * xg, e57.Fem(xg, e57.x30), '-', 'Color', C(1, :), 'DisplayName', sprintf('F_{em}(x_1), x_3 = %.4f A', e57.x30));
yline(e57.m * P.g, '--', 'Color', C(2, :), 'DisplayName', 'weight m g');
plot(1e3 * e57.x10, e57.m * P.g, 'o', 'MarkerSize', 9, 'MarkerFaceColor', C(3, :), ...
     'MarkerEdgeColor', 'k', 'DisplayName', 'equilibrium (9 mm)');
grid on; box on; xlabel('Gap x_1 (mm)'); ylabel('Force (N)'); title('Force versus gap', 'Color', 'k'); legend('Location', 'northeast');
nexttile; hold on;
plot(x3v, e57.Fem(9e-3, x3v), '-', 'Color', C(1, :), 'DisplayName', 'F_{em}(x_3), x_1 = 9 mm');
yline(e57.m * P.g, '--', 'Color', C(2, :), 'DisplayName', 'weight m g');
plot(e57.x30, e57.m * P.g, 'o', 'MarkerSize', 9, 'MarkerFaceColor', C(3, :), ...
     'MarkerEdgeColor', 'k', 'DisplayName', 'equilibrium (0.9345 A)');
grid on; box on; xlabel('Coil current x_3 (A)'); ylabel('Force (N)'); title('Force versus current', 'Color', 'k'); legend('Location', 'northwest');

exportgraphics(fig1, fullfile(P.dir.figs, 'p1_sweep.png'),        'Resolution', P.plot.res, 'BackgroundColor', 'white');
exportgraphics(fig2, fullfile(P.dir.figs, 'p1_force_curves.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'white');

%% 5. Sign tests (catch a wrong sign convention)
% (a) plant gain is negative: more voltage -> smaller gap
tests(end+1, :) = {'sign: a23 < 0 (1=yes)',            double(e57.a23 < 0),            1, 0};
tests(end+1, :) = {'sign: b3 > 0 (1=yes)',             double(e57.b3 > 0),             1, 0};
tests(end+1, :) = {'sign: a23*ki < 0, plant gain negative (1=yes)', double(e57.a23 * P.act.ki < 0), 1, 0};
% (b) ball BELOW setpoint (gap larger): same current gives LESS force than weight ...
dx = 1e-3;
tests(end+1, :) = {'sign: Fem(x10+1mm, x30) < m g  (ball would fall) (1=yes)', ...
                   double(e57.Fem(e57.x10 + dx, e57.x30) < e57.m * P.g), 1, 0};
% ... so the controller must RAISE u: with e = x1 - x0 and u = u0 + Kp*e, Kp > 0
Kp = 1.5 * e57.Kp_min;   Kd = 0.5;               % [V/m], [V s/m]  (test gains, not a design)
u_below = e57.u0 + Kp * ((e57.x10 + dx) - e57.x10);
tests(end+1, :) = {'sign: u rises when ball is below setpoint (1=yes)', double(u_below > e57.u0), 1, 0};
% (c) full 3rd-order loop: u = u0 + Kp*e + Kd*e' as state feedback [Kp Kd 0]
eigPlus  = eig(e57.A + e57.B * [ Kp,  Kd, 0]);   % correct sign
eigMinus = eig(e57.A + e57.B * [-Kp, -Kd, 0]);   % wrong sign
tests(end+1, :) = {'sign: +Kp,+Kd stabilizes 3rd-order plant (1=yes)', double(max(real(eigPlus)) < 0), 1, 0};
tests(end+1, :) = {'sign: -Kp,-Kd is UNSTABLE (1=yes)',               double(max(real(eigMinus)) > 0), 1, 0};
fprintf('\nSign-test closed-loop poles, Kp = %.1f V/m, Kd = %.2f V s/m, 57.1 g @ 9 mm:\n', Kp, Kd);
fprintf('  correct sign (+): '); fprintf('% .1f%+.1fj  ', [real(eigPlus), imag(eigPlus)].'); fprintf('\n');
fprintf('  wrong sign   (-): '); fprintf('% .1f%+.1fj  ', [real(eigMinus), imag(eigMinus)].'); fprintf('\n');

%% 6. Report PASS/FAIL
fprintf('\n=== Self-checks ===\n');
nFail = 0;
for k = 1:size(tests, 1)
    ok = abs(tests{k, 2} - tests{k, 3}) <= tests{k, 4};
    if ok, tag = 'PASS'; else, tag = 'FAIL'; nFail = nFail + 1; end
    fprintf('[%s] %-58s got % .6g, expected % .6g (tol %.3g)\n', tag, tests{k, 1}, ...
            tests{k, 2}, tests{k, 3}, tests{k, 4});
end
if nFail == 0
    fprintf('\nOVERALL: PASS  (%d/%d checks)\n', size(tests, 1), size(tests, 1));
else
    fprintf('\nOVERALL: FAIL  (%d of %d checks failed)\n', nFail, size(tests, 1));
end

%% 7. Save for later scripts
save(fullfile(P.dir.data, 'phase1_results.mat'), 'P', 'S', 'e57', 'e39', 'e42', 'e36', 'tests');
fprintf('Saved data/phase1_results.mat and 2 PNG files in figs/.\n');
