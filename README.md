# ECG Feature Extraction and Visualization (MATLAB)

This repository contains a MATLAB (2025b-compatible) pipeline for loading raw
ECG data from EDF files, extracting ECG and HRV features on a per-epoch basis,
and visualizing both the raw signal and derived features over time.

The implementation is designed to be transparent, modular, and aligned with
common Python/NeuroKit-style ECG processing practices.

---

## Features Extracted

Per epoch (user-defined window length), the pipeline computes:

- Mean heart rate (HR)
- Maximum and minimum HR
- HRV (RMSSD)
- SDNN
- LF power (0.04–0.15 Hz)
- HF power (0.15–0.40 Hz)
- LF/HF ratio
- Signal-to-noise ratio (SNR, dB)

All features are derived from windowed ECG signals using physiologically
constrained peak detection and robust filtering.

---

## Repository Structure

```text
.
├── main.m
└── utils/
    ├── load_ecg_raw.m
    ├── get_ecg_features.m
    └── plot_ecg_features_over_time.m  
```
---

## MATLAB Version and Toolboxes

**Tested with:**
- MATLAB **R2025b**

**Required Toolboxes:**
- Signal Processing Toolbox  
  (for `butter`, `filtfilt`, `pwelch`, `findpeaks`)

**Built-in MATLAB Functions Used:**
- `edfread`, `edfinfo` (EDF file support)
- `findpeaks`
- `pwelch`
- `butter`, `filtfilt`
- `interp1`
- `smoothdata`
- `zscore`

No external toolboxes or third-party libraries are required.

---

## Example Output

The pipeline generates a set of complementary figures that summarize raw ECG,
derived autonomic features, sleep staging, and nocturnal dipping behavior.

---

### Figure 1. ECG, HRV Features, and Sleep Stages (Time-Resolved)

![Figure 1](assets/Figure1.png)

**Figure 1.**  
Raw ECG waveform (top) and epoch-level autonomic features (HR, RMSSD, SDNN,
HF power, LF/HF ratio, and SNR) computed over fixed-length windows and displayed
as synchronized time series.  
The bottom panel shows the sleep hypnogram with color-coded sleep stages
(AWAKE, N1–N3, REM, UNSURE), aligned to clock time.

This figure provides a holistic overview of signal quality, autonomic dynamics,
and sleep architecture across the full overnight recording.

---

### Figure 2. Sleep Hypnogram

![Figure 2](assets/Figure2.png)

**Figure 2.**  
Sleep hypnogram derived from PSG annotations and plotted as a stage-resolved
timeline. Each sleep stage is represented by a distinct color and displayed
against absolute clock time.

This visualization highlights sleep continuity, fragmentation, and transitions
between wake, NREM, and REM stages.

---

### Figure 3. Heart Rate and HRV by Sleep Stage

![Figure 3](assets/Figure3.png)

**Figure 3.**  
Distribution of heart rate (left) and HRV (RMSSD; right) across sleep stages.
Each point represents an epoch-level estimate, overlaid with boxplots to
summarize central tendency and variability.

These plots enable stage-resolved autonomic comparisons (e.g., wake vs NREM vs
REM) and are suitable for group-level aggregation in downstream analyses.

---

### Figure 4. Nocturnal Heart Rate Dipping

![Figure 4](assets/Figure4.png)

**Figure 4.**  
Nocturnal heart rate trajectory with the AWAKE baseline shown as a dashed line.
Sleep periods are shaded according to sleep stage, enabling direct visual
association between autonomic changes and sleep architecture.

The title reports the computed nocturnal HR dipping percentage, supporting
classification into dipper, reduced dipper, or non-dipper phenotypes.


---

## Usage

### 1. Add utilities to MATLAB path
```matlab
addpath(fullfile(pwd, 'utils'));
