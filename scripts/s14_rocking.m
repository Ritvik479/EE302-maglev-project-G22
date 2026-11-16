% s14_rocking.m   [STANDALONE]
% =========================================================================
% PURPOSE   Open item (d): bounds on the ~2.4 Hz "rocking" (unmodelled dynamics, PS9 requirement 2),
%           from the data already recorded (no lab slot needed).
%             1. where and how big: 1.5-3.5 Hz band of x per hover plateau (9-11 mm sweeps, 11.5 mm holds)
%             2. what kind: self-sustained oscillation (limit cycle) or a damped mode excited by noise?
%                (envelope statistics; decay of the ringing after lift-off -> damping ratio)
%             3. is it sustained through the feedback loop? (current vs position at the rocking frequency,
%                compared with the controller's own i/x)
%             4. can the VERTICAL model produce it? (closed-loop modes for a21 from nominal down to
%                200 1/s^2, i.e. also with the "weaker force decay" hypothesis of s13). NOTE 2026-11-16
%                (AUDIT.md 4.12): this scan does not vary the position-sensor gain; a gain of 0.45-0.6 near
%                the stand makes the vertical loop itself oscillate at 2.4-3.1 Hz. "Rotation" is not supported.
%             5. robustness: how large an UNMODELLED relative loop error at 2.4 Hz a sustained oscillation
%                needs (from 1/|T| minus the parametric spread W), compared with what the s11 test still
%                tolerates there on top of W (Wu)
% INPUTS    data/lab_2026-11-13/runs/{hold115,sweep}_*.fig, data/linear_model.mat (LM),
%           data/robustness.mat (RB, incl. RB.opt2curves added 2026-11-15), maglev_cases.m
% OUTPUTS   console PASS/FAIL, data/rocking.mat, figs/p11_rocking.png
% DEFINITIONS
%   band rms   rms of x after a zero-phase FFT band-pass 1.5-3.5 Hz (mm)
%   envelope   |analytic signal| of the band-passed x. Its coefficient of variation CV = std/mean is
%              ~0 for a steady sinusoid (limit cycle) and ~0.52 for narrow-band Gaussian noise
%              (Rayleigh-distributed envelope), i.e. a damped mode kept alive by random excitation.
%   zeta       damping ratio of a free mode at f: envelope ~ exp(-zeta 2 pi f t)
%   T          complementary sensitivity L/(1+L) of the loop broken at u (same loop as s11)
%   Wu         extra unstructured relative loop error the s11 robustness test still tolerates on top of
%              the parametric set: (W + Wu (1 + W)) |T| < 1  =>  Wu = (1/|T| - W)/(1 + W)
% SIGNS     x = gap (down +), e = x - x_ref; the controller raises i when x grows (i/x > 0, s08 check).
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
nP = 0;  nF = 0;
chkp = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
runDir = fullfile(P.dir.data, 'lab_2026-11-13', 'runs');
g = P.g;  mB = [0.039288 0.042137];
D = load(fullfile(P.dir.data, 'linear_model.mat'), 'LM');  LM = D.LM;
[~, B] = maglev_cases(P);
C = B.C;  T0 = B.L.T0;  kaC = B.L.kaC;
lam = LM.lam;  cB = LM.cB;  tauN = LM.tau;  kaN = LM.ka;  dN = B.dly.nom;
ieqF = @(bi, x0) sqrt(mB(bi)*g*exp(x0/lam)/cB(bi));          % as s11 (nominal lam, c)
S = load(fullfile(P.dir.data, 'robustness.mat'));  RB = S.RB;
assert(isfield(RB, 'opt2curves'), 'robustness.mat has no opt2curves: re-run s11_robustness first');
fR = [1.5 3.5];                                                % rocking band [Hz]

%% ---- 0. load ------------------------------------------------------------
recs = {'hold115_39g_holeup', 1, 'hold'; 'hold115_42g_holeup', 2, 'hold'; 'hold115_39g_holedown', 1, 'hold';
        'sweep_39g_holeup', 1, 'sweep'; 'sweep_42g_holeup', 2, 'sweep'; 'sweep_42g_holedown', 2, 'sweep'};
desc = {'39 g hole-up', '42 g hole-up', '39 g hole-down', '39 g hole-up', '42 g hole-up (rolled)', '42 g hole-down'};
R = cell(size(recs, 1), 1);
for q = 1:size(recs, 1)
    mm = read_scope_fig(fullfile(runDir, [recs{q,1} '_main.fig']));
    qq = read_scope_fig(fullfile(runDir, [recs{q,1} '_iref.fig']));
    r = struct('t', mm.t, 'x', mm.y(:,1), 'i', mm.y(:,3), 'u', mm.y(:,4), 'xr', qq.y(:,3), 'ball', recs{q,2});
    r.kOn = find(r.u > 0.01, 1);  r.kOff = find(r.u > 0.01, 1, 'last');
    r.kLift = r.kOn - 1 + find(r.x(r.kOn:end) < 0.0115, 1);
    R{q} = r;
end
close all force;
fprintf('Loaded %d records (3 holds at 11.5 mm, 3 sweeps 11 -> 9 -> 11 mm).\n', numel(R));

%% ---- 1. where and how big ------------------------------------------------
fprintf('\n==== 1. Rocking band (%.1f-%.1f Hz) of x per hover plateau ====\n', fR);
PL = [];   % rows: [record, gap mm, band rms mm, peak Hz, x std mm]
for q = 1:numel(R), r = R{q};
    if strcmp(recs{q,3}, 'hold')
        segs = {r.t > r.t(r.kLift) + 2 & r.t < r.t(r.kOff) - 0.1};
    else      % sweep plateaus: from 0.5 s after each set-point change to the next change
        kc = [find(diff(r.xr) ~= 0) + 1; r.kOff];  segs = {};
        for j = 1:numel(kc) - 1, segs{end+1} = (1:numel(r.t))' >= kc(j) + round(0.5/T0) & (1:numel(r.t))' < kc(j+1) - 5; end %#ok<AGROW>
        if strcmp(recs{q,1}, 'sweep_42g_holeup')   % skip the roll (first 3 s after lift, s08)
            segs = cellfun(@(s) s & r.t > r.t(r.kLift) + 3, segs, 'UniformOutput', false);
        end
    end
    for j = 1:numel(segs), s = segs{j};
        if nnz(s) < round(2/T0), continue, end
        [xb, ~, fpk] = band_env(r.x(s), T0, fR);
        PL(end+1, :) = [q, 1e3*round(mean(r.xr(s))*2e3)/2e3, 1e3*rms(xb), fpk, 1e3*std(r.x(s))]; %#ok<AGROW>
    end
end
gaps = unique(PL(:,2))';
fprintf(' gap [mm] | band rms [mm] per record (min-max over visits)                       | peak [Hz]\n');
for x0 = gaps
    s = PL(:,2) == x0;  txt = '';
    for q = unique(PL(s,1))', sq = s & PL(:,1) == q;
        txt = [txt sprintf('%s %s: %.3f-%.3f; ', recs{q,3}(1), desc{q}, min(PL(sq,3)), max(PL(sq,3)))]; %#ok<AGROW>
    end
    fprintf(' %5.1f    | %-70s | %.1f-%.1f\n', x0, txt, min(PL(s,4)), max(PL(s,4)));
end
in911 = PL(:,2) <= 11;
bMax911 = max(PL(in911, 3));  b115 = PL(PL(:,2) == 11.5, 3);
c = bMax911 < 0.1;
chkp(c, sprintf('record: at 9-11 mm the rocking band stays small in every plateau (max %.3f mm rms, %d plateaus)', bMax911, nnz(in911)));
nP = nP + c;  nF = nF + ~c;
c = max(b115) > 2*bMax911;
chkp(c, sprintf('record: at 11.5 mm it is much larger for the 39 g ball (%s mm rms vs <= %.3f at 9-11 mm)', ...
     mat2str(round(b115', 3)), bMax911));  nP = nP + c;  nF = nF + ~c;

%% ---- 2. what kind: limit cycle or damped mode ------------------------------
fprintf('\n==== 2. Limit cycle or noise-driven damped mode? (11.5 mm holds) ====\n');
HK = zeros(3, 6);   % [f Hz, band rms mm, env CV, zeta from ringing, env start mm, env end mm]
for q = 1:3, r = R{q};
    s = r.t > r.t(r.kLift) + 2 & r.t < r.t(r.kOff) - 0.1;
    [xb, env, fpk] = band_env(r.x(s), T0, fR);  e = env(200:end-200);          % drop FFT edge effects
    % ringing right after lift-off: fit the log envelope 0.6-2.2 s after lift
    s2 = find(r.t > r.t(r.kLift) + 0.3 & r.t < r.t(r.kLift) + 2.5);
    [~, env2] = band_env(r.x(s2), T0, fR);  tt = r.t(s2) - r.t(s2(1));  w = tt > 0.3 & tt < 1.9;
    pz = polyfit(tt(w), log(env2(w)), 1);
    HK(q, :) = [fpk, 1e3*rms(xb), std(e)/mean(e), -pz(1)/(2*pi*fpk), 1e3*env2(find(w, 1)), 1e3*env2(find(w, 1, 'last'))];
    fprintf('  %-15s: %.2f Hz, band rms %.3f mm, envelope CV %.2f | after lift: envelope %.3f -> %.3f mm, zeta %+.3f\n', ...
            desc{q}, HK(q, [1 2 3 5 6 4]));
end
c = HK(1,3) < 0.15 && abs(HK(1,4)) < 0.02;
chkp(c, sprintf(['39 g hole-up at 11.5 mm is a LIMIT CYCLE: constant envelope (CV %.2f << 0.52) that neither grows ' ...
     'nor decays (zeta %+.3f)'], HK(1,3), HK(1,4)));  nP = nP + c;  nF = nF + ~c;
c = HK(2,3) > 0.35 && HK(2,4) > 0.02;
chkp(c, sprintf(['42 g at 11.5 mm is a DAMPED mode kept alive by noise: envelope CV %.2f (noise-like), ringing ' ...
     'after lift decays with zeta = %.3f'], HK(2,3), HK(2,4)));  nP = nP + c;  nF = nF + ~c;

%% ---- 3. is it inside the loop? --------------------------------------------------
% If the oscillation passes through the controller, the current at the rocking frequency must be the
% controller's response to the measured x: i/x = C(j w) with the inner current loop ~ ideal at 2.4 Hz.
fprintf('\n==== 3. Is the oscillation inside the feedback loop? (current vs x at the peak frequency) ====\n');
IX = zeros(3, 3);
for q = 1:3, r = R{q};
    s = r.t > r.t(r.kLift) + 2 & r.t < r.t(r.kOff) - 0.1;
    xb = band_env(r.x(s), T0, fR);  ib = band_env(r.i(s), T0, fR);
    X = fft(xb);  I = fft(ib);  n = numel(xb);  f = (0:n-1)'/(n*T0);
    [~, k] = max(abs(X(f < 5)));  w0 = 2*pi*f(k);
    Cx = C.Kp + 1j*w0*C.Kd + C.Ki/(1j*w0);                     % i_ref / x of the outer controller
    IX(q, :) = [abs(I(k)/X(k)), angle(I(k)/X(k))*180/pi, abs(Cx)];
    fprintf('  %-15s: measured i/x %.0f A/m at %+.0f deg | controller %.0f A/m at %+.1f deg\n', desc{q}, IX(q,1:2), abs(Cx), angle(Cx)*180/pi);
end
c = all(abs(IX(:,1)./IX(:,3) - 1) < 0.25) && all(abs(IX(:,2)) < 20);
chkp(c, 'the 2.4 Hz current is the controller''s response to the measured x (gain and phase as the controller prescribes)');
fprintf(['  -> the oscillation is SUSTAINED through the loop: the only power source is the coil, and the coil''s\n' ...
         '     2.4 Hz current is produced by the controller from the measured x (a free mechanical mode would\n' ...
         '     decay, as the 42 g ringing does).\n']);
nP = nP + c;  nF = nF + ~c;

%% ---- 4. can the vertical model produce it? ----------------------------------------
% Linear vertical loop (s11's loop_u, fractional delay) at 11.5 mm, 39 g; a21 from the nominal g/lam down to
% 200 1/s^2 (covers the "weaker force decay beyond 11 mm" hypothesis of s13, local decay length up to 49 mm),
% delay d over the measured range. Slowest oscillatory closed-loop mode.
fprintf('\n==== 4. Can the VERTICAL model produce a 2.4 Hz mode? ====\n');
a21List = [g/lam 1200 900 700 516 400 300 200];  fMin = Inf;  zMin = Inf;
fprintf(' a21 [1/s^2] | slowest oscillatory mode (d = %.1f / %.1f / %.1f): f [Hz] (zeta)\n', B.dly.lo, dN, B.dly.hi);
for a21 = a21List
    txt = '';
    for dq = [B.dly.lo dN B.dly.hi]
        p = struct('a21', a21, 'b', 2*g/ieqF(1, 0.0115), 'tau', tauN, 'ka', kaN, 'd', dq);
        [~, Acl] = loop_u(C, T0, kaC, p, 1);
        sc = log(eig(Acl))/T0;  sc = sc(imag(sc) > 1e-6);  [~, o] = min(abs(sc));
        fq = abs(sc(o))/(2*pi);  zq = -real(sc(o))/abs(sc(o));  fMin = min(fMin, fq);  zMin = min(zMin, zq);
        txt = [txt sprintf('%5.1f (%.2f)  ', fq, zq)]; %#ok<AGROW>
    end
    fprintf('   %6.0f    | %s\n', a21, txt);
end
c = fMin > 5 && zMin > 0.3;
chkp(c, sprintf(['the vertical loop has no mode below %.1f Hz (all zeta >= %.2f) even with a21 cut to 200: the 2.4 Hz ' ...
     'rocking is not a mode of the vertical loop with its NOMINAL sensor gain (a sensor-gain loss near the stand can ' ...
     'produce it; rotation not supported, see data/lab_2026-11-16/README.md)'], fMin, zMin));
nP = nP + c;  nF = nF + ~c;

%% ---- 5. robustness at 2.4 Hz ------------------------------------------------------
% Small-gain view: an extra relative loop error delta at w can create a closed-loop pole there only if
% |delta(w)| >= 1/|T(w)|. Check our loop model first against s11's stored nominal |T| (39 g, 10 mm).
fprintf('\n==== 5. Robustness at the rocking frequency ====\n');
fHz = RB.f(:);  wg = 2*pi*fHz;
pN = struct('a21', g/lam, 'b', 2*g/ieqF(1, 0.010), 'tau', tauN, 'ka', kaN, 'd', dN);
Hn = squeeze(freqresp(loop_u(C, T0, kaC, pN, 1), wg));  Tchk = abs(Hn./(1 + Hn));
devT = max(abs(Tchk - RB.Tn(:)));
c = devT < 1e-6;
chkp(c, sprintf('loop model reproduces s11''s nominal |T| (max difference %.1e)', devT));  nP = nP + c;  nF = nF + ~c;
f0 = 2.4;  [~, k0] = min(abs(fHz - f0));
cases = {1, 0.0115, '39 g, 11.5 mm (limit cycle seen)'; 2, 0.0115, '42 g, 11.5 mm (damped, zeta ~0.07)';
         1, 0.0100, '39 g, 10 mm (nominal)'; 1, 0.0110, '39 g, 11 mm'; 2, 0.0110, '42 g, 11 mm'};
Tq = zeros(size(cases, 1), 1);
for q = 1:size(cases, 1)
    p = struct('a21', g/lam, 'b', 2*g/ieqF(cases{q,1}, cases{q,2}), 'tau', tauN, 'ka', kaN, 'd', dN);
    Hq = squeeze(freqresp(loop_u(C, T0, kaC, p, 1), 2*pi*fHz(k0)));  Tq(q) = abs(Hq/(1 + Hq));
end
O2 = RB.opt2curves;  Wu24 = arrayfun(@(o) o.Wu(k0), O2);  W24 = arrayfun(@(o) o.W(k0), O2);
fprintf('  at %.2f Hz: |T| and the relative loop error needed for a sustained oscillation (1/|T|):\n', fHz(k0));
for q = 1:size(cases, 1), fprintf('    %-36s |T| %.2f -> needs |delta| >= %.2f\n', cases{q,3}, Tq(q), 1/Tq(q)); end
fprintf('  s11 Option-2 regions at %.2f Hz: parametric W and the EXTRA error still tolerated, Wu:\n', fHz(k0));
bN = {'39 g', '42 g'};
for k = 1:numel(O2), fprintf('    %s %d-%d mm: W %.2f, Wu %.2f\n', bN{O2(k).ball}, O2(k).g, W24(k), Wu24(k)); end
% Like with like (corrected on verification): 1/|T| is the TOTAL relative loop error needed; the parametric
% spread can supply at most W of it (worst-case alignment), so the UNMODELLED part must be at least
%   du_min = (1/|T| - W)/(1 + W)            [from (1 + delta) = (1 + delta_p)(1 + delta_u)]
% which is directly comparable with Wu. W at 11.5 mm is not computed in s11; the 39 g 10-11 mm region's W
% is used (the nearest region; its spread is similar).
Wnear = W24(2);  duMin = (1/Tq(1) - Wnear)/(1 + Wnear);
fprintf(['  39 g at 11.5 mm: total error needed %.2f, parametric part <= %.2f (W, 39 g 10-11 mm region) ->\n' ...
         '    the UNMODELLED (rocking) part there is >= %.2f; the 9-11 mm result tolerates %.2f-%.2f on top of W\n'], ...
        1/Tq(1), Wnear, duMin, min(Wu24), max(Wu24));
c = duMin > 0.5*min(Wu24) && duMin < 2*max(Wu24);
chkp(c, sprintf(['record: the rocking mode is about as large as the WHOLE remaining margin at 2.4 Hz (>= %.2f vs %.2f-%.2f ' ...
     'tolerated): it is not safely covered; its size at 9-11 mm must be measured (sine injection)'], duMin, min(Wu24), max(Wu24)));
nP = nP + c;  nF = nF + ~c;

%% ---- 6. summary -------------------------------------------------------------------
fprintf('\n==== 6. Bounds on the rocking (for the report: unmodelled dynamics) ====\n');
fprintf('  frequency           %.1f-%.1f Hz (all records)\n', min(HK(:,1)), max(HK(:,1)));
fprintf('  amplitude, 9-11 mm  <= %.3f mm rms in the %.1f-%.1f Hz band (every plateau, both balls; an upper bound:\n                      the band also holds sensor noise and the tail of the 4-7 Hz wobble)\n', bMax911, fR);
fprintf('  amplitude, 11.5 mm  39 g: %.3f (hole-up, limit cycle) / %.3f mm (hole-down); 42 g: %.3f mm\n', HK([1 3 2], 2));
fprintf('  damping             42 g: zeta ~ %.2f; 39 g at 11.5 mm: none (self-sustained)\n', HK(2,4));
fprintf('  nature              sustained through the loop; tied to the stand (gone with the stand lowered); mechanism open\n');
fprintf('                      (candidate: position-sensor gain loss near the stand; not a demonstrated rotation)\n');
fprintf(['  consequence         at 11.5 mm the mode needs >= %.2f unmodelled loop error at 2.4 Hz, about the whole\n' ...
         '                      margin left at 9-11 mm (%.2f-%.2f). At 9-11 mm it is damped (no sustained rocking seen),\n' ...
         '                      but its size there is unknown -> keep 11.5 mm out of the claimed range; measure L(jw).\n'], ...
        duMin, min(Wu24), max(Wu24));
fprintf(['  LAB (wish-list 3, refined): sine injection at u at 1.5, 2, 2.4, 3, 4 Hz plus the planned higher\n' ...
         '                      frequencies, at 10 and 11 mm, both balls: measures L(j w) through the rocking band\n']);

%% ---- 7. figure -----------------------------------------------------------------
col = P.plot.colors;
f1 = figure('Position', [40 40 1300 900]);  try, theme(f1, 'light'); catch, end
tl = tiledlayout(f1, 2, 2, 'TileSpacing', 'compact');
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
mk = {'o', 's', 'd', 'o', 's', 'd'};
for q = 1:numel(R), s = PL(:,1) == q;
    plot(ax, PL(s,2) + 0.04*(q - 3.5), PL(s,3), mk{q}, 'Color', col(R{q}.ball,:), 'MarkerFaceColor', col(R{q}.ball,:), ...
         'MarkerSize', 7 + 3*strcmp(recs{q,3}, 'hold'));
end
set(ax, 'YScale', 'log');  xline(ax, 11.25, 'k--', 'validated range ends');
xlabel(ax, 'gap set point [mm]');  ylabel(ax, sprintf('x band rms %.1f-%.1f Hz [mm]', fR));
legend(ax, strcat(recs(:,3)', {' '}, desc), 'Location', 'northwest');
title(ax, '(a) Rocking amplitude per hover plateau', 'Color', 'k');
for q = 1:3, r = R{q};
    if q == 3, continue, end
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    s = r.t > r.t(r.kLift) + 0.3 & r.t < r.t(r.kOff) - 0.1;
    [xb, env] = band_env(r.x(s), T0, fR);  ts = r.t(s) - r.t(r.kLift);
    plot(ax, ts, 1e3*xb, '-', 'Color', col(r.ball,:), 'LineWidth', 1.0);
    plot(ax, ts, 1e3*env, 'k-', 'LineWidth', 2);
    xlabel(ax, 'time after lift-off [s]');  ylabel(ax, 'x, 1.5-3.5 Hz band [mm]');
    legend(ax, 'band-passed x', 'envelope', 'Location', 'northeast');
    title(ax, sprintf('(%s) %s at 11.5 mm: envelope CV %.2f, zeta %+.3f', char('a' + q), desc{q}, HK(q,3), HK(q,4)), 'Color', 'k');
end
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
for k = 1:numel(O2)
    plot(ax, fHz, O2(k).Wu, '-', 'Color', col(O2(k).ball,:), 'LineWidth', 1 + (O2(k).g(1) == 10));
end
plot(ax, fHz(k0), duMin, 'kp', 'MarkerSize', 16, 'MarkerFaceColor', 'y');
set(ax, 'XScale', 'log');  xlim(ax, [0.5 50]);  ylim(ax, [0 0.6]);  xline(ax, f0, 'k:');
xlabel(ax, 'frequency [Hz]');  ylabel(ax, 'extra relative loop error tolerated, Wu');
legend(ax, [arrayfun(@(o) sprintf('%s %d-%d mm', bN{o.ball}, o.g), O2(:)', 'UniformOutput', false), ...
            {sprintf('11.5 mm limit cycle: unmodelled part >= %.2f', duMin)}], 'Location', 'northeast');
title(ax, '(d) Room left for unmodelled dynamics (s11)', 'Color', 'k');
exportgraphics(f1, fullfile(P.dir.figs, 'p11_rocking.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

save(fullfile(P.dir.data, 'rocking.mat'), 'PL', 'HK', 'IX', 'Tq', 'Wu24', 'W24', 'duMin', 'fR', 'bMax911');
fprintf('\nSaved data/rocking.mat, figs/p11_rocking.png\n');
fprintf('SUMMARY: %d PASS / %d FAIL\n', nP, nF);

%% ======================= local functions ================================
function [xb, env, fpk] = band_env(x, T0, fR)
% Zero-phase FFT band-pass, envelope (|analytic signal|) and the peak frequency inside the band.
x = x(:) - mean(x);  n = numel(x);  X = fft(x);  f = (0:n-1)'/(n*T0);  f(f > 1/(2*T0)) = f(f > 1/(2*T0)) - 1/T0;
m = abs(f) >= fR(1) & abs(f) <= fR(2);  Xb = X.*m;  xb = real(ifft(Xb));
A = Xb;  A(f < 0) = 0;  A(f > 0) = 2*A(f > 0);  env = abs(ifft(A));
fp = f(f >= fR(1) & f <= fR(2));  [~, k] = max(abs(X(f >= fR(1) & f <= fR(2))));  fpk = fp(k);
end

function [L, Acl] = loop_u(C, T, kaC, p, sgn)
% COPY of s11_robustness.m>loop_u (section 5 checks it against s11's stored |T|).
% Discrete loop broken at the plant input, with the extra loop delay p.d (samples, any real >= 0).
Ac = [0 1 0; p.a21 0 -p.b; 0 0 -1/p.tau];  Bc = [0; 0; p.ka/p.tau];
Gc = ss(Ac, Bc, eye(3), 0);  Gc.InputDelay = p.d*T;
Gd = absorbDelay(c2d(Gc, T, 'zoh'));
[Ap, Bp, Cp, Dp] = ssdata(Gd);  assert(all(Dp(:) == 0), 'loop_u: plant must be strictly proper');
np = size(Ap, 1);  Cx = Cp(1, :);  Ci = Cp(3, :);
Kp = sgn*C.Kp;  Kd = sgn*C.Kd;  Ki = sgn*C.Ki;  Kc = sgn*C.Kc;  kff = sgn/kaC;
A = blkdiag(Ap, 0, 1);
A(np + 1, 1:np) = Cx;
A(np + 2, 1:np) = T*Cx;
B = [Bp; 0; 0];
Cu = [(kff + Kc)*(Kp + Kd/T)*Cx - Kc*Ci, -(kff + Kc)*Kd/T, (kff + Kc)*Ki];
L = ss(A, B, -Cu, 0, T);
Acl = A + B*Cu;
end
