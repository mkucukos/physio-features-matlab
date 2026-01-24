function plot_ecg_features_over_time(ecg, fs, epoch_len, phys_min, phys_max, t_abs, sleep_tbl)
% ECG + HRV features + sleep stages (datetime-safe, version-safe)

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
LF     = nan(n_epochs,1);
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
        LF(k)      = feats(6);
        HF(k)      = feats(7);
        LFHF(k)    = feats(8);
        SNR(k)     = feats(9);
    end
end

% mild smoothing
k = 7;
HR_mean = medfilt1(HR_mean,k,'omitnan','truncate');
RMSSD   = medfilt1(RMSSD,k,'omitnan','truncate');
SDNN    = medfilt1(SDNN,k,'omitnan','truncate');
LF      = medfilt1(LF,k,'omitnan','truncate');
HF      = medfilt1(HF,k,'omitnan','truncate');
LFHF    = medfilt1(LFHF,k,'omitnan','truncate');
SNR     = medfilt1(SNR,k,'omitnan','truncate');

%% ---------------- Sleep stage mapping ----------------
stage_order = {'UNSURE','STAGE 3','STAGE 2','STAGE 1','REM','AWAKE'};
stage_map   = containers.Map(stage_order, 0:numel(stage_order)-1);

sleep_tbl = sortrows(sleep_tbl,'t_abs');
sleep_y = nan(height(sleep_tbl),1);
for i = 1:height(sleep_tbl)
    sleep_y(i) = stage_map(sleep_tbl.Stage{i});
end

%% ---------------- Figure & layout ----------------
figure('Color','w','Position',[100 80 1500 1100]);

% 10 rows → last plot spans 2 rows
t = tiledlayout(10,1,'TileSpacing','compact','Padding','compact');

ax = gobjects(9,1);

%% ---------------- Plots ----------------
ax(1) = nexttile;
plot(t_abs, ecg,'k','LineWidth',0.3);
ylabel('ECG');
ylim([0.3*phys_min 0.3*phys_max]);
title('ECG, HRV Features, and Sleep Stages');
grid on

ax(2) = nexttile;
stairs(epoch_time, HR_mean,'LineWidth',1.2);
ylabel('HR (bpm)'); grid on

ax(3) = nexttile;
stairs(epoch_time, RMSSD,'LineWidth',1.2);
ylabel('RMSSD'); grid on

ax(4) = nexttile;
stairs(epoch_time, SDNN,'LineWidth',1.2);
ylabel('SDNN'); grid on

ax(5) = nexttile;
stairs(epoch_time, LF,'LineWidth',1.2);
set(gca,'YScale','log');
ylabel('LF'); grid on

ax(6) = nexttile;
stairs(epoch_time, HF,'LineWidth',1.2);
set(gca,'YScale','log');
ylabel('HF'); grid on

ax(7) = nexttile;
stairs(epoch_time, LFHF,'LineWidth',1.2);
ylabel('LF/HF'); grid on

ax(8) = nexttile;
stairs(epoch_time, SNR,'LineWidth',1.2);
ylabel('SNR (dB)');
ylim([0 max(SNR,[],'omitnan')]);
grid on

%% ---------------- Sleep stages (TALL subplot) ----------------
%% ---------------- Sleep stages (STEP / LINE PLOT) ----------------
ax(9) = nexttile([2 1]);   % tall subplot
hold on

% Define stage order (bottom → top)
stage_order = {'UNSURE','STAGE 3','STAGE 2','STAGE 1','REM','AWAKE'};
stage_map   = containers.Map(stage_order, 0:numel(stage_order)-1);

% Sort by time
sleep_tbl = sortrows(sleep_tbl,'t_abs');

% Convert stages to numeric
stage_numeric = nan(height(sleep_tbl),1);
for i = 1:height(sleep_tbl)
    stage_numeric(i) = stage_map(sleep_tbl.Stage{i});
end

% Step plot (hypnogram)
stairs( ...
    sleep_tbl.t_abs, ...
    stage_numeric, ...
    'LineWidth', 2);

% Formatting
yticks(0:numel(stage_order)-1)
yticklabels(stage_order)
ylim([-0.5 numel(stage_order)-0.5])
ylabel('Sleep Stage')
grid on

% Optional: reverse y-axis (AWAKE on top)
set(gca,'YDir','reverse')

% Legend (compact)
legend('Sleep Stage','Location','southoutside','Box','off','FontSize',9)
