function [feats, locs, ecg_clean] = get_ecg_features(ecg, fs)
% GET_ECG_FEATURES  Toolbox-free ECG + HRV feature extraction
%
% Output:
% [HR_mean, HR_max, HR_min, HRV_RMSSD, SDNN, LF, HF, LFHF, SNR_dB]

%% ---------------- Safety ----------------
ecg = double(ecg(:));
N = numel(ecg);
if N < fs
    feats = nan(1,9);
    locs  = [];
    ecg_clean = nan(size(ecg));
    return
end

t = (0:N-1)' / fs;

%% ---------------- Bandpass 0.5–30 Hz ----------------
[b,a] = butter(4, [0.5 30] / (fs/2), 'bandpass');
ecg_filt = filtfilt(b, a, ecg);

%% ---------------- QRS-enhanced detection signal ----------------
% 1) Differentiate → emphasize slope (QRS)
ecg_clean = diff(ecg_filt);
ecg_clean(end+1) = ecg_clean(end);   % preserve length

% 2) Square → emphasize energy
ecg_clean = ecg_clean .^ 2;

% 3) Short integration window → QRS-scale only
window_int = round(0.08 * fs);        % ~80 ms (QRS duration)
ecg_clean = smoothdata(ecg_clean, 'movmean', window_int);

%% ---------------- Conservative R-peak detection ----------------
minPeakDist = round(0.3 * fs);   % ~200 bpm max
prom = 1.5 * std(ecg_clean, 'omitnan');

[~, locs] = findpeaks(ecg_clean, ...
    'MinPeakDistance', minPeakDist, ...
    'MinPeakProminence', prom);

if numel(locs) < 3
    feats = nan(1,9);
    locs  = [];
    return
end

%% ---------------- RR intervals ----------------
rr_times = t(locs);
rr = diff(rr_times);                 % seconds
rr(rr < 0.3 | rr > 2.0) = NaN;       % physiological bounds

%% ---------------- HR ----------------
hr = 60 ./ rr;

% Remove extreme beat-level outliers
z = abs(zscore_safe(hr));
hr(z > 10) = NaN;

hr_mean = mean(hr, 'omitnan');
hr_max  = max(hr, [], 'omitnan');
hr_min  = min(hr, [], 'omitnan');

%% ---------------- HRV (time domain) ----------------
rr_ms = rr * 1000;

% RMSSD
drr = diff(rr_ms);
z = abs(zscore_safe(drr));
drr(z > 100) = NaN;
hrv_rmssd = sqrt(mean(drr.^2, 'omitnan'));

% SDNN
sdnn = std(rr_ms, 'omitnan');

%% ---------------- Epoch-level physiological sanity check ----------------
% If HR or HRV is non-physiological → invalidate entire epoch

HR_MIN = 20;    % bpm
HR_MAX = 200;   % bpm

RMSSD_MIN = 2;    % ms
RMSSD_MAX = 300;  % ms

SDNN_MIN  = 5;    % ms
SDNN_MAX  = 300;  % ms

invalid_epoch = false;

% HR sanity
if ~isfinite(hr_mean) || hr_mean < HR_MIN || hr_mean > HR_MAX
    invalid_epoch = true;
end

% HRV sanity
if ~isfinite(hrv_rmssd) || hrv_rmssd < RMSSD_MIN || hrv_rmssd > RMSSD_MAX
    invalid_epoch = true;
end

if ~isfinite(sdnn) || sdnn < SDNN_MIN || sdnn > SDNN_MAX
    invalid_epoch = true;
end

if invalid_epoch
    feats = nan(1,9);
    locs  = [];
    return
end

%% ---------------- HRV (frequency domain) ----------------
rr_valid = rr_ms(~isnan(rr_ms));
t_rr = rr_times(2:end);
t_rr = t_rr(~isnan(rr_ms));

if numel(rr_valid) < 5
    lf = NaN; hf = NaN; lfhf = NaN;
else
    fs_rr = 4;  % Hz
    t_interp = t_rr(1):1/fs_rr:t_rr(end);
    rr_interp = interp1(t_rr, rr_valid, t_interp, 'pchip');

    rr_interp = detrend(rr_interp);

    [pxx, f] = pwelch(rr_interp, [], [], [], fs_rr);

    lf_band = (f >= 0.04 & f < 0.15);
    hf_band = (f >= 0.15 & f < 0.40);

    lf = trapz(f(lf_band), pxx(lf_band));
    hf = trapz(f(hf_band), pxx(hf_band));

    if hf > 0
        lfhf = lf / hf;
    else
        lfhf = NaN;
    end
end

%% ---------------- SNR ----------------
ecg_rr = [];
ecg_rr_clean = [];

half_win = round(0.1 * fs);   % ±100 ms

for i = 1:numel(locs)
    c = locs(i);
    s = max(1, c - half_win);
    e = min(N, c + half_win);

    ecg_rr        = [ecg_rr;        ecg(s:e)];
    ecg_rr_clean = [ecg_rr_clean; ecg_clean(s:e)];
end

if numel(ecg_rr) < fs * 0.5
    snr_db = NaN;
else
    signal_power = var(ecg_rr, 'omitnan');
    noise_power  = var(ecg_rr - ecg_rr_clean, 'omitnan');

    if noise_power <= 0
        snr_db = NaN;
    else
        snr_db = 10 * log10(signal_power / noise_power);
    end
end

%% ---------------- Output ----------------
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

%% =====================================================================
function z = zscore_safe(x)
% Toolbox-free z-score with NaN safety
x = x(:);
mu = mean(x, 'omitnan');
sd = std(x, 'omitnan');

if ~isfinite(sd) || sd == 0
    z = zeros(size(x));
else
    z = (x - mu) ./ sd;
end
end
