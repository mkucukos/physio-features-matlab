function plot_ecg_features_over_time(ecg, fs, epoch_len, phys_min, phys_max, t_abs, sleep_tbl)
% ECG + HRV features + MWT hypnogram + PER-TRIAL HR dipping
% Baseline = initial contiguous AWAKE period (>=5 epochs) at start of each trial

%% ---------------- Safety ----------------
ecg   = double(ecg(:));
t_abs = t_abs(:);

N = numel(ecg);
assert(numel(t_abs) == N, 't_abs must match ECG length');
assert(isdatetime(t_abs), 't_abs must be datetime');

samples_per_epoch = fs * epoch_len;
n_epochs = floor(N / samples_per_epoch);

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
figure('Color','w','Position',[100 60 1500 1300]);  

left = 0.07; width = 0.90; h = 0.085; gap = 0.015; y = 0.92;
ax = gobjects(8,1);

ax(1) = axes('Position',[left y width h]); y=y-h-gap;
plot(t_abs, ecg,'k','LineWidth',0.3)
ylim([0.3*phys_min 0.3*phys_max])
ylabel('ECG')
title('ECG, HRV Features, and MWT Hypnogram')
grid on

ax(2) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, HR_mean,'LineWidth',1.2); ylabel('HR (bpm)'); grid on

ax(3) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, RMSSD,'LineWidth',1.2); ylabel('RMSSD (ms)'); grid on

ax(4) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, SDNN,'LineWidth',1.2); ylabel('SDNN (ms)'); grid on

ax(5) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, HF,'LineWidth',1.2); set(gca,'YScale','log')
ylabel('HF'); grid on

ax(6) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, LFHF,'LineWidth',1.2); ylabel('LF/HF'); grid on

ax(7) = axes('Position',[left y width h]); y=y-h-gap;
stairs(epoch_time, SNR,'LineWidth',1.2); ylabel('SNR (dB)'); grid on

%% ---------------- Hypnogram (trials only, dynamic stages) ----------------
ax(8) = axes('Position',[left 0.06 width 0.18]); hold on

sleep_tbl = sortrows(sleep_tbl,'t_abs');
plot_stage = sleep_tbl.Stage;
plot_stage(plot_stage == "?") = "";   % baseline not plotted here

all_stages = ["AWAKE","STAGE 1","STAGE 2","STAGE 3","REM","UNSURE"];
stage_present = intersect(all_stages, unique(plot_stage,'stable'), 'stable');

stage_map = containers.Map(stage_present, 1:numel(stage_present));

stage_colors = containers.Map( ...
    ["AWAKE","STAGE 1","STAGE 2","STAGE 3","REM","UNSURE"], ...
    { ...
        [0.55 0.55 0.55], ...   % AWAKE
        [0.30 0.75 0.93], ...   % STAGE 1
        [0.00 0.45 0.74], ...   % STAGE 2
        [0.00 0.20 0.50], ...   % STAGE 3
        [0.80 0.40 0.80], ...   % REM
        [0.95 0.70 0.40]  ...   % UNSURE (light orange)
    });

for i = 1:height(sleep_tbl)-1
    st = plot_stage(i);
    if ~isKey(stage_map, st), continue; end
    yv = stage_map(st);
    plot([sleep_tbl.t_abs(i) sleep_tbl.t_abs(i+1)], ...
         [yv yv], 'LineWidth',6,'Color',stage_colors(st));
end

yticks(1:numel(stage_present))
yticklabels(stage_present)
ylim([0.5 numel(stage_present)+0.5])
set(gca,'YDir','reverse')
xlabel('Clock Time')
ylabel('Stage')
grid on
box on

linkaxes(ax,'x')
xlim([t_abs(1) t_abs(end)])
ax(end).XAxis.TickLabelFormat = 'dd-MMM HH:mm';

%% ========================= FIGURE 2: PER-TRIAL HR DIPPING =========================
figure('Color','w','Position',[200 200 1400 420]);
hold on
plot(epoch_time, HR_mean,'k','LineWidth',1.1)

% Map stage to epochs
epoch_stage = strings(n_epochs,1);
for i = 1:n_epochs
    idx = find(sleep_tbl.t_abs <= epoch_time(i),1,'last');
    if ~isempty(idx)
        epoch_stage(i) = sleep_tbl.Stage(idx);
    end
end

% Trial epochs (exclude baseline + unsure)
valid = epoch_stage ~= "" & epoch_stage ~= "?" & epoch_stage ~= "UNSURE";
trial_blocks = find_contiguous_blocks(valid);

yl = ylim;
dip_vals = [];
trial_id = 0;

for t = 1:size(trial_blocks,1)
    idx_trial = trial_blocks(t,1):trial_blocks(t,2);

    % --- Initial contiguous AWAKE block
    is_awake = epoch_stage(idx_trial) == "AWAKE";
    d = diff([false; is_awake; false]);
    s = find(d==1,1,'first');
    e = find(d==-1,1,'first')-1;

    if isempty(s) || (e-s+1) < 5
        continue
    end

    baseline_idx = idx_trial(s:e);
    HR_base = median(HR_mean(baseline_idx),'omitnan');
    HR_trial = median(HR_mean(idx_trial),'omitnan');

    dHR_pct = 100 * (HR_base - HR_trial) / HR_base;

    trial_id = trial_id + 1;
    dip_vals(end+1) = dHR_pct; %#ok<AGROW>

    % Baseline shading
    patch([epoch_time(baseline_idx(1)) epoch_time(baseline_idx(end)) ...
           epoch_time(baseline_idx(end)) epoch_time(baseline_idx(1))], ...
          [yl(1) yl(1) yl(2) yl(2)], ...
          [1.0 0.85 0.85], 'EdgeColor','none','FaceAlpha',0.35);

    % Trial shading
    patch([epoch_time(idx_trial(1)) epoch_time(idx_trial(end)) ...
           epoch_time(idx_trial(end)) epoch_time(idx_trial(1))], ...
          [yl(1) yl(1) yl(2) yl(2)], ...
          [0.85 0.9 1], 'EdgeColor','none','FaceAlpha',0.25);

    % Baseline HR line
    plot([epoch_time(baseline_idx(1)) epoch_time(baseline_idx(end))], ...
         [HR_base HR_base],'--','Color',[0.8 0 0],'LineWidth',1.6)

    % Labels
    text(mean(epoch_time(baseline_idx)), yl(2)-0.6, ...
        'Awake baseline', 'Color',[0.6 0 0], ...
        'FontWeight','bold','HorizontalAlignment','center');

    text(mean(epoch_time(idx_trial)), yl(2)-1.8, ...
        sprintf('T%d (%.1f%%)',trial_id,dHR_pct), ...
        'Color',[0 0.2 0.6],'FontWeight','bold', ...
        'HorizontalAlignment','center');
end

plot(epoch_time, HR_mean,'k','LineWidth',1.1)

mean_dHR = mean(dip_vals,'omitnan');
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
title(sprintf('MWT HR Change (Per-Trial Awake Baseline): %.1f%% (%s)', ...
    mean_dHR, dip_class))
ax = gca; ax.XAxis.TickLabelFormat = 'dd-MMM HH:mm';

hold off
end
