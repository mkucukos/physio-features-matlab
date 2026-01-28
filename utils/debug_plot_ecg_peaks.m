function debug_plot_ecg_peaks(ecg, fs, epoch_len, epoch_idx)
% DEBUG_PLOT_ECG_PEAKS
% Detects R-peaks using QRS-energy signal and plots them on RAW ECG

samples_per_epoch = fs * epoch_len;

s = (epoch_idx-1)*samples_per_epoch + 1;
e = min(epoch_idx*samples_per_epoch, numel(ecg));

seg = ecg(s:e);                          % RAW ECG
t = (0:numel(seg)-1)/fs;

% --- Run detection pipeline (QRS energy based) ---
[~, locs, ecg_detect] = get_ecg_features(seg, fs);

figure('Color','w','Position',[200 200 1400 520]);

%% -------- RAW ECG + detected R-peaks --------
subplot(2,1,1)
plot(t, seg, 'k', 'LineWidth', 1); hold on

if ~isempty(locs)
    % Peaks plotted at TRUE raw ECG amplitude
    plot(t(locs), seg(locs), 'ro', ...
        'MarkerSize', 6, 'LineWidth', 1.5)
end
ymin = min(seg) - 100;
ymax = max(seg) + 100;
ylim([ymin ymax])
grid on
title(sprintf('RAW ECG + detected R-peaks — Epoch %d', epoch_idx))
ylabel('Amplitude (raw units)')

%% -------- QRS energy detection signal --------
subplot(2,1,2)
plot(t, ecg_detect, 'b', 'LineWidth', 1); hold on

if ~isempty(locs)
    plot(t(locs), ecg_detect(locs), 'ro', ...
        'MarkerSize', 6, 'LineWidth', 1.5)
end

% Energy signal y-limits with negative buffer
ymin = min(ecg_detect) - 200;
ymax = max(ecg_detect) + 100;
ylim([ymin ymax])

grid on
title(sprintf('QRS Energy Detection Signal | n = %d peaks', numel(locs)))
xlabel('Time (s)')
ylabel('Energy')

linkaxes(findall(gcf,'Type','axes'),'x')
end
