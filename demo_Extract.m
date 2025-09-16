addpath('src');

% Copy .sr3 file in the current directory
% Change file path to your SR3 file
filePath = 'YourSR3File.sr3';

[sr3, Paths] = read_SR3(filePath);
[Spatial_DATA,Spatial_time_days, Spatial_time_date, meta] = extract_spatial_from_sr3(sr3, Paths,filePath);
[WELL_DATA, time_days, time_date, meta_wells] = extract_well_from_sr3(sr3, filePath, 100);
