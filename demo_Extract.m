addpath('src');

% Copy .sr3 file in the current directory
% Change file path to your SR3 file
filePath = 'YourSR3File.sr3';

[sr3, Paths] = read_SR3(filePath);
[DATA, meta] = extract_spatial_from_sr3(sr3, Paths, filePath);
