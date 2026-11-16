% s11_robustness.m   [STANDALONE]
% =========================================================================
% PURPOSE   PS9 deliverables 3+4, robustness part: "guaranteed stability margins over the defined
%           uncertainty range". Uses the linear model of s10 (data/linear_model.mat).
%             1. the loop, broken at the coil command u (the ONE point every feedback path passes)
%             2. margins at every point of the uncertainty grid (1458 cases, including the loop delay):
%                M_s (peak |S|), the stable gain range [k_low, k_high], phase margin, delay margin
%             3. checks of the loop model: fractional-delay loop = whole-sample loop at d = 0 and 1; sign
%                test; the nonlinear simulation agrees on both gain limits
%             4. Exp C (kg 0.4 .. 2.0, all stable in the lab) vs the model with the measured delay
%             5. robust stability: multiplicative uncertainty, |W T| < 1 (sufficient test)
%             6. integral clamp and bias current i0: simulation-only check of fixes (variant D)
% LOOP DELAY (revised 2026-11-15) extra delay d beyond the normal ZOH step, measured in s12: nominal 0.5,
%           range 0.3-0.6 sample (maglev_cases, B.dly). The plant is discretized EXACTLY with the fractional
%           input delay (c2d with InputDelay, then absorbDelay). Before 2026-11-15 the set was d = 0 / +1
%           sample (not observable then); both are kept only as reference rows.
% CRITERIA  (chosen before the run; standard values, e.g. Skogestad & Postlethwaite ch. 2)
%           required: closed loop stable at EVERY grid point
%           target  : worst M_s <= 2 over the whole set (=> gain range at least [0.67, 2], phase margin
%                     at least 29 deg)
%           target  : delay margin of the nominal loop (on top of the measured d) >= 1 sample (3 ms)
% LOOP      x, v, i = deviations from the operating point. Controller exactly as deployed:
%             i_ref = Kp e + Kd (x[k] - x[k-1])/T0 + Ki z,  z[k+1] = z[k] + T0 e,  e = x - x_ref
%             u_c   = kg * ( i_ref/kaC + Kc (i_ref - i) )
%           H(z) = map from a signal w injected as the plant input to u_c. Closing the loop means
%           w = u_c, i.e. 1 - H = 0. With L = -H this is the usual 1 + L = 0, S = 1/(1+L), T = L/(1+L).
% SIGNS     all gains positive with e = x - x_ref (manual convention). Section 3 negates them and
%           expects an unstable loop.
% OUTPUTS   console PASS/FAIL, data/robustness.mat, figs/p8_margins.png, figs/p8_WT.png,
%           figs/p8_WT_options.png, figs/p8_clamp_fix.png
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
nP = 0;  nF = 0;
function_chk = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
g = P.g;  mB = [0.039288 0.042137];  bName = {'39 g', '42 g'};
D = load(fullfile(P.dir.data, 'linear_model.mat'), 'LM');  LM = D.LM;
[~, B] = maglev_cases(P);
C = B.C;  C.zLim = C.iLim/C.Ki;  T = B.L.T0;  kaC = B.L.kaC;  umax = B.L.umax;
lam = LM.lam;  cB = LM.cB;  tauN = LM.tau;  kaN = LM.ka;  xStand = B.pl39.xStand;
dN = B.dly.nom;  dLo = B.dly.lo;  dHi = B.dly.hi;  dSet = [dLo dN dHi];
ieqF = @(bi, x0, fl, fc) sqrt(mB(bi)*g*exp(x0/(fl*lam))/(fc*cB(bi)));
wg = logspace(log10(2*pi*0.05), log10(0.999*pi/T), 1500);      % [rad/s] up to Nyquist (166.7 Hz)
fHz = wg/(2*pi);
fprintf('Loop delay (s12, via maglev_cases): nominal d = %.1f sample, range %.1f-%.1f (measured %.2f-%.2f)\n', ...
        dN, dLo, dHi, B.dly.measured);

%% ---- 1. nominal loop ----------------------------------------------------------
fprintf('\n==== 1. Nominal loop (39 g, 10 mm, d = %.1f), broken at the coil command u ====\n', dN);
nomP = struct('a21', g/lam, 'b', 2*g/ieqF(1, 0.010, 1, 1), 'tau', tauN, 'ka', kaN, 'd', dN);
[Ln, An] = loop_u(C, T, kaC, nomP, 1);
Mn = margins(Ln, An, wg, T);
print_m(sprintf('nominal, d = %.1f', dN), Mn);
MR = struct('d', {}, 'M', {});
for dr = [0 dLo dHi 1]
    pr = nomP;  pr.d = dr;  [Lr, Ar] = loop_u(C, T, kaC, pr, 1);  MR(end+1) = struct('d', dr, 'M', margins(Lr, Ar, wg, T)); %#ok<SAGROW>
    tag = '';  if dr == 0, tag = ' (model before 2026-11-15)'; elseif dr == 1, tag = ' (stress, outside the range)'; end
    print_m(sprintf('nominal, d = %.1f%s', dr, tag), MR(end).M);
end

%% ---- 2. the uncertainty grid ----------------------------------------------------
fprintf('\n==== 2. Margins over the uncertainty grid ====\n');
% ball x gap x lam x c x tau x ka x delay = 2 x 3 x 3 x 3 x 3 x 3 x 3 = 1458 points
G = [];  % rows: [ball x0 fl fc tau ka d | Ms kLow kHigh PM DM_s stable]
Sall = cell(0);
for dq = dSet, for bi = 1:2, for x0 = [9 10 11]*1e-3, for fl = [0.95 1 1.05], for fc = [0.95 1 1.05]
for tq = [0.020 0.027 0.035], for kq = [2.2 kaN 2.7]
    pq = struct('a21', g/(fl*lam), 'b', 2*g/ieqF(bi, x0, fl, fc), 'tau', tq, 'ka', kq, 'd', dq);
    [Lq, Aq] = loop_u(C, T, kaC, pq, 1);
    M = margins(Lq, Aq, wg, T);
    G(end+1, :) = [bi x0 fl fc tq kq dq M.Ms M.kLow M.kHigh M.PM M.DM M.stable]; %#ok<SAGROW>
    Sall{end+1} = M.Sabs; %#ok<SAGROW>
