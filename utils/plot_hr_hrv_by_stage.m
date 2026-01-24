function plot_hr_hrv_by_stage(ecg, fs, epoch_len, t_abs, sleep_tbl)
% PLOT_HR_HRV_BY_STAGE
% HR and RMSSD grouped by sleep stage

samples_per_epoch = fs * epoch_len;
n_epochs = floor(numel(ecg) / samples_per_epoch);

epoch_centers = round(((0:n_epochs-1)+0.5)*samples_per_epoch);
epoch_centers(epoch_centers < 1) = 1;
epoch_centers(epoch_centers > numel(ecg)) = numel(ecg);
epoch_time = t_abs(epoch_centers);

HR = nan(n_epochs,1);
RMSSD = nan(n_epochs,1);

for k = 1:n_epochs
    s = (k-1)*samples_per_epoch + 1;
    e = k*samples_per_epoch;
    try
        feats = get_ecg_features(ecg(s:e), fs);
        HR(k) = feats(1);
        RMSSD(k) = feats(4);
    end
end

% Map sleep stage to each epoch (nearest neighbor)
epoch_stage = strings(n_epochs,1);
for k = 1:n_epochs
    [~,ix] = min(abs(sleep_tbl.t_abs - epoch_time(k)));
    epoch_stage(k) = sleep_tbl.Stage(ix);
end

stage_names = ["AWAKE","STAGE 1","STAGE 2","STAGE 3","REM"];

figure('Color','w','Position',[200 200 1200 480]);

metrics = {HR, RMSSD};
labels  = {'Heart Rate (bpm)','RMSSD (ms)'};

for m = 1:2
    subplot(1,2,m); hold on

    for s = 1:numel(stage_names)
        idx = epoch_stage == stage_names(s);
        vals = metrics{m}(idx);

        if isempty(vals), continue; end

        x = s + 0.15*randn(size(vals));
        scatter(x, vals, 10, 'filled', ...
            'MarkerFaceAlpha',0.25);

        boxchart(ones(size(vals))*s, vals, ...
            'BoxWidth',0.4);
    end

    xticks(1:numel(stage_names))
    xticklabels(stage_names)
    ylabel(labels{m})
    title(labels{m} + " by Sleep Stage")
    grid on
end

end
