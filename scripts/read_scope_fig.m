function r = read_scope_fig(file)
% READ_SCOPE_FIG  [STANDALONE]  Read a lab scope "Print to Figure -> Save" .fig
% without openfig (openfig fails off the lab PC: tileGrid missing).
% =========================================================================
% OUTPUT  r.names  trace names (scope DisplayName), in plotting order
%         r.t      common time vector [s] (unique stamps of the first trace)
%         r.y      one column per trace, sampled on r.t (zero-order hold)
%         r.file   the file read
% NOTE    unique() drops repeated time stamps, if any (the stored lab files have none).
%         Harmless "tileGrid"/"proplistener" messages may print while loading.
% =========================================================================
w = warning('off', 'all');
try
    S = load(file, '-mat');
catch
end
warning(w);
assert(exist('S', 'var') && isfield(S, 'hgS_070000'), 'read_scope_fig: cannot read %s', file);
L = collect(S.hgS_070000, {});
assert(~isempty(L), 'read_scope_fig: no traces in %s', file);
r.file  = file;
r.names = cellfun(@(c) c{1}, L, 'UniformOutput', false);
r.t = unique(L{1}{2});
r.y = zeros(numel(r.t), numel(L));
for j = 1:numel(L)
    [tj, ij] = unique(L{j}{2});
    yj = L{j}{3}(ij);
    r.y(:, j) = interp1(tj, yj, r.t, 'previous', 'extrap');
end
end

function L = collect(h, L)
for k = 1:numel(h)
    p = h(k).properties;
    if strcmp(h(k).type, 'specgraph.stairseries') && isfield(p, 'DisplayName') && ~isempty(p.DisplayName)
        L{end+1} = {p.DisplayName, p.XData(:), p.YData(:)}; %#ok<AGROW>
    end
    if isfield(h(k), 'children') && ~isempty(h(k).children), L = collect(h(k).children, L); end
end
end
