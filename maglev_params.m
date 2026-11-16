% maglev_params.m   [STANDALONE]
% =========================================================================
% PURPOSE   The ONE place where every number of the MagLev project lives.
%           Creates the struct P. Every other script starts with
%               maglev_params;
%           and never retypes a number.
% INPUTS    none
% OUTPUTS   struct P in the caller's workspace (overwrites any existing P).
% CHECKED   by 01_verify_model.m (reproduces the manual's numbers from P).
%
% UNITS     SI everywhere: m, m/s, A, V, s, kg.
% SIGNS     x1 = gap from the magnet face [m]; INCREASING x1 = ball moves DOWN.
%           x2 = x1' [m/s];  x3 = coil current [A];  u = command [V].
%           Plant gain is NEGATIVE: more voltage -> more current -> more pull
%           -> SMALLER gap.   G_reduced(s) = a23*ki/(s^2 - a21) = -K/(s^2-a21)
%           Controller convention (manual p.37):  e = x1 - x0 (measured minus
%           desired),  u = u0 + C(s)*e,  with POSITIVE Kp, Kd.
%           In MATLAB standard form this loop is POSITIVE feedback, so use
%           feedback(G*C, -1)  (or flip the sign of C). Each script says which.
%
% STATUS TAGS  Anything marked UNCONFIRMED is a guess until a lab experiment
%           (Phase 6) measures it. Changing the value here changes it everywhere.
% =========================================================================

P = struct();

%% ---- meta -------------------------------------------------------------
P.meta.version = 'maglev_params v2 (Phase 2)';
P.meta.units   = 'SI: m, m/s, A, V, s, kg';

%% ---- folders ----------------------------------------------------------
P.dir.root    = fileparts(mfilename('fullpath'));
P.dir.scripts = fullfile(P.dir.root, 'scripts');
P.dir.models  = fullfile(P.dir.root, 'models');
P.dir.data    = fullfile(P.dir.root, 'data');
P.dir.figs    = fullfile(P.dir.root, 'figs');

%% ---- physics (manual p.31, p.34) --------------------------------------
P.g = 9.81;                         % [m/s^2]

% Electromagnetic force  Fem = x3^2 * (P1/P2) * exp(-x1/P2)
% P1, P2 are pure FIT parameters of the manual's spheres (names unexplained).
P.Fem.P1     = 1.7521e-2;           % [H]
P.Fem.P2     = 5.8231e-3;           % [m]
P.Fem.status = 'manual values; PROVISIONAL for the ellipsoidal balls (Phase 6 force fit)';

% Actuator (coil + current driver):  x3' = (ki*u + ci - x3)/fi
% Manual p.31 mask = dynamic ID with gain 1 (small steps).
P.act.ki     = 0.5432595;           % [A/V]
P.act.ci     = 0.0367586;           % [A]
P.act.fi     = 0.6263e-3;           % [s]  grows to ~17 ms for LARGE steps (manual p.24)
P.act.status = 'manual values; re-identify on this unit in Phase 6';

%% ---- limits -----------------------------------------------------------
P.lim.umin        = 0.0;            % [V]
P.lim.umax        = 5.0;            % [V]
P.lim.x3min       = 0.0345;         % [A]  manual pp.17,31
P.lim.x3min_table = 0.03884;        % [A]  manual p.34 table (conflicts; irrelevant near 0.8 A)
P.lim.x3max       = 2.345;          % [A]  HARD safety limit, never exceed
P.lim.x1min       = 0.0;            % [m]
P.lim.x1max       = 0.02;           % [m]  model limit
P.lim.x1sensor    = 0.014;          % [m]  UNCONFIRMED: sensor flattens beyond ~14 mm (Fig. 6); measure in Phase 6

%% ---- balls ------------------------------------------------------------
P.ball = struct( ...
    'name', {'manual_big', 'manual_small', 'mine_39g', 'mine_42g'}, ...
    'm',    {0.0571,       0.036,          0.039288,   0.042137}, ...
    'note', {'manual p.34 table (unit tests)', ...
             'manual mask default / PID sim p.37 (Fig. 46 check)', ...
             'my ball, hollow ellipsoid, mass measured', ...
             'my ball, hollow ellipsoid, mass measured'});

P.nom.ball = 'mine_39g';            % nominal ball for design (changeable)
P.nom.m    = P.ball(strcmp({P.ball.name}, P.nom.ball)).m;
P.nom.x10  = 9e-3;                  % [m] nominal operating gap (manual uses 9 mm)

%% ---- digital loop (ALL UNCONFIRMED, Phase 6 measures them) ------------
P.loop.Ts             = 10e-3;      % [s] controller sample time (manual p.25: 10 ms for USB)
P.loop.nExtraSamples  = 0;          % extra whole samples of delay (RT-CON may add 1)
P.loop.delayExtra     = 0.0;        % [s] any additional pure delay
P.loop.filtersInPath  = true;       % are the Fig. 30 driver filters in the path?
P.loop.tauPos         = 5e-3;       % [s] position filter 1/(tau*s+1)
P.loop.tauVel         = 5e-3;       % [s] velocity filter
P.loop.tauCur         = 5e-3;       % [s] current filter
P.loop.status = struct( ...
    'Ts',         'UNCONFIRMED: read fixed step and log time spacing', ...
    'delay',      'UNCONFIRMED: step-injection test; does RT-CON add a sample?', ...
    'filters',    'UNCONFIRMED: Fig. 30 is low-res; inspect driver read-only', ...
    'velocity',   'UNCONFIRMED: which velocity signal the PD block uses');

%% ---- manual's PID (p.37, continuous simulation, 36 g ball) ------------
P.manualPID.Kp = 200;               % [V/m]
P.manualPID.Ki = 1000;              % [V/(m s)]
P.manualPID.Kd = 50;                % [V s/m]

%% ---- sweeps -----------------------------------------------------------
P.sweep.gap   = (7:0.5:11) * 1e-3;                    % [m]
P.sweep.balls = {'manual_big', 'mine_39g', 'mine_42g'};

%% ---- plant models and frequency grids (Phase 2) -----------------------
P.plant.padeN = 3;                              % order of the Pade delay approximation
P.freq.w      = logspace(0, 3.5, 800);          % [rad/s] Bode grid (1 ... ~3162)
P.freq.wNyq   = logspace(-2, 4, 3000);          % [rad/s] Nyquist grid
% Demo PD gains used ONLY for the Phase 2 stability illustrations (not a design):
%   Kp = KpFactor * Kp_min,   u = u0 + Kp*e + Kd*de/dt,   e = x1 - x0
P.demo.KpFactor = 1.5;
P.demo.Kd       = 0.5;                          % [V s/m]

%% ---- plotting (white background, bright colours, for the report) ------
P.plot.fs     = 12;
P.plot.lw     = 1.8;
P.plot.res    = 200;                % PNG resolution [dpi]
P.plot.colors = [ 0.00 0.45 0.95;   % bright blue
                  0.95 0.15 0.10;   % bright red
                  0.00 0.70 0.25;   % bright green
                  1.00 0.55 0.00;   % orange
                  0.65 0.15 0.85;   % purple
                  0.00 0.75 0.80];  % cyan
% Call  P.plot.apply();  at the top of every plotting script (white background,
% black text, bright colour order, font size and line width from above).
P.plot.apply  = @() set(groot, 'defaultFigureColor', 'w', 'defaultAxesColor', 'w', ...
    'defaultAxesXColor', 'k', 'defaultAxesYColor', 'k', 'defaultAxesGridColor', 'k', ...
    'defaultTextColor', 'k', 'defaultLegendTextColor', 'k', 'defaultLegendColor', 'w', ...
    'defaultAxesFontSize', P.plot.fs, 'defaultLineLineWidth', P.plot.lw, ...
    'defaultAxesColorOrder', P.plot.colors);

%% ---- expected numbers for self-checks (manual + briefing) -------------
% 57.1 g ball at 9 mm (manual pp.35-36, briefing sec.3)
P.test.ref57 = struct('x30',0.9345, 'u0',1.65, 'a21',1684.7, 'p',41.05, ...
                      'a23',-21.0, 'a33',-1597, 'b3',867, 'K',11.41);
P.test.tol57 = struct('x30',1e-3, 'u0',0.01, 'a21',0.1, 'p',0.01, ...
                      'a23',0.02, 'a33',1, 'b3',1, 'K',0.02);
% my balls at 9 mm (briefing, provisional)
P.test.mine    = struct('x30_39',0.775, 'u0_39',1.36, 'Kpmin_39',122.5, ...
                        'x30_42',0.803, 'u0_42',1.41, 'Kpmin_42',126.9);
P.test.minetol = struct('x30',2e-3, 'u0',0.01, 'Kpmin',0.2);
% 36 g at 10 mm vs manual Fig. 46 (reading of a plot: ~0.8 A, ~1.4 V)
P.test.fig46 = struct('x30',0.8, 'u0',1.4, 'tolx30',0.02, 'tolu0',0.03);
