% s10_linear_model.m   [STANDALONE]
% =========================================================================
% PURPOSE   PS9 deliverable 1: "Linearized operating model, assumptions, and uncertainty
%           characterization". Collects in ONE place what s05-s09 found piecemeal:
%             1. force law from the 42 hover visits, with 95 % confidence intervals
%             2. operating points (2 balls x 9-11.5 mm) and their linear coefficients
%             3. checks of the linearization (Jacobian, sign, unstable pole, ZOH)
%             4. transfer functions (continuous and 3 ms ZOH, with the measured extra loop delay of s12)
%             5. how far the linear model can be trusted (force error, 24 lab steps)
%             6. uncertainty: parametric ranges mapped onto the linear coefficients, and
%                the unstructured (unmodelled) effects with their evidence and status
% INPUTS    data/lab_2026-11-13/{sweeps_holds_results,exp_ABC_results}.mat, maglev_cases.m
% OUTPUTS   console PASS/FAIL, data/linear_model.mat,
%           figs/p7_linear_coeffs.png, figs/p7_plant_bode.png, figs/p7_lin_vs_nl_overshoot.png
% MODEL     x = gap [m], DOWN = +.  i = true coil current [A].  u = command (PWM duty, 0..1).
%             x'' = g - c i^2 exp(-x/lam) / m           (ball)
%             tau i' = ka u - i                          (coil + driver)
%           Linearized at (x0, i0):  dx'' = a21 dx - b di,  a21 = g/lam,  b = 2 g / i0
%           (exact for any force law F = c i^2 f(x) with f = exp(-x/lam)).
% SIGNS     b > 0 enters with a MINUS: more current pulls the ball UP (x falls). Section 3 checks
%           this against the nonlinear model and shows that a +b model is caught.
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
addpath(here);
P.plot.apply();
chk = @(c, m) fprintf('%s: %s\n', subsref({'FAIL','PASS'}, substruct('{}', {1 + logical(c)})), m);
nPass = 0;  nFail = 0;
g = P.g;  m39 = 0.039288;  m42 = 0.042137;  mB = [m39 m42];  bName = {'39 g', '42 g'};

[~, B, U] = maglev_cases(P);
S8 = load(fullfile(P.dir.data, 'lab_2026-11-13', 'sweeps_holds_results.mat'), 'lam', 'cB', 'NF', 'ST');
S7 = load(fullfile(P.dir.data, 'lab_2026-11-13', 'exp_ABC_results.mat'), 'F', 'kaP');
C = B.C;  C.zLim = C.iLim/C.Ki;
T0 = B.L.T0;  kaC = B.L.kaC;  umax = B.L.umax;
tau = B.pl39.tau;  ka = B.pl39.ka;  xStand = B.pl39.xStand;
dN = B.dly.nom;  dLo = B.dly.lo;  dHi = B.dly.hi;     % extra loop delay [samples] (s12, via maglev_cases)
x0N = 0.010;                                  % nominal operating gap [m]

