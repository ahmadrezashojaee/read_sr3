function [DATA, meta] = extract_spatial_from_sr3(sr3, Paths)
% EXTRACT_SPATIAL_FROM_SR3  Gather all /SpatialProperties/<step>/<var> datasets
% into matrices with columns ordered by timestep, skipping empty step tokens.
%
% INPUTS
%   sr3   : struct from read_SR3 (sr3.data is a containers.Map with HDF5 datasets)
%   Paths : cellstr of dataset paths returned by read_SR3
%
% OUTPUTS
%   DATA  : struct with one field per variable. Each field is [nCells x nSteps]
%           with columns corresponding to 'meta.timesteps_str' order (no empties).
%   meta  : struct with metadata:
%           - timesteps_str  : cellstr of unique non-empty timestep strings (sorted numeric; NaNs at end)
%           - timesteps_num  : numeric timesteps (NaN if non-numeric)
%           - var_original   : cellstr of HDF5 variable names (e.g., 'ACTIV(1)')
%           - var_fields     : cellstr of corresponding DATA fieldnames (e.g., 'ACTIVE1')
%           - paths_table    : table of all spatial paths (Path, StepStr, VarName)

    arguments
        sr3 struct
        Paths cell
    end

    % 1) Filter spatial property paths
    isSpatial = startsWith(Paths, '/SpatialProperties/');
    spPaths   = Paths(isSpatial);
    if isempty(spPaths)
        error('No /SpatialProperties/ paths found in provided Paths.');
    end

    % 2) Parse each spatial path into (step, var)
    n = numel(spPaths);
    stepStr  = cell(n,1);
    varNames = cell(n,1);

    for i = 1:n
        parts = split(spPaths{i}, '/'); % {'','SpatialProperties','000000','PRES'}
        if numel(parts) >= 4
            stepStr{i}  = strtrim(parts{3});
            varNames{i} = strtrim(parts{4});
        else
            stepStr{i}  = '';
            varNames{i} = '';
        end
    end

    % Reference table (keeps empties for auditing)
    meta.paths_table = table(spPaths(:), stepStr(:), varNames(:), ...
        'VariableNames', {'Path','StepStr','VarName'});

    % 3) Unique, NON-EMPTY steps (sorted numeric when possible; NaNs at end)
    nonEmptyMask = ~cellfun(@isempty, stepStr);
    steps_clean  = stepStr(nonEmptyMask);
    [steps_u, ~, ~] = unique(steps_clean, 'stable');
    steps_u = cellfun(@strtrim, steps_u, 'UniformOutput', false);
    steps_num = str2double(steps_u);
    [~, sortOrder] = sortrows([isnan(steps_num), steps_num]); % non-NaN first, ascending
    meta.timesteps_str = steps_u(sortOrder);
    meta.timesteps_num = steps_num(sortOrder);

    % 4) Unique variables (keep stable order)
    [vars_u, ~, var_idx] = unique(varNames, 'stable');
    vars_u = cellfun(@strtrim, vars_u, 'UniformOutput', false);
    meta.var_original = vars_u;

    % Sanitize variable names to struct fields
    meta.var_fields = cellfun(@sanitize_varname, meta.var_original, 'UniformOutput', false);

    % 5) Pre-scan to determine nCells for each variable and preallocate matrices
    DATA = struct();
    var_nCells = zeros(numel(vars_u), 1);

    for v = 1:numel(vars_u)
        rows_v = find(var_idx == v);
        found = false;
        for r = rows_v(:)'
            p = spPaths{r};
            if isKey(sr3.data, p)
                sample = sr3.data(p);
                sample = sample(:);       % ensure column vector
                var_nCells(v) = numel(sample);
                found = true;
                break;
            end
        end
        if ~found, var_nCells(v) = 0; end

        if var_nCells(v) > 0
            DATA.(meta.var_fields{v}) = nan(var_nCells(v), numel(meta.timesteps_str));
        else
            DATA.(meta.var_fields{v}) = nan(0, numel(meta.timesteps_str));
        end
    end

    % 6) Fill matrices — robust column lookup via strcmp, skip empty steps
    for i = 1:n
        vname = strtrim(varNames{i});
        sstr  = strtrim(stepStr{i});
        if isempty(vname) || isempty(sstr), continue; end

        % Find column index only among NON-EMPTY timesteps
        c = find(strcmp(meta.timesteps_str, sstr), 1, 'first');
        if isempty(c), continue; end

        % Variable index
        v = find(strcmp(vars_u, vname), 1, 'first');
        if isempty(v), continue; end

        % Read vector
        p = spPaths{i};
        if ~isKey(sr3.data, p), continue; end
        vec = sr3.data(p);
        vec = vec(:);

        target = DATA.(meta.var_fields{v});
        nCells = size(target,1);

        if numel(vec) ~= nCells
            if nCells == 0
                % Late size discovery -> rebuild
                nCells = numel(vec);
                newMat = nan(nCells, size(target,2));
                newMat(:, c) = vec;
                DATA.(meta.var_fields{v}) = newMat;
            else
                % Mismatch -> truncate/pad
                tmp = nan(nCells,1);
                m = min(nCells, numel(vec));
                tmp(1:m) = vec(1:m);
                target(:, c) = tmp;
                DATA.(meta.var_fields{v}) = target;
            end
        else
            target(:, c) = vec;
            DATA.(meta.var_fields{v}) = target;
        end
    end
end

% ---------- helpers ----------
function out = sanitize_varname(in)
    out = upper(char(string(in)));               % char row vector
    out = regexprep(out, '[\(\)\[\]\s]', '');    % remove brackets & spaces
    out = regexprep(out, '[^A-Z0-9_]', '_');     % non-alnum -> underscore
    out = regexprep(out, '_+', '_');             % collapse repeats
    out = regexprep(out, '^_+|_+$', '');         % trim underscores
    if isempty(out), out = 'VAR'; end
    if ~isempty(out) && ~isempty(regexp(out(1), '\d', 'once'))
        out = ['V_' out];
    end
end