end, end, end, end, end, end, end
Sall = cell2mat(Sall);                                 % 1500 x 1458
for dq = dSet
    r = G(abs(G(:,7) - dq) < 1e-9, :);
    [~, iw] = max(r(:,8));
    fprintf(['  d = %.1f: %d points, all stable: %s | worst Ms %.2f, kLow max %.2f, kHigh min %.2f, ' ...
             'PM min %.1f deg, DM min %.1f ms\n'], dq, size(r,1), string(all(r(:,13) == 1)), max(r(:,8)), ...
            max(r(:,9)), min(r(:,10)), min(r(:,11)), 1e3*min(r(:,12)));
    fprintf('     worst-Ms point: %s, %.0f mm, lam %+.0f %%, c %+.0f %%, tau %.0f ms, ka %.2f\n', ...
            bName{r(iw,1)}, 1e3*r(iw,2), 100*(r(iw,3)-1), 100*(r(iw,4)-1), 1e3*r(iw,5), r(iw,6));
end
nmP = {'ball', 'gap', 'lam', 'c', 'tau', 'ka', 'd'};
fprintf('  worst Ms per parameter level: ');
for j = 1:7
    lv = unique(G(:,j))';  w = arrayfun(@(v) max(G(G(:,j) == v, 8)), lv);
    fprintf('%s %s | ', nmP{j}, mat2str(round(w, 2)));
end
fprintf('\n');
for bi = 1:2                                           % provisional 11.5 mm points (nominal parameters)
    pq = struct('a21', g/lam, 'b', 2*g/ieqF(bi, 0.0115, 1, 1), 'tau', tauN, 'ka', kaN, 'd', dN);
    [Lq, Aq] = loop_u(C, T, kaC, pq, 1);  M = margins(Lq, Aq, wg, T);
    print_m(sprintf('%s at 11.5 mm (provisional), d %.1f', bName{bi}, dN), M);
end
c = all(G(:,13) == 1);  function_chk(c, sprintf('closed loop stable at all %d grid points (delay 0.3-0.6 included)', size(G,1)));
nP = nP + c;  nF = nF + ~c;
c = max(G(:,8)) <= 2;  function_chk(c, sprintf('worst Ms <= 2 over the whole set (got %.2f)', max(G(:,8))));  nP = nP + c;  nF = nF + ~c;
c = Mn.DM >= T;  function_chk(c, sprintf('nominal delay margin on top of d = %.1f >= 1 sample (got %.1f ms = %.2f samples)', ...
    dN, 1e3*Mn.DM, Mn.DM/T));  nP = nP + c;  nF = nF + ~c;

%% ---- 3. checks of the loop model ------------------------------------------------
fprintf('\n==== 3. Loop-model checks ====\n');
dev = 0;
for dr = [0 1]
    pr = nomP;  pr.d = dr;  [La, Aa] = loop_u(C, T, kaC, pr, 1);  [Lb, Ab] = loop_u_int(C, T, kaC, pr, 1);
    Ma = margins(La, Aa, wg, T);  Mb = margins(Lb, Ab, wg, T);
    dev = max([dev, abs(Ma.Ms - Mb.Ms), abs(Ma.kLow - Mb.kLow), abs(Ma.kHigh - Mb.kHigh), abs(Ma.PM - Mb.PM)]);
end
c = dev < 1e-6;
function_chk(c, sprintf(['fractional-delay loop = the earlier whole-sample loop at d = 0 and d = 1 (Ms, gain ' ...
    'range, PM; largest difference %.1e)'], dev));  nP = nP + c;  nF = nF + ~c;
[~, Aw] = loop_u(C, T, kaC, nomP, -1);
rhoW = max(abs(eig(Aw)));
c = rhoW > 1;  function_chk(c, sprintf('all controller gains negated -> unstable (max|eig| %.3f)', rhoW));  nP = nP + c;  nF = nF + ~c;
S = allmargin(Ln);  gm = S.GainMargin;
gmL = max([gm(gm < 1), 0]);  gmH = min([gm(gm > 1), Inf]);
c = abs(gmL/Mn.kLow - 1) < 0.01 && abs(gmH/Mn.kHigh - 1) < 0.01;
function_chk(c, sprintf('gain range from allmargin [%.3f, %.3f] = eigenvalue sweep [%.3f, %.3f]', gmL, gmH, Mn.kLow, Mn.kHigh));
nP = nP + c;  nF = nF + ~c;
pr = nomP;  pr.d = dN + 1;  [Lr, Ar] = loop_u(C, T, kaC, pr, 1);  Mp1 = margins(Lr, Ar, wg, T);
c = (Mn.DM >= T) == Mp1.stable;
function_chk(c, sprintf('delay margin %.2f samples is consistent with the loop at d + 1 sample being %s', Mn.DM/T, ...
    ternary(Mp1.stable, 'stable', 'unstable')));  nP = nP + c;  nF = nF + ~c;
% the NONLINEAR simulation (with the same delay) must agree on BOTH gain limits (integral clamp opened).
% (Revised in the first version after a FAIL: the upper limit is a Nyquist-frequency mode of the inner
% current loop that shows in u, not x, so the check looks at u AND x.)
plN = struct('m', mB(1), 'lam', lam, 'c', cB(1), 'ioff', 0, 'tau', tauN, 'ka', kaN, 'ci', 0);
Cw = C;  Cw.zLim = 10;  Lf = struct('T0', T, 'ka', kaC, 'umax', umax);
[Aq, Bq, Cq] = ssdata(Ln);
kgT = [0.92*Mn.kHigh, 1.08*Mn.kHigh, 1.08*Mn.kLow, 0.92*Mn.kLow];  expUnst = [0 1 0 1];  isUnst = false(1, 4);
fprintf('  nonlinear sim at 10 mm, d = %.1f, start 0.02 mm off, 3 s; last 0.5 s: std(u), rms(x - 10 mm)\n', dN);
for q = 1:4
    i0 = ieqF(1, 0.010, 1, 1);  iref = (i0/(kaN*kgT(q)) + C.Kc*i0)/(1/kaC + C.Kc);
    o = struct('x0', 0.010 + 0.02e-3, 'i0s', i0, 'z0', (iref - C.i0)/C.Ki, 'kg', kgT(q), 'xStand', 0.02, ...
               'd', dN, 'uIC', i0/kaN);
    s = maglev_cascade_sim(Cw, Lf, plN, @(t) 0.010, 3.0, o);
    late = s.t > 2.5;  su = std(s.u(late));  ex = rms(s.x(late) - 0.010);
    isUnst(q) = su > 0.02 || ex > 0.05e-3;
    ev = eig(Aq - kgT(q)*Bq*Cq);  [rr, j] = max(abs(ev));
    fprintf('    kg %.3f (%s): std(u) %.1e, rms x %.1e mm -> %s | linear: max|eig| %.3f, mode %.1f Hz\n', kgT(q), ...
            ternary(q <= 2, sprintf('%.2f k_high', kgT(q)/Mn.kHigh), sprintf('%.2f k_low', kgT(q)/Mn.kLow)), ...
            su, 1e3*ex, ternary(isUnst(q), 'UNSTABLE', 'settles'), rr, abs(angle(ev(j)))/(2*pi*T));
