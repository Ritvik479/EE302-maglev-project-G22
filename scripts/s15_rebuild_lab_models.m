function R = s15_rebuild_lab_models(baseModel, outDir, overwrite)
%S15_REBUILD_LAB_MODELS  [LAB] Rebuild the cascade hardware models deleted from the lab PC on 2026-11-16.
%
%   Builds  my_cascade_rt, my_cascade_kg_rt, my_cascade_sweep_rt  with the parameters that were DEPLOYED on
%   2026-11-13, starting from a fresh copy of the INTECO PD example (my_pd_rt). The cascade models were made from
%   that copy (their driver has Saturation Current +-30, as only the PD copy has), so the rig block, its internal
%   settings, the solver and the RT-CON target all come from it unchanged. Only our blocks are added.
%
%   LAB PC (R2024a):
%     s15_rebuild_lab_models('C:\Users\hp\Desktop\group_22\my_pd_rt.slx', 'C:\Users\hp\Desktop\group_22')
%   LAPTOP test [STANDALONE] (stand-in plant, also simulates the sweep logic):
%     s15_rebuild_lab_models('stub', fullfile(tempdir,'s15_test'))
%   Third argument true = allow overwriting existing .slx files (default false).
%
%   Source of every value: generated C code inside models/build_cache_2026-11-13/*.slxc (the build caches of the deployed models,
%   13-Nov-2026: *_data.c for values, *.c for wiring and switch settings) and the screenshots
%   data/lab_2026-11-13/screenshots/01, 02, 05, 07, 08, 09.
%
%   Sign convention (as on the lab): e = x - x_ref (Sum '-+', x_ref on the minus port). Ball too LOW (x larger)
%   -> e > 0 -> i_ref larger -> more pull. Check 7 tests this.

if nargin < 1 || isempty(baseModel), baseModel = 'C:\Users\hp\Desktop\group_22\my_pd_rt.slx'; end
if nargin < 2 || isempty(outDir),    outDir    = 'C:\Users\hp\Desktop\group_22'; end
if nargin < 3,                       overwrite = false; end
stub = strcmpi(baseModel, 'stub');
if ~exist(outDir, 'dir'), mkdir(outDir); end

% ---------------- deployed values (from the .slxc build caches) ----------------
V.T0 = 0.003;  V.Kp = 151.2;  V.Ki = 734;  V.Kd = 2.6;  V.i0 = 0.75;  V.Icl = 0.3;
V.irefMax = 2.0;  V.itest = 0.5;  V.Kc = 2.05;  V.ka = 2.44;  V.uMax = 0.9;  V.xref = 0.011;  V.kg = 1;
V.lift = 0.0115;  V.bp = [0 10 15 20 25 30 35 40 45];  V.tab = [11 10.5 10 9.5 9 9.5 10 10.5 11]*1e-3;
models = { 'my_cascade_rt',       '65', false, false
           'my_cascade_kg_rt',    '75', true,  false
           'my_cascade_sweep_rt', '90', false, true };      % name, stop time, has kg, has sweep

R = struct('check', {}, 'pass', {}, 'info', {});
fprintf('==== s15: rebuild lab models (%s mode) -> %s ====\n', ternary(stub,'STUB','LAB'), outDir);
if ~stub
    ok = exist(baseModel, 'file') == 4 || exist(baseModel, 'file') == 2;
    R = rec(R, 'C0 base model file exists', ok, baseModel);
    if ~ok, report(R); error('s15:noBase', 'Base model not found. Re-copy the INTECO PD example first (see header).'); end
end

for m = 1:size(models,1)
    name = models{m,1};  stopT = models{m,2};  hasKg = models{m,3};  hasSweep = models{m,4};
    file = fullfile(outDir, [name '.slx']);
    if bdIsLoaded(name), close_system(name, 0); end
    if exist(file, 'file') && ~overwrite
        R = rec(R, ['C1 ' name ' not overwritten'], false, 'file exists; call with overwrite = true'); continue
    end
    % ---- base: rig block + its scope ----
    if stub
        new_system(name);  plant = make_stub_plant(name, V);
        scope = add_block('simulink/Sinks/Scope', [name '/MagLev - system Control and States'], ...
            'NumInputPorts', '4', 'Position', [1700 265 1890 560]);
        scope = getfullname(scope);
        set_param(name, 'SolverType', 'Fixed-step', 'Solver', 'ode3', 'FixedStep', '0.003');
    else
        copyfile(baseModel, file, 'f');  load_system(file);
        plant = find_system(name, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'MaskType', 'Magnetic Levitation MLS1EM - System');
        R = rec(R, ['C1 ' name ' rig block found'], numel(plant) == 1, sprintf('%d found', numel(plant)));
        if numel(plant) ~= 1, close_system(name, 0); continue, end
        plant = plant{1};
        scope = find_system(name, 'SearchDepth', 1, 'BlockType', 'Scope');
        scope = scope(contains(get_param(scope, 'Name'), 'Control and States'));
        R = rec(R, ['C1 ' name ' main scope found'], numel(scope) == 1, sprintf('%d found', numel(scope)));
        if numel(scope) ~= 1, close_system(name, 0); continue, end
        scope = scope{1};
        delete_line(find_system(name, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line'));
        blks = find_system(name, 'SearchDepth', 1, 'Type', 'block');
        for b = 1:numel(blks)
            if ~any(strcmp(blks{b}, {plant, scope})), delete_block(blks{b}); end
        end
        t0 = str2double(get_param(plant, 'T0'));
        R = rec(R, ['C2 ' name ' rig T0 = 0.003 s'], abs(t0 - V.T0) < 1e-12, sprintf('T0 = %g', t0));
    end
    set_param(name, 'StopTime', stopT);

    % ---- controller subsystem ----
    ctrl = [name '/Cascade controller'];
    build_controller(ctrl, V, hasKg);
    set_param(ctrl, 'Position', [545 305 785 520], 'BackgroundColor', 'red');

    % ---- root blocks ----
    A = @(lib, nm, varargin) add_block(lib, [name '/' nm], varargin{:});
    if hasSweep
        A('simulink/Sources/Constant', 'x_ref manual', 'Value', num2str(V.xref), 'Position', [595 768 695 802], 'BackgroundColor', 'cyan');
        A('simulink/Logic and Bit Operations/Compare To Constant', 'lifted ?', 'relop', '<', 'const', num2str(V.lift), ...
          'OutDataTypeStr', 'boolean', 'Position', [90 597 170 657]);
        A('simulink/Signal Attributes/Data Type Conversion', 'to double', 'OutDataTypeStr', 'double', 'Position', [225 597 355 657]);
        A('simulink/Discrete/Discrete-Time Integrator', 'sweep clock', 'IntegratorMethod', 'Integration: Forward Euler', ...
          'gainval', '1.0', 'InitialCondition', '0', 'LimitOutput', 'off', 'SampleTime', num2str(V.T0), 'Position', [445 597 505 657]);
        A('simulink/Lookup Tables/1-D Lookup Table', 'sweep table', 'Table', mat2str(V.tab), ...
          'BreakpointsForDimension1', mat2str(V.bp), 'InterpMethod', 'Flat', 'Position', [595 572 705 682]);
        A('simulink/Signal Routing/Manual Switch', 'auto//manual', 'sw', '1', 'Position', [770 615 830 675]);
        xrefSrc = [name '/auto//manual'];
    else
        A('simulink/Sources/Constant', 'Desired position [m]', 'Value', num2str(V.xref), 'Position', [87 273 240 323], 'BackgroundColor', 'cyan');
        xrefSrc = [name '/Desired position [m]'];
    end
    A('simulink/Math Operations/Sum', 'Sum', 'Inputs', '-+', 'IconShape', 'rectangular', 'Position', [418 257 443 417]);
    A('simulink/Sources/Constant', 'Control 0', 'Value', '0', 'Position', [850 500 965 555], 'BackgroundColor', 'cyan');
    A('simulink/Signal Routing/Manual Switch', 'Manual Switch2', 'sw', '0', 'Position', [1015 380 1075 440]);  % 0 = Control 0 (coil off)
    nSc = 2 + 2*hasSweep;
    A('simulink/Sinks/Scope', 'Scope', 'NumInputPorts', num2str(nSc), 'Position', [1750 780 1830 880]);

    L = @(s, sp, d, dp) add_line(name, out(s, sp), in(d, dp), 'autorouting', 'smart');
    L(xrefSrc, 1, [name '/Sum'], 1);
    L(plant, 1, [name '/Sum'], 2);
    L([name '/Sum'], 1, ctrl, 1);
    L(plant, 2, ctrl, 2);
    L(plant, 3, ctrl, 3);
    L(ctrl, 1, [name '/Manual Switch2'], 1);
    L([name '/Control 0'], 1, [name '/Manual Switch2'], 2);
    L([name '/Manual Switch2'], 1, plant, 1);
    for p = 1:4, L(plant, p, scope, p); end
    hI  = L(plant, 3, [name '/Scope'], 1);  set_param(hI, 'Name', 'Current [A]');
    hIr = L(ctrl, 2, [name '/Scope'], 2);   set_param(hIr, 'Name', 'i_ref');
    if hasSweep
        L(plant, 1, [name '/lifted ?'], 1);
        L([name '/lifted ?'], 1, [name '/to double'], 1);
        L([name '/to double'], 1, [name '/sweep clock'], 1);
        L([name '/sweep clock'], 1, [name '/sweep table'], 1);
        L([name '/sweep table'], 1, [name '/auto//manual'], 1);
        L([name '/x_ref manual'], 1, [name '/auto//manual'], 2);
        hX = L([name '/auto//manual'], 1, [name '/Scope'], 3);  set_param(hX, 'Name', 'x_ref');
        hT = L([name '/sweep clock'], 1, [name '/Scope'], 4);   set_param(hT, 'Name', 'tau');
    end
    save_system(name, file);

    % ---------------- checks ----------------
    R = check_params(R, name, ctrl, V, hasKg, hasSweep, stub);
    R = check_wiring(R, name, plant, xrefSrc);
    R = check_controller(R, name, ctrl, V, hasKg);
    if stub, R = check_stub_sim(R, name, V, hasSweep); end
    close_system(name, 0);
end
report(R);
end

% ======================================================================================================== build
function build_controller(ctrl, V, hasKg)
add_block('simulink/Ports & Subsystems/Subsystem', ctrl);
Simulink.SubSystem.deleteContents(ctrl);
A = @(lib, nm, varargin) add_block(lib, [ctrl '/' nm], varargin{:});
A('simulink/Sources/In1', 'e', 'Port', '1', 'Position', [50 340 80 356]);
A('simulink/Sources/In1', 'v', 'Port', '2', 'Position', [50 620 80 636]);
A('simulink/Sources/In1', 'i', 'Port', '3', 'Position', [1290 470 1320 486]);
A('simulink/Math Operations/Gain', 'Kp', 'Gain', num2str(V.Kp), 'Position', [350 300 450 395]);
A('simulink/Math Operations/Gain', 'Ki', 'Gain', num2str(V.Ki), 'Position', [280 440 380 535]);
A('simulink/Discrete/Discrete-Time Integrator', 'Discrete-Time Integrator', 'IntegratorMethod', 'Integration: Forward Euler', ...
  'gainval', '1.0', 'InitialCondition', '0', 'LimitOutput', 'on', 'UpperSaturationLimit', num2str(V.Icl), ...
  'LowerSaturationLimit', num2str(-V.Icl), 'SampleTime', num2str(V.T0), 'Position', [460 445 540 530]);
A('simulink/Math Operations/Gain', 'Kd', 'Gain', num2str(V.Kd), 'Position', [280 580 380 675]);
A('simulink/Sources/Constant', 'i0', 'Value', num2str(V.i0), 'Position', [280 740 340 795]);
A('simulink/Math Operations/Sum', 'Add', 'Inputs', '++++', 'IconShape', 'rectangular', 'Position', [610 265 700 850]);
A('simulink/Discontinuities/Saturation', 'i_ref limit', 'UpperLimit', num2str(V.irefMax), 'LowerLimit', '0', 'Position', [810 528 870 588]);
A('simulink/Sources/Constant', 'i_test', 'Value', num2str(V.itest), 'Position', [810 720 870 775]);
A('simulink/Signal Routing/Manual Switch', 'test//run', 'sw', '1', 'Position', [990 545 1050 605]);   % 1 = run (outer loop)
A('simulink/Math Operations/Gain', '1//ka', 'Gain', '1/2.44', 'Position', [1200 530 1300 625]);
A('simulink/Math Operations/Sum', 'Add1', 'Inputs', '+-', 'IconShape', 'rectangular', 'Position', [1440 432 1500 492]);
A('simulink/Math Operations/Gain', 'Kc', 'Gain', num2str(V.Kc), 'Position', [1600 420 1700 515]);
A('simulink/Math Operations/Sum', 'Add2', 'Inputs', '++', 'IconShape', 'rectangular', 'Position', [1440 562 1500 622]);
A('simulink/Discontinuities/Saturation', 'u limit', 'UpperLimit', num2str(V.uMax), 'LowerLimit', '0', 'Position', [1640 570 1700 630]);
A('simulink/Sinks/Out1', 'u', 'Port', '1', 'Position', [1840 590 1870 606]);
A('simulink/Sinks/Out1', 'i_ref', 'Port', '2', 'Position', [1840 700 1870 716]);
L = @(s, sp, d, dp) add_line(ctrl, out([ctrl '/' s], sp), in([ctrl '/' d], dp), 'autorouting', 'smart');
L('e', 1, 'Kp', 1);  L('e', 1, 'Ki', 1);  L('Ki', 1, 'Discrete-Time Integrator', 1);  L('v', 1, 'Kd', 1);
L('Kp', 1, 'Add', 1);  L('Discrete-Time Integrator', 1, 'Add', 2);  L('Kd', 1, 'Add', 3);  L('i0', 1, 'Add', 4);
L('Add', 1, 'i_ref limit', 1);  L('i_ref limit', 1, 'test//run', 1);  L('i_test', 1, 'test//run', 2);
L('test//run', 1, 'Add1', 1);  L('i', 1, 'Add1', 2);  L('Add1', 1, 'Kc', 1);
L('test//run', 1, '1//ka', 1);  L('1//ka', 1, 'Add2', 1);  L('Kc', 1, 'Add2', 2);
L('test//run', 1, 'i_ref', 1);  L('u limit', 1, 'u', 1);
if hasKg   % deployed kg model: Product(Add2, kg) placed before the u limit
    A('simulink/Sources/Constant', 'kg', 'Value', num2str(V.kg), 'Position', [1440 680 1500 720]);
    A('simulink/Math Operations/Product', 'Product', 'Inputs', '2', 'Position', [1545 570 1590 630]);
    L('Add2', 1, 'Product', 1);  L('kg', 1, 'Product', 2);  L('Product', 1, 'u limit', 1);
else
    L('Add2', 1, 'u limit', 1);
end
end

function plant = make_stub_plant(name, V)
% Stand-in for the INTECO block (laptop test only): same name, 1 input, 4 outputs.
% Position: ball on the stand (11.9 mm) until t = 1 s, then "levitating" at 10 mm, to exercise the sweep clock gate.
plant = [name '/Magnetic Levitation System 1EM  USB2'];
add_block('simulink/Ports & Subsystems/Subsystem', plant, 'Position', [1155 270 1385 555]);
Simulink.SubSystem.deleteContents(plant);
A = @(lib, nm, varargin) add_block(lib, [plant '/' nm], varargin{:});
A('simulink/Sources/In1', 'Control', 'Position', [30 200 60 216]);
A('simulink/Sources/Step', 'x', 'Time', '1', 'Before', '0.0119', 'After', '0.010', 'SampleTime', num2str(V.T0));
A('simulink/Sources/Constant', 'vel', 'Value', '0', 'SampleTime', num2str(V.T0));
A('simulink/Math Operations/Gain', 'ka', 'Gain', '2.44');
A('simulink/Discrete/Unit Delay', 'z1', 'SampleTime', num2str(V.T0));      % no algebraic loop through i
for k = 1:4, A('simulink/Sinks/Out1', sprintf('o%d', k), 'Port', num2str(k)); end
add_line(plant, 'x/1', 'o1/1');  add_line(plant, 'vel/1', 'o2/1');
add_line(plant, 'Control/1', 'ka/1');  add_line(plant, 'ka/1', 'z1/1');  add_line(plant, 'z1/1', 'o3/1');
add_line(plant, 'Control/1', 'o4/1');
end

% ======================================================================================================== checks
function R = check_params(R, name, ctrl, V, hasKg, hasSweep, stub)
c = @(b) [ctrl '/' b];  r = @(b) [name '/' b];
exp = { c('Kp'),'Gain',V.Kp;  c('Ki'),'Gain',V.Ki;  c('Kd'),'Gain',V.Kd;  c('i0'),'Value',V.i0;
        c('Discrete-Time Integrator'),'UpperSaturationLimit',V.Icl;  c('Discrete-Time Integrator'),'LowerSaturationLimit',-V.Icl;
        c('Discrete-Time Integrator'),'InitialCondition',0;  c('i_ref limit'),'UpperLimit',V.irefMax;
        c('i_ref limit'),'LowerLimit',0;  c('i_test'),'Value',V.itest;  c('1//ka'),'Gain',1/V.ka;  c('Kc'),'Gain',V.Kc;
        c('u limit'),'UpperLimit',V.uMax;  c('u limit'),'LowerLimit',0;  r('Control 0'),'Value',0 };
if hasKg, exp(end+1,:) = {c('kg'),'Value',V.kg}; end
if hasSweep
    exp = [exp; {r('x_ref manual'),'Value',V.xref;  r('lifted ?'),'const',V.lift;  r('sweep table'),'Table',V.tab;
                 r('sweep table'),'BreakpointsForDimension1',V.bp}];
else
    exp(end+1,:) = {r('Desired position [m]'),'Value',V.xref};
end
bad = {};
for k = 1:size(exp,1)
    got = str2num(get_param(exp{k,1}, exp{k,2})); %#ok<ST2NM>
    if ~isequal(size(got), size(exp{k,3})) || any(abs(got - exp{k,3}) > 1e-12), bad{end+1} = [exp{k,1} '.' exp{k,2}]; end %#ok<AGROW>
end
R = rec(R, ['C4 ' name ' all ' num2str(size(exp,1)) ' parameters = deployed values'], isempty(bad), strjoin(bad, ', '));
mth = get_param(c('Discrete-Time Integrator'), 'IntegratorMethod');
R = rec(R, ['C4 ' name ' integrator Forward Euler, clamped'], contains(mth, 'Forward Euler') && ...
    strcmp(get_param(c('Discrete-Time Integrator'), 'LimitOutput'), 'on'), mth);
if hasSweep
    ok = strcmp(get_param(r('sweep table'), 'InterpMethod'), 'Flat') && strcmp(get_param(r('lifted ?'), 'relop'), '<');
    R = rec(R, ['C4 ' name ' sweep table Flat, lifted ? is x < 0.0115'], ok, '');
end
sw = {get_param(r('Manual Switch2'), 'sw'), get_param(c('test//run'), 'sw')};
R = rec(R, ['C5 ' name ' safe start: Manual Switch2 on Control 0, test/run on run'], strcmp(sw{1}, '0') && strcmp(sw{2}, '1'), strjoin(sw, '/'));
ok = strcmp(get_param(name, 'SolverType'), 'Fixed-step') && strcmp(get_param(name, 'Solver'), 'ode3') && ...
     abs(str2double(get_param(name, 'FixedStep')) - V.T0) < 1e-12;
info = sprintf('%s %s %s', get_param(name, 'SolverType'), get_param(name, 'Solver'), get_param(name, 'FixedStep'));
if ~stub
    ok = ok && strcmp(get_param(name, 'SystemTargetFile'), 'mls1em_rtcon_usb2.tlc') && strcmp(get_param(name, 'SimulationMode'), 'external');
    info = [info ' ' get_param(name, 'SystemTargetFile') ' ' get_param(name, 'SimulationMode')];
end
R = rec(R, ['C3 ' name ' solver/target'], ok, info);
end

function R = check_wiring(R, name, plant, xrefSrc)
% Sign test: Sum is '-+' with x_ref on port 1 (minus) and the rig's Position (output 1) on port 2 (plus): e = x - x_ref.
pc = get_param([name '/Sum'], 'PortConnectivity');
src1 = pc(1).SrcBlock;  src2 = pc(2).SrcBlock;  pport2 = pc(2).SrcPort;
ok = strcmp(get_param([name '/Sum'], 'Inputs'), '-+') && src1 == get_param(xrefSrc, 'Handle') && ...
     src2 == get_param(plant, 'Handle') && pport2 == 0;
R = rec(R, ['C7 ' name ' sign: e = x - x_ref (x_ref on minus port, Position on plus)'], ok, '');
% every input port of every block we added is connected
blks = [find_system(name, 'SearchDepth', 1, 'Type', 'block'); find_system([name '/Cascade controller'], 'SearchDepth', 1, 'Type', 'block')];
open = {};
for b = 1:numel(blks)
    if strcmp(blks{b}, plant), continue, end
    ph = get_param(blks{b}, 'PortHandles');
    for p = ph.Inport, if get_param(p, 'Line') == -1, open{end+1} = blks{b}; end, end %#ok<AGROW>
end
R = rec(R, ['C6 ' name ' no unconnected inputs'], isempty(open), strjoin(unique(open), ', '));
end

function R = check_controller(R, name, ctrl, V, hasKg)
% Copy the controller into a plain test model, drive e, v, i, compare with the recurrence read from the generated C code.
h = 's15_harness';  if bdIsLoaded(h), close_system(h, 0); end
new_system(h);  add_block(ctrl, [h '/C']);
for k = 1:3, add_block('simulink/Sources/In1', sprintf('%s/in%d', h, k), 'SampleTime', num2str(V.T0)); add_line(h, sprintf('in%d/1', k), ['C/' num2str(k)]); end
for k = 1:2, add_block('simulink/Sinks/Out1', sprintf('%s/out%d', h, k)); add_line(h, ['C/' num2str(k)], sprintf('out%d/1', k)); end
kgT = 1;  if hasKg, kgT = 1.7; set_param([h '/C/kg'], 'Value', '1.7'); end   % kg ~= 1 proves where the Product sits
set_param(h, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', 'FixedStep', num2str(V.T0), 'StopTime', '1.5', ...
    'SaveOutput', 'on', 'SaveFormat', 'Array', 'OutputSaveName', 'yout', 'SaveTime', 'on', 'LoadExternalInput', 'on');
T = V.T0;  t = (0:500)'*T;  N = numel(t);
e = zeros(N,1);  e(t >= 0.15) = 0.002;  e(t >= 0.6) = 0.012;  e(t >= 0.8) = -0.012;  e(t >= 1.1) = 0.001*sin(2*pi*3*t(t >= 1.1));
v = 0.05*sin(2*pi*2*t);  i = 0.8 + 0.4*sin(2*pi*1.3*t);
err = zeros(1,2);
for mode = [1 0]                                            % 1 = run, 0 = test (i_test)
    set_param([h '/C/test//run'], 'sw', num2str(mode));
    in = Simulink.SimulationInput(h);  in = in.setExternalInput([t e v i]);
    o = sim(in);  y = o.yout;
    I = 0;  yx = zeros(N,2);  Ih = zeros(N,1);
    for k = 1:N
        Ih(k) = I;
        if mode, ir = min(max(V.Kp*e(k) + I + V.Kd*v(k) + V.i0, 0), V.irefMax); else, ir = V.itest; end
        yx(k,:) = [min(max(kgT*(V.Kc*(ir - i(k)) + ir/V.ka), 0), V.uMax), ir];
        I = min(max(I + V.Ki*T*e(k), -V.Icl), V.Icl);
    end
    err(2-mode) = max(abs(y(:) - yx(:)));
    if mode   % coverage of the run-mode test: did it reach every limit?
        hit = [any(yx(:,1) == V.uMax), any(yx(:,1) == 0), any(yx(:,2) == V.irefMax), any(yx(:,2) == 0), any(Ih == V.Icl), any(Ih == -V.Icl)];
    end
end
close_system(h, 0);
R = rec(R, sprintf('C8 %s controller matches C-code recurrence (run, kg=%g)', name, kgT), err(1) < 1e-9, sprintf('max err %.1e', err(1)));
R = rec(R, ['C8 ' name ' test mode gives i_ref = i_test'], err(2) < 1e-9, sprintf('max err %.1e', err(2)));
R = rec(R, ['C8 ' name ' test reached u (0, 0.9), i_ref (0, 2) and integrator (+-0.3) limits'], all(hit), mat2str(hit));
end

function R = check_stub_sim(R, name, V, hasSweep)
% Laptop only: the whole model runs; for the sweep model, x_ref follows the table, timed from lift-off (stub: t = 1 s).
ph = get_param([name '/Scope'], 'PortHandles');
if hasSweep
    lx = get_param(ph.Inport(3), 'Line');  lt = get_param(ph.Inport(4), 'Line');
    set_param(get_param(lx, 'SrcPortHandle'), 'DataLogging', 'on');  set_param(get_param(lt, 'SrcPortHandle'), 'DataLogging', 'on');
end
try
    o = sim(name, 'StopTime', '55', 'SignalLogging', 'on', 'SignalLoggingName', 'logsout');  ran = true;  msg = '';
catch ME
    ran = false;  msg = ME.message;
end
R = rec(R, ['C9 ' name ' simulates (stub plant)'], ran, msg);
if hasSweep && ran
    xr = o.logsout.get('x_ref').Values;  ta = o.logsout.get('tau').Values;
    tq = [0.5 5 13.5 18.5 23.5 28.5 33.5 38.5 43.5 50];  xexp = [11 11 10.5 10 9.5 9 9.5 10 10.5 11]*1e-3;
    xg = interp1(xr.Time, squeeze(xr.Data), tq, 'previous');
    tau05 = interp1(ta.Time, squeeze(ta.Data), 0.5, 'previous');  tau50 = interp1(ta.Time, squeeze(ta.Data), 50, 'previous');
    R = rec(R, ['C9 ' name ' sweep clock frozen before lift-off, runs after'], tau05 == 0 && abs(tau50 - 49) < 0.01, ...
        sprintf('tau(0.5 s) = %g, tau(50 s) = %.3f', tau05, tau50));
    R = rec(R, ['C9 ' name ' x_ref follows 11 -> 9 -> 11 mm table'], max(abs(xg - xexp)) < 1e-12, mat2str(xg*1e3, 3));
end
end

% ======================================================================================================== helpers
function p = out(b, k), ph = get_param(b, 'PortHandles'); p = ph.Outport(k); end
function p = in(b, k),  ph = get_param(b, 'PortHandles'); p = ph.Inport(k);  end
function R = rec(R, check, pass, info)
R(end+1) = struct('check', check, 'pass', logical(pass), 'info', info);
fprintf('%s  %s%s\n', ternary(pass, 'PASS', 'FAIL'), check, ternary(isempty(info), '', ['  [' info ']']));
end
function report(R)
fprintf('==== s15 summary: %d PASS / %d FAIL ====\n', sum([R.pass]), sum(~[R.pass]));
end
function s = ternary(c, a, b), if c, s = a; else, s = b; end, end
