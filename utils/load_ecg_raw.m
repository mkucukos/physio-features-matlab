function [ecg, fs, label, phys_min, phys_max] = load_ecg_raw(edf_path)
% LOAD_ECG_RAW
% Load raw ECG signal and metadata from EDF (MATLAB 2025 compatible)
%
% Outputs:
%   ecg       - raw ECG signal (numeric vector)
%   fs        - sampling frequency (Hz)
%   label     - ECG channel label (from edfread)
%   phys_min  - physical minimum (from edfinfo)
%   phys_max  - physical maximum (from edfinfo)

%% --- Read signal ---
data = edfread(edf_path);   % timetable
vars = data.Properties.VariableNames;
%% fprintf('%s\n', vars{:});
% Robust ECG channel detection (priority order)
candidates = ["ECGII", "ECG"];
idx = [];

for c = candidates
    idx = find(contains(vars, c, 'IgnoreCase', true), 1);
    if ~isempty(idx), break; end
end

assert(~isempty(idx), "ECG channel not found in EDF (edfread)");
label = vars{idx};

% Extract ECG (cell-per-second → numeric)
ecg_cell = data.(label);
ecg_cell = cellfun(@double, ecg_cell, 'UniformOutput', false);
ecg = vertcat(ecg_cell{:});

% Sampling rate = samples per EDF record (usually 1 second)
fs = numel(ecg_cell{1});

% Sanity check
assert(all(cellfun(@numel, ecg_cell) == fs), ...
    "Inconsistent sampling rate across EDF records");

%% --- Read metadata (DIRECTLY via edfinfo) ---
info = edfinfo(edf_path);

% IMPORTANT:
% edfread variable order == edfinfo.SignalLabels order
% so we use *idx* directly, NOT string matching
assert(idx <= numel(info.SignalLabels), ...
    "ECG index exceeds metadata channel count");

phys_min = info.PhysicalMin(idx);
phys_max = info.PhysicalMax(idx);

%% --- Report ---
fprintf("Loaded %s | fs = %.1f Hz | samples = %d\n", ...
        label, fs, numel(ecg));
fprintf("ECG limits: %.1f to %.1f\n", phys_min, phys_max);

end
