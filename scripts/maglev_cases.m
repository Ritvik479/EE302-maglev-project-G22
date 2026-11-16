function [K, B, U] = maglev_cases(P, variant)
% MAGLEV_CASES  [STANDALONE]  Nominal and uncertain cases for models/maglev_cl_sim.slx.
% =========================================================================
% OUTPUT  B  base structs: B.pl39, B.pl42 (plant), B.C (controller), B.L (lab), B.sc (scenario)
%         K  struct array of cases: name, group, ball, pl, sc  (complete structs, ready to simulate)
%         U  uncertainty table: parameter, nominal, range, evidence (for the report)
% NOMINAL PLANT  = force law fitted to 42 hover visits (s08): lam 5.90 mm, c 3.29 / 3.02 N/A^2,
%                  coil tau 27 ms, static gain 2.43 A/unit (s07), no actuator offset.
% CONTROLLER     = the values deployed in the lab (read from the generated C code, 2026-11-13).
% SCENARIO       = lift-off from the stand (rest 11.92 mm), then the lab's gated sweep clock
%                  with 0.5 mm steps, 1.5 s per level: 11 -> 9 -> 11 mm (14.5 s), i.e. the lab sweep,
%                  compressed in time. (11.5 mm is NOT a step target: it is only 0.42 mm above the
%                  stand; s09 reports that step separately.)
%                  kg cases copy lab Exp C: start HOVERING at 10 mm and hold it (kg was changed in hover).
% VARIANT        (optional, default 'lab') controller variant:
%                  'lab' = as deployed: i0 0.75 A, integral clamp +-0.30 A, integral wound up to the clamp
%                          at switch-on (the outer loop runs while the ball sits on the stand)
%                  'D'   = SIMULATION ONLY (s11, 2026-11-15; not on the hardware): i0 0.85 A, clamp +-0.45 A,
%                          integral reset to 0 at switch-on (sc.zI = 0; the simulation starts at switch-on)
% LOOP DELAY     (revised 2026-11-15, s12) extra delay d beyond the normal ZOH step, in samples:
%                  measured 0.32-0.55 (data/delay_estimate.mat). Rules, in tenths of a sample so that the
%                  Simulink model applies it exactly (sub-step T0/10):
%                    nominal = spectral best fit rounded to 0.1  (-> 0.5)
%                    range   = measured range rounded OUTWARD to 0.1 (-> 0.3 .. 0.6)
%                  sc.nd = whole samples, sc.ndSub = tenths. Before 2026-11-15 the set was d = 0 / +1 sample.
% =========================================================================
if nargin < 2, variant = 'lab'; end
D = load(fullfile(P.dir.data, 'lab_2026-11-13', 'sweeps_holds_results.mat'), 'lam', 'cB');
E = load(fullfile(P.dir.data, 'lab_2026-11-13', 'exp_ABC_results.mat'), 'kaP', 'sigX', 'sigI', 'ioff');
DE = load(fullfile(P.dir.data, 'delay_estimate.mat'), 'DE');  DE = DE.DE;
[~, kb] = min(DE.dSpectral(:,4));
B.dly = struct('nom', round(10*DE.dSpectral(kb,3))/10, 'lo', floor(10*DE.range(1) + 1e-9)/10, ...
               'hi', ceil(10*DE.range(2) - 1e-9)/10, 'measured', DE.range, 'dHatTime', DE.dHat, ...
               'dHatSpectral', DE.dSpectral(kb,3));
m39 = 0.039288;  m42 = 0.042137;  xStand = 0.01192;

B.C = struct('Kp', 151.2, 'Ki', 734, 'Kd', 2.6, 'Kc', 2.05, 'i0', 0.75, 'iLim', 0.3);
B.L = struct('T0', 0.003, 'kaC', 2.44, 'umax', 0.9);
B.pl39 = struct('m', m39, 'c', D.cB(1), 'lam', D.lam, 'g', P.g, 'tau', 0.027, 'ka', E.kaP, 'ci', 0, 'xStand', xStand);
B.pl42 = B.pl39;  B.pl42.m = m42;  B.pl42.c = D.cB(2);
B.sc = struct('x0', xStand, 'i0s', 0, 'zI', B.C.iLim, ...
              'bpT', [0 2 3.5 5 6.5 8 9.5 11 12.5], ...
              'bpX', [11 10.5 10 9.5 9 9.5 10 10.5 11]*1e-3, 'gate', 0.0115, ...
              'kg', 1, 'nd', 0, 'sigX', 0, 'sigI', 0, 'seedX', 11, 'seedI', 12, ...
              'iz0', E.ioff, 'izRate', 0, 'dxA', 0, 'dxF', 2.45, 'Tend', 14.5, 'ndSub', 0, 'uIC', 0);
