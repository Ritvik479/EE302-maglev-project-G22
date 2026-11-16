function mdl = build_maglev_cl_sim(outDir)
% BUILD_MAGLEV_CL_SIM  [STANDALONE]  Build models/maglev_cl_sim.slx: the closed-loop
% MagLev simulation used for the nominal and uncertain cases (PS9 deliverable 2).
% =========================================================================
% STRUCTURE (top level)                          all parameters come from 4 workspace structs:
%   Set point  --x_ref-->  Cascade controller  --u-->  Plant  --x, i_true-->  Sensors --xm, im--> (back)
%     pl  plant      m, c, lam, g, tau, ka, ci, xStand
%     C   controller Kp, Ki, Kd, Kc, i0, iLim       (same numbers as the lab models)
%     L   lab        T0, kaC (controller's ka = 2.44), umax
%     sc  scenario   x0, i0s, zI, bpT, bpX, gate, kg, nd, sigX, sigI, seedX, seedI,
%                    iz0, izRate, dxA, dxF, Tend
% PLANT (continuous, ode4 at T0/10):
%   i_true' = (ka u + ci - i_true)/tau
%   x''     = g - (c/m) max(i_true,0)^2 exp(-x/lam)        x = gap, DOWN = +
%   x limited to [0, xStand] (magnet face, stand); velocity reset at the limits.
% SENSORS (sampled every T0): xm = sat_[0,0.02](x + noise + dxA sin(2 pi dxF t))   (dxA: tilt artifact)
%                             im = i_true + iz0 + izRate t + noise        (current-sensor zero + drift)
% SET POINT (as my_cascade_sweep_rt): tau = Forward-Euler sum of T0*[xm < gate];
%   x_ref = table(tau), Flat, Clip.   gate = 1 m makes tau = t (a plain timetable).
% CONTROLLER (as the lab "Cascade controller", e = x - x_ref):
%   v = (xm[k] - xm[k-1])/T0
%   i_ref = sat_[0,2]( i0 + Kp e + Kd v + DTI_FE(Ki e) clamped to +-iLim )
%   u     = sat_[0,umax]( kg (i_ref/kaC + Kc (i_ref - im)) )
% LOOP DELAY (top level, between controller and plant; revised 2026-11-15): the coil receives u delayed by
%   d = sc.nd + sc.ndSub/10 samples beyond the normal ZOH step: ONE Delay block at the solver step T0/10 with
%   length 10*sc.nd + sc.ndSub sub-steps. u changes only every T0, so this applies a delay in tenths of a
%   sample exactly. (A version with a T0-rate delay + Rate Transition block added a spurious delay: rejected.)
%   The delay line starts holding sc.uIC (0 for a lift-off; the equilibrium command for a hover start).
%   (Before 2026-11-15 only whole samples existed, inside the controller, and the logged u was the delayed one.)
% LOGGED (To Workspace, every T0): tt, x, xm, it, im, u (controller output, before the loop delay, as the
%   lab scope logs it), iref, xref, tau
% =========================================================================
mdl = 'maglev_cl_sim';
if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl);
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', 'L.T0/10', ...
          'StopTime', 'sc.Tend', 'EnableMultiTasking', 'off', 'ReturnWorkspaceOutputs', 'on', ...
          'SaveTime', 'off', 'SaveOutput', 'off', 'AlgebraicLoopMsg', 'error');
T = 'L.T0';

%% ---- Plant ----------------------------------------------------------------
p = sub(mdl, 'Plant');
add(p, 'u', 'simulink/Ports & Subsystems/In1');
add(p, 'ka', 'simulink/Math Operations/Gain', 'Gain', 'pl.ka');
add(p, 'ci', 'simulink/Sources/Constant', 'Value', 'pl.ci');
add(p, 'coil sum', 'simulink/Math Operations/Sum', 'Inputs', '++-');
add(p, 'inv tau', 'simulink/Math Operations/Gain', 'Gain', '1/pl.tau');
add(p, 'coil', 'simulink/Continuous/Integrator', 'InitialCondition', 'sc.i0s');
add(p, 'i>=0', 'simulink/Discontinuities/Saturation', 'UpperLimit', 'inf', 'LowerLimit', '0');
add(p, 'i^2', 'simulink/Math Operations/Math Function', 'Operator', 'square');
add(p, 'neg inv lam', 'simulink/Math Operations/Gain', 'Gain', '-1/pl.lam');
add(p, 'exp', 'simulink/Math Operations/Math Function', 'Operator', 'exp');
add(p, 'i^2 exp', 'simulink/Math Operations/Product');
add(p, 'c over m', 'simulink/Math Operations/Gain', 'Gain', 'pl.c/pl.m');
add(p, 'g', 'simulink/Sources/Constant', 'Value', 'pl.g');
add(p, 'x dd', 'simulink/Math Operations/Sum', 'Inputs', '+-');
add(p, 'ball (x, stand, magnet)', 'simulink/Continuous/Integrator, Second-Order', ...
    'ICX', 'sc.x0', 'ICDXDT', '0', 'LimitX', 'on', 'UpperLimitX', 'pl.xStand', 'LowerLimitX', '0', ...
    'ShowOutput', 'x');
