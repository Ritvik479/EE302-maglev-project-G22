function D = s04_save_scope_traces(outFile)
% s04_save_scope_traces  [LAB]  Save every plotted trace from open figures.
%
%   Use after a hardware run:  scope window -> File -> Print to Figure, then
%       s04_save_scope_traces('C:\Users\hp\Desktop\group_22\pd_run3_traces.mat')
%
% Why: the "Print to Figure" window has a hidden handle, so gcf/savefig grab
% an empty figure instead. findall sees hidden figures too.
% Output D(k): .fig (figure name), .axis (subplot title), .t (time), .y (values)

if nargin < 1, outFile = fullfile(pwd, 'scope_traces.mat'); end
F = findall(0, 'Type', 'figure');
D = struct('fig', {}, 'axis', {}, 't', {}, 'y', {});
for f = F(:)'
    for l = findall(f, 'Type', 'line')'
        ax = ancestor(l, 'axes'); ttl = '';
        if ~isempty(ax), ttl = ax.Title.String; end
        if numel(l.XData) > 10      % skip grid/marker lines
            D(end+1) = struct('fig', string(f.Name), 'axis', string(ttl), ...
                              't', l.XData(:), 'y', l.YData(:)); %#ok<AGROW>
        end
    end
end
for k = 1:numel(D)
    fprintf('%d | %s | %s | %d points, t = %.2f..%.2f s\n', k, D(k).fig, ...
            D(k).axis, numel(D(k).t), D(k).t(1), D(k).t(end));
end
if numel(D) >= 4
    fprintf('PASS: %d traces found\n', numel(D));
else
    fprintf('FAIL: only %d traces found. Did you do File -> Print to Figure first?\n', numel(D));
end
save(outFile, 'D');
fprintf('Saved to %s\n', outFile);
end
