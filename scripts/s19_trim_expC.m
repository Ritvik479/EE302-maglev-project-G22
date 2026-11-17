% s19_trim_expC.m   [STANDALONE]
% =========================================================================
% PURPOSE   FIXPLAN step 10c (follow-up to decision D2): if the uncertainty set were trimmed with Exp C,
%           would the Option-2 robust-stability peak max|W T| (0.96-0.997, s11 section 5b) go down?
%           Exp C (13-Nov): 39 g at 10 mm stayed stable for actuator-gain factors kg 0.4 .. 2.0. A plant
%           of the set whose loop is UNSTABLE at kg 0.4 (or 2.0) is contradicted by that test.
%           Decision R1/D2 stands: the REPORTED set is not trimmed. This script only answers the question,
%           for one sentence in the report's discussion.
% METHOD    Same loop (loop_u), same Option-2 regions, nominals, grid plants, frequency grid, W = 1.1 x
%           envelope and 400 random interior plants (rng 5) as s11, copied verbatim. Two trimming rules:
%             A: keep a plant if its loop is stable at kg 0.4           (the rule of FIXPLAN step 1)
%             B: keep a plant if its loop is stable at kg 0.4 AND 2.0   (both ends of Exp C)
%           Random interior plants are drawn from the same sampler and rejected (redrawn) if they fail
%           the rule. NOTE: Exp C was run at 39 g, 10 mm only; applying it to every grid point assumes the
%           rule transfers to the other gaps and to the 42 g ball (it constrains tau, ka, d mostly).
% RECORD    per region: how much W drops anywhere and at the |W T| peak, and which plant sets W at the peak.
% CHECKS    untrimmed run reproduces s11's stored Option-2 peaks; rule A on s11's grid removes 260 of 1458
%           points (FIXPLAN step 1); each region nominal survives the trimming; the trimmed envelope never
%           exceeds the untrimmed one; trimmed W covers the trimmed interior plants.
% OUTPUTS   console only. Reads data/linear_model.mat, data/robustness.mat. Writes NOTHING.
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
nP = 0;  nF = 0;
chk = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
g = P.g;  mB = [0.039288 0.042137];  bName = {'39 g', '42 g'};
D = load(fullfile(P.dir.data, 'linear_model.mat'), 'LM');  LM = D.LM;
R = load(fullfile(P.dir.data, 'robustness.mat'), 'RB');  RB = R.RB;
[~, B] = maglev_cases(P);
C = B.C;  T = B.L.T0;  kaC = B.L.kaC;
lam = LM.lam;  cB = LM.cB;  tauN = LM.tau;  kaN = LM.ka;
dN = B.dly.nom;  dLo = B.dly.lo;  dHi = B.dly.hi;  dSet = [dLo dN dHi];
ieqF = @(bi, x0, fl, fc) sqrt(mB(bi)*g*exp(x0/(fl*lam))/(fc*cB(bi)));
wg = logspace(log10(2*pi*0.05), log10(0.999*pi/T), 1500);
fHz = wg/(2*pi);
stabAt = @(p, k) stab_at(C, T, kaC, p, k);
rules = struct('name', {'none', 'A: stable at kg 0.4', 'B: stable at kg 0.4 and 2.0'}, 'kg', {[], 0.4, [0.4 2.0]});

%% ---- 1. rule A on s11's stored grid (FIXPLAN step 1 count) -------------------------------
fprintf('==== 1. Trimming s11''s 1458-point grid (stored k_low, k_high) ====\n');
G = RB.grid;  cLow = strcmp(RB.gridCols, 'kLow');  cHigh = strcmp(RB.gridCols, 'kHigh');  cMs = strcmp(RB.gridCols, 'Ms');
cPM = strcmp(RB.gridCols, 'PM');
outA = G(:, cLow) >= 0.4;  outB = outA | G(:, cHigh) <= 2.0;
fprintf('  rule A removes %d of %d points; rule B removes %d (of which %d only because k_high <= 2.0)\n', ...
        nnz(outA), size(G,1), nnz(outB), nnz(outB & ~outA));
fprintf('  worst Ms: all %.3f | rule A %.3f | rule B %.3f ; PM min: all %.1f | A %.1f | B %.1f deg\n', ...
        max(G(:,cMs)), max(G(~outA,cMs)), max(G(~outB,cMs)), min(G(:,cPM)), min(G(~outA,cPM)), min(G(~outB,cPM)));