end
c = isequal(isUnst, logical(expUnst));
function_chk(c, 'nonlinear simulation (same delay) settles just inside both gain limits and not just outside them');
nP = nP + c;  nF = nF + ~c;

%% ---- 4. Exp C vs the model with the measured delay -----------------------------------
fprintf('\n==== 4. Exp C (39 g at 10 mm, kg 0.4 .. 2.0: all stable in the lab) vs the model ====\n');
for dq = dSet
    eq = G(G(:,1) == 1 & abs(G(:,2) - 0.010) < 1e-9 & abs(G(:,7) - dq) < 1e-9, :);
    fprintf(['  d = %.1f, %d grid points: k_high %.2f .. %.2f, k_low %.2f .. %.2f -> stable at kg 2.0: %d, ' ...
             'at kg 0.4: %d, at both: %d\n'], dq, size(eq,1), min(eq(:,10)), max(eq(:,10)), min(eq(:,9)), ...
            max(eq(:,9)), nnz(eq(:,10) > 2.0), nnz(eq(:,9) < 0.4), nnz(eq(:,10) > 2.0 & eq(:,9) < 0.4));
end
e3 = G(G(:,1) == 1 & abs(G(:,2) - 0.010) < 1e-9, :);
bad = e3(e3(:,9) >= 0.4 | e3(:,10) <= 2.0, :);
for k = 1:size(bad, 1)
    fprintf('    contradicted by Exp C (unstable at kg %s): d %.1f, lam %+.0f %%, c %+.0f %%, tau %.0f ms, ka %.2f\n', ...
            ternary(bad(k,9) >= 0.4, '0.4', '2.0'), bad(k,7), 100*(bad(k,3)-1), 100*(bad(k,4)-1), 1e3*bad(k,5), bad(k,6));
end
c = Mn.kLow < 0.4 && Mn.kHigh > 2.0;
function_chk(c, sprintf(['the nominal model with the measured delay reproduces Exp C: stable for kg 0.4 .. 2.0 ' ...
    '(predicted range %.3f .. %.2f)'], Mn.kLow, Mn.kHigh));  nP = nP + c;  nF = nF + ~c;

%% ---- 5. robust stability: |W T| < 1 ----------------------------------------------------
fprintf('\n==== 5. Robust stability, multiplicative uncertainty at u (|W T| < 1, sufficient) ====\n');
% Every grid plant gives a loop L_k = L_nom (1 + delta_k). If |delta_k(w)| <= W(w) for all k and the
% loops have the same unstable poles, the loop is stable for ALL of them when |W T_nom| < 1 at every w.
% W = 1.1 x envelope of |delta_k| over the grid plants; interior coverage is checked with random plants
% (all parameters, including d, drawn uniformly inside their ranges).
nR = 400;  rng(5);
pAll = arrayfun(@(k) struct('a21', g/(G(k,3)*lam), 'b', 2*g/ieqF(G(k,1), G(k,2), G(k,3), G(k,4)), ...
                'tau', G(k,5), 'ka', G(k,6), 'd', G(k,7)), 1:size(G,1));
smpAll = @() rand_plant(g, lam, ieqF, randi(2), 0.009 + 0.002*rand, dLo, dHi);
O0 = wt_test(C, T, kaC, nomP, pAll, smpAll, nR, wg);
Wpar = O0.W;  Tn = O0.Tn;  WTp = O0.WTp;  pkP = O0.pkP;
fprintf('  one disk around 39 g, 10 mm, d %.1f (%d grid plants): max |W T| = %.2f at %.1f Hz | interior |delta|/W %.2f\n', ...
        dN, numel(pAll), pkP, O0.fP/(2*pi), O0.ratio);
c = O0.ratio <= 1;  function_chk(c, 'W (grid envelope + 10 %) covers random plants between the grid points');  nP = nP + c;  nF = nF + ~c;
c = pkP < 1;  function_chk(c, 'robust stability guaranteed with ONE disk for the whole set (|W T| < 1)');  nP = nP + c;  nF = nF + ~c;
% ---- 5b. two less conservative versions of the same test (added after the one-disk test failed) ----
%   Option 1: same set, nominal moved to the middle of each coefficient range (a21, b, tau, ka, d).
%   Option 2: the set split by operating point: ball x gap range [9,10] or [10,11] mm, each with its own
%             nominal (mid gap, nominal lam, c, tau, ka, d) and its own W. Together they cover 9-11 mm.
% Both are still sufficient tests; the nominal used for the TEST need not be the design point.
fprintf('\n  ---- 5b. Less conservative versions (added after the one-disk test failed) ----\n');
a21v = [pAll.a21];  bv = [pAll.b];
nomC = struct('a21', mean([min(a21v) max(a21v)]), 'b', mean([min(bv) max(bv)]), 'tau', 0.0275, 'ka', 2.45, ...
              'd', mean([dLo dHi]));
O1 = wt_test(C, T, kaC, nomC, pAll, smpAll, nR, wg);
fprintf('  Option 1, centred nominal (a21 %.0f, b %.2f, tau %.1f ms, ka %.2f, d %.2f): max |W T| %.2f at %.1f Hz | interior %.2f\n', ...
        nomC.a21, nomC.b, 1e3*nomC.tau, nomC.ka, nomC.d, O1.pkP, O1.fP/(2*pi), O1.ratio);
