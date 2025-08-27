function [sr3,Paths] = read_SR3(filePath)
% READ_SR3 Reads an SR3 file and stores all datasets in a structured way.
%   sr3 = READ_SR3(filePath) reads the HDF5 file at filePath, collects all
%   datasets recursively, and stores them in sr3.data as a containers.Map.

    sr3 = struct();
    sr3.data = containers.Map();
    % Read file metadata
    info = h5info(filePath);
    datasetList = collect_all_datasets(info);
    Paths = cell(numel(datasetList),1);
    fprintf('Reading %d datasets from %s...\n', numel(datasetList), filePath);

    for i = 1:numel(datasetList)
        rawPath = datasetList{i};

        % Convert to proper HDF5 path format
        hdf5Path   = fix_path_format(rawPath);
        Paths{i,1} = hdf5Path;
        try
            data = h5read(filePath, hdf5Path);
            sr3.data(hdf5Path) = data;
            %fprintf('✓ Loaded: %s\n', hdf5Path);
        catch err
            warning('⚠️ Failed to read %s: %s', hdf5Path, err.message);
        end
    end
end

function datasetPaths = collect_all_datasets(group)
% Recursively collect all datasets in the HDF5 file
    datasetPaths = {};

    % Add current group's datasets
    for i = 1:length(group.Datasets)
        datasetPaths{end+1} = fullfile(group.Name, group.Datasets(i).Name);
    end

    % Recurse into subgroups
    for i = 1:length(group.Groups)
        subPaths = collect_all_datasets(group.Groups(i));
        datasetPaths = [datasetPaths, subPaths];
    end
end

function pathOut = fix_path_format(pathIn)
% Ensure path uses forward slashes and starts with '/'
    pathOut = strrep(pathIn, '\', '/');
    if ~startsWith(pathOut, '/')
        pathOut = ['/' pathOut];
    end
end
