function eq = maglev_equilibrium(P, m, x10)
% MAGLEV_EQUILIBRIUM  Equilibrium and linearization of the MLS1EM model.
% =========================================================================
% PURPOSE   Given parameters P, ball mass m and gap x10, compute the
%           equilibrium (x30, u0) and the linear model (A,B,C) with the
%           manual's formulas (p.36). Used by many scripts (analysis, design,
%           robustness grid), so it lives here once.
%
% INPUTS    P    struct from maglev_params (uses P.g, P.Fem, P.act, P.lim).
%                To vary other parameters (FemP1, FemP2, ki, ci, fi) copy P,
%                edit the copy, and pass it in:  Q = P; Q.Fem.P2 = 1.1*Q.Fem.P2;
%           m    ball mass [kg]
%           x10  equilibrium gap [m]   (0 < x10 <= P.lim.x1max)
%
% OUTPUT    eq   struct with fields
%   m, x10        inputs
%   x30           equilibrium current [A]     (Fem = m*g)
%   u0            equilibrium command [V]     from x30 = ki*u0 + ci
%   F_eq, resid   Fem at equilibrium [N], relative force-balance residual
%   a21,a23,a33,b3  linearization entries (manual p.36), computed from the
%                 partial derivatives of Fem, NOT from the simplified forms
%   K             |a23|*ki  [(m/s^2)/V]   reduced-plant gain
%   p             sqrt(a21)  [rad/s]      unstable pole
%   Kp_min        a21/K      [V/m]        minimum stabilizing proportional gain
%   A,B,C         x' = A dx + B du,  y = C dx = dx1   (deviation variables)
%   Fem           function handle @(x1,x3) -> force [N] (elementwise)
%   inLimits      struct: x3, u, x1model, x1sensor, all (all = x3&u&x1model)
%
% SIGNS     x1 = gap, increasing downward. a23 < 0, b3 > 0, so the plant gain
%           a23*ki is NEGATIVE. Reduced plant: G(s) = -K/(s^2 - a21).
%
% CHECKED   by 01_verify_model.m against the manual's unit-test numbers.
% =========================================================================

assert(isstruct(P) && isfield(P, 'Fem'), 'maglev_equilibrium: P must come from maglev_params.');
assert(isscalar(m) && m > 0,   'maglev_equilibrium: mass must be a positive scalar [kg].');
assert(isscalar(x10) && x10 > P.lim.x1min && x10 <= P.lim.x1max, ...
       'maglev_equilibrium: gap must be in (0, x1max] [m]; got %g.', x10);

g  = P.g;
P1 = P.Fem.P1;   P2 = P.Fem.P2;
ki = P.act.ki;   ci = P.act.ci;   fi = P.act.fi;

% Electromagnetic force (elementwise so it can be plotted over vectors)
Fem = @(x1, x3) x3.^2 .* (P1 / P2) .* exp(-x1 ./ P2);

% Equilibrium: Fem(x10,x30) = m*g  ->  x30^2 = m*g*P2/P1 * exp(x10/P2)
x30 = sqrt(m * g * P2 / P1) * exp(x10 / (2 * P2));
u0  = (x30 - ci) / ki;                      % static actuator law x3 = ki*u + ci

F_eq  = Fem(x10, x30);
resid = abs(F_eq - m * g) / (m * g);

% Linearization of  x2' = -Fem/m + g  and  x3' = (ki*u + ci - x3)/fi
dFdx1 = -x30^2 * (P1 / P2^2) * exp(-x10 / P2);   % dFem/dx1  (< 0: force falls with gap)
dFdx3 =  2 * x30 * (P1 / P2) * exp(-x10 / P2);   % dFem/dx3  (> 0: force rises with current)
a21 = -dFdx1 / m;                                % > 0  -> unstable
a23 = -dFdx3 / m;                                % < 0  -> negative plant gain
a33 = -1 / fi;
b3  =  ki / fi;

K      = abs(a23) * ki;
p      = sqrt(a21);
Kp_min = a21 / K;

eq.m = m;  eq.x10 = x10;  eq.x30 = x30;  eq.u0 = u0;
eq.F_eq = F_eq;  eq.resid = resid;
eq.a21 = a21;  eq.a23 = a23;  eq.a33 = a33;  eq.b3 = b3;
eq.K = K;  eq.p = p;  eq.Kp_min = Kp_min;
eq.A = [0 1 0; a21 0 a23; 0 0 a33];
eq.B = [0; 0; b3];
eq.C = [1 0 0];
eq.Fem = Fem;

eq.inLimits.x3       = (x30 >= P.lim.x3min) && (x30 <= P.lim.x3max);
eq.inLimits.u        = (u0  >= P.lim.umin)  && (u0  <= P.lim.umax);
eq.inLimits.x1model  = (x10 >= P.lim.x1min) && (x10 <= P.lim.x1max);
eq.inLimits.x1sensor = (x10 <= P.lim.x1sensor);   % flag only; sensor range UNCONFIRMED
eq.inLimits.all      = eq.inLimits.x3 && eq.inLimits.u && eq.inLimits.x1model;
end
