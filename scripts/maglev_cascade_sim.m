function s = maglev_cascade_sim(C, L, pl, xref, Tend, opts)
% MAGLEV_CASCADE_SIM  [STANDALONE]  Nonlinear MagLev + cascade controller, as in the lab.
% =========================================================================
% PLANT (continuous, RK4 at T0/10):
%   x'' = g - c*max(i - ioff, 0)^2 * exp(-x/lam) / m      (x = gap, down = +)
%   i'  = (ka*kg*u + ci - i)/tau        i = coil current as the SENSOR reports it;
%                                       ioff = sensor reading at zero true current
%   stand at x = xStand (catches the ball), magnet face at x = 0.
% CONTROLLER (every T0, same blocks as my_cascade_rt; e = x - x_ref):
%   v = (xm[k] - xm[k-1])/T0 ;  i_ref = sat_[0,2]( i0 + Kp e + Kd v + Ki*z )
%   z: forward-Euler integral of e, Ki*z clamped to +-0.3 A
%   u = sat_[0,0.9]( kg * ( i_ref/ka_c + Kc (i_ref - im) ) )
%   xm, im = measured x, i (+ white noise sigX, sigI if given)
% INPUTS
%   C    gains struct (Kp, Kd, Ki, Kc, i0, zLim) from phase3_cascade.mat
%   L    lab struct (T0, ka, ci, umax) from phase3_cascade.mat (L.ka = controller's 1/ka value)
%   pl   plant: m, lam, c, ioff, tau, ka, ci
%   xref function handle @(t) -> set point [m]
%   Tend final time [s]
%   opts (optional): x0, v0, i0s (initial current), z0 (initial integral state),
%        kg (scalar or @(t)), sigX, sigI (noise std), seed, xStand,
%        d  extra loop delay in samples beyond the normal ZOH step (default 0; added 2026-11-15).
%           d must be a multiple of 0.1 (the plant sub-step), so it is applied exactly: the command
%           computed at sample k reaches the coil over [k + d, k + 1 + d) T0.
%        uIC  command held by the delay line at the start (default 0; equilibrium command for a hover start).
%        fx   force multiplier @(x) -> scalar, applied to the force law (default 1 = unchanged; added
%             2026-11-15 for s13: hypothesis "the force decays more slowly than exp(-x/lam) beyond 11 mm").
% OUTPUT s.t, s.x (true), s.xm (measured), s.i, s.u, s.iref, s.xr
% =========================================================================
if nargin < 6, opts = struct(); end
g = 9.81; T = L.T0; sub = 10; h = T/sub;
def = struct('x0', 0.0119, 'v0', 0, 'i0s', 0, 'z0', C.zLim, 'kg', 1, 'sigX', 0, 'sigI', 0, ...
             'seed', 1, 'xStand', 0.0119, 'd', 0, 'uIC', 0, 'fx', []);
fn = fieldnames(def);
for k = 1:numel(fn), if ~isfield(opts, fn{k}), opts.(fn{k}) = def.(fn{k}); end, end
nInt = floor(opts.d + 1e-9);  mSub = round((opts.d - nInt)*10);
assert(opts.d >= 0 && abs((opts.d - nInt)*10 - mSub) < 1e-6, 'maglev_cascade_sim: d must be a multiple of 0.1');
uHist = opts.uIC*ones(1, nInt + 2);              % uHist(end) = u[k], uHist(end-1) = u[k-1], ... (start: uIC)
if isempty(opts.fx), fxf = @(x) 1; else, fxf = opts.fx; end
if isnumeric(opts.kg), kgv = opts.kg; kgf = @(t) kgv; else, kgf = opts.kg; end
rng(opts.seed);
N = round(Tend/T);
s.t = (0:N-1)'*T;
[s.x, s.xm, s.i, s.u, s.iref, s.xr] = deal(zeros(N,1));
x = opts.x0; v = opts.v0; i = opts.i0s; z = opts.z0;
xmPrev = x + opts.sigX*randn;
for k = 1:N
    tk = s.t(k);
    xr = xref(tk);
    xm = x + opts.sigX*randn;   im = i + opts.sigI*randn;
    e = xm - xr;  vel = (xm - xmPrev)/T;  xmPrev = xm;
    iref = min(max(C.i0 + C.Kp*e + C.Kd*vel + C.Ki*z, 0), 2.0);
    u = min(max(kgf(tk)*(iref/L.ka + C.Kc*(iref - im)), 0), L.umax);
    z = min(max(z + T*e, -C.zLim), C.zLim);
    s.x(k) = x; s.xm(k) = xm; s.i(k) = i; s.u(k) = u; s.iref(k) = iref; s.xr(k) = xr;
    uHist = [uHist(2:end), u];
    for j = 1:sub
        if j <= mSub, ua = uHist(end - nInt - 1); else, ua = uHist(end - nInt); end   % command reaching the coil
        f = @(y) [y(2); g - pl.c*max(y(3) - pl.ioff, 0)^2*exp(-y(1)/pl.lam)*fxf(y(1))/pl.m; ...
                  (pl.ka*ua + pl.ci - y(3))/pl.tau];
        y = [x; v; i];
        k1 = f(y); k2 = f(y + h/2*k1); k3 = f(y + h/2*k2); k4 = f(y + h*k3);
        y = y + h/6*(k1 + 2*k2 + 2*k3 + k4);
        x = y(1); v = y(2); i = y(3);
        if x >= opts.xStand && v >= 0, x = opts.xStand; v = 0; end
        if x <= 0, x = 0; v = 0; end
    end
end
end
