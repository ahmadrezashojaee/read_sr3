# read_sr3
# SR3 Extractor for MATLAB

MATLAB utilities for reading and extracting spatial datasets from CMG SR3 restart files (HDF5 format).

## Features
- Read all datasets in an SR3 file into a `containers.Map`.
- Extract `/SpatialProperties/<timestep>/<variable>` into tidy MATLAB matrices.
- One field per variable (e.g., `DATA.PRES`, `DATA.PH`, `DATA.ACTIVE1`).
- Columns = timesteps (sorted numerically, empty steps skipped).
- Handles missing datasets gracefully (fills with NaN).

## Installation
Clone this repo and add the `src/` folder to your MATLAB path:
```matlab
addpath('src');

