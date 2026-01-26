function plot_ecg_features_over_time(ecg, fs, epoch_len, phys_min, phys_max, t_abs, sleep_tbl)
% ECG + HRV features + MWT hypnogram + PER-TRIAL HR dipping
% Baseline = initial contiguous AWAKE period (>=5 epochs) at start of each trial
%
% Outputs:
%   Saves two PNG figures to ./figures/
%     1) ECG + features + hypnogram
%     2) Per-trial HR dipping
%
% Debugging:
%   Prints a summary explaining why features may be missing

%% ========================= DEBUG SETUP =========================
DEBUG = true;
debug.flat_epochs = [];
debug.nan_epochs  = [];
debug.feat_errors = {};

%% ---------------- Safety ----------------
ecg   = double(ecg(:));
t_abs = t_abs(:);

N = numel(ecg);
assert(numel(t_abs) == N, 't_abs must match ECG length');
assert(isdatetime(t_abs), 't_abs must be datetime');

samples_per_epoch = fs * epoch_len;
n_epochs = floor(N / samples_per_epoch);

fprintf('\n===== ECG PIPELINE START =====\n');
fprintf('Total samples: %d (%.2f hours)\n', N, N/fs/3600);
fprintf('Epoch length: %d s | Epochs: %d\n', epoch_len, n_epochs);

%% ---------------- Epoch times ----------------
epoch_centers = round(((0:n_epochs-1)+0.5)*samples_per_epoch);
epoch_centers(epoch_centers < 1) = 1;
epoch_centers(epoch_centers > N) = N;
epoch_time = t_abs(epoch_centers);

%% ---------------- Feature extraction ----------------
HR_mean = nan(n_epochs,1);
RMSSD  = nan(n_epochs,1);
SDNN   = nan(n_epochs,1);
HF     = nan(n_epochs,1);
LFHF   = nan(n_epochs,1);
SNR    = nan(n_epochs,1);

for k = 1:n_epochs
    s = (k-1)*samples_per_epoch + 1;
    e = k*samples_per_epoch;
    seg = ecg(s:e);

    if all(seg == 0) || std(seg,'omitnan') < 1e-6
        if DEBUG, debug.flat_epochs(end+1) = k; end
        continue
    end

    try
        feats = get_ecg_features(seg, fs);

        if any(isnan(feats))
            if DEBUG, debug.nan_epochs(end+1) = k; end
            continue
        end

        HR_mean(k) = feats(1);
        RMSSD(k)   = feats(4);
        SDNN(k)    = feats(5);
        HF(k)      = feats(7);
        LFHF(k)    = feats(8);
        SNR(k)     = feats(9);

    catch ME
        if DEBUG
            debug.feat_errors{end+1} = struct( ...
                'epoch', k, 'message', ME.message);
        end
        continue
    end
end

%% ---------------- DEBUG SUMMARY ----------------
if DEBUG
    fprintf('\n===== ECG FEATURE DEBUG SUMMARY =====\n');
    fprintf('Total epochs: %d\n', n_epochs);
    fprintf('Flat / zero epochs: %d\n', numel(debug.flat_epochs));
    fprintf('NaN feature epochs: %d\n', numel(debug.nan_epochs));
    fprintf('Feature errors: %d\n', numel(debug.feat_errors));
    if ~isempty(debug.feat_errors)
        fprintf('First feature error (epoch %d):\n%s\n', ...
            debug.feat_errors{1}.epoch, debug.feat_errors{1}.message);
    end
end

%% ---------------- Mild smoothing ----------------
k = 7;
HR_mean = medfilt1(HR_mean,k,'omitnan','truncate');
RMSSD   = medfilt1(RMSSD,k,'omitnan','truncate');
SDNN    = medfilt1(SDNN,k,'omitnan','truncate');
HF      = medfilt1(HF,k,'omitnan','truncate');
LFHF    = medfilt1(LFHF,k,'omitnan','truncate');
SNR     = medfilt1(SNR,k,'omitnan','truncate');

%% ========================= FIGURE 1 =========================
fig1 = figure('Color','w','Position',[100 60 1500 1300]);
left = 0.07; width = 0.90; h = 0.085; gap = 0.015; y = 0.92;
ax = gobjects(8,1);

ax(1) = axes('Position',[left y width h]); y=y-h-gap;
plot(t_abs, ecg,'k','LineWidth',0.3)
if ~isfinite(phys_min) || ~isfinite(phys_max) || phys_min >= phys_max
    yl = prctile(ecg(isfinite(ecg)),[1 99]);
    if diff(yl)==0, yl = yl + [-1 1]; end
else
    yl = [0.3*phys_min 0.3*phys_max];
end
ylim(yl); ylabel('ECG'); title('ECG, HRV Features, and MWT Hypnogram'); grid on

labels = {'HR (bpm)','RMSSD (ms)','SDNN (ms)','HF','LF/HF','SNR (dB)'};
data   = {HR_mean, RMSSD, SDNN, HF, LFHF, SNR};

