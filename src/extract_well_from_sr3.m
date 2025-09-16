function [WELL_DATA, time_days, time_date, meta] = extract_well_from_sr3(sr3, filePath, stride)
% EXTRACT_WELL_FROM_SR3
% Extract well variables from SR3 file with stride sampling.
% After extraction, trailing numbers in variable names are replaced
% with the corresponding component names from /General/ComponentTable.
% Time information is returned both in days (double) and as datetime.
%
% INPUTS
%   sr3      : struct from read_SR3 (sr3.data is a containers.Map)
%   filePath : SR3 file path (for reading component names)
%   stride   : integer, import every Nth timestep (e.g. 100)
%
% OUTPUTS
%   WELL_DATA : struct of wells, each well has fields for each variable
%   time_days : sampled linear time in days
%   time_date : sampled datetime array
%   meta      : metadata (original variable names, renamed fields, stride info)

    arguments
        sr3 struct
        filePath char
        stride double {mustBePositive} = 1
    end

    % -------------------------------
    % STEP 1. Read component names
    % -------------------------------
    compNames = [];
    try
        rawComp = h5read(filePath, '/General/ComponentTable');
        compNames = cellstr(rawComp.Name');  % transpose → rows = components
        compNames = strtrim(compNames);
        compNames = string(compNames);
    catch
        warning('⚠️ Could not read /General/ComponentTable');
    end

    % -------------------------------
    % STEP 2. Read time information
    % -------------------------------
    tinfo = sr3.data('/General/MasterTimeTable');
    tDays  = double(tinfo.OffsetInDays);    % length q+1
    tDate  = double(tinfo.Date);            % length q+1

    % Align with well data (skip initial t=0)
    tDays  = tDays(2:end);
    tDate  = tDate(2:end);
    nSteps = numel(tDays);

    % -------------------------------
    % STEP 3. Handle stride intelligently
    % -------------------------------
    if stride > nSteps
        warning(['⚠️ Stride (%d) is greater than total number of steps (%d).\n' ...
                 '   Using stride = %d. To see a better resolution, use a smaller stride.'], ...
                 stride, nSteps, nSteps);
        stride = nSteps;
    end

    if nSteps < 1000
        fprintf('Warning: Total timesteps = %d. Stride = 1 is fine for full resolution.\n', nSteps);
    else
        fprintf('Warning: Total timesteps = %d. Consider using stride > 1 (e.g. 10, 50, 100) for faster extraction.\n', nSteps);
    end

    % Subsample
    idx = 1:stride:nSteps;
    time_days = tDays(idx);

    % Convert numeric YYYYMMDD.xxx to datetime
    rawDates = tDate(idx);
    intPart  = floor(rawDates);        % YYYYMMDD
    fracPart = rawDates - intPart;     % fractional part of day
    dt = datetime(num2str(intPart), 'InputFormat','yyyyMMdd');
    time_date = dt + days(fracPart);

    % -------------------------------
    % STEP 4. Read well variable names + data
    % -------------------------------
    rawNames = sr3.data('/TimeSeries/WELLS/Variables');
    varNames = strtrim(cellstr(rawNames));   % convert to list of strings

    % Read 3D well data [nWells × nVars × nSteps]
    rawData = sr3.data('/TimeSeries/WELLS/Data');
    [nWells, nVars, nStepsCheck] = size(rawData);
    if nStepsCheck ~= nSteps
        warning('⚠️ Time length mismatch: MasterTimeTable=%d, WellData=%d', nSteps, nStepsCheck);
        nSteps = min(nSteps, nStepsCheck);
        idx = idx(idx <= nSteps);
    end

    % -------------------------------
    % STEP 5. Get well names from Origins
    % -------------------------------
    try
        wellNames = strtrim(string(sr3.data('/TimeSeries/WELLS/Origins')));
    catch
        % fallback: generic WELL1, WELL2, ...
        wellNames = arrayfun(@(w) sprintf("WELL%d", w), 1:nWells, 'UniformOutput', true);
    end

    % -------------------------------
    % STEP 6. Build WELL_DATA struct with raw names
    % -------------------------------
    WELL_DATA = struct();
    for w = 1:nWells
        thisWell = struct();
        for v = 1:nVars
            series = squeeze(rawData(w,v,idx));
            thisWell.(sanitize_varname(varNames{v})) = series;
        end
        WELL_DATA.(sanitize_varname(wellNames(w))) = thisWell;
    end

    % -------------------------------
    % STEP 7. Rename fields with component names
    % -------------------------------
    for w = 1:nWells
        wName = sanitize_varname(wellNames(w));
        fields = fieldnames(WELL_DATA.(wName));
        for f = 1:numel(fields)
            fname = fields{f};
            tokens = regexp(fname, '^(.*?)(\d+)$', 'tokens'); % detect trailing digits
            if ~isempty(tokens)
                base = tokens{1}{1};
                idx  = str2double(tokens{1}{2});
                if ~isempty(compNames) && idx <= numel(compNames)
                    newName = [base '_' char(compNames(idx))];
                    WELL_DATA.(wName).(newName) = WELL_DATA.(wName).(fname);
                    WELL_DATA.(wName) = rmfield(WELL_DATA.(wName), fname);
                end
            end
        end
    end

    % -------------------------------
    % STEP 8. Metadata
    % -------------------------------
    meta = struct();
    meta.var_original = varNames;
    meta.var_fields   = fieldnames(WELL_DATA.(sanitize_varname(wellNames(1))));
    meta.stride       = stride;
    meta.nWells       = nWells;
    meta.nVars        = nVars;
    meta.nSteps_full  = nStepsCheck;
    meta.nSteps_used  = numel(idx);
    meta.well_names   = wellNames;
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
