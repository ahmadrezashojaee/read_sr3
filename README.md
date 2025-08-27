### read_sr3
# SR3 Spatial Extractor (CMG-GEM) — MATLAB

Utilities for reading **CMG-GEM** `.SR3` restart files (HDF5) and extracting **spatial properties** into clean MATLAB matrices for analysis and plotting.

Developed by **Ahmadreza Shojaee** during PhD research at **Heriot-Watt University**.

---

## 💡 What this does

- Loads an SR3 (HDF5) file and indexes **all datasets** into a `containers.Map`.
- Gathers everything under  
  `/SpatialProperties/<TIMESTEP>/<VARIABLE>`  
  into MATLAB matrices with **columns = timesteps** and **rows = cells**.
- Creates a tidy struct:
  - `DATA.<VAR>` → `[nCells x nSteps]` (e.g., `DATA.PRES`, `DATA.PH`, `DATA.SW`, `DATA.SG`)
  - `meta` → timestep labels, numeric order, and a table of all spatial paths.
- Makes variable names MATLAB-safe (e.g., `ACTIV(1)` → `ACTIVE1`).

## 📦 Installation

**Download the package**
Download the repo as a .zip and unzip it locally.

## Usage

**Add src/ to your MATLAB path**

```bash
addpath('src');
```bash
Run the demo_Extract.m file.
```bash
demo_extract;
```bash

% Load SR3 file
[sr3, Paths] = read_SR3('CASE.SR3');

% Extract all spatial properties
[DATA, meta] = extract_spatial_from_sr3(sr3, Paths);

% Inspect results
fieldnames(DATA)          % list of variables
size(DATA.PRES)           % [nCells x nSteps]
meta.timesteps_str        % timestep identifiers