c = nnz(outA) == 260;  chk(c, sprintf('rule A removes 260 grid points as in FIXPLAN step 1 (got %d)', nnz(outA)));
nP = nP + c;  nF = nF + ~c;

%% ---- 2. Option-2 |W T| per region, untrimmed and trimmed -----------------------------------
fprintf('\n==== 2. Option-2 robust-stability test, per region ====\n');
regs = [1 9 10; 1 10 11; 2 9 10; 2 10 11];
nR = 400;
pk = zeros(size(regs,1), numel(rules));  ratio = pk;  nKeep = pk;  nAll = zeros(size(regs,1), 1);
WuR = cell(1, numel(rules));  envOK = true;  nomOK = true;
for r = 1:numel(rules), WuR{r} = inf(numel(wg), 1); end
for k = 1:size(regs, 1)
    bi = regs(k,1);  gl = regs(k,2:3)*1e-3;  xm = mean(gl);
    nomR = struct('a21', g/lam, 'b', 2*g/ieqF(bi, xm, 1, 1), 'tau', tauN, 'ka', kaN, 'd', dN);
    pR = [];
    for x0 = [gl(1) xm gl(2)], for fl = [0.95 1 1.05], for fc = [0.95 1 1.05], for tq = [0.020 0.027 0.035]
    for kq = [2.2 kaN 2.7], for dq = dSet
        pR = [pR, struct('a21', g/(fl*lam), 'b', 2*g/ieqF(bi, x0, fl, fc), 'tau', tq, 'ka', kq, 'd', dq)]; %#ok<AGROW>
    end, end, end, end, end, end
    nAll(k) = numel(pR);
    Wprev = [];
    for r = 1:numel(rules)
        kgs = rules(r).kg;
        keep = arrayfun(@(p) all(arrayfun(@(kk) stabAt(p, kk), kgs)), pR);
        nomOK = nomOK && all(arrayfun(@(kk) stabAt(nomR, kk), kgs));
        rng(5);                                            % same random stream for every rule
        smp = @() draw_ok(@() rand_plant(g, lam, ieqF, bi, gl(1) + diff(gl)*rand, dLo, dHi), stabAt, kgs);
        o = wt_test(C, T, kaC, nomR, pR(keep), smp, nR, wg);
        pk(k, r) = o.pkP;  ratio(k, r) = o.ratio;  nKeep(k, r) = nnz(keep);
        WuR{r} = min(WuR{r}, o.Wu);
        if r == 1
            Wprev = o.W;  pk1 = o;  pR1 = pR;
        else
            envOK = envOK && all(o.W <= Wprev + 1e-12);
            [~, kf] = max(pk1.WTp);  [~, js] = max(pk1.dl(kf, :));  ps = pR1(js);   % envelope-setting plant at the peak
            fprintf(['     [record] W lower by up to %.1f %% (at %.1f Hz); at the peak (%.1f Hz) by %.2f %%; plant setting W ' ...
                     'there: tau %.0f ms, ka %.2f, d %.1f, a21 %.0f -> kept by this rule: %d\n'], ...
                    100*max(1 - o.W./Wprev), fHz(find(1 - o.W./Wprev == max(1 - o.W./Wprev), 1)), fHz(kf), ...
                    100*(1 - o.W(kf)/Wprev(kf)), 1e3*ps.tau, ps.ka, ps.d, ps.a21, keep(js));
        end
        fprintf('  %s, %2d-%2d mm, %-28s: %3d/%3d plants | max |W T| %.4f at %.1f Hz | interior |delta|/W %.2f\n', ...
                bName{bi}, regs(k,2:3), rules(r).name, nnz(keep), numel(pR), o.pkP, o.fP/(2*pi), o.ratio);
    end