for i = 1:6
    ax(i+1) = axes('Position',[left y width h]); y=y-h-gap;
    stairs(epoch_time, data{i}, 'LineWidth',1.2);
    ylabel(labels{i});
    if i==4, set(gca,'YScale','log'); end
    grid on
end

%% ---------------- Hypnogram ----------------
ax(8) = axes('Position',[left 0.06 width 0.18]); hold on
sleep_tbl = sortrows(sleep_tbl,'t_abs');
plot_stage = sleep_tbl.Stage;
plot_stage(plot_stage=="?") = "";

stages = ["AWAKE","STAGE 1","STAGE 2","STAGE 3","REM","UNSURE"];
stage_present = intersect(stages, unique(plot_stage,'stable'),'stable');
stage_map = containers.Map(stage_present,1:numel(stage_present));
colors = containers.Map(stages,{[.55 .55 .55],[.3 .75 .93],[0 .45 .74],[0 .2 .5],[.8 .4 .8],[.95 .7 .4]});

for i = 1:height(sleep_tbl)-1
    st = plot_stage(i);
    if isKey(stage_map,st)
        plot([sleep_tbl.t_abs(i) sleep_tbl.t_abs(i+1)], ...
             [stage_map(st) stage_map(st)], ...
             'LineWidth',6,'Color',colors(st));
    end
end
set(gca,'YDir','reverse'); yticks(1:numel(stage_present));
yticklabels(stage_present); grid on; box on
linkaxes(ax,'x'); ax(end).XAxis.TickLabelFormat='dd-MMM HH:mm';

%% ========================= FIGURE 2 =========================
fig2 = figure('Color','w','Position',[200 200 1400 420]); hold on

epoch_stage = strings(n_epochs,1);
for i=1:n_epochs
    idx = find(sleep_tbl.t_abs<=epoch_time(i),1,'last');
    if ~isempty(idx), epoch_stage(i)=sleep_tbl.Stage(idx); end
end

valid = epoch_stage~="" & epoch_stage~="?" & epoch_stage~="UNSURE";
trial_blocks = find_contiguous_blocks(valid);
yl = [min(HR_mean)-2 max(HR_mean)+2];
ylim(yl)

dip_vals = []; trial_id = 0;

for t = 1:size(trial_blocks,1)
    idx_trial = trial_blocks(t,1):trial_blocks(t,2);
    is_awake = epoch_stage(idx_trial)=="AWAKE";
    d = diff([false; is_awake; false]);
    s = find(d==1,1,'first'); e = find(d==-1,1,'first')-1;
    if isempty(s) || (e-s+1)<5, continue; end

    baseline_idx = idx_trial(s:e);
    HR_base = median(HR_mean(baseline_idx),'omitnan');
    HR_trial = median(HR_mean(idx_trial),'omitnan');
    dHR = 100*(HR_base - HR_trial)/HR_base;

    trial_id = trial_id+1; dip_vals(end+1)=dHR;

    % ---- Trial shading (blue)
    patch([epoch_time(idx_trial(1)) epoch_time(idx_trial(end)) ...
           epoch_time(idx_trial(end)) epoch_time(idx_trial(1))], ...
          [yl(1) yl(1) yl(2) yl(2)], ...
          [.85 .9 1],'EdgeColor','none','FaceAlpha',0.25);

    % ---- Baseline shading (pink)
    patch([epoch_time(baseline_idx(1)) epoch_time(baseline_idx(end)) ...
           epoch_time(baseline_idx(end)) epoch_time(baseline_idx(1))], ...
          [yl(1) yl(1) yl(2) yl(2)], ...
          [1 .85 .85],'EdgeColor','none','FaceAlpha',0.35);

    % ---- Baseline HR line
    plot([epoch_time(baseline_idx(1)) epoch_time(baseline_idx(end))], ...
         [HR_base HR_base],'--','Color',[.8 0 0],'LineWidth',1.6);

    text(mean(epoch_time(idx_trial)), yl(2)-1, ...
        sprintf('T%d (%.1f%%)',trial_id,dHR), ...
        'FontWeight','bold','HorizontalAlignment','center');
end

plot(epoch_time, HR_mean,'k','LineWidth',1.1)
title(sprintf('MWT HR Change (Per-Trial Awake Baseline): %.1f%%',mean(dip_vals,'omitnan')))
ylabel('Heart Rate (bpm)'); xlabel('Clock Time'); grid on
ax=gca; ax.XAxis.TickLabelFormat='dd-MMM HH:mm';

%% ---------------- Save figures ----------------
out_dir = fullfile(pwd,'figures'); if ~exist(out_dir,'dir'), mkdir(out_dir); end
ts = datestr(now,'yyyymmdd_HHMMSS');
exportgraphics(fig1,fullfile(out_dir,sprintf('MWT_ECG_Features_%s.png',ts)),'Resolution',300);
exportgraphics(fig2,fullfile(out_dir,sprintf('MWT_HR_Dipping_%s.png',ts)),'Resolution',300);

fprintf('Figures saved to ./figures/\n');
fprintf('===== ECG PIPELINE DONE =====\n');
end
