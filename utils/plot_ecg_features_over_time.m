function plot_ecg_features_over_time(ecg, fs, epoch_len, phys_min, phys_max, t_abs, sleep_tbl)
% ECG + HRV features + MWT hypnogram + PER-TRIAL baseline HR analysis
% Baseline is defined locally before each MWT trial ("?")

%% ---------------- Safety ----------------
ecg   = double(ecg(:));
t_abs = t_abs(:);

N = numel(ecg);
assert(numel(t_abs) == N, 't_abs must match ECG length');
assert(isdatetime(t_abs), 't_abs must be datetime');

samples_per_epoch = fs * epoch_len;
n_epochs = floor(N / samples_per_epoch);

%% ---------------- Epoch times ----------------
epoch_centers = round(((0:n_epochs-1) + 0.5) * samples_per_epoch);
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
    try
        feats = get_ecg_features(ecg(s:e), fs);
        HR_mean(k) = feats(1);
        RMSSD(k)   = feats(4);
        SDNN(k)    = feats(5);
        HF(k)      = feats(7);
        LFHF(k)    = feats(8);
        SNR(k)     = feats(9);
    end
end

% Mild smoothing
k = 7;
HR_mean = medfilt1(HR_mean,k,'omitnan','truncate');
RMSSD   = medfilt1(RMSSD,k,'omitnan','truncate');
SDNN    = medfilt1(SDNN,k,'omitnan','truncate');
HF      = medfilt1(HF,k,'omitnan','truncate');
LFHF    = medfilt1(LFHF,k,'omitnan','truncate');
SNR     = medfilt1(SNR,k,'omitnan','truncate');

%% ========================= FIGURE 1 =========================
figure('Color','w','Position',[100 60 1500 1050]);

left = 0.07; width = 0.90; h = 0.085; gap = 0.015; y = 0.92;
ax = gobjects(8,1);

ax(1) = axes('Position',[left y width h]); y=y-h-gap;
plot(t_abs, ecg,'k','LineWidth',0.3)
ylabel('ECG'); ylim([0.3*phys_min 0.3*phys_max]); grid on
title('ECG, HRV Features, and MWT Hypnogram')

ax(2) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, HR_mean,'LineWidth',1.2); ylabel('HR'); grid on

ax(3) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, RMSSD,'LineWidth',1.2); ylabel('RMSSD'); grid on

ax(4) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, SDNN,'LineWidth',1.2); ylabel('SDNN'); grid on

ax(5) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, HF,'LineWidth',1.2); set(gca,'YScale','log')
ylabel('HF'); grid on

ax(6) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, LFHF,'LineWidth',1.2); ylabel('LF/HF'); grid on

ax(7) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, SNR,'LineWidth',1.2); ylabel('SNR'); grid on

%% ---------------- Hypnogram (MWT-aware, only existing stages) ----------------
ax(8) = axes('Position',[left 0.06 width 0.18]); hold on

sleep_tbl = sortrows(sleep_tbl,'t_abs');

% Normalize stages
plot_stage = sleep_tbl.Stage;
plot_stage(plot_stage == "?") = "BASELINE";

unique_stages = unique(plot_stage,'stable');

stage_order = ["BASELINE","AWAKE","STAGE 1","STAGE 2","STAGE 3","REM","UNSURE"];
stage_names = stage_order(ismember(stage_order, unique_stages));
stage_y = 1:numel(stage_names);

stage_map = containers.Map(stage_names, stage_y);

stage_colors = containers.Map( ...
    ["BASELINE","AWAKE","STAGE 1","STAGE 2","STAGE 3","REM","UNSURE"], ...
    { ...
        [0.95 0.92 0.85], ...
        [0.60 0.60 0.60], ...
        [0.30 0.75 0.93], ...
        [0.00 0.45 0.74], ...
        [0.00 0.20 0.50], ...
        [0.80 0.40 0.80], ...
        [0.85 0.85 0.85] ...
    } ...
);

for i = 1:height(sleep_tbl)-1
    st = plot_stage(i);
    if isKey(stage_map, st)
        plot([sleep_tbl.t_abs(i) sleep_tbl.t_abs(i+1)], ...
             [stage_map(st) stage_map(st)], ...
             'LineWidth',6,'Color',stage_colors(st));
    end
