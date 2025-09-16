# read_SR3
# SR3 Spatial Variables Extractor CMG — MATLAB

Utilities for reading **CMG-GEM** `.sr3` restart files (HDF5) and extracting **spatial properties** into clean MATLAB matrices for analysis and plotting.

Developed by **Ahmadreza Shojaee** during PhD research at **Heriot-Watt University**.

---

## 💡 What this does

- Loads an SR3 (HDF5) file and indexes **all datasets** into a `containers.Map`.

- **Spatial Properties Extraction**
  - Gathers everything under `/SpatialProperties/<TIMESTEP>/<VARIABLE>` into MATLAB matrices with **columns = timesteps** and **rows = cells**.
  - Produces a tidy struct:
    - `DATA.<VAR>` → `[nCells x nSteps]` (e.g., `DATA.PRES`, `DATA.PH`, `DATA.SW`, `DATA.SG`)
    - `meta` → timestep labels (strings & numeric), original variable names, sanitized field names, and a table of all spatial paths.
  - Variable names ending in numbers (e.g., `ACTIV(1)`, `X1`) are automatically mapped to component names from `/General/ComponentTable` (e.g., `ACTIVE_H2`, `X_CO2`).

- **Well Data Extraction**
  - Reads `/TimeSeries/WELLS/Data` into MATLAB time series for each well.
  - Well names are taken from `/TimeSeries/WELLS/Origins`.
  - Produces a structured output:
    - `WELL_DATA.<WELL>.<VAR>` → `[nSteps x 1]` (e.g., `WELL_DATA.WELL_A.OILMOLSC_H2`, `WELL_DATA.WELL_A.BHP`)
    - `time_days` → simulation time in days (double)
    - `time_date` → simulation time as MATLAB `datetime`
    - `meta` → original vs renamed variable names, well names, stride info
  - Variables ending with numbers (e.g., `OILMOLSC1`, `GASMOLSC2`) are automatically renamed with component names (e.g., `OILMOLSC_H2`, `GASMOLSC_CH4`).
  - Supports **stride sampling** (e.g., import every 100 timesteps) for faster processing of large cases.


## 📦 Installation

1. **Download the package**
   - Clone the repository:
     ```bash
     git clone https://github.com/ahmadrezashojaee/read_sr3.git
     ```
   - Or download it as a `.zip` and unzip locally.

2. **Add `src/` to your MATLAB path**
   ```matlab
   addpath('src');
   ```

---

## 🚀 Quick Start

1) **Run the demo**
```matlab
demo_Extract
```

2) **What the demo does**
- Copy your SR3 File in the directory.
- Reads `YourSR3File.sr3` (change it your file name)
- Extracts all `/SpatialProperties/...` datasets
- Builds `DATA` and `meta`

3) **Use your own SR3** 

Edit the demo and set your file path:
```matlab
filePath = 'YourSR3File.sr3';     % or a full path like 'D:\runs\GEM\MySimulation.SR3'
```
Run the script again:
```matlab
examples/demo_extract
```

---

## 🧪 Direct Usage (without the demo)

```matlab
% Add the source folder (once per session)
addpath('src');

% 1) Load SR3 file and index datasets
[sr3, Paths] = read_SR3('YourSR3File.sr3');

% 2) Extract all spatial and well properties into matrices
[DATA, meta] = extract_spatial_from_sr3(sr3, Paths, filePath);
[WELL_DATA, time_days, time_date, meta_wells] = extract_well_from_sr3(sr3, filePath, 1000);
% 3) Inspect results
fieldnames(DATA)          % list of variables (sanitized names)
size(DATA.PRES)           % -> [nCells x nSteps]
meta.timesteps_str        % timestep identifiers (strings; empties skipped)
meta.timesteps_num        % numeric timesteps (sorted)
```

---

## 📚 API Reference

### `read_SR3.m`
**Purpose:** Read the SR3 HDF5 and collect every dataset.

**Signature**
```matlab
[sr3, Paths] = read_SR3(filePath)
```

**Returns**
- `sr3.data` — `containers.Map` keyed by full HDF5 dataset paths  
  (e.g., `/SpatialProperties/000315/PRES`)
- `Paths` — cell array of all dataset paths found

---

### `extract_spatial_from_sr3.m`
**Purpose:** Extract all `/SpatialProperties/<TIMESTEP>/<VARIABLE>` datasets into matrices.

**Signature**
```matlab
[DATA, meta] = extract_spatial_from_sr3(sr3, Paths, filePath)
```

**Returns**
- `DATA` — struct with one field per variable  
  (e.g., `DATA.PRES` is `[nCells x nSteps]`)
- `meta` — struct with:
  - `timesteps_str` — unique **non-empty** timestep strings (sorted)
  - `timesteps_num` — numeric ordering for plotting
  - `var_original` / `var_fields` — original vs MATLAB-safe names
  - `paths_table` — table of `(Path, StepStr, VarName)`

**Variable name sanitization**
- Uppercase, remove `()[]` and spaces
- Replace non-alphanumeric with `_`
- Collapse repeated `_`, trim edges
- If the name would contain digits at the end, it changes with the name of variable.  
Examples: `ACTIV10` → `ACTIVE_Ca`, `X1` → `X_H2`

---

## 📂 Repository Structure

```
sr3-extractor/
├── README.md
├── src/
│   ├── read_SR3.m
│   ├── extract_spatial_from_sr3.m
│   └── extract_well_from_sr3.m
├── demo_extract.m
```

