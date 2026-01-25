function hypno_tbl = load_sleep_hypnogram(h_path, t_start)
% LOAD_SLEEP_HYPNOGRAM
% Load 30s epoch hypnogram (H file)
%
% Inputs:
%   h_path  - path to H file
%   t_start - datetime of recording start
%
% Output:
%   hypno_tbl with variables:
%       t_abs, Stage

%% Read raw labels (one per line)
labels = string(readlines(h_path));
labels = strtrim(labels);
labels(labels == "") = [];

%% Map labels to stages
stage = strings(size(labels));

stage(labels == "W") = "AWAKE";
stage(labels == "1") = "STAGE 1";
stage(labels == "2") = "STAGE 2";
stage(labels == "3") = "STAGE 3";
stage(labels == "R") = "REM";
stage(labels == "U" | labels == "?") = "UNSURE";

%% Time vector (30s epochs)
epoch_len = seconds(30);
t_abs = t_start + (0:numel(stage)-1)' * epoch_len;

%% Output table
hypno_tbl = table(t_abs, stage, ...
    'VariableNames', {'t_abs','Stage'});

fprintf("Loaded hypnogram (%d epochs) from:\n  %s\n", ...
    height(hypno_tbl), h_path);

end