B.sc = set_delay(B.sc, B.dly.nom);
switch variant
    case 'lab'
    case 'D'
        B.C.i0 = 0.85;  B.C.iLim = 0.45;  B.sc.zI = 0;
    otherwise
        error('maglev_cases: unknown variant ''%s'' (use ''lab'' or ''D'')', variant);
end
B.variant = variant;

U = struct('param', {}, 'nominal', {}, 'range', {}, 'evidence', {});
U(end+1) = struct('param', 'ball mass m', 'nominal', '39.288 g', 'range', '39.288 / 42.137 g', ...
    'evidence', 'the two lab balls (weighed)');
U(end+1) = struct('param', 'force constant c', 'nominal', sprintf('%.2f / %.2f N/A^2', D.cB), 'range', '+-5 %', ...
    'evidence', 'refits on different data sets moved c by 2-4 %; fit residual 5.9 mA = 1.4 % force');
U(end+1) = struct('param', 'force decay length lam', 'nominal', sprintf('%.2f mm', 1e3*D.lam), 'range', '+-5 % (5.6-6.2 mm)', ...
    'evidence', 'fits 5.81 (morning) / 5.90 (all data), manual 5.82 mm');
U(end+1) = struct('param', 'operating gap x0', 'nominal', '10 mm', 'range', '9-11.5 mm', ...
    'evidence', 'validated hover range in the lab (equilibrium shift; covered by the scenario)');
U(end+1) = struct('param', 'coil time constant tau', 'nominal', '27 ms', 'range', '20-35 ms', ...
    'evidence', 'coil step test 25-29 ms, widened for heating and gap-dependent inductance');
U(end+1) = struct('param', 'coil static gain ka', 'nominal', sprintf('%.2f A/unit', E.kaP), 'range', '2.2-2.7 A/unit', ...
    'evidence', 'coil steps dI/du 2.4-2.6 (1.9 near u = 0); hover data 2.43');
U(end+1) = struct('param', 'actuator gain error kg', 'nominal', '1', 'range', '0.4 / 2.0', ...
    'evidence', 'Exp C: tested in the lab, all stable');
U(end+1) = struct('param', 'extra loop delay d', 'nominal', sprintf('%.1f sample (%.1f ms)', B.dly.nom, 3*B.dly.nom), ...
    'range', sprintf('%.1f-%.1f sample', B.dly.lo, B.dly.hi), ...
    'evidence', sprintf(['s12 (run 3, inner loop alone): output-error fit %.2f, noise shaping %.2f; measured range ' ...
    '%.2f-%.2f, d = 0 and d = 1 both rejected; open-loop coil steps uninformative'], B.dly.dHatTime, ...
    B.dly.dHatSpectral, B.dly.measured));
U(end+1) = struct('param', 'sensor noise', 'nominal', '0', 'range', sprintf('x %.4f mm, i %.3f A (std)', 1e3*E.sigX, E.sigI), ...
    'evidence', 'readings with the ball on the stand, u = 0');
U(end+1) = struct('param', 'current-sensor zero drift', 'nominal', '0', 'range', '-0.85 mA/s', ...
    'evidence', 'u = 0 readings before/after the long sweeps');
U(end+1) = struct('param', 'tilt artifact on x (unmodelled rocking)', 'nominal', '0', 'range', '0.27 mm at 2.45 Hz', ...
    'evidence', ['39 g 11.5 mm hold: current swing 54.5 mA needs ~0.62 mm true motion (88 mA/mm), ' ...
                 'reading 0.35 mm -> ~0.27 mm of the reading is tilt (Newton test, s08)']);