c = O1.pkP < 1 && O1.ratio <= 1;
function_chk(c, 'Option 1: robust stability guaranteed for the whole set (|W T| < 1, W covers interior plants)');
nP = nP + c;  nF = nF + ~c;
regs = [1 9 10; 1 10 11; 2 9 10; 2 10 11];          % [ball, gap from, gap to] in mm
O2 = struct('ball', {}, 'g', {}, 'pkP', {}, 'ratio', {}, 'fP', {}, 'WTp', {}, 'Wu', {}, 'nPl', {}, 'W', {}, 'Tn', {});
for k = 1:size(regs, 1)
    bi = regs(k,1);  gl = regs(k,2:3)*1e-3;  xm = mean(gl);
    nomR = struct('a21', g/lam, 'b', 2*g/ieqF(bi, xm, 1, 1), 'tau', tauN, 'ka', kaN, 'd', dN);
    pR = [];
    for x0 = [gl(1) xm gl(2)], for fl = [0.95 1 1.05], for fc = [0.95 1 1.05], for tq = [0.020 0.027 0.035]
    for kq = [2.2 kaN 2.7], for dq = dSet
        pR = [pR, struct('a21', g/(fl*lam), 'b', 2*g/ieqF(bi, x0, fl, fc), 'tau', tq, 'ka', kq, 'd', dq)]; %#ok<AGROW>
    end, end, end, end, end, end
    o = wt_test(C, T, kaC, nomR, pR, @() rand_plant(g, lam, ieqF, bi, gl(1) + diff(gl)*rand, dLo, dHi), nR, wg);
    O2(end+1) = struct('ball', bi, 'g', regs(k,2:3), 'pkP', o.pkP, 'ratio', o.ratio, 'fP', o.fP, ...
                       'WTp', o.WTp, 'Wu', o.Wu, 'nPl', numel(pR), 'W', o.W, 'Tn', o.Tn); %#ok<AGROW>
    fprintf('  Option 2, %s, %2d-%2d mm (%d grid plants): max |W T| %.2f at %.1f Hz | interior |delta|/W %.2f\n', ...
            bName{bi}, regs(k,2:3), numel(pR), o.pkP, o.fP/(2*pi), o.ratio);
end
c = all([O2.pkP] < 1) && all([O2.ratio] <= 1);
function_chk(c, 'Option 2: robust stability guaranteed in every operating-point region (|W T| < 1, W covers interior plants)');
nP = nP + c;  nF = nF + ~c;
% room left for unmodelled dynamics: robust stability also holds with an extra unstructured
% |delta_u| <= Wu if (W + Wu (1 + W)) |T| < 1. Option 2 regions, worst region at each frequency.
WuR = min([O2.Wu], [], 2);
bands = [0.05 2; 2 10; 10 30; 30 166];
fprintf('  extra unmodelled relative error the loop can still tolerate, Option 2, worst region (min over each band):\n');
fprintf('    band [Hz]    | on top of the parametric set (incl. the delay range)\n');
for j = 1:size(bands, 1)
    s = fHz >= bands(j,1) & fHz < bands(j,2);
    fprintf('    %5.2f - %5.1f | %6.0f %%\n', bands(j,:), 100*min(WuR(s)));
end

