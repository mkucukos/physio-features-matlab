function [ecg, fs, t_rel, t_abs, label, phys_min, phys_max] = load_ecg_raw(edf_path)
% LOAD_ECG_RAW
% Load raw ECG signal from EDF and reconstruct time
%
% Outputs:
%   ecg       - ECG signal (numeric vector, physical units)
%   fs        - sampling frequency (Hz)
%   t_rel     - relative time (seconds)
%   t_abs     - absolute time (datetime)
%   label     - ECG channel label
%   phys_min  - physical minimum (EDF metadata)
%   phys_max  - physical maximum (EDF metadata)

%% ---------------- Read signal ----------------
data = edfread(edf_path);   % timetable
vars = data.Properties.VariableNames;

% Robust ECG channel detection
candidates = ["ECGII", "ECG", "EKG"];
idx = [];

for c = candidates
    idx = find(contains(vars, c, 'IgnoreCase', true), 1);
    if ~isempty(idx), break; end
end

assert(~isempty(idx), "ECG channel not found in EDF");

label = vars{idx};

% Extract ECG (cell-per-record → numeric vector)
ecg_cell = data.(label);
ecg_cell = cellfun(@double, ecg_cell, 'UniformOutput', false);
ecg = vertcat(ecg_cell{:});

% Sampling frequency = samples per record (EDF record = 1 sec)
fs = numel(ecg_cell{1});

% Sanity check
assert(all(cellfun(@numel, ecg_cell) == fs), ...
    "Inconsistent sampling rate across EDF records");

N = numel(ecg);

%% ---------------- Read EDF metadata ----------------
info = edfinfo(edf_path);

phys_min = info.PhysicalMin(idx);
phys_max = info.PhysicalMax(idx);

%% ---------------- Time reconstruction (FIXED) ----------------
% EDF date/time are STRINGS → must parse explicitly

date_str = info.StartDate;   % e.g. "16.12.22"
time_str = info.StartTime;   % e.g. "21.46.01"

start_dt = datetime( ...
    date_str + " " + time_str, ...
    'InputFormat', 'dd.MM.yy HH.mm.ss' ...
);

% Relative time (seconds)
t_rel = (1:N)' / fs;

% Absolute time (datetime)
t_abs = start_dt + seconds(t_rel);

%% ---------------- Report ----------------
fprintf("Loaded %s\n", label);
fprintf("Sampling rate: %.1f Hz\n", fs);
fprintf("Samples: %d (%.2f hours)\n", N, N/fs/3600);
fprintf("Start time: %s\n", datestr(start_dt));
fprintf("ECG limits: %.2f to %.2f\n", phys_min, phys_max);

end