K = struct('name', {}, 'group', {}, 'ball', {}, 'pl', {}, 'sc', {});
for b = [39 42]
    pl = B.(sprintf('pl%d', b));
    K(end+1) = mk(sprintf('nominal %d g', b), 'nominal', b, pl, B.sc, struct()); %#ok<AGROW>
    % references outside the measured delay range: the model used before 2026-11-15 (d = 0) and a stress case
    K(end+1) = mk(sprintf('nominal %d g, d 0 (old model)', b), 'delay ref', b, pl, set_delay(B.sc, 0), struct()); %#ok<AGROW>
    K(end+1) = mk(sprintf('nominal %d g, d 1 (stress)', b), 'delay ref', b, pl, set_delay(B.sc, 1), struct()); %#ok<AGROW>
end
dLev = [B.dly.lo B.dly.hi];  gName = {'corner, d low', 'corner, d high'};
for q = 1:2, for b = [39 42], for tau = [0.020 0.035], for ka = [2.2 2.7], for fl = [0.95 1.05], for fc = [0.95 1.05]
    pl = B.(sprintf('pl%d', b));  pl.tau = tau;  pl.ka = ka;  pl.lam = fl*pl.lam;  pl.c = fc*pl.c;
    nm = sprintf('%d g, tau %2.0f ms, ka %.1f, lam %+.0f%%, c %+.0f%%, d %.1f', b, 1e3*tau, ka, 100*(fl-1), ...
                 100*(fc-1), dLev(q));
    K(end+1) = mk(nm, gName{q}, b, pl, set_delay(B.sc, dLev(q)), struct()); %#ok<AGROW>
end, end, end, end, end, end
for kgv = [0.4 2.0]                            % Exp C: hover at 10 mm with kg applied
    hv = hover_start(B.pl39, B.sc, B.C, 0.010, kgv);  hv.bpT = [0 1];  hv.bpX = [10 10]*1e-3;  hv.Tend = 6;
    K(end+1) = mk(sprintf('39 g, kg %.1f (hover 10 mm, as Exp C)', kgv), 'actuator', 39, B.pl39, B.sc, hv); %#ok<AGROW>
end
K(end+1) = mk('39 g, sensor noise', 'sensor', 39, B.pl39, B.sc, struct('sigX', E.sigX, 'sigI', E.sigI));
K(end+1) = mk('42 g, sensor noise', 'sensor', 42, B.pl42, B.sc, struct('sigX', E.sigX, 'sigI', E.sigI));
K(end+1) = mk('39 g, zero drift', 'sensor', 39, B.pl39, B.sc, struct('izRate', -0.85e-3));
K(end+1) = mk('39 g, tilt artifact', 'unmodelled', 39, B.pl39, B.sc, struct('dxA', 0.27e-3));
K(end+1) = mk('39 g, lab-like (noise + drift + tilt)', 'unmodelled', 39, B.pl39, B.sc, ...
              struct('sigX', E.sigX, 'sigI', E.sigI, 'izRate', -0.85e-3, 'dxA', 0.27e-3));
end

function ov = hover_start(pl, sc, C, x0, kg)
% initial state for starting in hover at gap x0 with actuator gain error kg: true equilibrium
% current ieq, and the integral value that makes the coil hold it with e = 0:
%   ieq = ka kg (i_ref/kaC + Kc (i_ref - ieq - iz0))  ->  solve for i_ref;  zI = i_ref - i0
if nargin < 5, kg = 1; end
kaC = 2.44;  ieq = sqrt(pl.m*pl.g*exp(x0/pl.lam)/pl.c);
iref = (ieq/(pl.ka*kg) + C.Kc*(ieq + sc.iz0))/(1/kaC + C.Kc);
ov = struct('x0', x0, 'i0s', ieq, 'zI', min(max(iref - C.i0, -C.iLim), C.iLim), 'kg', kg, ...
            'uIC', ieq/pl.ka);                  % the delay line starts holding the equilibrium command
end

function sc = set_delay(sc, d)
% extra loop delay d (samples, multiple of 0.1) -> whole samples sc.nd + tenths sc.ndSub
sc.nd = floor(d + 1e-9);  sc.ndSub = round(10*(d - sc.nd));
assert(abs(sc.nd + sc.ndSub/10 - d) < 1e-9, 'set_delay: d must be a multiple of 0.1');
end

function k = mk(name, group, ball, pl, sc, ov)
for f = fieldnames(ov)', sc.(f{1}) = ov.(f{1}); end
k = struct('name', name, 'group', group, 'ball', ball, 'pl', pl, 'sc', sc);
end