add(p, 'x', 'simulink/Ports & Subsystems/Out1');
add(p, 'i_true', 'simulink/Ports & Subsystems/Out1');
w(p, 'u/1', 'ka/1'); w(p, 'ka/1', 'coil sum/1'); w(p, 'ci/1', 'coil sum/2'); w(p, 'coil/1', 'coil sum/3');
w(p, 'coil sum/1', 'inv tau/1'); w(p, 'inv tau/1', 'coil/1');
w(p, 'coil/1', 'i>=0/1'); w(p, 'i>=0/1', 'i^2/1'); w(p, 'i^2/1', 'i^2 exp/1');
w(p, 'ball (x, stand, magnet)/1', 'neg inv lam/1'); w(p, 'neg inv lam/1', 'exp/1'); w(p, 'exp/1', 'i^2 exp/2');
w(p, 'i^2 exp/1', 'c over m/1'); w(p, 'g/1', 'x dd/1'); w(p, 'c over m/1', 'x dd/2');
w(p, 'x dd/1', 'ball (x, stand, magnet)/1');
w(p, 'ball (x, stand, magnet)/1', 'x/1'); w(p, 'coil/1', 'i_true/1');

%% ---- Sensors -------------------------------------------------------------
s = sub(mdl, 'Sensors');
add(s, 'x', 'simulink/Ports & Subsystems/In1');
add(s, 'i_true', 'simulink/Ports & Subsystems/In1');
add(s, 'ZOH x', 'simulink/Discrete/Zero-Order Hold', 'SampleTime', T);
add(s, 'ZOH i', 'simulink/Discrete/Zero-Order Hold', 'SampleTime', T);
add(s, 'x noise', 'simulink/Sources/Random Number', 'Variance', 'sc.sigX^2', 'Seed', 'sc.seedX', 'SampleTime', T);
add(s, 'i noise', 'simulink/Sources/Random Number', 'Variance', 'sc.sigI^2', 'Seed', 'sc.seedI', 'SampleTime', T);
add(s, 'tilt artifact', 'simulink/Sources/Sine Wave', 'Amplitude', 'sc.dxA', 'Frequency', '2*pi*sc.dxF', 'SampleTime', T);
add(s, 'clock', 'simulink/Sources/Digital Clock', 'SampleTime', T);
add(s, 'zero drift', 'simulink/Math Operations/Gain', 'Gain', 'sc.izRate');
add(s, 'zero', 'simulink/Sources/Constant', 'Value', 'sc.iz0');
add(s, 'x sum', 'simulink/Math Operations/Sum', 'Inputs', '+++');
add(s, 'i sum', 'simulink/Math Operations/Sum', 'Inputs', '++++');
add(s, 'Position sat (driver)', 'simulink/Discontinuities/Saturation', 'UpperLimit', '0.02', 'LowerLimit', '0');
add(s, 'xm', 'simulink/Ports & Subsystems/Out1');
add(s, 'im', 'simulink/Ports & Subsystems/Out1');
w(s, 'x/1', 'ZOH x/1'); w(s, 'ZOH x/1', 'x sum/1'); w(s, 'x noise/1', 'x sum/2'); w(s, 'tilt artifact/1', 'x sum/3');
w(s, 'x sum/1', 'Position sat (driver)/1'); w(s, 'Position sat (driver)/1', 'xm/1');
w(s, 'i_true/1', 'ZOH i/1'); w(s, 'ZOH i/1', 'i sum/1'); w(s, 'i noise/1', 'i sum/2'); w(s, 'zero/1', 'i sum/3');
w(s, 'clock/1', 'zero drift/1'); w(s, 'zero drift/1', 'i sum/4'); w(s, 'i sum/1', 'im/1');

