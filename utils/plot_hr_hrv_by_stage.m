function plot_hr_hrv_by_stage(ecg, fs, epoch_len, t_abs, sleep_tbl)
% PLOT_HR_HRV_BY_STAGE
% HR and RMSSD grouped by MWT stage (includes BASELINE)

%% ---------------- Epoching ----------------
samples_per_epoch = fs * epoch_len;
n_epochs = floor(numel(ecg) / samples_per_epoch);

epoch_centers = round(((0:n_epochs-1)+0.5)*samples_per_epoch);
epoch_centers(epoch_centers < 1) = 1;
epoch_centers(epoch_centers > numel(ecg)) = numel(ecg);
epoch_time = t_abs(epoch_centers);

%% ---------------- Feature extraction ----------------
HR     = nan(n_epochs,1);
RMSSD = nan(n_epochs,1);

for k = 1:n_epochs
    s = (k-1)*samples_per_epoch + 1;
    e = k*samples_per_epoch;
    try
        feats = get_ecg_features(ecg(s:e), fs);
        HR(k)     = feats(1);
        RMSSD(k) = feats(4);
    end
end

%% ---------------- Map sleep stage to epochs ----------------
epoch_stage = strings(n_epochs,1);
for k = 1:n_epochs
    idx = find(sleep_tbl.t_abs <= epoch_time(k),1,'last');
    if ~isempty(idx)
        epoch_stage(k) = sleep_tbl.Stage(idx);
    end
end

% Explicit MWT mapping
epoch_stage(epoch_stage == "?") = "BASELINE";

%% ---------------- Stage definitions ----------------
stage_names = ["BASELINE","AWAKE","STAGE 1","STAGE 2","STAGE 3","REM"];

stage_colors = containers.Map( ...
    stage_names, ...
    { ...
        [0.95 0.92 0.85], ... % BASELINE
        [0.60 0.60 0.60], ... % AWAKE
        [0.30 0.75 0.93], ... % STAGE 1
        [0.00 0.45 0.74], ... % STAGE 2
        [0.00 0.20 0.50], ... % STAGE 3
        [0.80 0.40 0.80]  ... % REM
    } ...
);

%% ---------------- Plot ----------------
figure('Color','w','Position',[200 200 1300 480]);

metrics = {HR, RMSSD};
labels  = {'Heart Rate (bpm)','RMSSD (ms)'};

for m = 1:2
    subplot(1,2,m); hold on

    for s = 1:numel(stage_names)
        idx  = epoch_stage == stage_names(s);
        vals = metrics{m}(idx);

        if isempty(vals)
            continue
        end

        % jittered scatter
        x = s + 0.15*randn(size(vals));
        scatter(x, vals, 12, ...
            'filled', ...
            'MarkerFaceColor', stage_colors(stage_names(s)), ...
            'MarkerFaceAlpha', 0.25);

        % boxplot
        boxchart(ones(size(vals))*s, vals, ...
            'BoxWidth',0.45, ...
            'BoxFaceColor',stage_colors(stage_names(s)), ...
            'MarkerStyle','none');
    end

    xticks(1:numel(stage_names))
    xticklabels(stage_names)
    ylabel(labels{m})
    title(labels{m} + " by MWT Stage")
    grid on
    box on
end

end