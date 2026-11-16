function M = maglev_plant(P, eq, opts)
% MAGLEV_PLANT  [STANDALONE]  Linear plant models for design and analysis.
% =========================================================================
% PURPOSE   Build the LTI models of the MagLev around an equilibrium, with
%           optional position filter, delay and sampling (ZOH). Used by the
%           analysis, design and robustness scripts, so it lives here once.
%
% INPUTS    P     struct from maglev_params
%           eq    struct from maglev_equilibrium (same operating point)
%           opts  (optional) struct; any missing field takes its default:
%             .filters   logical, include the position filter 1/(tauPos*s+1)
%                        (default P.loop.filtersInPath)
%             .tauDelay  total pure delay [s] of the loop
%                        (default Ts/2 [ZOH] + nExtraSamples*Ts + delayExtra)
%             .padeN     Pade order for the delay (default P.plant.padeN)
%             .nDelaySamples  extra whole samples in the discrete model
%                        (default P.loop.nExtraSamples)
%
% OUTPUT    M     struct of models (Control System Toolbox objects)
%  PHYSICAL sign (input du [V], output dx1 [m]; plant gain NEGATIVE):
%   M.G2    a23*ki/(s^2 - a21)                  = -K/(s^2 - a21)   reduced
%   M.G3    a23*ki/((s^2 - a21)(fi*s+1))                           third order
%   M.Gss   ss(A,B,C,0), same as G3 (checked in s02)
%  SIGN-ABSORBED (Gs = -G, so a controller with POSITIVE gains and ordinary
%  NEGATIVE unity feedback is the right loop: L = Gs*C, T = feedback(L,1)):
%   M.Gs2, M.Gs3           without filter / delay
%   M.Gs2f, M.Gs3f         x position filter x Pade delay   (pole/zero analysis)
%   M.Gs2d, M.Gs3d         x position filter, EXACT delay as InputDelay
%                          (Bode, Nyquist, margins; do not use for pole())
%   M.Gs3z                 c2d(Gs3*Fpos, Ts, 'zoh') with InputDelay = nDelaySamples
%  PIECES    M.Fpos, M.Hpade, M.tauDelay, M.opts, M.eq
%
% EQUIVALENCE   Manual convention e = x1 - x0, u = C*e is POSITIVE feedback of
%   the physical plant G. In MATLAB that is feedback(G*C, -1), and it has the
%   same poles as feedback(Gs*C, 1) with Gs = -G. The classic wrong-sign loop
%   is feedback(G*C, 1): negative feedback of the PHYSICAL plant with positive
%   gains. s02 tests that it is unstable.
%
% WHAT IS (NOT) MODELLED   Only the POSITION filter sits in this loop. The
%   velocity and current filters (P.loop.tauVel, tauCur) matter only for
%   controllers that use those signals; they are not applied here. Whether
%   the filters are in the real path at all is UNCONFIRMED (Phase 6/7).
%
% CHECKED   by s02_plant_analysis.m
% =========================================================================

if nargin < 3 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'filters'),  opts.filters  = P.loop.filtersInPath; end
if ~isfield(opts, 'tauDelay')
    opts.tauDelay = P.loop.Ts / 2 + P.loop.nExtraSamples * P.loop.Ts + P.loop.delayExtra;
end
if ~isfield(opts, 'padeN'),         opts.padeN         = P.plant.padeN; end
if ~isfield(opts, 'nDelaySamples'), opts.nDelaySamples = P.loop.nExtraSamples; end
assert(opts.tauDelay >= 0, 'maglev_plant: delay must be >= 0.');

fi  = P.act.fi;
ki  = P.act.ki;
den2 = [1 0 -eq.a21];                           % s^2 - a21

% Physical models (negative gain a23*ki = -K)
M.G2  = tf(eq.a23 * ki, den2);
M.G3  = tf(eq.a23 * ki, conv(den2, [fi 1]));
M.Gss = ss(eq.A, eq.B, eq.C, 0);

% Sign-absorbed models
M.Gs2 = -M.G2;
M.Gs3 = -M.G3;

% Position filter and delay
if opts.filters
    M.Fpos = tf(1, [P.loop.tauPos 1]);
else
    M.Fpos = tf(1, 1);
end
if opts.tauDelay > 0
    [nn, dd] = pade(opts.tauDelay, opts.padeN);  % Control System Toolbox
    M.Hpade  = tf(nn, dd);
else
    M.Hpade  = tf(1, 1);
end
M.tauDelay = opts.tauDelay;

% Models for pole/zero analysis (Pade delay)
M.Gs2f = M.Gs2 * M.Fpos * M.Hpade;
M.Gs3f = M.Gs3 * M.Fpos * M.Hpade;

% Models for frequency response (exact delay)
M.Gs2d = M.Gs2 * M.Fpos;   M.Gs2d.InputDelay = opts.tauDelay;
M.Gs3d = M.Gs3 * M.Fpos;   M.Gs3d.InputDelay = opts.tauDelay;

% Sampled model (zero-order hold at Ts, extra whole samples of delay)
M.Gs3z = c2d(M.Gs3 * M.Fpos, P.loop.Ts, 'zoh');
M.Gs3z.InputDelay = opts.nDelaySamples;

M.opts = opts;
M.eq   = eq;
end
