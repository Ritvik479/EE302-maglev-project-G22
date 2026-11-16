function s03_lab_discovery(mdl)
% s03_lab_discovery  [LAB]  Read-only inventory of a Simulink model.
%
%   s03_lab_discovery('my_copy')    % model name WITHOUT .slx, must be on path / in pwd
%
% Writes lab_discovery_<model>.txt in the current folder and prints the same
% to the console. It only LOADS the model; it never saves or changes it.
% Sections: MATLAB/toolboxes, solver + fixed step, callbacks, block inventory,
% parameters of every filter / switch / delay / gain / S-function / masked block.

if nargin < 1
    error('Give the model name, e.g. s03_lab_discovery(''my_copy'')');
end
[~, mdl] = fileparts(char(mdl));
outFile = fullfile(pwd, ['lab_discovery_' mdl '.txt']);
fid = fopen(outFile, 'w');
cleanup = onCleanup(@() fclose(fid));
nPass = 0; nFail = 0;

% ---------- 1. MATLAB + toolboxes ----------
p(fid, '==== 1. MATLAB ====\n');
p(fid, 'version : %s\n', version);
p(fid, 'computer: %s\n', computer);
v = ver;
for k = 1:numel(v)
    p(fid, '  %-45s %s\n', v(k).Name, v(k).Version);
end

% ---------- 2. Model file ----------
p(fid, '\n==== 2. MODEL FILE ====\n');
f = which(mdl);
if isempty(f)
    p(fid, 'FAIL: model "%s" not found on path / in pwd (%s)\n', mdl, pwd);
    p(fid, '\nSummary: 0 PASS, 1 FAIL. Saved to %s\n', outFile);
    return
end
p(fid, 'PASS: found %s\n', f); nPass = nPass + 1;
wasLoaded = bdIsLoaded(mdl);
load_system(mdl);

% ---------- 3. Solver / target ----------
p(fid, '\n==== 3. SOLVER / TARGET ====\n');
cfg = {'SolverType','Solver','FixedStep','StopTime','SimulationMode', ...
       'SystemTargetFile','ExtMode','SampleTimeConstraint'};
for k = 1:numel(cfg)
    p(fid, '  %-22s = %s\n', cfg{k}, gp(mdl, cfg{k}));
end
fs = gp(mdl, 'FixedStep');
val = tryEval(fs);
if ~isnan(val)
    p(fid, 'PASS: FixedStep "%s" evaluates to %g s\n', fs, val); nPass = nPass + 1;
else
    p(fid, 'FAIL: FixedStep "%s" could not be evaluated (variable not defined yet? run the model init first)\n', fs);
    nFail = nFail + 1;
end

% ---------- 4. Callbacks (often define T0, gains, filter constants) ----------
p(fid, '\n==== 4. MODEL CALLBACKS ====\n');
cb = {'PreLoadFcn','PostLoadFcn','InitFcn','StartFcn','StopFcn'};
for k = 1:numel(cb)
    s = gp(mdl, cb{k});
    if ~isempty(strtrim(s)), p(fid, '--- %s ---\n%s\n', cb{k}, s); end
end

% ---------- 5. Block inventory ----------
p(fid, '\n==== 5. BLOCK COUNT BY TYPE ====\n');
blks = find_system(mdl, 'LookUnderMasks','all', 'FollowLinks','on', 'Type','block');
types = cellfun(@(b) gp(b,'BlockType'), blks, 'UniformOutput', false);
[ut, ~, ix] = unique(types);
for k = 1:numel(ut)
    p(fid, '  %-28s %d\n', ut{k}, sum(ix == k));
end

% ---------- 6. Parameters of the blocks that matter ----------
p(fid, '\n==== 6. KEY BLOCK PARAMETERS ====\n');
want = struct( ...
  'SFunction',            {{'FunctionName','Parameters','SampleTime'}}, ...
  'TransferFcn',          {{'Numerator','Denominator'}}, ...
  'DiscreteTransferFcn',  {{'Numerator','Denominator','SampleTime'}}, ...
  'DiscreteFilter',       {{'Numerator','Denominator','SampleTime'}}, ...
  'DiscreteStateSpace',   {{'A','B','C','D','SampleTime'}}, ...
  'StateSpace',           {{'A','B','C','D'}}, ...
  'ManualSwitch',         {{'sw'}}, ...
  'Switch',               {{'Criteria','Threshold'}}, ...
  'MultiPortSwitch',      {{'DataPortOrder'}}, ...
  'Gain',                 {{'Gain'}}, ...
  'Constant',             {{'Value'}}, ...
  'Saturate',             {{'UpperLimit','LowerLimit'}}, ...
  'UnitDelay',            {{'SampleTime'}}, ...
  'Delay',                {{'DelayLength','SampleTime'}}, ...
  'Memory',               {{}}, ...
  'ZeroOrderHold',        {{'SampleTime'}}, ...
  'Derivative',           {{}}, ...
  'DiscreteIntegrator',   {{'gainval','SampleTime','UpperSaturationLimit','LowerSaturationLimit'}}, ...
  'Integrator',           {{}}, ...
  'FromWorkspace',        {{'VariableName'}}, ...
  'ToWorkspace',          {{'VariableName','SampleTime'}});
for k = 1:numel(blks)
    b = blks{k}; t = types{k};
    if isfield(want, t)
        p(fid, '[%s] %s\n', t, clean(b));
        prm = want.(t);
        for j = 1:numel(prm)
            p(fid, '     %-22s = %s\n', prm{j}, gp(b, prm{j}));
        end
    end
    % Masked blocks (e.g. the manual's PID / filter / driver masks)
    if strcmp(gp(b,'Mask'), 'on')
        mt = gp(b,'MaskType');
        p(fid, '[MASK:%s] %s\n', mt, clean(b));
        try
            nm = get_param(b,'MaskNames'); vl = get_param(b,'MaskValues');
            for j = 1:numel(nm)
                p(fid, '     %-22s = %s\n', nm{j}, vl{j});
            end
        catch
            p(fid, '     (mask parameters not readable)\n');
        end
    end
end

% ---------- 7. Signal names (helps find velocity / filter paths) ----------
p(fid, '\n==== 7. NAMED SIGNAL LINES ====\n');
lines = find_system(mdl, 'LookUnderMasks','all', 'FollowLinks','on', ...
                    'FindAll','on', 'Type','line');
names = unique(get(lines, {'Name'}));
names = names(~cellfun(@isempty, names));
for k = 1:numel(names), p(fid, '  %s\n', names{k}); end

if ~wasLoaded, close_system(mdl, 0); end   % 0 = do NOT save
p(fid, 'PASS: model closed without saving\n'); nPass = nPass + 1;
p(fid, '\nSummary: %d PASS, %d FAIL. Saved to %s\n', nPass, nFail, outFile);
end

% ===== helpers =====
function p(fid, fmt, varargin)
    fprintf(fmt, varargin{:});
    fprintf(fid, fmt, varargin{:});
end
function s = gp(obj, prm)
    try
        s = get_param(obj, prm);
        if isnumeric(s) || islogical(s), s = mat2str(s); end
        if ~ischar(s), s = '(non-text)'; end
    catch
        s = '';
    end
end
function x = tryEval(s)
    try, x = evalin('base', s); if ~isscalar(x), x = NaN; end
    catch, x = NaN; end
end
function s = clean(b)
    s = strrep(b, newline, ' ');
end
