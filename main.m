clear; clc;

% Add utils folder to path
addpath(fullfile(pwd, 'utils'));

% Run pipeline
[ecg, fs, label, phys_min, phys_max] = load_ecg_raw("ABC100110013333PSG06.edf");
plot_ecg_features_over_time(ecg, fs, 30, phys_min, phys_max);