end

yticks(stage_y)
yticklabels(stage_names)
ylim([0.5 numel(stage_names)+0.5])
set(gca,'YDir','reverse')
ylabel('Stage')
grid on

linkaxes(ax,'x')
xlim([t_abs(1) t_abs(end)])
ax(end).XAxis.TickLabelFormat = 'dd-MMM HH:mm';
xlabel('Clock Time')

%% ========================= FIGURE 2: BLOCK-WISE MWT HR CHANGE =========================

% Align hypnogram stage to epochs
epoch_stage = strings(numel(epoch_time),1);
for i = 1:numel(epoch_time)
    idx = find(sleep_tbl.t_abs <= epoch_time(i),1,'last');
    if ~isempty(idx)
        epoch_stage(i) = sleep_tbl.Stage(idx);
    end
end

% Define baseline and trial
is_baseline = epoch_stage == "?";
is_trial    = epoch_stage ~= "?" & epoch_stage ~= "";

% Find contiguous blocks
baseline_cc = bwconncomp(is_baseline);
trial_cc    = bwconncomp(is_trial);

figure('Color','w','Position',[200 200 1400 440]);
hold on

plot(epoch_time, HR_mean, 'k', 'LineWidth', 1.1)

yl = ylim;
dip_vals = [];

trial_counter = 0;

for b = 1:baseline_cc.NumObjects

    idx_base = baseline_cc.PixelIdxList{b};
    t_base_start = epoch_time(idx_base(1));
    t_base_end   = epoch_time(idx_base(end));

    % Find the first trial block AFTER this baseline
    idx_trial = [];
    for t = 1:trial_cc.NumObjects
        cand = trial_cc.PixelIdxList{t};
        if epoch_time(cand(1)) > t_base_end
            idx_trial = cand;
            break
        end
    end

    if isempty(idx_trial)
        continue
    end

    trial_counter = trial_counter + 1;

    % HR statistics
    HR_base  = median(HR_mean(idx_base), 'omitnan');
    HR_trial = median(HR_mean(idx_trial), 'omitnan');

    dHR_pct = 100 * (HR_base - HR_trial) / HR_base;
    dip_vals(end+1) = dHR_pct; %#ok<AGROW>

    % --- Baseline HR line (local only)
    plot([t_base_start t_base_end], ...
         [HR_base HR_base], ...
         '--', 'Color', [0.85 0 0], 'LineWidth', 1.6)

    % --- Shade trial block
    patch([epoch_time(idx_trial(1)) epoch_time(idx_trial(end)) ...
           epoch_time(idx_trial(end)) epoch_time(idx_trial(1))], ...
          [yl(1) yl(1) yl(2) yl(2)], ...
          [0.85 0.9 1], ...
          'EdgeColor','none','FaceAlpha',0.25);

    % --- Label BASELINE block
    text(mean([t_base_start t_base_end]), ...
         HR_base + 0.6, ...
         sprintf('B%d', b), ...
         'Color', [0.7 0 0], ...
         'FontWeight','bold', ...
         'HorizontalAlignment','center');

    % --- Label TRIAL block
    text(mean(epoch_time(idx_trial)), ...
         yl(2) - 1.5, ...
         sprintf('T%d (%.1f%%)', trial_counter, dHR_pct), ...
         'Color', [0 0.2 0.6], ...
         'FontWeight','bold', ...
         'HorizontalAlignment','center');
end

% Replot HR on top
plot(epoch_time, HR_mean, 'k', 'LineWidth', 1.1)

% Overall classification
mean_dHR = mean(dip_vals, 'omitnan');

if mean_dHR >= 10
    dip_class = "MWT dipper";
elseif mean_dHR >= 0
    dip_class = "Reduced MWT dipper";
else
    dip_class = "MWT non-dipper";
end

grid on
xlim([t_abs(1) t_abs(end)])
ylabel('Heart Rate (bpm)')
xlabel('Clock Time')
title(sprintf('MWT HR Change (Block-wise Baseline): %.1f%% (%s)', ...
      mean_dHR, dip_class))

ax = gca;
ax.XAxis.TickLabelFormat = 'dd-MMM HH:mm';

hold off


end