%% ---- Set point (gated sweep clock, as my_cascade_sweep_rt) ----------------
q = sub(mdl, 'Set point');
add(q, 'xm', 'simulink/Ports & Subsystems/In1');
add(q, 'lifted ?', 'simulink/Logic and Bit Operations/Compare To Constant', 'relop', '<', 'const', 'sc.gate');
add(q, 'to double', 'simulink/Signal Attributes/Data Type Conversion', 'OutDataTypeStr', 'double');
add(q, 'sweep clock', 'simulink/Discrete/Discrete-Time Integrator', 'IntegratorMethod', 'Integration: Forward Euler', ...
    'gainval', '1.0', 'SampleTime', T, 'InitialCondition', '0');
add(q, 'sweep table', 'simulink/Lookup Tables/1-D Lookup Table', 'BreakpointsForDimension1', 'sc.bpT', ...
    'Table', 'sc.bpX', 'InterpMethod', 'Flat', 'ExtrapMethod', 'Clip');
add(q, 'x_ref', 'simulink/Ports & Subsystems/Out1');
add(q, 'tau', 'simulink/Ports & Subsystems/Out1');
w(q, 'xm/1', 'lifted ?/1'); w(q, 'lifted ?/1', 'to double/1'); w(q, 'to double/1', 'sweep clock/1');
w(q, 'sweep clock/1', 'sweep table/1'); w(q, 'sweep table/1', 'x_ref/1'); w(q, 'sweep clock/1', 'tau/1');

%% ---- Cascade controller (same blocks as the lab subsystem) -----------------
c = sub(mdl, 'Cascade controller');
add(c, 'xm', 'simulink/Ports & Subsystems/In1');
add(c, 'x_ref', 'simulink/Ports & Subsystems/In1');
add(c, 'im', 'simulink/Ports & Subsystems/In1');
add(c, 'e = x - x_ref', 'simulink/Math Operations/Sum', 'Inputs', '+-');
add(c, 'x[k-1]', 'simulink/Discrete/Unit Delay', 'InitialCondition', 'sc.x0', 'SampleTime', T);
add(c, 'dx', 'simulink/Math Operations/Sum', 'Inputs', '+-');
add(c, 'inv T0', 'simulink/Math Operations/Gain', 'Gain', '1/L.T0');
add(c, 'Kp', 'simulink/Math Operations/Gain', 'Gain', 'C.Kp');
add(c, 'Ki', 'simulink/Math Operations/Gain', 'Gain', 'C.Ki');
add(c, 'Discrete-Time Integrator', 'simulink/Discrete/Discrete-Time Integrator', 'IntegratorMethod', ...
    'Integration: Forward Euler', 'gainval', '1.0', 'SampleTime', T, 'LimitOutput', 'on', ...
    'UpperSaturationLimit', 'C.iLim', 'LowerSaturationLimit', '-C.iLim', 'InitialCondition', 'sc.zI');
