% s20_liftoff_stand_height.m   [STANDALONE]
% =========================================================================
% PURPOSE   FIXPLAN step 10a (AUDIT.md 4.8). The slow ramp (s18) shows a STATIC stand effect: within ~0.7 mm
%           of the stand the hover current falls below the force law, i.e. an extra upward force. s13 section 5b
%           found NO extra force in lift-offs passing 11.4-11.8 mm, but binned by ABSOLUTE height, 13-Nov only.
%           Here the same Newton method is binned by HEIGHT ABOVE THE STAND and extended to the 16-Nov lift-offs,
%           including the two from the lowered stand (rest ~13.1 mm). Question: do lift-offs feel the extra force
%           that the quasi-static ramp feels at the same height above the stand?
% METHOD    Per sample during the first 0.3 s after switch-on (as s13 5b, local function copied and extended):
%             fx = m (g - x'') / ( c (i - i_z)^2 exp(-x/lam) ),   i_z = current reading with the coil off just before,
%           x'' = second difference with stride h (3 or 5 samples), x and i smoothed with the matching triangle.
%           NEW 1: height above the stand  hs = rest - x  (rest = reading on the stand just before switch-on).
%           NEW 2: a sample is used only if every reading in its stencil (k-h .. k+h) is >= 0.05 mm off the
%                  stand, so no contact force from the stand leaks into x''.
%           NEW 3: each lift-off is divided by its OWN baseline: median fx at x 10.3-10.9 mm and hs >= 0.95 mm
%                  (removes c per ball and orientation, and most of a current-zero error).
%           Static reference: the slow ramp (s18 B, drift-corrected, up/down averaged), converted to the same
%           quantity: fx_static = ((i_fit - a0)/(i_meas - a0))^2 with the far-field fit i_fit = a0 + a1 e^(x/2lam)
%           (fitted >= 0.95 mm above the stand, a0 = current zero), i.e. force needed / force the law gives.
% RESOLUTION (added after the first run, which found almost no samples near the stand): section 3b measures how
%           long each lift-off takes to cross 0.1-0.7 mm above the stand and how far the ramp's extra force could
%           move the ball in that time (x 0.5 a t^2), against the sensor noise (0.011 mm std).
% CHECKS    (declared before the run) every lift-off has a baseline; no current-to-force lag at 9.5-10.75 mm
%           (|slope| < 3 ms, as s13); the ramp gives fx_static > 1.05 at 0.4-0.5 mm (s18's -65 mA at 0.48 mm);
%           [record] dynamic vs static per height bin (normal stand), [record] lowered stand.
% RESULT    (2026-11-17) Lift-offs cross the stand zone (0.3-0.7 mm) in a median 7 ms, faster than the 18 ms Newton
%           stencil, so the per-sample force estimate there is blurred; the 'no extra force in lift-offs' of s13 5b
%           and of section 3 here is a resolution limit, not evidence against a static force (AUDIT.md 4.8).
% CAVEAT    On the lowered stand the near-stand bins lie at x 12.3-13.0 mm, beyond the range where the force law
%           was checked (<= 11.5 mm, within ~1 %), so there an extrapolation error and a stand force are mixed.
% INPUTS    data/lab_2026-11-13/runs/*_main.fig (13 lift-offs, as s13), data/lab_2026-11-16/runs/*_main.fig,
%           data/lab_2026-11-13/sweeps_holds_results.mat (lam, cB = s08 combined fit)
% SIGNS     x = gap, increasing DOWNWARD; x'' > 0 = accelerating downward; fx > 1 = more upward force than the law.
% OUTPUTS   console PASS/FAIL, figs/p16_liftoff_stand_height.png. Writes no .mat file.
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
nP = 0; nF = 0;
chkp = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
S8 = load(fullfile(P.dir.data, 'lab_2026-11-13', 'sweeps_holds_results.mat'));
T0 = 0.003;  g = P.g;  mb = [0.039288 0.042137];  lam = S8.lam;  cB = S8.cB;
d13 = fullfile(P.dir.data, 'lab_2026-11-13', 'runs');  d16 = fullfile(P.dir.data, 'lab_2026-11-16', 'runs');

%% ---- 0. lift-off runs ---------------------------------------------------------
% {folder, file, ball, stand: 1 normal / 2 lowered}
LRdef = {d13, 'cascade_run4', 1, 1;  d13, 'expA_39g_sweep_main', 1, 1;  d13, 'expB_42g_step_main1', 2, 1;
         d13, 'expB_42g_step_main2', 2, 1;  d13, 'expB_42g_sweep_main', 2, 1;  d13, 'expC_39g_kg_main', 1, 1;
         d13, 'sweep_39g_holeup_main', 1, 1;  d13, 'sweep_42g_holeup_main', 2, 1;  d13, 'sweep_42g_holedown_main', 2, 1;
         d13, 'hold115_39g_holeup_main', 1, 1;  d13, 'hold115_42g_holeup_main', 2, 1;
         d13, 'hold115_39g_holedown_main', 1, 1;  d13, 'liftoff_39g_SUSPECT_main', 1, 1;
         d16, 'steps_39g_main', 1, 1;  d16, 'steps_42g_main', 2, 1;  d16, 'rampFLAT_39g_main', 1, 1;
         d16, 'ramp_39g_main', 1, 1;  d16, 'sine_39g_10mm_main', 1, 1;  d16, 'variantD_39g_main', 1, 1;
         d16, 'ramp116FLAT_39g_lowstand_main', 1, 2;  d16, 'sweep_39g_lowstand_main', 1, 2};
LR = cell(size(LRdef, 1), 1);
for q = 1:numel(LR)
    mm = read_scope_fig(fullfile(LRdef{q,1}, [LRdef{q,2} '.fig']));
    LR{q} = struct('t', mm.t, 'x', mm.y(:,1), 'i', mm.y(:,3), 'u', mm.y(:,4), 'ball', LRdef{q,3}, 'stand', LRdef{q,4});
end
close all force;
fprintf('Loaded %d runs (%d on the lowered stand).\n', numel(LR), nnz([LRdef{:,4}] == 2));

%% ---- 1. dynamic force factor per lift-off, binned by height above the stand ----------
ed = [0.1 0.3 0.5 0.7 0.9 1.2];  nb = numel(ed) - 1;  cen = (ed(1:end-1) + ed(2:end))/2;
H = [3 5];
RelB = cell(1, 2);  info = [];  lagSlope = 0;  baseOK = true;
for jh = 1:2
    h = H(jh);  Ev = liftoff_fx(LR, h, lam, cB, mb, g, T0);   % [lift id, run, stand, x mm, hs mm, fx, di/dt, i-iz]
    ids = unique(Ev(:,1))';
    Rel = nan(numel(ids), nb);  nS = zeros(numel(ids), nb);
    for a = 1:numel(ids)
        e = Ev(Ev(:,1) == ids(a), :);
        base = median(e(e(:,4) >= 10.3 & e(:,4) < 10.9 & e(:,5) >= 0.95, 6));
        nBase = nnz(e(:,4) >= 10.3 & e(:,4) < 10.9 & e(:,5) >= 0.95);
        if nBase < 3, baseOK = false; fprintf('  no baseline: lift %d of %s\n', ids(a), LRdef{e(1,2),2}); continue, end
        for b = 1:nb
            s = e(:,5) >= ed(b) & e(:,5) < ed(b+1);  nS(a, b) = nnz(s);
            if nS(a, b) >= 2, Rel(a, b) = median(e(s,6))/base; end
        end
        if jh == 1, info(end+1, :) = [ids(a), e(1,2), e(1,3), median(e(:,5) + e(:,4)), nBase]; end %#ok<AGROW>
    end
    RelB{jh} = Rel;
    if h == 3
        sB = Ev(:,4) >= 9.5 & Ev(:,4) < 10.75;  pL = polyfit(Ev(sB,7)./Ev(sB,8), Ev(sB,6), 1);  lagSlope = 1e3*pL(1);
        nSamp = nS;
    end
end
st = info(:,3);
fprintf('\n==== 1. Lift-offs (h = 3): run, stand, rest reading, baseline samples ====\n');
for a = 1:size(info, 1)
    fprintf('  lift %2d  %-32s %-8s rest %.2f mm, baseline n = %d | fx/base per bin %s\n', info(a,1), LRdef{info(a,2),2}, ...
            subsref({'normal', 'LOWERED'}, substruct('{}', {info(a,3)})), info(a,4), info(a,5), mat2str(round(RelB{1}(a,:), 3)));
end
fprintf('  bins of height above the stand [mm]: %s\n', mat2str(ed));
fprintf('  samples per bin (h = 3), summed over lift-offs: normal %s | lowered %s\n', ...
        mat2str(sum(nSamp(st == 1, :), 1)), mat2str(sum(nSamp(st == 2, :), 1)));
c = baseOK;  chkp(c, sprintf('every lift-off has its own baseline (>= 3 samples at 10.3-10.9 mm, >= 0.95 mm above the stand; %d lift-offs)', size(info,1)));
nP = nP + c;  nF = nF + ~c;
c = abs(lagSlope) < 3;
chkp(c, sprintf('no detectable current-to-force lag at 9.5-10.75 mm (slope %+.1f ms)', lagSlope));  nP = nP + c;  nF = nF + ~c;

%% ---- 2. static reference: the slow ramp (as s18 B) -------------------------------
a2 = read_scope_fig(fullfile(d16, 'ramp_39g_main.fig'));  b2 = read_scope_fig(fullfile(d16, 'ramp_39g_iref.fig'));
close all force;
r = struct('t', b2.t, 'x', a2.y(:,1), 'i', a2.y(:,3), 'u', a2.y(:,4), 'xr', b2.y(:,3), 'tau', b2.y(:,4));
kOn = find(r.u > 0.01, 1);  r.xRest = median(r.x(r.t > 0.3 & r.t < r.t(kOn) - 0.05));
h1 = r.tau > 6 & r.tau < 9.8;  h2 = r.tau > 20 & r.tau < 23.8;
drift = (mean(r.i(h2)) - mean(r.i(h1)))/(mean(r.tau(h2)) - mean(r.tau(h1)));  ic = r.i - drift*(r.tau - mean(r.tau(h1)));
rp = (r.tau >= 10 & r.tau < 14.5) | (r.tau >= 14.5 & r.tau < 19);
edR = 10.5:0.05:11.4 + 1e-9;  cR = edR(1:end-1) + 0.025;  im = zeros(size(cR));
for k = 1:numel(cR), s = rp & 1e3*r.xr >= edR(k) & 1e3*r.xr < edR(k+1);  im(k) = mean(ic(s)); end
hsR = 1e3*r.xRest - cR;  far = hsR >= 0.95;
Af = @(x) [ones(numel(x), 1), exp(1e-3*x(:)/(2*lam))];
cf = Af(cR(far))\im(far)';  iFit = Af(cR)*cf;
fxS = ((iFit' - cf(1))./(im - cf(1))).^2;            % force needed / force the law gives at the measured current
fprintf('\n==== 2. Static reference: slow ramp, 39 g, normal stand (rest %.2f mm) ====\n', 1e3*r.xRest);
fprintf('  height above stand [mm]: %s\n  fx_static             : %s\n', mat2str(round(hsR, 2)), mat2str(round(fxS, 3)));
fxSb = arrayfun(@(b) mean(fxS(hsR >= ed(b) & hsR < ed(b+1))), 1:nb);
s45 = hsR >= 0.4 & hsR < 0.5;
c = mean(fxS(s45)) > 1.05;
chkp(c, sprintf('ramp reproduces s18: fx_static %.3f at 0.4-0.5 mm above the stand (> 1.05)', mean(fxS(s45))));  nP = nP + c;  nF = nF + ~c;

%% ---- 3. dynamic vs static per bin ------------------------------------------------
fprintf('\n==== 3. Lift-offs vs the ramp, by height above the stand ====\n');
fprintf('  bin [mm]   | ramp fx | normal stand h=3: mean +- se (n) | h=5            | lowered stand h=3 (n) | h=5\n');
mN = zeros(2, nb);  sN = mN;  mL = mN;  nN = mN;  nL = mN;
for jh = 1:2
    Rl = RelB{jh};
    for b = 1:nb
        v = Rl(st == 1, b);  v = v(~isnan(v));  w = Rl(st == 2, b);  w = w(~isnan(w));
        mN(jh, b) = mean(v);  sN(jh, b) = std(v)/sqrt(max(numel(v), 1));  nN(jh, b) = numel(v);
        mL(jh, b) = mean(w);  nL(jh, b) = numel(w);
    end
end
for b = 1:nb
    fprintf('  %.1f-%.1f    | %s   | %.3f +- %.3f (%2d)            | %.3f +- %.3f   | %s (%d)           | %s\n', ed(b), ed(b+1), ...
            num2s(fxSb(b)), mN(1,b), sN(1,b), nN(1,b), mN(2,b), sN(2,b), num2s(mL(1,b)), nL(1,b), num2s(mL(2,b)));
end
nearB = cen < 0.7;                                   % bins where the ramp shows the effect
okB = nearB & nN(1,:) >= 3;                         % bins with >= 3 normal-stand lift-offs
gapZ = (fxSb(okB) - mN(1, okB))./sN(1, okB);
feels = all(abs(gapZ) < 2);
chkp(true, sprintf(['[record] normal stand, bins %s mm above the stand (>= 3 lift-offs each): per-sample Newton values %s the ramp''s ' ...
     'extra force (ramp %s vs lift-offs %s, n = %s; difference %s se; h = 5: %s) -- BUT see 3b: blurred by the stencil'], mat2str(ed([find(okB, 1), find(okB, 1, 'last') + 1])), ...
     subsref({'do NOT show', 'DO show'}, substruct('{}', {1 + feels})), mat2str(round(fxSb(okB), 3)), ...
     mat2str(round(mN(1, okB), 3)), mat2str(nN(1, okB)), mat2str(round(gapZ, 1)), mat2str(round(mN(2, okB), 3))));
nP = nP + 1;
chkp(true, sprintf(['[record] lowered stand (2 lift-offs): lift-offs with a value per bin %s -> too few to compare ' ...
     '(and those bins lie at x 12.3-13.0 mm, beyond the checked force law)'], mat2str(nL(1, :))));
nP = nP + 1;

%% ---- 3b. would a static force of the ramp's size be visible in a lift-off? ---------------
% Same lift-off detection as liftoff_fx (coil-off gaps < 0.3 s merged); a genuine lift needs the law's upward
% acceleration > 5 m/s^2 while crossing. Extra displacement if the ramp's force factor acted during the
% crossing: 0.5 (fx - 1) a_law t^2.
fprintf('\n==== 3b. Crossing 0.3-0.7 mm above the stand: time, and the effect a static extra force would have ====\n');
fxZ = mean(fxS(hsR >= 0.3 & hsR < 0.7));  PT = [];  g0 = round(0.3/T0);
for q = 1:numel(LR), r = LR{q};  m = mb(r.ball);  c = cB(r.ball);
    off = double(r.u <= 0.01);  on = ~(movmin(off, [g0-1 0]) == 1 | movmin(off, [0 g0-1]) == 1);
    for kon = (find(diff(on) == 1) + 1)'
        if kon < 50, continue, end
        rest = mean(r.x(kon-40:kon-5));  iz = mean(r.i(kon-40:kon-5));  w = kon:min(kon + round(0.1/T0), numel(r.x));
        k1 = w(find(rest - r.x(w) > 0.3e-3, 1));  k7 = w(find(rest - r.x(w) > 0.7e-3, 1));
        if isempty(k1) || isempty(k7), continue, end
        kk = k1:k7;  aLaw = mean(c*max(r.i(kk) - iz, 0).^2.*exp(-r.x(kk)/lam)/m);
        if aLaw < 5, continue, end
        tp = r.t(k7) - r.t(k1);
        PT(end+1, :) = [q, r.stand, 1e3*tp, aLaw, 1e6*0.5*(fxZ - 1)*aLaw*tp^2]; %#ok<AGROW>
    end
end
for a = 1:size(PT, 1)
    fprintf('  %-32s %-8s %4.1f ms | law acceleration %5.1f m/s^2 | extra force x%.3f would add %5.0f um\n', ...
            LRdef{PT(a,1),2}, subsref({'normal', 'LOWERED'}, substruct('{}', {PT(a,2)})), PT(a,3), PT(a,4), fxZ, PT(a,5));
end
stc = 6e3*T0;  nShort = nnz(round(PT(:,3)) < round(stc));
chkp(true, sprintf(['[record] RESOLUTION: %d lift-offs cross 0.3-0.7 mm above the stand in %.0f-%.0f ms (median %.0f); %d of ' ...
     'them faster than the h = 3 Newton stencil (%.0f ms). So each Newton value in that zone averages over heights up to ' ...
     '~1 mm above the stand, where the ramp shows no effect: the per-sample test of section 3 is blurred toward 1 and ' ...
     'CANNOT reject a static force of the ramp''s size (x%.3f), which would move the ball only %.0f-%.0f um (median %.0f) ' ...
     'per crossing, 0.5-15x the 11 um noise std. Lift-offs neither confirm nor refute the static stand effect.'], ...
     size(PT,1), min(PT(:,3)), max(PT(:,3)), median(PT(:,3)), nShort, stc, fxZ, min(PT(:,5)), max(PT(:,5)), median(PT(:,5))));
nP = nP + 1;

%% ---- 4. figure ----------------------------------------------------------------------
fg = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 900 520]);
ax = axes(fg);  hold(ax, 'on');  grid(ax, 'on');
col = P.plot.colors;
pS = plot(ax, hsR, fxS, '-', 'Color', col(1,:), 'LineWidth', 2.2);
Rl = RelB{1};  jit = 0.012;
for a = 1:size(Rl, 1)
    cc = col(2 + (st(a) == 2), :);
    plot(ax, cen + jit*(a - size(Rl,1)/2)/size(Rl,1)*4, Rl(a, :), 'o', 'Color', cc, 'MarkerSize', 4);
end
pN = errorbar(ax, cen, mN(1,:), 2*sN(1,:), 's-', 'Color', col(2,:), 'LineWidth', 1.8, 'MarkerFaceColor', col(2,:));
yline(ax, 1, 'k--');
set(ax, 'XDir', 'reverse');  xlim(ax, [0 1.6]);
xlabel(ax, 'height above the stand  (rest reading - x)  [mm]');  ylabel(ax, 'force needed / force-law force');
legend(ax, [pS pN], {'slow ramp, 16-Nov (quasi-static, 39 g, normal stand)', ...
       sprintf('lift-offs, normal stand: mean \\pm 2 se (%d lifts; dots = each lift)', nnz(st == 1))}, ...
       'Location', 'northwest');
title(ax, {'Force factor near the stand: quasi-static ramp vs lift-offs (Newton, h = 3)', ...
       sprintf('lift-offs cross 0.3-0.7 mm in a median %.0f ms < %.0f ms stencil: their values there are blurred toward 1', ...
               median(PT(:,3)), stc)}, 'Color', 'k', 'FontSize', 11);
exportgraphics(fg, fullfile(P.dir.figs, 'p16_liftoff_stand_height.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');
close(fg);

fprintf('\nTOTAL: %d PASS, %d FAIL\n', nP, nF);

%% ======================= local functions ================================
function Ev = liftoff_fx(LR, h, lam, cB, mb, g, T0)
% Force factor per sample during every lift-off. Based on s13 liftoff_fx; adds the lift id, the height above
% the stand and the stencil-off-the-stand condition (see header, NEW 1-2).
% rows of Ev: [lift id, run, stand, x mm, hs mm, fx, di/dt A/s, i - i_z A]
tri = [1:h, h-1:-1:1]'/h^2;  g0 = round(0.3/T0);  Ev = [];  id = 0;
for q = 1:numel(LR), r = LR{q};  m = mb(r.ball);  c = cB(r.ball);
    am = nan(size(r.x));  kk = h+1:numel(r.x)-h;  am(kk) = (r.x(kk+h) - 2*r.x(kk) + r.x(kk-h))/(h*T0)^2;
    xf = conv(r.x, tri, 'same');  itf = conv(r.i, tri, 'same');  di = [0; diff(itf)]/T0;
    xmax = movmax(r.x, [h h]);                              % largest reading in the stencil k-h..k+h (closest to the stand)
    off = double(r.u <= 0.01);
    on = ~(movmin(off, [g0-1 0]) == 1 | movmin(off, [0 g0-1]) == 1);
    for kon = (find(diff(on) == 1) + 1)'
        if kon < 50, continue, end
        rest = mean(r.x(kon-40:kon-5));  iz = mean(r.i(kon-40:kon-5));
        w = kon:min(kon + round(0.3/T0), numel(r.x) - h);
        sel = w(xf(w) < rest - 0.1e-3 & itf(w) - iz > 0.3 & xmax(w) < rest - 0.05e-3);
        if isempty(sel), continue, end
        id = id + 1;
        fx = m*(g - am(sel))./(c*(itf(sel) - iz).^2.*exp(-xf(sel)/lam));
        Ev = [Ev; id*ones(numel(sel), 1), q*ones(numel(sel), 1), r.stand*ones(numel(sel), 1), 1e3*xf(sel), ...
              1e3*(rest - xf(sel)), fx, di(sel), itf(sel) - iz]; %#ok<AGROW>
    end
end
end

function s = num2s(v)
if isnan(v), s = '  -  '; else, s = sprintf('%.3f', v); end
end
