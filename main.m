clear; clc;

% Add utils folder to path
addpath(fullfile(pwd, 'utils'));

% Run pipeline
edf_path = "0311-GPIF5699320266PSG01/0311-GPIF5699320266PSG01.edf";
[ecg, fs, t_rel, t_abs, start_dt, label, phys_min, phys_max] = load_ecg_raw(edf_path);
h_path = "0311-GPIF5699320266PSG01/tempH.txt";
sleep_tbl = load_sleep_hypnogram(h_path, t_abs(1));

plot_ecg_features_over_time(ecg, fs, 30, phys_min, phys_max, t_abs, sleep_tbl)
plot_sleep_hypnogram(sleep_tbl);
plot_hr_hrv_by_stage(ecg, fs, 30, t_abs, sleep_tbl);
