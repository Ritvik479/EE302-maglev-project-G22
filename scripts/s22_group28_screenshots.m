% s22_group28_screenshots.m   [STANDALONE]
% =========================================================================
% PURPOSE   Group 28 cannot open the scope .fig files of the shared package ('group 28/'), so this script draws
%           every recording as a PNG from its data (read_scope_fig; openfig fails on other PCs, and here, with
%           'tileGrid'). One PNG per .fig (one panel per scope channel, full record, physical units) and one of
%           the sensor calibration table (group22_sensor.mat).
% UNITS     position and x_ref drawn in mm (stored in m); u = PWM duty fraction 0..1 (the scope labels it [V]).
% CHECKS    every file read, channel count as documented in group 28/README.md, time stamps strictly increasing,
%           every PNG written.
% OUTPUTS   group 28/screenshots/*.png (writes nothing else)
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
nP = 0;  nF = 0;
chk = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
pk = fullfile(here, '..', 'group 28');  out = fullfile(pk, 'screenshots');
if ~exist(out, 'dir'), mkdir(out); end
col = P.plot.colors;

% {file, title, channel labels (after unit conversion), scale per channel}
F = {'coil_steps_0p2_0p3_0p4', 'Coil step test, 12-Nov (driver model, ball on the stand at 12.9 mm; u = 0 \rightarrow 0.2 \rightarrow 0.3 \rightarrow 0.4 \rightarrow 0.2)', ...
        {'position x [mm]', 'velocity [m/s]', 'coil current reading [A]', 'command u (PWM duty, 0..1)'}, [1e3 1 1 1];
     'sweep_39g_holeup_main', 'Levitation sweep, 39 g ball (hole-up), 13-Nov: main scope', ...
        {'position x [mm]', 'velocity [m/s]', 'coil current reading [A]', 'command u (PWM duty, 0..1)'}, [1e3 1 1 1];
     'sweep_39g_holeup_iref', 'Levitation sweep, 39 g ball (hole-up), 13-Nov: set-point scope', ...
        {'coil current reading [A]', 'current set point i_{ref} [A]', 'position set point x_{ref} [mm]', 'sweep clock \tau [s]'}, [1 1 1e3 1];
     'sweep_42g_holedown_main', 'Levitation sweep, 42 g ball (hole-down), 13-Nov: main scope', ...
        {'position x [mm]', 'velocity [m/s]', 'coil current reading [A]', 'command u (PWM duty, 0..1)'}, [1e3 1 1 1];
     'sweep_42g_holedown_iref', 'Levitation sweep, 42 g ball (hole-down), 13-Nov: set-point scope', ...
        {'coil current reading [A]', 'current set point i_{ref} [A]', 'position set point x_{ref} [mm]', 'sweep clock \tau [s]'}, [1 1 1e3 1]};
nOK = 0;
for q = 1:size(F, 1)
    r = read_scope_fig(fullfile(pk, [F{q,1} '.fig']));  close all force;
    okR = size(r.y, 2) == 4 && all(diff(r.t) > 0);
    fg = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1500 1100]);
    tl = tiledlayout(fg, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, {F{q,2}, sprintf('file %s.fig  |  %d samples, %.1f s, sample time 3 ms  |  position = gap below the magnet (larger = lower)', ...
          strrep(F{q,1}, '_', '\_'), numel(r.t), r.t(end) - r.t(1))}, 'Color', 'k', 'FontWeight', 'bold', 'FontSize', 13);
    for j = 1:4
        ax = nexttile(tl);  plot(ax, r.t, F{q,4}(j)*r.y(:,j), 'Color', col(j,:), 'LineWidth', 1.2);
        grid(ax, 'on');  grid(ax, 'minor');  ylabel(ax, F{q,3}{j}, 'Color', 'k');
        if F{q,4}(j) == 1e3 && contains(F{q,3}{j}, 'position'), set(ax, 'YDir', 'reverse'); end   % magnet at the top
        if contains(F{q,3}{j}, 'velocity')       % the driver's derivative starts from 0: one-sample spike at t = 0
            v = r.y(:,j);  lim = 1.1*max(abs(v(3:end)));  ylim(ax, [-lim lim]);
            text(ax, 0.995, 0.95, sprintf('y-axis excludes the 1-sample start-up spike at t = 0 (%.1f m/s)', v(1 + (abs(v(2)) > abs(v(1))))), ...
                 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 10, ...
                 'Color', 'k', 'BackgroundColor', 'w', 'EdgeColor', [0.6 0.6 0.6]);
        end
        xlim(ax, [r.t(1) r.t(end)]);
        if j < 4, set(ax, 'XTickLabel', []); else, xlabel(ax, 'time [s]'); end
    end
    fn = fullfile(out, [F{q,1} '.png']);
    exportgraphics(fg, fn, 'Resolution', 150, 'BackgroundColor', 'w');  close(fg);
    okW = exist(fn, 'file') == 2;
    fprintf('  %-26s %5d samples, %.1f s, channels: %s -> %s\n', F{q,1}, numel(r.t), r.t(end) - r.t(1), strjoin(r.names, ', '), ...
            subsref({'NOT written', 'written'}, substruct('{}', {1 + okW})));
    nOK = nOK + (okR && okW);
end
c = nOK == size(F, 1);  chk(c, sprintf('%d of %d recordings read (4 channels, increasing time) and drawn', nOK, size(F, 1)));
nP = nP + c;  nF = nF + ~c;

% sensor calibration table
s = load(fullfile(pk, 'group22_sensor.mat'));  S = s.SensorData;
fg = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1100 650]);
ax = axes(fg);  plot(ax, S.Distance_mm, S.Sensor_V, 'o-', 'Color', col(1,:), 'MarkerFaceColor', col(1,:));
grid(ax, 'on');  grid(ax, 'minor');  xlabel(ax, 'distance (gap) [mm]');  ylabel(ax, 'sensor output [V]');
title(ax, {sprintf('Sensor calibration table SensorData (group22\\_sensor.mat), %d points', numel(S.Distance_mm)), ...
           'used by the driver''s 1-D lookup (sensor V \rightarrow distance) in every run of this package'}, 'Color', 'k');
for k = 1:numel(S.Distance_mm)
    text(ax, S.Distance_mm(k), S.Sensor_V(k), sprintf('  %.2f', S.Sensor_V(k)), 'FontSize', 8, 'Rotation', 45, 'Color', 'k');
end
fn = fullfile(out, 'group22_sensor_table.png');
exportgraphics(fg, fn, 'Resolution', 150, 'BackgroundColor', 'w');  close(fg);
c = exist(fn, 'file') == 2;  chk(c, 'sensor calibration table drawn');  nP = nP + c;  nF = nF + ~c;
fprintf('\nTOTAL: %d PASS, %d FAIL\n', nP, nF);