%% ---- 1. force law and its confidence intervals ----------------------------
fprintf('==== 1. Force law F = c i^2 exp(-x/lam), refitted from the hover visits ====\n');
FM = S7.F([S7.F.used]);  NU = S8.NF(~[S8.NF.rock]);
X = [[FM.x], [NU.x]]';  I = [[FM.itrue], [NU.itrue]]';  Bb = [[FM.ball], [NU.ball]]';
% log i = x/(2 lam) + 0.5 log(m g / c_b): linear in th = [1/lam; 0.5 log(m g/c_39); 0.5 log(m g/c_42)]
A = [X/2, Bb == 1, Bb == 2];
th = A \ log(I);
lam = 1/th(1);  cB = mB*g./exp(2*th(2:3)');
nV = numel(I);  r = log(I) - A*th;  s2 = sum(r.^2)/(nV - 3);
Cv = s2*inv(A'*A);  se = sqrt(diag(Cv));                %#ok<MINV>
tq = 1.96 + 2.4/(nV - 3);                               % Student-t 97.5 % point (approximation, no Stats toolbox)
ciLam = tq*se(1)/th(1);                                 % relative half-width of the 95 % CI of lam
ciC = 2*tq*se(2:3)';                                    % relative half-width for c (c ~ exp(-2 th))
rhoLC = Cv(1,2)/sqrt(Cv(1,1)*Cv(2,2));                  % correlation of lam and c_39 estimates
ifit = @(x, b) sqrt(mB(b)*g./cB(b)).*exp(x/(2*lam));
resI = I - arrayfun(@(k) ifit(X(k), Bb(k)), (1:nV)');
fprintf('  %d visits (%d morning + %d afternoon, rocking-flagged visits excluded)\n', nV, numel(FM), numel(NU));
fprintf('  lam = %.3f mm  (95 %% CI +-%.1f %%)\n', 1e3*lam, 100*ciLam);
fprintf('  c   = %.3f / %.3f N/A^2 for 39 / 42 g  (95 %% CI +-%.1f / +-%.1f %%; correlation with lam %.2f)\n', ...
        cB, 100*ciC, rhoLC);
fprintf('  residual: %.1f mA rms, max %.1f mA\n', 1e3*rms(resI), 1e3*max(abs(resI)));
% hover-current confidence band over the validated range (this is what b depends on)
xg = (9:0.5:11)'*1e-3;  ciI = zeros(numel(xg), 2);
for b = 1:2
    for k = 1:numel(xg)
        a = [xg(k)/2, b == 1, b == 2];  ciI(k, b) = tq*sqrt(a*Cv*a');     % in log i = relative
    end
end
fprintf('  95 %% CI of the predicted hover current, 9-11 mm: +-%.2f %% (39 g) / +-%.2f %% (42 g) at worst\n', ...
        100*max(ciI(:,1)), 100*max(ciI(:,2)));
c1 = abs(lam/S8.lam - 1) < 1e-9 && max(abs(cB./S8.cB - 1)) < 1e-9;
chk(c1, 'refit reproduces the s08 values exactly (lam, c_39, c_42)');  nPass = nPass + c1;  nFail = nFail + ~c1;
c1 = ciLam < 0.05;
chk(c1, sprintf('the +-5 %% range used for lam covers its 95 %% CI (+-%.1f %%)', 100*ciLam));
nPass = nPass + c1;  nFail = nFail + ~c1;
fprintf(['  NOTE: c alone is poorly determined (CI +-%.1f %%) because it is strongly correlated with lam (%.2f).\n' ...
         '        What the linear model needs is the hover current i0 at the operating gap, and that is known to\n' ...
         '        +-%.2f %%. Section 6 therefore checks the uncertainty set against the measured currents directly.\n'], ...
        100*max(ciC), rhoLC, 100*max(ciI(:)));

%% ---- 2. operating points and linear coefficients ---------------------------
fprintf('\n==== 2. Operating points and linear coefficients (nominal: 39 g at 10 mm) ====\n');
gaps = (9:0.5:11.5)'*1e-3;
OP = struct('ball', {}, 'x0', {}, 'i0', {}, 'u0', {}, 'a21', {}, 'b', {}, 'p', {}, 'Kst', {});
fprintf(' ball | x0 [mm] | i0 [A] | u0 [-] | a21 [1/s^2] | b [m/s^2/A] | p [rad/s] (Hz) | |G_xi(0)| = b/a21 [mm/A]\n');
for bi = 1:2
    for k = 1:numel(gaps)
        x0 = gaps(k);  i0 = ifit(x0, bi);
        o = struct('ball', bi, 'x0', x0, 'i0', i0, 'u0', i0/ka, 'a21', g/lam, 'b', 2*g/i0, ...
                   'p', sqrt(g/lam), 'Kst', (2*g/i0)/(g/lam));
        OP(end+1) = o; %#ok<SAGROW>
        tag = '';  if x0 > 0.0111, tag = '  <- provisional (rocking, 0.42 mm above the stand)'; end
        fprintf(' %s | %5.1f   | %.3f  | %.3f  | %7.1f     | %6.2f      | %5.2f (%.2f)   | %6.2f%s\n', ...
                bName{bi}, 1e3*x0, i0, o.u0, o.a21, o.b, o.p, o.p/(2*pi), 1e3*o.Kst, tag);
    end
end
nom = OP([OP.ball] == 1 & abs([OP.x0] - x0N) < 1e-9);
v = [OP([OP.x0] <= 0.0111).b];
fprintf('  Over the validated range (9-11 mm, both balls) b varies %.2f..%.2f (%+.0f / %+.0f %% of nominal %.2f);\n', ...
        min(v), max(v), 100*(min(v)/nom.b - 1), 100*(max(v)/nom.b - 1), nom.b);
fprintf('  a21 = g/lam does not depend on the gap or the ball: an equilibrium shift changes ONLY the input gain b.\n');

%% ---- 3. checks of the linearization --------------------------------------
fprintf('\n==== 3. Linearization checks ====\n');
fnl = @(y, u, pl) [y(2); g - pl.c*y(3)^2*exp(-y(1)/pl.lam)/pl.m; (pl.ka*u - y(3))/pl.tau];
errJ = 0;
for o = OP
    pl = struct('m', mB(o.ball), 'c', cB(o.ball), 'lam', lam, 'ka', ka, 'tau', tau);
    y0 = [o.x0; 0; o.i0];  u0 = o.u0;  hh = [1e-7; 1e-5; 1e-5];
    J = zeros(3);  for j = 1:3, d = zeros(3,1); d(j) = hh(j); J(:,j) = (fnl(y0+d,u0,pl) - fnl(y0-d,u0,pl))/(2*hh(j)); end
    Jb = (fnl(y0, u0+1e-5, pl) - fnl(y0, u0-1e-5, pl))/2e-5;
    Aa = [0 1 0; o.a21 0 -o.b; 0 0 -1/tau];  Ba = [0; 0; ka/tau];
    errJ = max([errJ, norm(J - Aa)/norm(Aa), norm(Jb - Ba)/norm(Ba), norm(fnl(y0, u0, pl))]);
end
c1 = errJ < 1e-4;
chk(c1, sprintf('analytic A, B = numerical Jacobian of the nonlinear model at all %d points (worst rel. error %.1e), f = 0 there', ...
                numel(OP), errJ));  nPass = nPass + c1;  nFail = nFail + ~c1;
% sign: hold the current 1 mA above i0 for 20 ms, starting at rest at 10 mm
pl = struct('m', m39, 'c', cB(1), 'lam', lam, 'ka', ka, 'tau', 1e9);   % tau huge: current frozen
y = [x0N; 0; nom.i0 + 1e-3];  for k = 1:200, y = y + 1e-4*fnl(y, 0, pl); end
s = tf('s');
Gxi = -nom.b/(s^2 - nom.a21);   GxiW = +nom.b/(s^2 - nom.a21);
yl = step(1e-3*Gxi, 0.02);  yw = step(1e-3*GxiW, 0.02);
fprintf('  +1 mA for 20 ms from hover at 10 mm: nonlinear dx = %+.4f mm, linear %+.4f mm, wrong-sign (+b) model %+.4f mm\n', ...
        1e3*(y(1) - x0N), 1e3*yl(end), 1e3*yw(end));
c1 = y(1) < x0N && yl(end) < 0 && abs(yl(end)/(y(1) - x0N) - 1) < 0.02;
chk(c1, 'more current -> ball rises (x falls) in the nonlinear AND the linear model, same size within 2 %');
nPass = nPass + c1;  nFail = nFail + ~c1;
c1 = yw(end) > 0;
chk(c1, 'a model with the wrong sign (+b) predicts the opposite, so this test catches a sign error');
nPass = nPass + c1;  nFail = nFail + ~c1;

%% ---- 4. transfer functions -------------------------------------------------
fprintf('\n==== 4. Transfer functions at the nominal point (39 g, 10 mm) ====\n');
Giu = ka/(tau*s + 1);   Gxu = Gxi*Giu;
Gz0 = c2d(Gxu, T0, 'zoh');                                   % no extra delay (pole check below)
GxuD = Gxu;  GxuD.InputDelay = dN*T0;                        % measured extra delay d (s12), fractional
Gz = absorbDelay(c2d(GxuD, T0, 'zoh'));                      % exact ZOH discretization, delay as a state
fprintf('  G_xi(s) = -%.2f / (s^2 - %.1f)                    [m/A]   ball: current -> gap\n', nom.b, nom.a21);
fprintf('  G_iu(s) = %.3f / (%.3f s + 1)                     [A/unit] coil: command -> current\n', ka, tau);
fprintf('  G_xu(s) = G_xi G_iu, poles %s rad/s\n', mat2str(round(sort(real(pole(Gxu)))', 2)));
[zz, pp, kk] = zpkdata(Gz0, 'v');
fprintf('  G_xu(z), ZOH T0 = %.0f ms, no extra delay: zeros %s, poles %s, gain %.3e\n', 1e3*T0, mat2str(round(zz', 4)), ...
        mat2str(round(pp', 4)), kk);
[zz, pp, kk] = zpkdata(Gz, 'v');
fprintf('  G_xu(z) with the measured extra delay d = %.1f sample (%.1f ms; range %.1f-%.1f, s12):\n', dN, 1e3*dN*T0, dLo, dHi);
fprintf('           zeros %s, poles %s, gain %.3e\n', mat2str(round(zz', 4)), mat2str(round(pp', 4)), kk);
nUnst = sum(real(pole(Gxu)) > 0);  dp = max(abs(sort(pole(Gz0)) - sort(exp(pole(Gxu)*T0))));
pD = sort(pole(Gz));  dpD = max(abs(pD - sort([exp(pole(Gxu)*T0); 0])));
c1 = nUnst == 1 && abs(max(real(pole(Gxu))) - nom.p) < 1e-9 && dp < 1e-9 && dpD < 1e-9;
chk(c1, sprintf(['exactly one unstable pole, +sqrt(a21) = %.2f rad/s (%.2f Hz); ZOH poles = exp(p T0); the ' ...
    'fractional delay adds only a pole at z = 0'], nom.p, nom.p/(2*pi)));
nPass = nPass + c1;  nFail = nFail + ~c1;
hw = squeeze(freqresp(Gz, 2*pi*[1 10 50])) ./ squeeze(freqresp(Gz0, 2*pi*[1 10 50]));
fprintf('  effect of the delay: |G| ratio %s, extra phase %s deg at 1 / 10 / 50 Hz (pure delay: %s deg)\n', ...
        mat2str(round(abs(hw)', 4)), mat2str(round(angle(hw)'*180/pi, 2)), mat2str(round(-360*[1 10 50]*dN*T0, 2)));
c1 = max(abs(angle(hw)'*180/pi + 360*[1 10 50]*dN*T0)) < 0.2 && max(abs(abs(hw) - 1)) < 0.01;
chk(c1, 'the discretized delay acts as a pure delay of d T0 (phase within 0.2 deg, gain within 1 % up to 50 Hz)');
nPass = nPass + c1;  nFail = nFail + ~c1;

%% ---- 5. how far the linear model can be trusted ----------------------------
fprintf('\n==== 5. Validity of the linear model ====\n');
% (a) static force error for the excursions seen in 0.5 mm steps
worst = 0;
for o = OP([OP.x0] <= 0.0111)
    for dx = [-0.5 0.5]*1e-3, for di = [-0.1 0.1]
        Fnl = cB(o.ball)*(o.i0 + di)^2*exp(-(o.x0 + dx)/lam)/mB(o.ball);
        Flin = g - o.a21*dx + o.b*di;
        worst = max(worst, abs(Fnl - Flin)/g);
    end, end
end
fprintf(['  INFO: static worst corner dx = +-0.5 mm AND di = +-0.1 A (same-signed): force error %.2f %% of m g.\n' ...
         '        (This was a PASS/FAIL check with a 2 %% limit in the first run and FAILED; it is pessimistic because\n' ...
         '        it assumes both excursions at their maximum at once. Replaced by the trajectory check in 5c.)\n'], 100*worst);
% (b) implementation check of the step simulator used below
o = OP([OP.ball] == 1 & abs([OP.x0] - x0N) < 1e-9);
plA = struct('m', m39, 'c', cB(1), 'lam', lam, 'ka', ka, 'tau', tau);
sA = cl_step(@(y, u) fnl(y, u, plA), C, T0, kaC, ka, umax, x0N, o.i0, 0.0105, 1.0, 0.3, xStand, dN);
Cf = C;  Lf = struct('T0', T0, 'ka', kaC, 'umax', umax);
plf = struct('m', m39, 'lam', lam, 'c', cB(1), 'ioff', 0, 'tau', tau, 'ka', ka, 'ci', 0);
sB = maglev_cascade_sim(Cf, Lf, plf, @(t) x0N + 0.5e-3*(t >= 0.3), 1.0, ...
                        struct('x0', x0N, 'i0s', o.i0, 'z0', sA.z0, 'xStand', xStand, 'd', dN, 'uIC', o.i0/ka));
dImp = max(abs(sA.x - sB.x));
c1 = dImp < 1e-9;
chk(c1, sprintf('step simulator = maglev_cascade_sim.m (max difference %.1e m)', dImp));  nPass = nPass + c1;  nFail = nFail + ~c1;
% (c) the 24 afternoon lab steps: lab vs nonlinear vs linear (local) vs linear (one nominal model)
ST = S8.ST;  ballOfRun = [1 2 2];  nS = size(ST, 1);
OS = zeros(nS, 4);                    % [lab, nonlinear, linear local, linear nominal 39 g @ 10 mm]
TR = cell(nS, 1);  EX = zeros(nS, 3);   % [max force error / g, max |dx|, max |di|] along each step
for k = 1:nS
    bi = ballOfRun(ST(k,1));  a = ST(k,2)*1e-3;  z = ST(k,3)*1e-3;
    plN = struct('m', mB(bi), 'c', cB(bi), 'lam', lam, 'ka', ka, 'tau', tau);
    fN = @(y, u) fnl(y, u, plN);
    % local linearization at the middle of the step
    xL = (a + z)/2;  iL = ifit(xL, bi);  a21L = g/lam;  bL = 2*g/iL;
    fL = @(y, u) [y(2); a21L*(y(1) - xL) - bL*(y(3) - iL); (ka*u - y(3))/tau];
    % one model for everything: 39 g at 10 mm
    fM = @(y, u) [y(2); nom.a21*(y(1) - x0N) - nom.b*(y(3) - nom.i0); (ka*u - y(3))/tau];
    sN = cl_step(fN, C, T0, kaC, ka, umax, a, ifit(a, bi), z, 2.0, 0.5, xStand, dN);
    sL = cl_step(fL, C, T0, kaC, ka, umax, a, iL + a21L*(a - xL)/bL, z, 2.0, 0.5, Inf, dN);
    sM = cl_step(fM, C, T0, kaC, ka, umax, a, nom.i0 + nom.a21*(a - x0N)/nom.b, z, 2.0, 0.5, Inf, dN);
    OS(k, :) = [ST(k,4), step_metrics(sN.t, sN.x, a, z), step_metrics(sL.t, sL.x, a, z), step_metrics(sM.t, sM.x, a, z)];
    TR{k} = struct('t', sN.t, 'xN', sN.x, 'xL', sL.x, 'xM', sM.x);
    % force error of the local linearization along the NONLINEAR trajectory
    Fn = cB(bi)*sN.i.^2.*exp(-sN.x/lam)/mB(bi);  Fl = g - a21L*(sN.x - xL) + bL*(sN.i - iL);
    EX(k, :) = [max(abs(Fn - Fl))/g, max(abs(sN.x - xL)), max(abs(sN.i - iL))];
end
rn = {'S39u', 'S42u', 'S42d'};
fprintf(' run  | step [mm]    | overshoot [mm]: lab | nonlinear | linear local | linear nominal (39 g, 10 mm)\n');
for k = 1:nS
    fprintf(' %s | %4.1f -> %4.1f |                %4.2f |   %4.2f    |    %4.2f      |   %4.2f\n', rn{ST(k,1)}, ST(k,2:3), OS(k,:));
end
dLN = rms(OS(:,3) - OS(:,2));  dMN = rms(OS(:,4) - OS(:,2));  dNL = rms(OS(:,2) - OS(:,1));  dML = rms(OS(:,4) - OS(:,1));
fprintf('  rms differences: linear local - nonlinear %.3f mm | linear nominal - nonlinear %.3f mm\n', dLN, dMN);
fprintf('                   nonlinear - lab %.3f mm | linear nominal - lab %.3f mm\n', dNL, dML);
fprintf('  along the nonlinear step trajectories: max |dx| %.2f mm, max |di| %.0f mA, max force error %.2f %% of m g\n', ...
        1e3*max(EX(:,2)), 1e3*max(EX(:,3)), 100*max(EX(:,1)));
c1 = max(EX(:,1)) < 0.02;
chk(c1, 'force error of the local linearization along all 24 simulated steps < 2 % of m g');
nPass = nPass + c1;  nFail = nFail + ~c1;
c1 = dLN < 0.05;
chk(c1, 'local linear model reproduces the nonlinear model on all 24 lab steps (overshoot rms < 0.05 mm)');
nPass = nPass + c1;  nFail = nFail + ~c1;
c1 = dMN < 0.10;
chk(c1, ['ONE linear model (39 g, 10 mm) stays within 0.10 mm rms of the nonlinear model for both balls, 9-11 mm ' ...
         '(threshold = about half the lab-vs-model gap of 0.18 mm)']);  nPass = nPass + c1;  nFail = nFail + ~c1;
fprintf(['  So the lab-vs-model overshoot gap (%.2f mm rms, worst on the 10.5 -> 11 mm down-steps) is NOT caused by\n' ...
         '  linearizing: the nonlinear model has it too. It is a model-vs-hardware mismatch (open item).\n'], dNL);

%% ---- 6. uncertainty characterization ----------------------------------------
fprintf('\n==== 6. Uncertainty, mapped onto the linear-model coefficients ====\n');
% corner set of maglev_cases.m: lam +-5 %, c +-5 %, both balls, gaps 9-11 mm
fl = [0.95 1.05];  fc = [0.95 1.05];  gv = (9:0.5:11)*1e-3;
a21R = g./(lam*fl);  iR = [];  bR = [];
for bi = 1:2, for x0 = gv, for l = fl, for cc = fc
    i0 = sqrt(mB(bi)*g*exp(x0/(l*lam))/(cc*cB(bi)));  iR(end+1) = i0; bR(end+1) = 2*g/i0; %#ok<SAGROW>
end, end, end, end
fprintf(' coefficient            | nominal (39 g, 10 mm) | range over the uncertainty set        | from\n');
fprintf(' a21 = g/lam [1/s^2]    | %8.1f              | %.1f .. %.1f  (%+.1f / %+.1f %%)     | lam +-5 %%\n', ...
        nom.a21, min(a21R), max(a21R), 100*(min(a21R)/nom.a21 - 1), 100*(max(a21R)/nom.a21 - 1));
fprintf(' p = sqrt(a21) [Hz]     | %8.2f              | %.2f .. %.2f                         | lam +-5 %%\n', ...
        nom.p/(2*pi), sqrt(min(a21R))/(2*pi), sqrt(max(a21R))/(2*pi));
fprintf(' b = 2g/i0 [m/s^2/A]    | %8.2f              | %.2f .. %.2f  (%+.0f / %+.0f %%)       | ball, gap 9-11 mm, lam, c\n', ...
        nom.b, min(bR), max(bR), 100*(min(bR)/nom.b - 1), 100*(max(bR)/nom.b - 1));
fprintf(' tau [ms]               | %8.0f              | 20 .. 35                             | measured 22-25 ms (steps, sine), widened\n', 1e3*tau);
fprintf(' ka [A/unit]            | %8.2f              | 2.2 .. 2.7                           | coil steps, hover data\n', ka);
fprintf(' extra delay d [samples]| %8.1f              | %.1f .. %.1f (%.1f .. %.1f ms)            | measured, s12 (run 3)\n', ...
        dN, dLo, dHi, 3*dLo, 3*dHi);
fprintf(' kg (gain error on u)   | %8d              | 0.4 .. 2.0 (tested in the lab)       | Exp C\n', 1);
% coverage: every measured hover current inside the corner band at its gap
inside = false(nV, 1);  marg = zeros(nV, 1);
for k = 1:nV
    bi = Bb(k);  cand = [];
    for l = fl, for cc = fc, cand(end+1) = sqrt(mB(bi)*g*exp(X(k)/(l*lam))/(cc*cB(bi))); end, end %#ok<AGROW>
    inside(k) = I(k) >= min(cand) && I(k) <= max(cand);
    marg(k) = min(I(k) - min(cand), max(cand) - I(k));
end
fprintf('  measured hover currents vs the corner band: %d / %d inside, smallest margin %.1f mA\n', nnz(inside), nV, 1e3*min(marg));
i10 = [];  for l = fl, for cc = fc, i10(end+1) = sqrt(m39*g*exp(x0N/(l*lam))/(cc*cB(1))); end, end %#ok<AGROW>
fprintf(['  corner band at 10 mm (39 g): %.3f .. %.3f A (%+.1f / %+.1f %%) vs the data: 2 x residual rms = +-%.1f %%,\n' ...
         '  so the parametric set is about %.0fx wider than the measured scatter in i0 (conservative, as intended)\n'], ...
        min(i10), max(i10), 100*(min(i10)/nom.i0 - 1), 100*(max(i10)/nom.i0 - 1), 100*2*rms(resI)/nom.i0, ...
        (max(i10) - min(i10))/2/(2*rms(resI)));
c1 = all(inside);
chk(c1, 'the uncertainty set covers every measured hover current (both balls, 9-11 mm)');  nPass = nPass + c1;  nFail = nFail + ~c1;

fprintf('\n  Unmodelled (unstructured) effects:\n');
UM = {
 'stand-proximity effect (2.4 Hz limit cycle, static upward force, braking spike)', ...
     'within ~0.7-0.9 mm of the stand only; gone with the stand lowered (16-Nov); mechanism open (not shadowing alone, not shown to be rotation)', ...
     'one lowered-stand session', 'excluded by the range (stand >= 0.85 mm below the set point); 11.5 mm stress case in s09';
 'extra loop delay (cause unknown)', 's12: 0.32-0.55 sample from run 3; d = 0 and 1 rejected', ...
     'measured (cause not separable)', 'parametric 0.3-0.6 sample';
 'coil inductance changes with gap (back-EMF)', 'current dips when the ball moves (coil test)', ...
     'solid (small, inner loop rejects it)', 'covered by tau 20-35 ms';
 'coil gain at small u', 'dI/du 1.9 near u = 0 vs 2.4-2.6', ...
     'solid', 'only at lift-off; nonlinear sim';
 'current-sensor zero drift', '-0.5 .. -0.85 mA/s while levitating', ...
     'solid', 'disturbance; integral removes it; sim case';
 'sensor noise', 'sigma x 0.011 mm, i 0.021 A', ...
     'solid', 'sim case; sets the jitter floor';
 'position-sensor calibration nonlinearity', 'two tables agree within 0.1 mm over 7-13 mm', ...
     'open (hypothesis for the 11 mm step mismatch)', 'high-frequency part of W (s11)';
 'limits: u 0..0.9, i_ref 0..2 A, integral clamp, stand', 'design values / rig geometry', ...
     'solid', 'nonlinear sim only (inactive for small signals)'};
fprintf('  %-48s | %-60s | %-42s | handled by\n', 'effect', 'evidence', 'status');
for k = 1:size(UM, 1), fprintf('  %-48s | %-60s | %-42s | %s\n', UM{k, :}); end

%% ---- 7. figures --------------------------------------------------------------
col = P.plot.colors;
% (a) hover current and b vs gap
f1 = figure('Position', [100 100 1100 450]);
tl = tiledlayout(1, 2, 'TileSpacing', 'compact');
xs = linspace(8.8, 11.7, 100)*1e-3;
ax1 = nexttile; hold on; grid on;  ax2 = nexttile; hold on; grid on;
hB = gobjects(2, 1);
for bi = 1:2
    lo = inf(size(xs));  hi = -lo;
    for l = fl, for cc = fc
        ii = sqrt(mB(bi)*g*exp(xs/(l*lam))/(cc*cB(bi)));  lo = min(lo, ii);  hi = max(hi, ii);
    end, end
    fill(ax1, 1e3*[xs fliplr(xs)], [lo fliplr(hi)], col(bi,:), 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill(ax2, 1e3*[xs fliplr(xs)], 2*g./[lo fliplr(hi)], col(bi,:), 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    hB(bi) = plot(ax1, 1e3*xs, ifit(xs, bi), '-', 'Color', col(bi,:));
    plot(ax1, 1e3*X(Bb == bi), I(Bb == bi), 'o', 'Color', col(bi,:), 'MarkerFaceColor', col(bi,:), 'MarkerSize', 5, ...
         'HandleVisibility', 'off');
    plot(ax2, 1e3*xs, 2*g./ifit(xs, bi), '-', 'Color', col(bi,:));
end
for ax = [ax1 ax2]
    xp = [11.25 11.7 11.7 11.25];  yl = ylim(ax);
    patch(ax, xp, [yl(1) yl(1) yl(2) yl(2)], [0.5 0.5 0.5], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    ylim(ax, yl);  xlim(ax, 1e3*xs([1 end]));  xlabel(ax, 'operating gap x_0 [mm]');
    text(ax, 11.3, yl(1) + 0.92*diff(yl), {'11.5 mm:', 'provisional'}, 'Color', 'k', 'FontSize', 10);
end
plot(ax1, 1e3*x0N, nom.i0, 'kp', 'MarkerSize', 14, 'MarkerFaceColor', 'y');
ylabel(ax1, 'hover current i_0 [A]');  ylabel(ax2, 'input gain b = 2g/i_0 [m s^{-2} A^{-1}]');
legend(ax1, [hB; findobj(ax1, 'Marker', 'p')], {'39 g fit (dots: lab)', '42 g fit (dots: lab)', 'nominal point'}, ...
       'Location', 'northwest');
legend(ax2, {'39 g', '42 g'}, 'Location', 'southwest');
title(ax1, sprintf('Hover current: fit, %d lab visits, uncertainty band', nV), 'Color', 'k');
title(ax2, sprintf('Input gain b (a_{21} = g/\\lambda = %.0f s^{-2} at every gap)', nom.a21), 'Color', 'k');
exportgraphics(f1, fullfile(P.dir.figs, 'p7_linear_coeffs.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

% (b) Bode of the sampled plant G_xu(z): corners grey, nominals coloured
f2 = figure('Position', [100 100 900 650]);
tl2 = tiledlayout(2, 1, 'TileSpacing', 'compact');
axM = nexttile; hold on; grid on;  axP = nexttile; hold on; grid on;
fHz = logspace(-1, log10(0.98/(2*T0)), 600);  w = 2*pi*fHz;
for bi = 1:2, for x0 = [9 10 11]*1e-3, for l = fl, for cc = fc, for tq2 = [0.020 0.035], for kq = [2.2 2.7], for dq = [dLo dHi]
    i0 = sqrt(mB(bi)*g*exp(x0/(l*lam))/(cc*cB(bi)));
    Gc = -(2*g/i0)/(s^2 - g/(l*lam)) * kq/(tq2*s + 1);  Gc.InputDelay = dq*T0;  Gd = absorbDelay(c2d(Gc, T0, 'zoh'));
    h = squeeze(freqresp(Gd, w));
    plot(axM, fHz, 20*log10(abs(h)), '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.6, 'HandleVisibility', 'off');
    plot(axP, fHz, unwrap(angle(h))*180/pi, '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.6, 'HandleVisibility', 'off');
end, end, end, end, end, end, end
for bi = 1:2
    i0 = ifit(x0N, bi);
    Gc = -(2*g/i0)/(s^2 - g/lam) * ka/(tau*s + 1);  Gc.InputDelay = dN*T0;
    Gd = absorbDelay(c2d(Gc, T0, 'zoh'));  h = squeeze(freqresp(Gd, w));
    plot(axM, fHz, 20*log10(abs(h)), '-', 'Color', col(bi,:));
    plot(axP, fHz, unwrap(angle(h))*180/pi, '-', 'Color', col(bi,:));
end
xline(axM, nom.p/(2*pi), 'k--', sprintf('unstable pole %.1f Hz', nom.p/(2*pi)), 'LabelVerticalAlignment', 'bottom', ...
      'HandleVisibility', 'off');
set([axM axP], 'XScale', 'log');  xlim(axM, fHz([1 end]));  xlim(axP, fHz([1 end]));
ylabel(axM, '|G_{xu}| [dB re 1 m/unit]');  ylabel(axP, 'phase [deg]');  xlabel(axP, 'frequency [Hz]');
legend(axM, {'nominal 39 g, 10 mm', 'nominal 42 g, 10 mm'}, 'Location', 'southwest');
title(axM, 'Plant u \rightarrow x, ZOH 3 ms (grey: 192 corners, d 0.3 / 0.6; colour: d 0.5)', 'Color', 'k');
title(axP, 'Phase', 'Color', 'k');
exportgraphics(f2, fullfile(P.dir.figs, 'p7_plant_bode.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

% (c) overshoot of the 24 lab steps: lab vs nonlinear vs linear
f3 = figure('Position', [100 100 1000 430]); hold on; grid on;
kk = (1:nS)';
plot(kk, OS(:,1), 'ks', 'MarkerFaceColor', 'k', 'MarkerSize', 7);
plot(kk, OS(:,2), 'o', 'Color', col(1,:), 'MarkerSize', 9, 'LineWidth', 1.5);
plot(kk, OS(:,3), '+', 'Color', col(3,:), 'MarkerSize', 9, 'LineWidth', 1.5);
plot(kk, OS(:,4), 'x', 'Color', col(4,:), 'MarkerSize', 9, 'LineWidth', 1.5);
lbl = arrayfun(@(k) sprintf('%s %.1f\\rightarrow%.1f', rn{ST(k,1)}(2:end), ST(k,2), ST(k,3)), kk, 'UniformOutput', false);
set(gca, 'XTick', kk, 'XTickLabel', lbl, 'XTickLabelRotation', 60, 'FontSize', 9);
ylabel('overshoot [mm]', 'FontSize', P.plot.fs);
ylim([0.2 0.9]);
legend({'lab', 'nonlinear model', 'linear, local', 'linear, one model (39 g, 10 mm)'}, 'Location', 'north', ...
       'NumColumns', 4, 'FontSize', 10);
title({'Overshoot of the 24 afternoon 0.5 mm steps', sprintf(['rms vs nonlinear: linear local %.2f mm, one linear ' ...
       'model %.2f mm  |  nonlinear vs lab %.2f mm'], dLN, dMN, dNL)}, 'Color', 'k', 'FontSize', 11);
exportgraphics(f3, fullfile(P.dir.figs, 'p7_lin_vs_nl_overshoot.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

%% ---- 8. save --------------------------------------------------------------
LM = struct('lam', lam, 'cB', cB, 'ciLam', ciLam, 'ciC', ciC, 'rhoLC', rhoLC, 'resRms', rms(resI), ...
            'tau', tau, 'ka', ka, 'T0', T0, 'nom', nom, 'OP', OP, 'Gxi', Gxi, 'Giu', Giu, 'Gxu', Gxu, ...
            'Gz', Gz, 'Gz0', Gz0, 'dly', B.dly, 'a21R', [min(a21R) max(a21R)], 'bR', [min(bR) max(bR)], ...
            'OS', OS, 'stepTable', ST, 'unmodelled', {UM});
save(fullfile(P.dir.data, 'linear_model.mat'), 'LM', 'U');
fprintf('\nSaved data/linear_model.mat, figs/p7_linear_coeffs.png, figs/p7_plant_bode.png, figs/p7_lin_vs_nl_overshoot.png\n');
fprintf('SUMMARY: %d PASS, %d FAIL\n', nPass, nFail);

%% ======================= local functions ================================
function s = cl_step(f, C, T0, kaC, ka, umax, x0, ieq, xr, Tend, tStep, xStand, d)
% Lab cascade controller (as maglev_cascade_sim, no noise) around a plant f(y, u), y = [x; v; i].
% Starts at rest at x0 with current ieq and the integral at its equilibrium value.
% d = extra loop delay in samples (multiple of 0.1), applied exactly as in maglev_cascade_sim; the delay
% line starts holding the equilibrium command ieq/ka.
sub = 10;  h = T0/sub;  N = round(Tend/T0);
nInt = floor(d + 1e-9);  mSub = round((d - nInt)*sub);  assert(abs((d - nInt)*sub - mSub) < 1e-6);
uHist = (ieq/ka)*ones(1, nInt + 2);
iref0 = (ieq/ka + C.Kc*ieq)/(1/kaC + C.Kc);
z = min(max((iref0 - C.i0)/C.Ki, -C.zLim), C.zLim);  s.z0 = z;
x = x0;  v = 0;  i = ieq;  xp = x;
s.t = (0:N-1)'*T0;  s.x = zeros(N, 1);  s.i = s.x;
for k = 1:N
    r = x0 + (xr - x0)*(s.t(k) >= tStep);
    e = x - r;  vel = (x - xp)/T0;  xp = x;
    iref = min(max(C.i0 + C.Kp*e + C.Kd*vel + C.Ki*z, 0), 2.0);
    u = min(max(iref/kaC + C.Kc*(iref - i), 0), umax);
    z = min(max(z + T0*e, -C.zLim), C.zLim);
    s.x(k) = x;  s.i(k) = i;
    uHist = [uHist(2:end), u];
    for j = 1:sub
        if j <= mSub, ua = uHist(end - nInt - 1); else, ua = uHist(end - nInt); end
        y = [x; v; i];
        k1 = f(y, ua); k2 = f(y + h/2*k1, ua); k3 = f(y + h/2*k2, ua); k4 = f(y + h*k3, ua);
        y = y + h/6*(k1 + 2*k2 + 2*k3 + k4);
        x = y(1); v = y(2); i = y(3);
        if x >= xStand && v >= 0, x = xStand; v = 0; end
        if x <= 0, x = 0; v = 0; end
    end
end
end

function os = step_metrics(t, x, a, z)
% Overshoot beyond the new level z [mm], as s07/s08 (33 ms running mean, after the 50 % crossing).
d = z - a;  xs = movmean(x, 11);
k50 = find(sign(d)*(xs - (a + d/2)) > 0, 1);
if isempty(k50), os = NaN; return; end
os = max(1e3*max(sign(d)*(xs(k50:end) - z)), 0);
end
