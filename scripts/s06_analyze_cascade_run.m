% s06_analyze_cascade_run.m   [STANDALONE]
% =========================================================================
% PURPOSE   Analyse the first successful cascade-controller levitation
%           (lab 2026-11-13) and compare it with the Phase 3 prediction.
%             run 3 : inner current loop only, ball on the stand (i_test 0.3 -> 0.5 A)
%             run 4 : levitation, set point 11 mm, then 10 mm at ~14.4 s
% INPUTS    data/lab_2026-11-13/runs/cascade_run3.fig, cascade_run4.fig
%           (scope "Print to Figure -> Save"; read with load -mat because
%           openfig fails off the lab PC), data/phase3_cascade.mat
% OUTPUTS   console PASS/FAIL, figs/p3_lab_run4.png, figs/p3_lab_run3.png,
%           data/lab_2026-11-13/run34_metrics.mat
% SIGNS     x = gap, increasing downward. Set point 11 -> 10 mm moves the ball UP.
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
P.plot.apply();
chk = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
runDir = fullfile(P.dir.data, 'lab_2026-11-13', 'runs');
T0 = 0.003;  ka = 2.44;  Kc = 2.05;

%% ---- run 3: inner current loop -----------------------------------------
r3 = read_scope_fig(fullfile(runDir, 'cascade_run3.fig'));
t = r3.t;  i = r3.y(:,3);  u = r3.y(:,4);
iTest = (u + Kc*i) / (1/ka + Kc);          % invert u = i_test/ka + Kc(i_test - i)
on = u > 0.01;  kOn = find(on, 1);
lev = round(movmedian(iTest, 31)/0.05)*0.05;
kStep = kOn + find(diff(lev(kOn:end)) > 0.1, 1);
seg03 = t > t(kOn) + 1 & t < t(kStep) - 0.1;
seg05 = t > t(kStep) + 0.5;
fprintf('RUN 3 inner loop: i_test 0.3 -> mean i %.3f A (std %.3f); i_test 0.5 -> mean i %.3f A (std %.3f)\n', ...
        mean(i(seg03)), std(i(seg03)), mean(i(seg05)), std(i(seg05)));
kJ = find(t > t(kStep) - 0.05 & i > 0.3 + 0.63*0.2, 1);
kU = find(t > t(kStep) - 0.05 & u > 0.5, 1);        % the sample where the command jumps
fprintf('  step 0.3 -> 0.5 A: 63%% reached %d sample(s) after the command jump\n', kJ - kU);
chk(abs(mean(i(seg03)) - 0.30) < 0.02 && abs(mean(i(seg05)) - 0.50) < 0.02, 'inner loop steady error < 20 mA');
chk(kJ - kU <= 3, 'inner loop reaches 63 % within 3 samples (design: ~1, open coil: 9)');
fprintf('  current noise in the loop: std %.3f A -> command noise ~Kc*std = %.2f\n', std(i(seg05)), Kc*std(i(seg05)));

%% ---- run 4: levitation --------------------------------------------------
r4 = read_scope_fig(fullfile(runDir, 'cascade_run4.fig'));
t = r4.t;  x = r4.y(:,1);  i = r4.y(:,3);  u = r4.y(:,4);
xs = movmean(x, 11);                        % 33 ms mean, removes sample noise for settling
kOn = find(u > 0.01, 1);  tOn = t(kOn);
xStand = mean(x(1:kOn-1));
fprintf('\nRUN 4 levitation: switched on at %.2f s, ball on stand at %.2f mm\n', tOn, 1e3*xStand);
kLift = find(t > tOn & x < xStand - 0.2e-3, 1);
w1 = t > tOn & t < tOn + 1;
band = 0.25e-3;
kS1 = find(w1 & abs(xs - 0.011) > band, 1, 'last');
fprintf('  lift-off %.0f ms after switch-on, highest point %.2f mm, inside +-0.25 mm of 11 mm after %.0f ms\n', ...
        1e3*(t(kLift) - tOn), 1e3*min(x(w1)), 1e3*(t(kS1) - tOn));
kStep = find(t > tOn + 2 & x < 0.0106, 1);
while x(kStep) < 0.01085, kStep = kStep - 1; end
tStep = t(kStep);
w2 = t > tStep & t < tStep + 1.5;
kS2 = find(w2 & abs(xs - 0.010) > band, 1, 'last');
fprintf('  step 11 -> 10 mm at %.2f s: highest point %.2f mm (overshoot %.2f mm), inside +-0.25 mm after %.0f ms\n', ...
        tStep, 1e3*min(x(w2)), 1e3*(0.010 - min(x(w2))), 1e3*(t(kS2) - tStep));
