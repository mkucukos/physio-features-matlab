function [ecg, fs, t_rel, t_abs, start_dt, label] = load_ecg_raw(edf_path)
% LOAD_ECG_RAW
% Load raw ECG signal from EDF and reconstruct time
%
% Outputs:
%   ecg       : raw ECG signal (vector)
%   fs        : sampling rate (Hz)
%   t_rel     : relative time vector (seconds)
%   t_abs     : absolute datetime vector
%   start_dt  : EDF start datetime
%   label     : ECG channel label used

%% ---------------- Read signal ----------------
data = edfread(edf_path);
vars = data.Properties.VariableNames;

candidates = ["ECGII", "ECG", "EKG"];
idx = [];

for c = candidates
    idx = find(contains(vars, c, 'IgnoreCase', true), 1);
    if ~isempty(idx)
        break
    end
end

assert(~isempty(idx), "ECG channel not found in EDF");

label = vars{idx};

ecg_cell = data.(label);
ecg_cell = cellfun(@double, ecg_cell, 'UniformOutput', false);
ecg = vertcat(ecg_cell{:});

%% ---------------- Sampling rate ----------------
fs = numel(ecg_cell{1});
assert(all(cellfun(@numel, ecg_cell) == fs), ...
    "Inconsistent sampling rate across EDF records");

N = numel(ecg);

%% ---------------- EDF metadata ----------------
info = edfinfo(edf_path);

date_str = info.StartDate;   % e.g. "16.12.22"
time_str = info.StartTime;   % e.g. "21.46.01"

start_dt = datetime( ...
    date_str + " " + time_str, ...
    'InputFormat', 'dd.MM.yy HH.mm.ss' ...
);

%% ---------------- Time reconstruction ----------------
t_rel = (0:N-1)' / fs;
t_abs = start_dt + seconds(t_rel);

%% ---------------- Report ----------------
fprintf("Loaded %s\n", label);
fprintf("Sampling rate: %.1f Hz\n", fs);
fprintf("Samples: %d (%.2f hours)\n", N, N/fs/3600);
fprintf("Start time (EDF): %s\n", datestr(start_dt));

end
