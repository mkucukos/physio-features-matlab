function plot_hr_hrv_by_stage(ecg, fs, epoch_len, t_abs, sleep_tbl, subject_id)
% PLOT_HR_HRV_BY_STAGE
% HR and RMSSD grouped by MWT stage
% - BASELINE = initial awake (handled elsewhere)
% - UNSURE excluded from statistics
%
% Output:
%   ./figures/<SUBJECT_ID>/MWT_HR_RMSSD_ByStage.png
%   (overwrites if exists)

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
    catch
        continue
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

% REMOVE BASELINE AND UNSURE
epoch_stage(epoch_stage=="?" | epoch_stage=="UNSURE") = "";

%% ---------------- Stage definitions ----------------
stage_names = ["AWAKE","STAGE 1","STAGE 2","STAGE 3","REM"];

stage_colors = containers.Map( ...
    stage_names, ...
    { ...
        [0.60 0.60 0.60], ...
        [0.30 0.75 0.93], ...
        [0.00 0.45 0.74], ...
        [0.00 0.20 0.50], ...
        [0.80 0.40 0.80] ...
    } ...
);

%% ---------------- Plot ----------------
fig = figure('Color','w','Position',[200 200 1300 480]);

metrics = {HR, RMSSD};
labels  = {'Heart Rate (bpm)','RMSSD (ms)'};

for m = 1:2
    subplot(1,2,m); hold on

    for s = 1:numel(stage_names)
        idx  = epoch_stage == stage_names(s);
        vals = metrics{m}(idx);
        vals = vals(~isnan(vals));

        if isempty(vals)
            continue
        end

        % Scatter
        x = s + 0.12*randn(size(vals));
        scatter(x, vals, 14, ...
            'filled', ...
            'MarkerFaceColor', stage_colors(stage_names(s)), ...
            'MarkerFaceAlpha', 0.25);

        % Box
        boxchart(ones(size(vals))*s, vals, ...
            'BoxWidth',0.45, ...
            'BoxFaceColor',stage_colors(stage_names(s)), ...
            'MarkerStyle','none');

        % ----- Numeric annotations -----
        q1  = prctile(vals,25);
        med = median(vals);
        q3  = prctile(vals,75);

        text(s, q3,  sprintf('Q3 %.1f',q3), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','bottom', ...
            'FontSize',8);

        text(s, med, sprintf('Med %.1f',med), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontSize',9, 'FontWeight','bold');

        text(s, q1,  sprintf('Q1 %.1f',q1), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','top', ...
            'FontSize',8);
    end

    xticks(1:numel(stage_names))
    xticklabels(stage_names)
    ylabel(labels{m})
    title(sprintf('%s by MWT Stage – %s', labels{m}, subject_id))
    box on
end

%% ---------------- Save figure ----------------
out_dir = fullfile(pwd,'figures',subject_id);
if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

out_file = fullfile(out_dir,'MWT_HR_RMSSD_ByStage.png');
exportgraphics(fig, out_file, 'Resolution',300);

end