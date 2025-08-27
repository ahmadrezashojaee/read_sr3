addpath('src');

% Change file path to your SR3 file
filePath = 'CASE.sr3';

[sr3, Paths] = read_SR3(filePath);
[DATA, meta] = extract_spatial_from_sr3(sr3, Paths);