h11 = t > tOn + 1 & t < tStep - 0.1;   h10 = t > tStep + 1.5;
for c = {{h11, 0.011, '11 mm'}, {h10, 0.010, '10 mm'}}
    s = c{1}{1};
    fprintf('  hover %s: mean %.3f mm, std %.3f mm, p-p %.2f mm | i %.3f A | u %.3f | u at 0 or 0.9: %.1f %%\n', ...
        c{1}{3}, 1e3*mean(x(s)), 1e3*std(x(s)), 1e3*(max(x(s)) - min(x(s))), mean(i(s)), mean(u(s)), ...
        100*mean(u(s) <= 0.001 | u(s) >= 0.899));
end
chk(abs(mean(x(h10)) - 0.010) < 0.02e-3, 'zero steady error at 10 mm (integral action works)');
chk(std(x(h10)) < 0.1e-3, 'hover jitter std < 0.1 mm');
chk(min(x) > 5e-3, 'ball never closer than 5 mm to the magnet');
chk(max(i) < 2.2, sprintf('peak current %.2f A < 2.2 A', max(i)));

% Jitter spectrum at 10 mm (Hann window, no toolbox needed)
xh = x(h10) - mean(x(h10));  N = numel(xh);
wv = 0.5 - 0.5*cos(2*pi*(0:N-1)'/(N-1));
Pw = abs(fft(xh.*wv)).^2;  f = (0:N-1)'/(N*T0);  sel = f > 0.5 & f < 1/(2*T0);
Pm = movmean(Pw(sel), 9);  fs = f(sel);  [~, kp] = max(Pm);
fprintf('  jitter spectrum at 10 mm: broad peak near %.1f Hz; %.0f %% of the power is in 2-10 Hz\n', ...
        fs(kp), 100*sum(Pw(sel & f > 2 & f < 10))/sum(Pw(sel)));

%% ---- force law from the two hover points --------------------------------
% F = c i^2 exp(-x/lam) = m g at both points  ->  (i11/i10)^2 = exp((11-10) mm / lam)
i11 = mean(i(h11));  i10 = mean(i(h10 & t < tStep + 3.5));
ioff = 0.05;                                % sensor reading at u = 0 (runs 1-3: 0.045-0.055 A)
lamRaw = 1e-3 / log((i11/i10)^2);
lamCor = 1e-3 / log(((i11 - ioff)/(i10 - ioff))^2);
eqM = maglev_equilibrium(P, P.nom.m, 0.010);
fprintf('\nForce law from hover: i(11 mm) %.3f A, i(10 mm) %.3f A\n', i11, i10);
fprintf('  decay length lam = %.2f mm (raw) / %.2f mm (minus %.2f A sensor offset); manual P2 = %.2f mm\n', ...
        1e3*lamRaw, 1e3*lamCor, ioff, 1e3*P.Fem.P2);
fprintf('  manual model hover current at 10 mm (39.288 g): %.3f A; measured %.3f A raw, %.3f A offset-corrected\n', ...
        eqM.x30, i10, i10 - ioff);
chk(lamCor > 4.5e-3 && lamCor < 7.5e-3, 'hover data agree with the manual force decay length (within 25 %)');

%% ---- comparison with the Phase 3 simulation -----------------------------
D = load(fullfile(P.dir.data, 'phase3_cascade.mat'));
sim = D.S{1};  kSim = find(sim.t >= 1.5, 1);
tS = sim.t(kSim:end) - sim.t(kSim);  xS = sim.x(kSim:end);
fprintf('  simulation (manual force law) for the same step: highest point %.2f mm (lab %.2f mm)\n', ...
        1e3*min(xS(tS < 1.5)), 1e3*min(x(w2)));

%% ---- figures -------------------------------------------------------------
f1 = figure('Position', [80 80 1000 800]);
tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile([1 2]); hold on; grid on;
plot(t, 1e3*x, 'Color', P.plot.colors(1,:), 'LineWidth', 1.0);
xline(tOn, 'k--', 'switch on', 'LineWidth', 1); xline(tStep, 'k--', 'x_{ref} 11 \rightarrow 10 mm', 'LineWidth', 1);
set(ax, 'YDir', 'reverse'); ylabel('gap x [mm]'); xlabel('time [s]');
title('Run 4: first levitation with the cascade controller (39 g ball)', 'Color', 'k');
ax = nexttile; hold on; grid on;
s = t > tOn - 0.1 & t < tOn + 0.6;
plot(1e3*(t(s) - tOn), 1e3*x(s), 'Color', P.plot.colors(1,:));
yline(11, 'k--'); set(ax, 'YDir', 'reverse');
xlabel('time after switch-on [ms]'); ylabel('gap x [mm]');
title('Lift-off from the stand', 'Color', 'k');
ax = nexttile; hold on; grid on;
s = t > tStep - 0.1 & t < tStep + 1.0;
plot(1e3*(t(s) - tStep), 1e3*x(s), 'Color', P.plot.colors(1,:));
plot(1e3*tS(tS < 1.0), 1e3*xS(tS < 1.0), 'Color', P.plot.colors(2,:), 'LineWidth', 2);
yline(10, 'k--'); set(ax, 'YDir', 'reverse');
xlabel('time after set-point change [ms]'); ylabel('gap x [mm]');
legend('lab', 'simulation (Phase 3)', 'set point', 'Location', 'southeast');
title('Set-point step 11 \rightarrow 10 mm', 'Color', 'k');
ax = nexttile([1 2]); hold on; grid on;
plot(t, i, 'Color', P.plot.colors(3,:), 'LineWidth', 1.0);
plot(t, u, 'Color', P.plot.colors(4,:), 'LineWidth', 1.0);
xlabel('time [s]'); ylabel('i [A], u [-]'); legend('coil current i', 'command u', 'Location', 'east');
title('Coil current and command', 'Color', 'k');
exportgraphics(f1, fullfile(P.dir.figs, 'p3_lab_run4.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

t = r3.t;  i = r3.y(:,3);  u = r3.y(:,4);
f2 = figure('Position', [80 80 900 420]); hold on; grid on;
s = t > t(kU) - 0.06 & t < t(kU) + 0.15;
stairs(1e3*(t(s) - t(kU)), i(s), 'Color', P.plot.colors(3,:));
stairs(1e3*(t(s) - t(kU)), u(s), 'Color', P.plot.colors(4,:));
tt = linspace(0, 150, 300);
plot(tt, 0.3 + 0.2*(1 - exp(-tt/27)), 'k--', 'LineWidth', 1.2);
xlabel('time after i_{test} change [ms]'); ylabel('i [A], u [-]');
legend('coil current i (lab)', 'command u (lab)', 'open coil, \tau = 27 ms (for comparison)', 'Location', 'southeast');
title('Run 3: inner current loop, i_{test} 0.3 \rightarrow 0.5 A, ball on the stand', 'Color', 'k');
exportgraphics(f2, fullfile(P.dir.figs, 'p3_lab_run3.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

save(fullfile(P.dir.data, 'lab_2026-11-13', 'run34_metrics.mat'), 'i11', 'i10', 'lamRaw', 'lamCor', 'tOn', 'tStep');
fprintf('\nSaved figs/p3_lab_run4.png, figs/p3_lab_run3.png, data/lab_2026-11-13/run34_metrics.mat\n');

%% ======================= local function ==================================
function r = read_scope_fig(file)
% Read a scope "Print to Figure" .fig without openfig. Returns r.t (unique
% time stamps) and r.y (one column per trace, in the order Position,
% Velocity, Current, Control as plotted by the lab scope), r.names.
w = warning('off', 'all');
try
    S = load(file, '-mat');
catch
end
warning(w);
L = collect(S.hgS_070000, {});
r.names = cellfun(@(c) c{1}, L, 'UniformOutput', false);
[r.t, iu] = unique(L{1}{2});
r.y = zeros(numel(r.t), numel(L));
for j = 1:numel(L)
    [tj, ij] = unique(L{j}{2});
    yj = L{j}{3}(ij);
    r.y(:, j) = interp1(tj, yj, r.t, 'previous', 'extrap');
end
assert(numel(L) == 4 && strcmp(r.names{1}, 'Position [m]') && strcmp(r.names{3}, 'Current [A]'), ...
       'read_scope_fig: unexpected traces in %s', file);
end

function L = collect(h, L)
for k = 1:numel(h)
    p = h(k).properties;
    if strcmp(h(k).type, 'specgraph.stairseries') && isfield(p, 'DisplayName') && ~isempty(p.DisplayName)
        L{end+1} = {p.DisplayName, p.XData(:), p.YData(:)}; %#ok<AGROW>
    end
    if isfield(h(k), 'children') && ~isempty(h(k).children), L = collect(h(k).children, L); end
end
end
