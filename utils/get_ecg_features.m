function feats = get_ecg_features(ecg, fs)
% GET_ECG_FEATURES  Python-aligned ECG + HRV feature extraction
%
% Output:
% [HR_mean, HR_max, HR_min, HRV_RMSSD, SDNN, LF, HF, LFHF, SNR_dB]

% ---------------- Safety ----------------
ecg = double(ecg(:));
N = numel(ecg);
if N < fs
    error("Epoch too short for ECG feature extraction");
end

t = (0:N-1)' / fs;

% ---------------- Bandpass 0.25–25 Hz ----------------
[b,a] = butter(4, [0.25 25] / (fs/2), 'bandpass');
ecg_filt = filtfilt(b, a, ecg);

% ---------------- NeuroKit-like cleaning ----------------
ecg_clean = detrend(ecg_filt);
ecg_clean = smoothdata(ecg_clean, 'movmedian', round(0.2 * fs));
ecg_clean = smoothdata(ecg_clean, 'movmean', round(0.05 * fs));

% ---------------- Conservative R-peak detection ----------------
minPeakDist = round(0.3 * fs);   % ~200 bpm max
prom = 1.5 * std(ecg_clean);

[~, locs] = findpeaks(ecg_clean, ...
    'MinPeakDistance', minPeakDist, ...
    'MinPeakProminence', prom);

if numel(locs) < 3
    error("No reliable R-peaks detected");
end

% ---------------- RR intervals ----------------
rr_times = t(locs);
rr = diff(rr_times);              % seconds
rr(rr < 0.3 | rr > 2.0) = NaN;    % physiological bounds

% ---------------- HR ----------------
hr = 60 ./ rr;
z = abs(zscore(hr, 0, 'omitnan'));
hr(z > 5) = NaN;

hr_mean = mean(hr, 'omitnan');
hr_max  = max(hr, [], 'omitnan');
hr_min  = min(hr, [], 'omitnan');

% ---------------- HRV (time domain) ----------------
rr_ms = rr * 1000;

% RMSSD
drr = diff(rr_ms);
z = abs(zscore(drr, 0, 'omitnan'));
drr(z > 100) = NaN;
hrv_rmssd = sqrt(mean(drr.^2, 'omitnan'));

% SDNN
sdnn = std(rr_ms, 'omitnan');

% ---------------- HRV (frequency domain) ----------------
% Interpolate RR to evenly sampled signal (4 Hz standard)
rr_valid = rr_ms(~isnan(rr_ms));
t_rr = rr_times(2:end);
t_rr = t_rr(~isnan(rr_ms));

fs_rr = 4;  % Hz
t_interp = t_rr(1):1/fs_rr:t_rr(end);
rr_interp = interp1(t_rr, rr_valid, t_interp, 'pchip');

rr_interp = detrend(rr_interp);

% Welch PSD
[pxx, f] = pwelch(rr_interp, [], [], [], fs_rr);

% Frequency bands
lf_band = (f >= 0.04 & f < 0.15);
hf_band = (f >= 0.15 & f < 0.40);

lf = trapz(f(lf_band), pxx(lf_band));
hf = trapz(f(hf_band), pxx(hf_band));
lfhf = lf / hf;

% ---------------- SNR (RR-centered, Python-equivalent) ----------------
ecg_rr = [];
ecg_rr_clean = [];

half_win = round(0.1 * fs);   % 0.1 seconds before/after R-peak

for i = 1:numel(locs)
    idx_center = locs(i);

    s = max(1, idx_center - half_win);
    e = min(numel(ecg), idx_center + half_win);

    ecg_rr = [ecg_rr; ecg(s:e)];
    ecg_rr_clean = [ecg_rr_clean; ecg_clean(s:e)];
end

if numel(ecg_rr) < fs * 0.5
    snr_db = NaN;   % not enough data
else
    signal_power = var(ecg_rr, 'omitnan');
    noise_power  = var(ecg_rr - ecg_rr_clean, 'omitnan');

    if noise_power <= 0
        snr_db = NaN;
    else
        snr_db = 10 * log10(signal_power / noise_power);
    end
end

% ---------------- Output ----------------
feats = [ ...
    hr_mean, ...
    hr_max, ...
    hr_min, ...
    hrv_rmssd, ...
    sdnn, ...
    lf, ...
    hf, ...
    lfhf, ...
    snr_db ...
];

end
