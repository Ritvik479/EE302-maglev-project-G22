% s05_cascade_design.m   [STANDALONE]
% =========================================================================
% PURPOSE   Phase 3 (revised after the 2026-11-12 lab session): design a
%           CASCADE controller for the lab rig and check it before it touches
%           the hardware.
%             inner loop : current controller  u = i_ref/ka + Kc*(i_ref - i)
%             outer loop : PID on position     i_ref = i0 + Kp*e + Kd*v + Ki*z
%           e = x - x_ref (manual sign), v = (x[k]-x[k-1])/T0 (driver's own
%           velocity output), z = clamped discrete integral of e.
%
% WHY       The coil lags the command (tau ~ 22-25 ms measured; 27 ms is the design value,
%           range 20-35 ms). A loop that sees only the position handles that lag badly.
%           (Revised 2026-11-16, AUDIT.md 2.15. The earlier text said the lab PD was "predicted
%           (and was observed) to oscillate at 7-9 Hz"; the linear model does not predict that.)
%           On a linear model of the rig (fitted plant, T0 = 3 ms, measured delay), the lab PD
%           as run on 12-Nov (Kp 45, Kd on the difference e[k]-e[k-1]) sits ON the stability
%           boundary: unstable pole ~5.2-5.6 Hz, max|eig| 1.004-1.011 (Kp 40 without extra delay
%           is even just stable). The 7-9 Hz seen in the lab was a large-amplitude cycle that hit
%           the stand every period and drove u to 0, i.e. nonlinear, not a linear prediction.
%           A full grid of position-only PD gains does contain stable points, but the best have
%           Ms 5.7-13 (Ms = peak of |1/(1+L)|; ~2 is a usual target), i.e. very fragile.
%           So the cascade is chosen for ROBUSTNESS: measuring the current and closing a fast
%           loop around it makes the coil look like an ~4 ms lag, and an ordinary PID on
%           position then has comfortable margins.
%
% PLANT     Lab-identified, NOT the manual's mask values:
%   T0 = 3 ms, ZOH, current  i' = (ka*u + ci - i)/tau,  ka = 2.44 A/unit,
%   tau = 27 ms (range 20..35 ms). Ball: x'' = g - F(x,i)/m, F = c*i^2*exp(-x/lam).
%   Linearized: x'' = a21*dx - b*di with a21 = g/lam and b = 2g/i0 (exact for
%   any force law of the form F ~ i^2*f(x)). lam and i0 are uncertain, so the
%   grid covers them.
%
% SIGNS     Increasing x = ball DOWN. More current = more pull = x decreases.
%           e = x - x_ref > 0 (ball too low) must RAISE the current, so all the
%           gains Kp, Kd, Ki, Kc are POSITIVE. Section 5 flips the sign and
%           checks that it is unstable.
%
% OUTPUTS   console PASS/FAIL lines, data/phase3_cascade.mat,
%           figs/p3_liftoff_sim.png, figs/p3_inner_step.png
% =========================================================================
clear; clc;
here = fileparts(mfilename('fullpath'));
run(fullfile(here, '..', 'maglev_params.m'));
P.plot.apply();
chk = @(c, m) fprintf('%s: %s\n', ternary(c, 'PASS', 'FAIL'), m);

%% ---- 0. lab-identified numbers (data/lab_2026-11-12) -------------------
L.T0   = 0.003;          % [s]  FixedStep of the lab models
L.ka   = 2.44;           % [A per unit u]  coil static gain (coil steps, run 4)
L.ci   = 0.02;           % [A]  offset
L.tau  = 0.027;          % [s]  coil time constant: design value (measured later 22-25 ms; see data/README.md)
L.m    = P.nom.m;        % [kg] 39.288 g ball
L.xr   = 0.010;          % [m]  set point used in the lab
L.umax = 0.90;           % [-]  our command ceiling: 0.9*2.44 = 2.2 A steady (< 2.345 A)

% Lift evidence (both read from the lab runs):
%   run 2   : ball on stand at 11.8 mm, 0.87 A, NO lift   -> F(11.8, 0.87) < m g
%   steps   : ball on stand at 12.9 mm, 0.93 A, LIFT      -> F(12.9, 0.93) >= m g
% With F = c i^2 exp(-x/lam) both hold only if
%   (0.93/0.87)^2 * exp(-1.1 mm / lam) > 1   ->   lam > 1.1 mm / ln((0.93/0.87)^2)
lamMin = 1.1e-3 / log((0.93/0.87)^2);
fprintf('Force decay length: manual P2 = %.2f mm, lab data need lam > %.2f mm\n', ...
        1e3*P.Fem.P2, 1e3*lamMin);
fprintf('  -> manual model is %s with the lift data (one-sided bound, 2 points only)\n', ...
        ternary(P.Fem.P2 > lamMin, 'consistent', 'INCONSISTENT'));
fprintf(['  [SUPERSEDED 2026-11-13: lift thresholds from the stand are not an equilibrium, so this bound is void; the\n' ...
         '   hover fits give lam ~5.9 mm, consistent with the manual (data/README.md). The lift-off sims below and\n' ...
         '   figs/p3_liftoff_sim.png use force constants built on this premise: pre-lab design check only.]\n']);

% Hover current at 10 mm for a force law that lifts at 12.9 mm with ~0.90 A:
%   i0(10 mm) = 0.90*exp(-(12.9-10) mm / (2 lam))
lamGrid = [P.Fem.P2, 8.3e-3, 10e-3];
i0_39 = 0.90 * exp(-2.9e-3 ./ (2*lamGrid));
fprintf('Predicted hover current at 10 mm (39 g): %s A for lam = %s mm\n', ...
        mat2str(round(i0_39, 3)), mat2str(round(1e3*lamGrid, 2)));
L.i0 = 0.75;             % [A] nominal feed-forward hover current (the integral fixes the rest)

%% ---- 1. controller gains ----------------------------------------------
% Inner loop. Discrete coil: i[k+1] = a i[k] + bd u[k], a = exp(-T0/tau), bd = ka(1-a).
% With u = i_ref/ka + Kc (i_ref - i) the closed-loop pole is  a - bd*Kc.
% Target pole p_in = exp(-T0/tau_in) with tau_in = 3 ms (about 9x faster than the coil).
% (Sweep of wn, zeta, tau_in vs the grid: 3 ms gave the lowest worst-case Ms.)
a  = exp(-L.T0/L.tau);  bd = L.ka*(1 - a);
tau_in = 0.003;  p_in = exp(-L.T0/tau_in);
C.Kc = (a - p_in)/bd;                      % [unit/A]

% Outer loop: pole placement on  x'' = a21 x - b i  with ideal current:
%   s^3 + b Kd s^2 + (b Kp - a21) s + b Ki = (s + w_i)(s^2 + 2 zeta w_n s + w_n^2)
a21n = P.g / P.Fem.P2;   bn = 2*P.g / L.i0;
wn = 40;  zeta = 0.7;  wi = 12;          % [rad/s], [-], [rad/s]
c2 = wi + 2*zeta*wn;  c1 = wn^2 + 2*zeta*wn*wi;  c0 = wi*wn^2;
C.Kd = c2/bn;                              % [A s/m]
C.Kp = (c1 + a21n)/bn;                     % [A/m]
C.Ki = c0/bn;                              % [A/(m s)]
C.zLim = 0.30 / C.Ki;                      % integral clamp: Ki*z within +-0.30 A
C.i0 = L.i0;
fprintf('\nGains: Kc = %.3f /A | Kp = %.1f A/m, Kd = %.3f A s/m, Ki = %.0f A/(m s)\n', ...
        C.Kc, C.Kp, C.Kd, C.Ki);
fprintf('       integral clamp |z| <= %.3g m s  (= +-0.30 A)\n', C.zLim);

%% ---- 2. linear discrete closed loop + robustness grid ------------------
tauG = [0.020 0.027 0.035];  kaG = [2.2 2.44 2.7];   % measured: tau 22-25 ms, ka 2.43 (2.33-2.46 incremental)
a21G = P.g ./ [P.Fem.P2 8.3e-3 10e-3];  i0G = [0.65 0.75 0.90];   % predicted 0.70-0.81 A (both balls)
nd = [0 1];                                % extra whole samples of delay (RT-CON)
res = [];                                  % [tau ka a21 i0 nd rho Ms]
for t1 = tauG, for k1 = kaG, for a1 = a21G, for q1 = i0G, for d1 = nd
    [rho, Ms] = cascade_loop(C, L.T0, t1, k1, L.ka, a1, 2*P.g/q1, d1, +1);
    res(end+1, :) = [t1 k1 a1 q1 d1 rho Ms]; %#ok<SAGROW>
end, end, end, end, end
r0 = res(res(:,5) == 0, :);  r1 = res(res(:,5) == 1, :);
[rhoN, MsN] = cascade_loop(C, L.T0, L.tau, L.ka, L.ka, a21n, bn, 0, +1);
fprintf('\nNominal: max|eig| = %.4f, Ms = %.2f\n', rhoN, MsN);
fprintf('Grid (%d cases, no extra delay): worst max|eig| = %.4f, worst Ms = %.2f\n', ...
        size(r0,1), max(r0(:,6)), max(r0(:,7)));
fprintf('Grid (%d cases, +1 sample)    : worst max|eig| = %.4f, worst Ms = %.2f\n', ...
        size(r1,1), max(r1(:,6)), max(r1(:,7)));
[~, iw] = max(r1(:,7));
fprintf('  worst case: tau %.0f ms, ka %.2f, a21 %.0f, i0 %.2f A\n', ...
        1e3*r1(iw,1), r1(iw,2), r1(iw,3), r1(iw,4));

chk(rhoN < 1, 'nominal cascade loop is stable');
chk(all(r0(:,6) < 1), 'stable over the whole grid (no extra delay)');
chk(all(r1(:,6) < 1), 'stable over the whole grid (+1 sample delay; the coil test showed none)');
chk(max(r0(:,7)) < 2.0, sprintf('worst Ms < 2.0 without extra delay (got %.2f)', max(r0(:,7))));
fprintf('NOTE: with +1 sample the worst Ms is %.2f: stable but fragile, so re-check the delay in the lab.\n', max(r1(:,7)));

%% ---- 3. sign test and the lab PD for comparison ------------------------
rhoW = cascade_loop(C, L.T0, L.tau, L.ka, L.ka, a21n, bn, 0, -1);
chk(rhoW > 1, sprintf('WRONG sign (all gains negated) is unstable (max|eig| = %.2f)', rhoW));
rhoPD = pd_only_loop(45, 450, L.T0, L.tau, L.ka, a21n, bn);
chk(rhoPD > 1, sprintf(['lab x-only PD (Kp 45, Kd_raw 450) is unstable with tau = 27 ms (max|eig| = %.3f; linear model, ' ...
     'manual force law; the 7-9 Hz of run 4 was a nonlinear cycle, see WHY)'], rhoPD));

%% ---- 4. nonlinear lift-off simulation (ball starts on the stand) -------
% Plan used in the lab: stand at 12 mm, set point 11 mm at start, 10 mm at t = 1.5 s.
cases = struct('name', {}, 'lam', {}, 'm', {}, 'tau', {}, 'ka', {});
cases(end+1) = struct('name', '39 g, manual lam',  'lam', P.Fem.P2, 'm', 0.039288, 'tau', 0.027, 'ka', 2.44);
cases(end+1) = struct('name', '39 g, lam 10 mm',   'lam', 10e-3,    'm', 0.039288, 'tau', 0.027, 'ka', 2.44);
cases(end+1) = struct('name', '42 g, slow coil',   'lam', 8.3e-3,   'm', 0.042137, 'tau', 0.035, 'ka', 1.9);
cases(end+1) = struct('name', '39 g, fast coil',   'lam', 5.8e-3,   'm', 0.039288, 'tau', 0.020, 'ka', 2.7);
S = cell(size(cases));
for n = 1:numel(cases)
    S{n} = nl_sim(C, L, cases(n));
    s = S{n};
    late = s.t > 3.0;
    fprintf('\n[%s] lift-off sim:\n', cases(n).name);
    chk(s.lifted,              '  ball leaves the stand');
    chk(min(s.x) > 1.0e-3,     sprintf('  never closer than 1 mm to the magnet (min x = %.2f mm)', 1e3*min(s.x)));
    chk(max(abs(s.x(late) - 0.010)) < 0.1e-3, sprintf('  |x - 10 mm| < 0.1 mm after 3 s (got %.3f mm)', 1e3*max(abs(s.x(late)-0.010))));
    chk(max(s.i) < 2.2,        sprintf('  peak current %.2f A < 2.2 A', max(s.i)));
    chk(s.uSatFrac < 0.05,     sprintf('  command saturated %.1f %% of the time (< 5 %%)', 100*s.uSatFrac));
end

%% ---- 5. inner-loop-only test (ball on the stand, no levitation) --------
% First lab step: drive i_ref directly, 0.3 -> 0.5 A. Prediction to compare with.
tt = (0:399)'*L.T0;  iref = 0.3 + 0.2*(tt >= 0.3);
ii = zeros(size(tt)); ii(1) = 0.3; uu = zeros(size(tt));
for k = 1:numel(tt)-1
    uu(k) = min(max(iref(k)/L.ka + C.Kc*(iref(k) - ii(k)), 0), L.umax);
    ii(k+1) = a*ii(k) + bd*uu(k) + (1-a)*L.ci;
end
uu(end) = uu(end-1);
i63 = 0.3 + 0.63*(ii(end) - 0.3);
t63 = tt(find(ii >= i63 & tt >= 0.3, 1)) - 0.3;
fprintf('\nInner-loop step 0.3 -> 0.5 A: steady %.3f A, 63%% rise %.1f ms (open coil: %.0f ms), u peak %.2f\n', ...
        ii(end), 1e3*t63, 1e3*L.tau, max(uu));
chk(t63 < 0.008, 'inner loop at least 3x faster than the open coil');
chk(abs(ii(end) - 0.5) < 0.02, 'inner loop steady error < 20 mA (feed-forward)');

%% ---- 6. figures --------------------------------------------------------
f1 = figure('Position', [100 100 900 750]);
tl = tiledlayout(3,1, 'TileSpacing', 'compact');
ax = gobjects(3,1);
for j = 1:3, ax(j) = nexttile; hold on; grid on; end
for n = 1:numel(S)
    s = S{n};
    plot(ax(1), s.t, 1e3*s.x);  plot(ax(2), s.t, s.i);  plot(ax(3), s.t, s.u);
end
plot(ax(1), S{1}.t, 1e3*S{1}.xr, 'k--', 'LineWidth', 1.2);
set(ax(1), 'YDir', 'reverse');
ylabel(ax(1), 'gap x [mm]');  ylabel(ax(2), 'current i [A]');  ylabel(ax(3), 'command u [-]');
xlabel(ax(3), 'time [s]');
legend(ax(1), [{cases.name}, {'set point'}], 'Location', 'southeast');
title(ax(1), {'Cascade controller: nonlinear lift-off from the 12 mm stand', ...
       '(PRE-LAB check; force constants from a withdrawn premise, see s05 section 0)'}, 'Color', 'k');
title(ax(2), 'Coil current', 'Color', 'k');  title(ax(3), 'Command (PWM duty)', 'Color', 'k');
exportgraphics(f1, fullfile(P.dir.figs, 'p3_liftoff_sim.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

f2 = figure('Position', [100 100 800 420]); hold on; grid on;
plot(tt, iref, 'k--', 'LineWidth', 1.2); plot(tt, ii);
plot(tt, 0.3 + 0.2*(1 - exp(-max(tt-0.3,0)/L.tau)).*(tt>=0.3));
xlabel('time [s]'); ylabel('current [A]');
legend('i_{ref}', 'with inner loop (predicted)', 'open coil, \tau = 27 ms', 'Location', 'southeast');
title('Lab step 1: inner current loop, ball on the stand', 'Color', 'k');
exportgraphics(f2, fullfile(P.dir.figs, 'p3_inner_step.png'), 'Resolution', P.plot.res, 'BackgroundColor', 'w');

save(fullfile(P.dir.data, 'phase3_cascade.mat'), 'C', 'L', 'res', 'cases', 'S');
fprintf('\nSaved data/phase3_cascade.mat, figs/p3_liftoff_sim.png, figs/p3_inner_step.png\n');

%% ======================= local functions ================================
function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end

function [rho, Ms] = cascade_loop(C, T, tau, ka, kaCtrl, a21, b, nd, sgn)
% Discrete loop of the linearized plant + cascade controller.
% States [dx; v; di] (plant, ZOH), [xp; z] (controller), d1..d_nd (delay of u).
% The loop is broken at the controller output u_c:  L(z) = -H(z), where H is
% the map from an injected plant input w to u_c. S = 1/(1+L). sgn = -1 negates
% every controller gain (wrong-sign test).
Ac = [0 1 0; a21 0 -b; 0 0 -1/tau];  Bc = [0; 0; ka/tau];
sysd = c2d(ss(Ac, Bc, eye(3), 0), T, 'zoh');
Ad = sysd.A; Bd = sysd.B;
Kp = sgn*C.Kp; Kd = sgn*C.Kd; Ki = sgn*C.Ki; Kc = sgn*C.Kc; kff = sgn/kaCtrl;
% i_ref = Kp x + Kd (x - xp)/T + Ki z ;  u_c = i_ref/kaCtrl + Kc (i_ref - i)
Ri = [Kp + Kd/T, 0, 0, -Kd/T, Ki];
Ru = (kff + Kc)*Ri - Kc*[0 0 1 0 0];
n = 5 + nd;
A = zeros(n); B = zeros(n,1);
A(1:3,1:3) = Ad;
A(4,1) = 1;                     % xp[k+1] = x[k]
A(5,[1 5]) = [T 1];             % z[k+1] = z[k] + T x[k]   (forward Euler)
if nd == 0
    B(1:3) = Bd;                % w drives the plant directly
else
    B(6) = 1;                   % w enters the delay chain
    for j = 7:n, A(j, j-1) = 1; end
    A(1:3, n) = Bd;             % plant gets the oldest stored command
end
Cu = [Ru zeros(1, nd)];
rho = max(abs(eig(A + B*Cu)));  % closed loop: w = u_c
Lsys = ss(A, B, -Cu, 0, T);
w = logspace(-1, log10(0.999*pi/T), 2000);
Sresp = squeeze(freqresp(feedback(1, Lsys), w));
if rho < 1, Ms = max(abs(Sresp)); else, Ms = Inf; end
end

function rho = pd_only_loop(Kp, KdRaw, T, tau, ka, a21, b)
% Lab PD: u = u0 + Kp e + KdRaw (e[k]-e[k-1]); position-only.
Ac = [0 1 0; a21 0 -b; 0 0 -1/tau];  Bc = [0; 0; ka/tau];
sysd = c2d(ss(Ac, Bc, eye(3), 0), T, 'zoh');
R = [Kp + KdRaw, 0, 0, -KdRaw];
A = zeros(4); A(1:3,1:3) = sysd.A; A(4,1) = 1;
A(1:3,:) = A(1:3,:) + sysd.B*R;
rho = max(abs(eig(A)));
end

function s = nl_sim(C, L, cs)
% Nonlinear sim. Plant at dt = T0/10 (RK4), controller at T0 with ZOH.
g = 9.81; T = L.T0; Tend = 4.0; sub = 10; h = T/sub;
xStand = 0.012;
c = cs.m*g / (0.90^2 * exp(-0.0129/cs.lam));      % lifts at 12.9 mm with 0.90 A
N = round(Tend/T);
s.t = (0:N-1)'*T; s.x = zeros(N,1); s.i = s.x; s.u = s.x; s.xr = s.x;
x = xStand; v = 0; i = 0.30; xp = x; z = 0; lifted = false; nSat = 0;
for k = 1:N
    tk = s.t(k);
    xr = 0.011 - 0.001*(tk >= 1.5);
    e = x - xr;  vel = (x - xp)/T;  xp = x;
    iref = C.i0 + C.Kp*e + C.Kd*vel + C.Ki*z;
    iref = min(max(iref, 0), 2.0);
    u = iref/L.ka + C.Kc*(iref - i);
    if u > L.umax || u < 0, nSat = nSat + 1; end
    u = min(max(u, 0), L.umax);
    z = min(max(z + T*e, -C.zLim), C.zLim);     % clamped integral (anti-windup)
    s.x(k) = x; s.i(k) = i; s.u(k) = u; s.xr(k) = xr;
    for j = 1:sub
        f = @(y) [y(2); g - c*max(y(3),0)^2*exp(-y(1)/cs.lam)/cs.m; (cs.ka*u + L.ci - y(3))/cs.tau];
        y = [x; v; i];
        k1 = f(y); k2 = f(y + h/2*k1); k3 = f(y + h/2*k2); k4 = f(y + h*k3);
        y = y + h/6*(k1 + 2*k2 + 2*k3 + k4);
        x = y(1); v = y(2); i = y(3);
        if x >= xStand && v >= 0, x = xStand; v = 0; end   % stand catches the ball
        if x <= 0, x = 0; v = 0; end                       % magnet face
        if x < xStand - 0.2e-3, lifted = true; end
    end
end
s.lifted = lifted; s.uSatFrac = nSat/N;
end