end
c = max(abs(pk(:,1) - [RB.opt2.pkP]')) < 1e-9;
chk(c, sprintf('untrimmed run reproduces s11''s stored Option-2 peaks (largest difference %.1e)', max(abs(pk(:,1) - [RB.opt2.pkP]'))));
nP = nP + c;  nF = nF + ~c;
c = nomOK;  chk(c, 'every region nominal is stable at kg 0.4 and 2.0 (it survives the trimming)');  nP = nP + c;  nF = nF + ~c;
c = envOK;  chk(c, 'trimmed envelope W never exceeds the untrimmed one (subset of the plants)');  nP = nP + c;  nF = nF + ~c;
c = all(ratio(:) <= 1);
chk(c, sprintf('W covers the random interior plants in every region and rule (worst ratio %.2f)', max(ratio(:))));
nP = nP + c;  nF = nF + ~c;

%% ---- 3. summary --------------------------------------------------------------------------
fprintf('\n==== 3. Summary ====\n');
for r = 1:numel(rules)
    fprintf('  %-28s: plants kept %4d/%4d | Option-2 max |W T| per region %s -> worst %.4f\n', rules(r).name, ...
            sum(nKeep(:,r)), sum(nAll), mat2str(round(pk(:,r)', 4)), max(pk(:,r)));
end
bands = [0.05 2; 2 10; 10 30; 30 166];
fprintf('  extra unmodelled relative error tolerated, worst region (min over band):\n');
fprintf('    band [Hz]     |%s\n', sprintf(' %-28s|', rules.name));
for j = 1:size(bands, 1)
    s = fHz >= bands(j,1) & fHz < bands(j,2);
    fprintf('    %5.2f - %5.1f |%s\n', bands(j,:), sprintf(' %26.0f %% |', cellfun(@(x) 100*min(x(s)), WuR)));
end
fprintf('[record] reduction of the worst Option-2 peak: rule A %.4f -> %.4f, rule B %.4f -> %.4f\n', ...
        max(pk(:,1)), max(pk(:,2)), max(pk(:,1)), max(pk(:,3)));
fprintf('\nTOTAL: %d PASS, %d FAIL\n', nP, nF);

%% ======================= local functions ================================
function s = stab_at(C, T, kaC, p, k)
% closed loop with the controller output scaled by kg = k (as kg in the lab model): stable?
[L, ~] = loop_u(C, T, kaC, p, 1);
[A, Bm, Cm] = ssdata(L);
s = max(abs(eig(A - k*Bm*Cm))) < 1;                  % L = -Cu, so A + k B Cu = A - k B C_L
end

function p = draw_ok(sampler, stabAt, kgs)
% rejection sampling: redraw until the plant satisfies the trimming rule (no rule: first draw)
for n = 1:10000
    p = sampler();
    if all(arrayfun(@(kk) stabAt(p, kk), kgs)), return; end
end
error('draw_ok: no admissible plant in 10000 draws');
end

% ---- copied verbatim from s11_robustness.m ----
function [L, Acl] = loop_u(C, T, kaC, p, sgn)
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

function R = wt_test(C, T, kaC, nomP, plants, sampler, nR, w)
Ln = loop_u(C, T, kaC, nomP, 1);
assert(max(abs(eig(Ln.A - Ln.B*Ln.C))) < 1, 'wt_test: nominal loop of the test is unstable');
Hn = squeeze(freqresp(Ln, w));  R.Tn = abs(Hn./(1 + Hn));
R.dl = zeros(numel(w), numel(plants));
for k = 1:numel(plants), R.dl(:, k) = abs(squeeze(freqresp(loop_u(C, T, kaC, plants(k), 1), w))./Hn - 1); end
R.W = 1.10*max(R.dl, [], 2);  R.ratio = 0;
for k = 1:nR
    R.ratio = max(R.ratio, max(abs(squeeze(freqresp(loop_u(C, T, kaC, sampler(), 1), w))./Hn - 1)./R.W));
end
R.WTp = R.W.*R.Tn;  R.Wu = (1./R.Tn - R.W)./(1 + R.W);
[R.pkP, kk] = max(R.WTp);  R.fP = w(kk);
end

function p = rand_plant(g, lam, ieqF, bi, x0, dLo, dHi)
fl = 0.95 + 0.1*rand;  fc = 0.95 + 0.1*rand;
p = struct('a21', g/(fl*lam), 'b', 2*g/ieqF(bi, x0, fl, fc), 'tau', 0.020 + 0.015*rand, 'ka', 2.2 + 0.5*rand, ...
           'd', dLo + (dHi - dLo)*rand);
end