add(c, 'Kd', 'simulink/Math Operations/Gain', 'Gain', 'C.Kd');
add(c, 'i0', 'simulink/Sources/Constant', 'Value', 'C.i0');
add(c, 'PID sum', 'simulink/Math Operations/Sum', 'Inputs', '++++');
add(c, 'i_ref limit', 'simulink/Discontinuities/Saturation', 'UpperLimit', '2.0', 'LowerLimit', '0');
add(c, 'i error', 'simulink/Math Operations/Sum', 'Inputs', '+-');
add(c, 'Kc', 'simulink/Math Operations/Gain', 'Gain', 'C.Kc');
add(c, 'inv ka', 'simulink/Math Operations/Gain', 'Gain', '1/L.kaC');
add(c, 'u sum', 'simulink/Math Operations/Sum', 'Inputs', '++');
add(c, 'kg', 'simulink/Sources/Constant', 'Value', 'sc.kg');
add(c, 'x kg', 'simulink/Math Operations/Product');
add(c, 'u limit', 'simulink/Discontinuities/Saturation', 'UpperLimit', 'L.umax', 'LowerLimit', '0');
add(c, 'u', 'simulink/Ports & Subsystems/Out1');
add(c, 'i_ref', 'simulink/Ports & Subsystems/Out1');
w(c, 'xm/1', 'e = x - x_ref/1'); w(c, 'x_ref/1', 'e = x - x_ref/2');
w(c, 'xm/1', 'x[k-1]/1'); w(c, 'xm/1', 'dx/1'); w(c, 'x[k-1]/1', 'dx/2'); w(c, 'dx/1', 'inv T0/1');
w(c, 'e = x - x_ref/1', 'Kp/1'); w(c, 'e = x - x_ref/1', 'Ki/1'); w(c, 'Ki/1', 'Discrete-Time Integrator/1');
w(c, 'inv T0/1', 'Kd/1');
w(c, 'Kp/1', 'PID sum/1'); w(c, 'Discrete-Time Integrator/1', 'PID sum/2'); w(c, 'Kd/1', 'PID sum/3'); w(c, 'i0/1', 'PID sum/4');
w(c, 'PID sum/1', 'i_ref limit/1');
w(c, 'i_ref limit/1', 'i error/1'); w(c, 'im/1', 'i error/2'); w(c, 'i error/1', 'Kc/1');
w(c, 'i_ref limit/1', 'inv ka/1'); w(c, 'inv ka/1', 'u sum/1'); w(c, 'Kc/1', 'u sum/2');
w(c, 'u sum/1', 'x kg/1'); w(c, 'kg/1', 'x kg/2'); w(c, 'x kg/1', 'u limit/1');
w(c, 'u limit/1', 'u/1');
w(c, 'i_ref limit/1', 'i_ref/1');

%% ---- top level wiring + logging ------------------------------------------
add(mdl, 'loop delay (sub-steps)', 'simulink/Discrete/Delay', 'DelayLength', '10*sc.nd + sc.ndSub', ...
    'InitialCondition', 'sc.uIC', 'SampleTime', 'L.T0/10');
w(mdl, 'Cascade controller/1', 'loop delay (sub-steps)/1');
w(mdl, 'loop delay (sub-steps)/1', 'Plant/1');
w(mdl, 'Plant/1', 'Sensors/1'); w(mdl, 'Plant/2', 'Sensors/2');
w(mdl, 'Sensors/1', 'Set point/1');
w(mdl, 'Sensors/1', 'Cascade controller/1'); w(mdl, 'Set point/1', 'Cascade controller/2');
w(mdl, 'Sensors/2', 'Cascade controller/3');
add(mdl, 'time', 'simulink/Sources/Digital Clock', 'SampleTime', T);
logs = {'time/1', 'tt'; 'Plant/1', 'x'; 'Sensors/1', 'xm'; 'Plant/2', 'it'; 'Sensors/2', 'im'; ...
        'Cascade controller/1', 'u'; 'Cascade controller/2', 'iref'; 'Set point/1', 'xref'; 'Set point/2', 'tau'};
for k = 1:size(logs, 1)
    add(mdl, ['log ' logs{k,2}], 'simulink/Sinks/To Workspace', 'VariableName', logs{k,2}, ...
        'SaveFormat', 'Array', 'SampleTime', T, 'MaxDataPoints', 'inf');
    w(mdl, logs{k,1}, ['log ' logs{k,2} '/1']);
end
for sys = {p, s, q, c, mdl}, Simulink.BlockDiagram.arrangeSystem(sys{1}); end
set_param(mdl, 'Description', ['[STANDALONE] Closed-loop MagLev simulation (nonlinear plant + lab cascade controller). ' ...
    'Built by scripts/build_maglev_cl_sim.m. Parameters: workspace structs pl, C, L, sc (see scripts/maglev_cases.m).']);
save_system(mdl, fullfile(outDir, [mdl '.slx']));
end

%% ---- helpers ---------------------------------------------------------------
function p = sub(parent, name)
p = [parent '/' name];
add_block('simulink/Ports & Subsystems/Subsystem', p);
delete_line(p, 'In1/1', 'Out1/1');  delete_block([p '/In1']);  delete_block([p '/Out1']);
end
function add(sys, name, lib, varargin)
add_block(lib, [sys '/' name], varargin{:});
end
function w(sys, a, b)
add_line(sys, a, b, 'autorouting', 'smart');
end
