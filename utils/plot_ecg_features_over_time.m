function plot_ecg_features_over_time(ecg, fs, epoch_len, phys_min, phys_max)
% PLOT_ECG_FEATURES_OVER_TIME
% Visualize raw ECG and per-epoch ECG features
%
% Subplots:
%   1) Raw ECG
%   2) HR mean
%   3) HRV (RMSSD)
%   4) SDNN
%   5) LF/HF
%   6) SNR (dB)

ecg = double(ecg(:));
N = numel(ecg);

samples_per_epoch = fs * epoch_len;
n_epochs = floor(N / samples_per_epoch);

t = (0:N-1) / fs;
epoch_time = ((0:n_epochs-1) + 0.5) * epoch_len;

% ---------------- Preallocate feature arrays ----------------
HR_mean    = nan(n_epochs,1);
HRV_RMSSD = nan(n_epochs,1);
SDNN       = nan(n_epochs,1);
LF         = nan(n_epochs,1);
HF         = nan(n_epochs,1);
LFHF       = nan(n_epochs,1);
SNR        = nan(n_epochs,1);

% ---------------- Epoch loop ----------------
for k = 1:n_epochs
    s = (k-1)*samples_per_epoch + 1;
    e = k*samples_per_epoch;
    epoch = ecg(s:e);

    try
        feats = get_ecg_features(epoch, fs);
        HR_mean(k)    = feats(1);
        HRV_RMSSD(k)  = feats(4);
        SDNN(k)       = feats(5);
        LF(k)         = feats(6);
        HF(k)         = feats(7);
        LFHF(k)       = feats(8);
        SNR(k)        = feats(9);
    catch
        % leave NaNs
    end
end

% ---------------- Plot ----------------
figure('Color','w','Position',[100 100 1400 1100]);

ax(1) = subplot(8,1,1);
plot(t, ecg, 'k', 'LineWidth', 0.4);
ylabel('ECG');
ylim([0.3 * phys_min, 0.3 * phys_max]);
title('ECG and Derived Features Over Time');
grid on

ax(2) = subplot(8,1,2);
stairs(epoch_time, HR_mean, 'LineWidth', 1.5);
ylabel('HR (bpm)');
grid on

ax(3) = subplot(8,1,3);
stairs(epoch_time, HRV_RMSSD, 'LineWidth', 1.5);
ylabel('RMSSD (ms)');
grid on

ax(4) = subplot(8,1,4);
stairs(epoch_time, SDNN, 'LineWidth', 1.5);
ylabel('SDNN (ms)');
grid on

ax(5) = subplot(8,1,5);
stairs(epoch_time, LF, 'LineWidth', 1.5);
ylabel('LF Power');
grid on

ax(6) = subplot(8,1,6);
stairs(epoch_time, HF, 'LineWidth', 1.5);
ylabel('HF Power');
grid on

ax(7) = subplot(8,1,7);
stairs(epoch_time, LFHF, 'LineWidth', 1.5);
ylabel('LF/HF');
grid on

ax(8) = subplot(8,1,8);
stairs(epoch_time, SNR, 'LineWidth', 1.5);
ylabel('SNR (dB)');
xlabel('Time (s)');
ylim([0 max(SNR, [], 'omitnan')]);
grid on

linkaxes(ax, 'x');
xlim([0 t(end)]);

end