%% ---- 6. integral clamp and bias current (simulation only) ---------------------------------
fprintf('\n==== 6. Integral clamp (+-0.3 A) and bias i0 (0.75 A): how much is used, two fixes ====\n');
% integral output needed in steady state:  Ki z = i_ref,eq - i0,
%   i_ref,eq = (ieq/(ka kg) + Kc (ieq + ioff)) / (1/kaC + Kc)   (ioff = current-sensor zero, up to 0.04 A)
%   kg multiplies the controller output BEFORE the 0..0.9 limit (lab model and maglev_cascade_sim), so the
%   command reaching the coil is u = ieq/ka for every kg; the limits that can bind are i_ref <= 2 A and the clamp.
%   (Corrected on recheck: the first version tested ieq/(ka kg) <= 0.9, called the 42 g kg 0.4 case "no
%   equilibrium", and dropped such points from the grid summary.)
need = @(ieq, ka, kg, ioff) (ieq./(ka.*kg) + C.Kc*(ieq + ioff))/(1/kaC + C.Kc);
fprintf(' case                                    | i_eq [A] | i_ref,eq [A] | integral needs [A] | u to coil | feasible (u <= 0.9, i_ref <= 2)?\n');
cs = {'39 g 10 mm nominal', 1, 0.010, 1, 1, kaN, 1;  '42 g 11 mm nominal', 2, 0.011, 1, 1, kaN, 1;
      '42 g 11 mm, lam -5 %, c -5 %, ka 2.2', 2, 0.011, 0.95, 0.95, 2.2, 1;
      '42 g 11.5 mm, lam -5 %, c -5 %, ka 2.2', 2, 0.0115, 0.95, 0.95, 2.2, 1;
      '39 g 10 mm, kg 0.4 (Exp C)', 1, 0.010, 1, 1, kaN, 0.4;  '39 g 11 mm, kg 0.4', 1, 0.011, 1, 1, kaN, 0.4;
      '42 g 11 mm, kg 0.4, ka 2.2', 2, 0.011, 0.95, 0.95, 2.2, 0.4};
NE = zeros(size(cs,1), 3);
for k = 1:size(cs, 1)
    ie = ieqF(cs{k,2}, cs{k,3}, cs{k,4}, cs{k,5});  ir = need(ie, cs{k,6}, cs{k,7}, 0.04);  ue = ie/cs{k,6};
    NE(k, :) = [ie, ir - C.i0, ue];
    fprintf(' %-39s | %.3f    | %.3f        | %+.3f (%3.0f %% of clamp) | %.2f      | %s\n', cs{k,1}, ie, ir, ir - C.i0, ...
            100*(ir - C.i0)/C.iLim, ue, ternary(ue <= umax && ir <= 2, 'yes', 'NO'));
end
% whole grid x kg {0.4, 1, 2} x sensor zero {0, 0.04 A}: integral needed, for i0 0.75 and 0.85
NG = [];
for bi = 1:2, for x0 = [9 10 11]*1e-3, for fl = [0.95 1 1.05], for fc = [0.95 1 1.05], for kq = [2.2 kaN 2.7]
for kgq = [0.4 1 2], for io = [0 0.04]
    ie = ieqF(bi, x0, fl, fc);
    ir = need(ie, kq, kgq, io);  assert(ie/kq <= umax && ir <= 2, 'grid point without an equilibrium');
    % is the linear loop stable at this kg for every tau AND every delay d of the grid (section 2)?
    rows = G(G(:,1) == bi & abs(G(:,2) - x0) < 1e-9 & G(:,3) == fl & G(:,4) == fc & abs(G(:,6) - kq) < 1e-9, :);
    stb = all(rows(:,9) < kgq & rows(:,10) > kgq);
    NG(end+1, :) = [ir, kgq, stb]; %#ok<AGROW>
end, end, end, end, end, end, end
% (added on recheck: at kg 0.4 some grid points are linearly UNSTABLE (k_low > 0.4); there the "integral needed"
%  is meaningless, so the summary is also given for the points that are stable at that kg)
fprintf('\n  whole grid (2 balls x 9-11 mm x lam x c x ka, sensor zero 0 / 0.04 A; %d points, all with an equilibrium):\n', size(NG,1));
for i0o = [0.75 0.85]
    for kgq = [1 0.4 2]
        for onlyStable = [false true]
            q = NG(:,2) == kgq & (NG(:,3) == 1 | ~onlyStable);  wst = max(abs(NG(q,1) - i0o));
            fprintf('    i0 %.2f, kg %.1f, %-34s: integral %+.3f .. %+.3f A -> %3.0f %% of a 0.30 clamp, %3.0f %% of 0.45\n', ...
                    i0o, kgq, ternary(onlyStable, sprintf('points stable at this kg (%d/%d)', nnz(q), nnz(NG(:,2) == kgq)), ...
                    'all points'), min(NG(q,1)) - i0o, max(NG(q,1)) - i0o, 100*wst/0.30, 100*wst/0.45);
        end
    end
end
% options, simulated from the stand with the integral wound up (as in the lab)
% C = the combination chosen by the student (2026-11-15). The 4th case is the plant that lifts off most
% violently (strongest force, highest coil gain): the bigger wound-up integral of C hits it hardest.
% D = C with the integral reset to 0 at switch-on (added 2026-11-15 after C's lift-off proved unsafe).
% zStart: 1 = integral wound up to the clamp at switch-on (lab model today), 0 = reset to 0.
opt = struct('name', {'now: i0 0.75, clamp 0.30', 'A: i0 0.75, clamp 0.45', 'B: i0 0.85, clamp 0.30', ...
                      'C: i0 0.85, clamp 0.45', 'D: C + integral reset'}, 'i0', {0.75, 0.75, 0.85, 0.85, 0.85}, ...
             'iLim', {0.30, 0.45, 0.30, 0.45, 0.45}, 'zStart', {1, 1, 1, 1, 0});
sc = struct('name', {'39 g nominal', '42 g, lam -5 %, c -5 %, ka 2.2', '39 g, kg 0.4', '39 g, lam +5 %, c +5 %, ka 2.7'}, ...
            'bi', {1, 2, 1, 1}, 'fl', {1, 0.95, 1, 1.05}, 'fc', {1, 0.95, 1, 1.05}, 'ka', {kaN, 2.2, kaN, 2.7}, ...
            'kg', {1, 1, 0.4, 1});
xr = @(t) 0.011 - 0.0005*(t >= 3) + 0.0005*(t >= 5);       % lift to 11 mm, 10.5 mm at 3 s, 11 mm at 5 s (lab-size steps)
% (corrected on the second recheck: the first version reported min x over the WHOLE run as "highest point
%  during lift-off"; when the lift-off does not overshoot (D), that minimum is the 11 -> 10.5 mm up-step's
%  overshoot instead. Both are now reported: lift-off = before the first step at 3 s.)
R = struct('opt', {}, 'sc', {}, 's', {}, 'lift', {}, 'xmin', {}, 'xLift', {}, 'ipk', {}, 'eEnd', {}, 'e10', {});
fprintf(['\n option                      | case                           | lifts by 0.5 s | min x [mm]: lift-off / whole run | ' ...
         'peak i [A] (sensor reading = true + 0.04) | |error| [mm] 11 mm (2.5 s) / 10.5 mm / 11 mm (end) | back on stand after lift\n']);
for a = 1:numel(opt)
    Co = C;  Co.i0 = opt(a).i0;  Co.zLim = opt(a).iLim/C.Ki;
    for q = 1:numel(sc)
        pl = struct('m', mB(sc(q).bi), 'lam', sc(q).fl*lam, 'c', sc(q).fc*cB(sc(q).bi), 'ioff', 0.04, ...
                    'tau', tauN, 'ka', sc(q).ka, 'ci', 0.04);
        o = struct('x0', xStand, 'xStand', xStand, 'i0s', 0.04, 'z0', opt(a).zStart*Co.zLim, 'kg', sc(q).kg, ...
                   'd', dN);                     % measured loop delay; delay line starts at 0 (coil off)
        s = maglev_cascade_sim(Co, Lf, pl, xr, 7.0, o);
        kL = find(s.x < xStand - 0.2e-3, 1);  lift = ~isempty(kL) && s.t(kL) < 0.5;
        e11 = mean(abs(s.x(s.t > 2.5 & s.t < 3) - 0.011));
        e10 = mean(abs(s.x(s.t > 4.5 & s.t < 5) - 0.0105));  eE = mean(abs(s.x(s.t > 6.5) - 0.011));
        touch = ~isempty(kL) && any(s.x(min(kL + 50, end):end) >= xStand - 1e-6);
        xLift = min(s.x(s.t < 3));
        R(end+1) = struct('opt', a, 'sc', q, 's', s, 'lift', lift, 'xmin', min(s.x), 'xLift', xLift, 'ipk', max(s.i), ...
                          'eEnd', eE, 'e10', e10); %#ok<SAGROW>
        fprintf(' %-27s | %-30s | %-14s | %6.2f / %6.2f                  | %5.2f      | %.3f / %.3f / %.3f                         | %s\n', ...
                opt(a).name, sc(q).name, string(lift), 1e3*xLift, 1e3*min(s.x), max(s.i), 1e3*e11, 1e3*e10, 1e3*eE, string(touch));
    end
end
fixOK = arrayfun(@(a) all([R([R.opt] == a).lift]) && all([R([R.opt] == a).eEnd] < 0.02e-3), 1:numel(opt));
for a = 1:numel(opt)
    fprintf('  %-27s: every case lifts within 0.5 s and ends within 0.02 mm of 11 mm: %s\n', opt(a).name, string(fixOK(a)));
end
c = all([R.ipk] < 2.2) && all([R.xmin] > 6e-3);
function_chk(c, 'every option and case: peak current < 2.2 A, ball never closer than 6 mm to the magnet');  nP = nP + c;  nF = nF + ~c;
c = fixOK(4);
function_chk(c, 'combination C: every case lifts within 0.5 s and ends within 0.02 mm of the set point');  nP = nP + c;  nF = nF + ~c;
rC = R([R.opt] == 4);  rN = R([R.opt] == 1);
rD = R([R.opt] == 5);
fprintf('  highest point during lift-off (before the first step), per case [mm]: now %s | C %s | D %s\n', ...
        mat2str(round(1e3*[rN.xLift], 2)), mat2str(round(1e3*[rC.xLift], 2)), mat2str(round(1e3*[rD.xLift], 2)));
fprintf('  peak current reading per case [A] (true current + 0.04 A sensor zero): now %s | C %s | D %s\n', mat2str(round([rN.ipk], 2)), mat2str(round([rC.ipk], 2)), ...
        mat2str(round([rD.ipk], 2)));
c = fixOK(5) && all([rD.xmin] >= 8e-3) && all([rD.ipk] < 2.2);
function_chk(c, sprintf(['variant D: every case lifts within 0.5 s, ends within 0.02 mm, never closer than 8 mm to the ' ...
    'magnet over the whole run (worst %.2f mm; lift-off alone %.2f mm), peak current < 2.2 A (worst %.2f A)'], ...
    1e3*min([rD.xmin]), 1e3*min([rD.xLift]), max([rD.ipk])));  nP = nP + c;  nF = nF + ~c;
fprintf('  NOTE: the clamp and i0 do not appear in the linear loop, so sections 1-5 are unchanged by either fix.\n');
fprintf('        Any change needs a lab slot before it is used on the hardware.\n');

%% ---- 7. figures -----------------------------------------------------------------------
col = P.plot.colors;  grey = [0.75 0.75 0.75];
f1 = figure('Position', [80 80 1150 800]);
tl = tiledlayout(2, 2, 'TileSpacing', 'compact');
ax = nexttile; hold on; grid on;
plot(fHz, Sall, '-', 'Color', grey, 'LineWidth', 0.5, 'HandleVisibility', 'off');
plot(fHz, Mn.Sabs, '-', 'Color', col(1,:));
yline(2, 'k--', 'M_s = 2', 'LabelHorizontalAlignment', 'left');
set(ax, 'XScale', 'log');  xlim(fHz([1 end]));  ylim([0 2.5]);
xlabel('frequency [Hz]');  ylabel('|S| at the coil command');
title(sprintf('|S|: worst M_s %.2f (grey: %d grid points, d %.1f-%.1f)', max(G(:,8)), size(G,1), dLo, dHi), 'Color', 'k');
legend({sprintf('nominal 39 g, 10 mm, d %.1f', dN)}, 'Location', 'northwest');
ax = nexttile; hold on; grid on;
for k = 1:numel(MR), plot(fHz, MR(k).M.Sabs, '-', 'Color', col(k,:)); end
plot(fHz, Mn.Sabs, 'k-', 'LineWidth', 2.2);
yline(2, 'k--', 'M_s = 2', 'LabelHorizontalAlignment', 'left');
set(ax, 'XScale', 'log');  xlim(fHz([1 end]));  ylim([0 2.6]);
xlabel('frequency [Hz]');  ylabel('|S| at the coil command');
legend([arrayfun(@(m) sprintf('d %.1f: M_s %.2f', m.d, m.M.Ms), MR, 'UniformOutput', false), ...
        {sprintf('d %.1f (nominal): M_s %.2f', dN, Mn.Ms)}], 'Location', 'west');
title('|S| of the nominal loop vs the extra delay d', 'Color', 'k');
ax = nexttile; hold on; grid on;
mk = {'o', '+', 'x'};
for q = 1:3
    r = G(abs(G(:,7) - dSet(q)) < 1e-9, :);
    plot(r(:,9), r(:,10), mk{q}, 'Color', col(q,:), 'MarkerSize', 4);
end
xline(0.4, 'k--');  yline(2.0, 'k--');
patch([0 0.4 0.4 0], [2 2 11 11], col(4,:), 'FaceAlpha', 0.12, 'EdgeColor', 'none');
xlabel('k_{low}: smallest stable gain on u');  ylabel('k_{high}: largest stable gain on u');
legend([arrayfun(@(d) sprintf('d %.1f', d), dSet, 'UniformOutput', false), {'', '', 'contains the lab range 0.4 - 2.0'}], ...
       'Location', 'northeast');
title('Stable gain range at every grid point', 'Color', 'k');  xlim([0 0.6]);  ylim([1 ceil(max(G(:,10))) + 3.5]);
ax = nexttile; hold on; grid on;
for q = 1:3
    r = G(abs(G(:,7) - dSet(q)) < 1e-9, :);
    histogram(1e3*r(:,12), 0:0.25:12, 'FaceColor', col(q,:), 'FaceAlpha', 0.5);
end
xline(1e3*T, 'k--', '1 sample');
xlabel('delay margin on top of d [ms]');  ylabel('grid points');
legend(arrayfun(@(d) sprintf('d %.1f', d), dSet, 'UniformOutput', false));
title('Delay margin', 'Color', 'k');
exportgraphics(f1, fullfile(P.dir.figs, 'p8_margins.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

f2 = figure('Position', [80 80 1000 760]);
tl2 = tiledlayout(2, 1, 'TileSpacing', 'compact');
ax = nexttile; hold on; grid on;
plot(fHz, O0.dl(:, 1:3:end), '-', 'Color', grey, 'LineWidth', 0.5, 'HandleVisibility', 'off');
plot(fHz, Wpar, '-', 'Color', col(1,:));  plot(fHz, 1./Tn, 'k-');
set(ax, 'XScale', 'log', 'YScale', 'log');  xlim(fHz([1 end]));  ylim([1e-3 1e2]);
ylabel('relative loop error');
legend({'W (grid envelope + 10 %)', '1/|T| (allowed)'}, 'Location', 'northwest');
title(sprintf('Multiplicative uncertainty at u, one disk (grey: every 3rd of the %d grid plants)', size(G,1)), 'Color', 'k');
ax = nexttile; hold on; grid on;
plot(fHz, WTp, '-', 'Color', col(1,:));  yline(1, 'k--', 'limit 1');
set(ax, 'XScale', 'log');  xlim(fHz([1 end]));  xlabel('frequency [Hz]');  ylabel('|W T|');
legend({sprintf('one disk: max %.2f', pkP)}, 'Location', 'northwest');
title('Robust stability test |W T| < 1 (one disk; see p8\_WT\_options for the split version)', 'Color', 'k');
exportgraphics(f2, fullfile(P.dir.figs, 'p8_WT.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

f4 = figure('Position', [80 80 1000 460]); hold on; grid on;
plot(fHz, WTp, '-', 'Color', grey, 'LineWidth', 2.5);
plot(fHz, O1.WTp, '-', 'Color', col(1,:), 'LineWidth', 2.2);
lsty = {'-', '--', '-', '--'};
for k = 1:numel(O2)
    plot(fHz, O2(k).WTp, lsty{k}, 'Color', col(2 + (O2(k).ball == 2), :), 'LineWidth', 1.5);
end
yline(1, 'k--', 'limit 1');
set(gca, 'XScale', 'log');  xlim(fHz([1 end]));  xlabel('frequency [Hz]');  ylabel('|W T|');
legend([{sprintf('one disk around 39 g, 10 mm: max %.2f', pkP), sprintf('Option 1, centred nominal: max %.2f', O1.pkP)}, ...
        arrayfun(@(o) sprintf('Option 2, %s, %d-%d mm: max %.2f', bName{o.ball}, o.g, o.pkP), O2, 'UniformOutput', false)], ...
       'Location', 'northwest', 'FontSize', 10);
title('Robust stability |W T| < 1, parametric set: the three ways of drawing the uncertainty', 'Color', 'k');
exportgraphics(f4, fullfile(P.dir.figs, 'p8_WT_options.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

f3 = figure('Position', [80 80 1100 750]);
tl3 = tiledlayout(numel(sc), 1, 'TileSpacing', 'compact');
for q = 1:numel(sc)
    ax = nexttile; hold on; grid on;
    for a = 1:numel(opt)
        rr = R([R.opt] == a & [R.sc] == q);  plot(rr.s.t, 1e3*rr.s.x, 'Color', col(a,:));
    end
    plot(rr.s.t, 1e3*rr.s.xr, 'k--', 'LineWidth', 1);  yline(1e3*xStand, 'k:', 'stand');
    set(ax, 'YDir', 'reverse');  ylabel('gap [mm]');  ylim([floor(1e3*min([R.xmin])) - 0.5, 12.3]);
    yline(0, 'k-', 'magnet');
    title(sc(q).name, 'Color', 'k');
    if q == 1, lg = legend([{opt.name}, {'set point'}], 'NumColumns', 3);  lg.Layout.Tile = 'south'; end
end
xlabel('time [s]');
title(tl3, 'Lift-off from the stand (integral wound up, except D: reset), then 11 \rightarrow 10.5 \rightarrow 11 mm (simulation)', 'Color', 'k');
exportgraphics(f3, fullfile(P.dir.figs, 'p8_clamp_fix.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

%% ---- 8. save --------------------------------------------------------------------------
RB = struct('grid', G, 'gridCols', {{'ball', 'x0', 'fl', 'fc', 'tau', 'ka', 'd', 'Ms', 'kLow', 'kHigh', 'PM', 'DM_s', 'stable'}}, ...
            'dly', B.dly, 'nominal', Mn, 'nominalRef', MR, 'f', fHz, 'Wpar', Wpar, 'Tn', Tn, 'maxWTpar', pkP, ...
            'opt1', rmfield(O1, {'WTp', 'Wu', 'dl', 'W', 'Tn'}), 'nomCentred', nomC, 'opt2', rmfield(O2, {'WTp', 'Wu', 'W', 'Tn'}), ...
            'opt2curves', O2, ...   % (added 2026-11-15 for s14: per-region W, |T|, Wu vs frequency)
            'clampNeed', NE, 'clampCases', {cs(:,1)}, 'fix', rmfield(R, 's'));
save(fullfile(P.dir.data, 'robustness.mat'), 'RB');
fprintf('\nSaved data/robustness.mat, figs/p8_margins.png, figs/p8_WT.png, figs/p8_WT_options.png, figs/p8_clamp_fix.png\n');
fprintf('SUMMARY: %d PASS, %d FAIL\n', nP, nF);

%% ======================= local functions ================================
function [L, Acl] = loop_u(C, T, kaC, p, sgn)
% Discrete loop broken at the plant input, with the extra loop delay p.d (samples, any real >= 0).
% Plant: x'' = a21 x - b i, tau i' = ka u(t - d T0) - i, discretized EXACTLY (ZOH, c2d with InputDelay,
% delay absorbed into states). Controller states [xp z]. Returns L = -H (1 + L = 0 is the closed loop)
% and the closed-loop matrix Acl (kg = 1). sgn = -1 negates every controller gain.
Ac = [0 1 0; p.a21 0 -p.b; 0 0 -1/p.tau];  Bc = [0; 0; p.ka/p.tau];
Gc = ss(Ac, Bc, eye(3), 0);  Gc.InputDelay = p.d*T;
Gd = absorbDelay(c2d(Gc, T, 'zoh'));
[Ap, Bp, Cp, Dp] = ssdata(Gd);  assert(all(Dp(:) == 0), 'loop_u: plant must be strictly proper');
np = size(Ap, 1);  Cx = Cp(1, :);  Ci = Cp(3, :);
Kp = sgn*C.Kp;  Kd = sgn*C.Kd;  Ki = sgn*C.Ki;  Kc = sgn*C.Kc;  kff = sgn/kaC;
A = blkdiag(Ap, 0, 1);
A(np + 1, 1:np) = Cx;                    % xp[k+1] = x[k]
A(np + 2, 1:np) = T*Cx;                  % z[k+1] = z[k] + T x[k]   (forward Euler)
B = [Bp; 0; 0];
% i_ref = (Kp + Kd/T) x - (Kd/T) xp + Ki z ;  u_c = i_ref/kaC + Kc (i_ref - i)
Cu = [(kff + Kc)*(Kp + Kd/T)*Cx - Kc*Ci, -(kff + Kc)*Kd/T, (kff + Kc)*Ki];
L = ss(A, B, -Cu, 0, T);
Acl = A + B*Cu;
end

function [L, Acl] = loop_u_int(C, T, kaC, p, sgn)
% The earlier implementation (whole samples only, nd = p.d), kept as an independent reference for the
% fractional-delay loop_u (section 3 checks that both agree at d = 0 and d = 1).
nd = round(p.d);  assert(abs(p.d - nd) < 1e-12, 'loop_u_int: whole samples only');
Ac = [0 1 0; p.a21 0 -p.b; 0 0 -1/p.tau];  Bc = [0; 0; p.ka/p.tau];
sd = c2d(ss(Ac, Bc, eye(3), 0), T, 'zoh');
Kp = sgn*C.Kp;  Kd = sgn*C.Kd;  Ki = sgn*C.Ki;  Kc = sgn*C.Kc;  kff = sgn/kaC;
Ri = [Kp + Kd/T, 0, 0, -Kd/T, Ki];               % i_ref on [x v i xp z]
Ru = (kff + Kc)*Ri - Kc*[0 0 1 0 0];             % u_c
n = 5 + nd;  A = zeros(n);  B = zeros(n, 1);
A(1:3, 1:3) = sd.A;  A(4, 1) = 1;  A(5, [1 5]) = [T 1];
if nd == 0
    B(1:3) = sd.B;
else
    B(6) = 1;  for j = 7:n, A(j, j-1) = 1; end
    A(1:3, n) = sd.B;
end
Cu = [Ru zeros(1, nd)];
L = ss(A, B, -Cu, 0, T);
Acl = A + B*Cu;
end

function M = margins(L, Acl, w, T)
% Ms, |S| on the grid, stable gain range (eigenvalue sweep), phase and delay margin.
[A, B, Cm] = ssdata(L);  Cu = -Cm;
M.stable = max(abs(eig(Acl))) < 1;
h = squeeze(freqresp(L, w));
M.Sabs = abs(1./(1 + h));  M.Ms = max(M.Sabs);
if ~M.stable, M.Ms = Inf; end
stab = @(k) max(abs(eig(A + k*B*Cu))) < 1;
M.kHigh = bisect(stab, 1, 50);  M.kLow = bisect(stab, 1, 1e-3);
S = allmargin(L);
if isempty(S.PhaseMargin), M.PM = Inf; M.DM = Inf;
else, M.PM = min(abs(S.PhaseMargin));  M.DM = min(S.DelayMargin)*T;   % discrete: DelayMargin in samples
end
end

function R = wt_test(C, T, kaC, nomP, plants, sampler, nR, w)
% Multiplicative-uncertainty test at u around the nominal plant nomP:
%   W = 1.1 x envelope of |L_k/L_nom - 1| over the given plants; T from the nominal loop;
%   interior check with nR random plants from sampler().
Ln = loop_u(C, T, kaC, nomP, 1);
assert(max(abs(eig(Ln.A - Ln.B*Ln.C))) < 1, 'wt_test: nominal loop of the test is unstable');
Hn = squeeze(freqresp(Ln, w));  R.Tn = abs(Hn./(1 + Hn));
R.dl = zeros(numel(w), numel(plants));
for k = 1:numel(plants), R.dl(:, k) = abs(squeeze(freqresp(loop_u(C, T, kaC, plants(k), 1), w))./Hn - 1); end
R.W = 1.10*max(R.dl, [], 2);  R.ratio = 0;
for k = 1:nR
    R.ratio = max(R.ratio, max(abs(squeeze(freqresp(loop_u(C, T, kaC, sampler(), 1), w))./Hn - 1)./R.W));
end
R.WTp = R.W.*R.Tn;  R.Wu = (1./R.Tn - R.W)./(1 + R.W);   % extra unstructured error still tolerated
[R.pkP, kk] = max(R.WTp);  R.fP = w(kk);
end

function p = rand_plant(g, lam, ieqF, bi, x0, dLo, dHi)
% random plant inside the parametric set: lam, c +-5 %, tau 20-35 ms, ka 2.2-2.7, d in [dLo, dHi]
% (any real value, not only tenths), at ball bi and gap x0
fl = 0.95 + 0.1*rand;  fc = 0.95 + 0.1*rand;
p = struct('a21', g/(fl*lam), 'b', 2*g/ieqF(bi, x0, fl, fc), 'tau', 0.020 + 0.015*rand, 'ka', 2.2 + 0.5*rand, ...
           'd', dLo + (dHi - dLo)*rand);
end

function k = bisect(stab, kIn, kOut)
% boundary of stability between kIn (stable) and kOut (assumed unstable), geometric bisection
if stab(kOut), k = kOut; return; end
for j = 1:40
    km = sqrt(kIn*kOut);
    if stab(km), kIn = km; else, kOut = km; end
end
k = sqrt(kIn*kOut);
end

function print_m(name, M)
fprintf('  %-34s stable %d | Ms %.2f | gain range [%.3f, %.2f] = [%+.1f, %+.1f] dB | PM %.1f deg | DM %.1f ms (%.2f samples)\n', ...
        name, M.stable, M.Ms, M.kLow, M.kHigh, 20*log10(M.kLow), 20*log10(M.kHigh), M.PM, 1e3*M.DM, M.DM/0.003);
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end
