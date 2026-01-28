clear; clc;

% Add utils folder to path
addpath(fullfile(pwd, 'utils'));

% Run pipeline
%% ---------------- Paths ----------------
edf_path = "0311-GPIF5699320266PSG01/0311-GPIF5699320266PSG01.edf";
h_path   = "0311-GPIF5699320266PSG01/tempH.txt";

%% ---------------- Subject ID (first 4 chars) ----------------
[~, subject_id_full, ~] = fileparts(edf_path);
subject_id = extractBetween(subject_id_full, 1, 4);
subject_id = subject_id{1};   % e.g. "0311"

%% ---------------- Load data ----------------
[ecg, fs, t_rel, t_abs, start_dt, label] = load_ecg_raw(edf_path);
ecg = -ecg;
sleep_tbl = load_sleep_hypnogram(h_path, t_abs(1));

%% ===================== DEBUG PEAK DETECTION =====================
epoch_len = 30;                 % seconds
samples_per_epoch = fs * epoch_len;
n_epochs = floor(numel(ecg) / samples_per_epoch);
epoch_to_view = randi(n_epochs);   % random epoch in [1, n_epochs]
debug_plot_ecg_peaks(ecg, fs, 30, epoch_to_view);

%% ---------------- Run plots ----------------
plot_ecg_features_over_time(ecg, fs, 30, t_abs, sleep_tbl, subject_id);
plot_sleep_hypnogram(sleep_tbl, subject_id);
plot_hr_hrv_by_stage(ecg, fs, 30, t_abs, sleep_tbl, subject_id);