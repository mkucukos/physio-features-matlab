function sleep_tbl = load_sleep_stages(txt_path)
% LOAD_SLEEP_STAGES
% Load PSG sleep-stage annotations from a specific TXT file.
%
% Input:
%   txt_path  - full path to annotation TXT
%
% Output:
%   sleep_tbl - table with:
%               t_abs (datetime), Stage, Event

%% ---------------- Extract date from filename ----------------
[~, fname, ~] = fileparts(txt_path);

% Expect pattern like 16DEC2022
date_token = regexp(fname, '\d{2}[A-Z]{3}\d{4}', 'match', 'once');
assert(~isempty(date_token), ...
    'Could not extract recording date from filename');

recording_date = datetime(date_token, 'InputFormat','ddMMMyyyy');

%% ---------------- Read annotation file ----------------
opts = delimitedTextImportOptions("Delimiter", ",");

opts.VariableNames = ["ClockTime","Epoch","Stage","Event", ...
                      "Duration","SpO2","Severity","Position"];

opts.VariableTypes = ["string","double","string","string", ...
                      "string","string","string","string"];

sleep_tbl = readtable(txt_path, opts);

%% ---------------- Clock time → absolute datetime ----------------
% Parse clock time only
t_clock = datetime(sleep_tbl.ClockTime, 'InputFormat','H:mm:ss');

% Combine date + time (ROBUST METHOD)
t_abs = recording_date + timeofday(t_clock);

% Handle midnight rollover
for i = 2:numel(t_abs)
    if t_abs(i) < t_abs(i-1)
        t_abs(i:end) = t_abs(i:end) + days(1);
        break
    end
end

sleep_tbl.t_abs = t_abs;

%% ---------------- Keep only sleep stages ----------------
valid_stages = ["AWAKE","STAGE 1","STAGE 2","STAGE 3","REM","UNSURE"];

sleep_tbl = sleep_tbl( ...
    ismember(sleep_tbl.Stage, valid_stages), ...
    {'t_abs','Stage','Event'} ...
);

%% ---------------- Report ----------------
fprintf("Loaded sleep stages from:\n  %s\n", txt_path);
fprintf("Recording date inferred: %s\n", datestr(recording_date));

end
