function [Spatial_DATA,Spatial_time_days, Spatial_time_date, meta] = extract_spatial_from_sr3(sr3, Paths, filePath)
% EXTRACT_SPATIAL_FROM_SR3  
% Gather all /SpatialProperties/<step>/<var> datasets into matrices.
% Variables with numeric indices (e.g. MOLAL(1), X1, Y2, Z(3)) are renamed
% using component names from /General/ComponentTable.
% 
% Reported times (days, GEM numeric dates, MATLAB datetime) are extracted
% from /General/MasterTimeTable based on timestep indices.
%
% INPUTS
%   sr3      : struct from read_SR3 (sr3.data is a containers.Map with HDF5 datasets)
%   Paths    : cellstr of dataset paths returned by read_SR3
%   filePath : path to the SR3 file (needed for reading component names)
%
% OUTPUTS
%   DATA              : struct with one field per variable [nCells x nSteps]
%   meta              : metadata structure (timesteps, reported times, varnames, etc.)
%   Spatial_time_days : reported variables at numeric days format
%   Spatial_time_date : reported variables at datetime format


    arguments
        sr3 struct
        Paths cell
        filePath char
    end

    % -------------------------------
    % STEP 1. Read component names
    % -------------------------------
    compNames = [];
    try
        raw = h5read(filePath, '/General/ComponentTable');
        compNames = strtrim(string(cellstr(raw.Name')));
    catch
        warning('⚠️ Could not read /General/ComponentTable');
    end

    % -------------------------------
    % STEP 2. Filter spatial property paths
    % -------------------------------
    isSpatial = startsWith(Paths, '/SpatialProperties/');
    spPaths   = Paths(isSpatial);
    if isempty(spPaths)
        error('No /SpatialProperties/ paths found in provided Paths.');
    end

    % Parse step + variable
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

    % Reference table
    meta.paths_table = table(spPaths(:), stepStr(:), varNames(:), ...
        'VariableNames', {'Path','StepStr','VarName'});

    % -------------------------------
    % STEP 3. Unique timesteps
    % -------------------------------
    nonEmptyMask = ~cellfun(@isempty, stepStr);
    steps_clean  = stepStr(nonEmptyMask);
    [steps_u, ~, ~] = unique(steps_clean, 'stable');
    steps_u = cellfun(@strtrim, steps_u, 'UniformOutput', false);
    steps_num = str2double(steps_u);

    [~, sortOrder] = sortrows([isnan(steps_num), steps_num]);
    meta.timesteps_str = steps_u(sortOrder);
    meta.timesteps_num = steps_num(sortOrder);

    % -------------------------------
    % STEP 4. Reported times from MasterTimeTable
    % -------------------------------
    try
        tinfo = sr3.data('/General/MasterTimeTable');
        allDays  = double(tinfo.OffsetInDays);   % includes t=0
        allDates = double(tinfo.Date);

        % Convert folder index (e.g. '000000') → MasterTimeTable row (+1)
        stepIdx = str2double(meta.timesteps_str);   % e.g. 0,1,2,...
        rowIdx  = stepIdx + 1;

        % Map to reported times
        meta.report_days  = allDays(rowIdx);
        meta.report_dates = allDates(rowIdx);

        % Convert to datetime
        intPart  = floor(meta.report_dates);
        fracPart = meta.report_dates - intPart;
        dt = datetime(num2str(intPart), 'InputFormat','yyyyMMdd');
        meta.report_datetime = dt + days(fracPart);
    catch ME
        warning('⚠️ Could not extract reported times: %s', ME.message);
        meta.report_days = [];
        meta.report_dates = [];
        meta.report_datetime = [];
    end

    % -------------------------------
    % STEP 5. Unique variables
    % -------------------------------
    [vars_u, ~, var_idx] = unique(varNames, 'stable');
    vars_u = cellfun(@strtrim, vars_u, 'UniformOutput', false);
    meta.var_original = vars_u;

    % -------------------------------
    % STEP 6. Rename variables with component names
    % -------------------------------
    meta.var_fields = vars_u; % start with original

    for v = 1:numel(vars_u)
        baseVar = vars_u{v};

        % Match patterns like NAME(NUM), NAME_NUM, NAME###, X1, Y2, etc.
        tokens = regexp(baseVar, '^(?<base>[A-Za-z_]+)\(?(?<idx>\d+)\)?$', 'names');

        if ~isempty(tokens)
            idx = str2double(tokens.idx);
            base = upper(tokens.base);

            if ~isempty(compNames) && idx <= numel(compNames)
                cname = compNames(idx);
                newName = base + "_" + cname;
                meta.var_fields{v} = sanitize_varname(newName);
            else
                meta.var_fields{v} = sanitize_varname(baseVar);
            end
        else
            meta.var_fields{v} = sanitize_varname(baseVar);
        end
    end

    % -------------------------------
    % STEP 7. Preallocate DATA
    % -------------------------------
    Spatial_DATA = struct();
    for v = 1:numel(meta.var_fields)
        Spatial_DATA.(meta.var_fields{v}) = nan(0, numel(meta.timesteps_str));
    end

    % -------------------------------
    % STEP 8. Fill values
    % -------------------------------
    for i = 1:n
        vname = strtrim(varNames{i});
        sstr  = strtrim(stepStr{i});
        if isempty(vname) || isempty(sstr), continue; end

        c = find(strcmp(meta.timesteps_str, sstr), 1, 'first');
        if isempty(c), continue; end

        v = find(strcmp(vars_u, vname), 1, 'first');
        if isempty(v), continue; end

        p = spPaths{i};
        if ~isKey(sr3.data, p), continue; end

        vec = sr3.data(p);
        vec = vec(:);

        target = Spatial_DATA.(meta.var_fields{v});
        nCells = size(target,1);

        if nCells == 0
            nCells = numel(vec);
            newMat = nan(nCells, size(target,2));
            newMat(:, c) = vec;
            Spatial_DATA.(meta.var_fields{v}) = newMat;
        else
            tmp = nan(nCells,1);
            m = min(nCells, numel(vec));
            tmp(1:m) = vec(1:m);
            target(:, c) = tmp;
            Spatial_DATA.(meta.var_fields{v}) = target;
        end
    end
Spatial_time_days = meta.report_days;
Spatial_time_date = meta.report_datetime;
end

% ---------- helpers ----------
function out = sanitize_varname(in)
    out = upper(char(string(in)));
    out = regexprep(out, '[\(\)\[\]\s]', '');
    out = regexprep(out, '[^A-Z0-9_]', '_');
    out = regexprep(out, '_+', '_');
    out = regexprep(out, '^_+|_+$', '');
    if isempty(out), out = 'VAR'; end
    if ~isempty(out) && ~isempty(regexp(out(1), '\d', 'once'))
        out = ['V_' out];
    end
end
