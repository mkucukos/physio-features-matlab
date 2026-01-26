function plot_sleep_hypnogram(sleep_tbl)
% PLOT_SLEEP_HYPNOGRAM
% Colored hypnogram with dynamic stages (MWT-safe)

%% ---------------- Prepare data ----------------
sleep_tbl = sortrows(sleep_tbl,'t_abs');

raw_stage = sleep_tbl.Stage;
disp_stage = raw_stage;
disp_stage(raw_stage == "?") = "BASELINE";

t_start = sleep_tbl.t_abs(1);
t_end   = sleep_tbl.t_abs(end);

%% ---------------- Stage definitions ----------------
all_stages = ["BASELINE","AWAKE","STAGE 1","STAGE 2","STAGE 3","REM","UNSURE"];

stage_colors = containers.Map( ...
    all_stages, ...
    { ...
        [0.95 0.92 0.85], ... % BASELINE
        [0.60 0.60 0.60], ... % AWAKE
        [0.30 0.75 0.93], ... % STAGE 1
        [0.00 0.45 0.74], ... % STAGE 2
        [0.00 0.20 0.50], ... % STAGE 3
        [0.80 0.40 0.80], ... % REM
        [0.85 0.85 0.85]  ... % UNSURE
    } ...
);

% Keep only stages that exist
stage_names = all_stages(ismember(all_stages, unique(disp_stage)));
stage_y = 1:numel(stage_names);
stage_map = containers.Map(stage_names, stage_y);

%% ---------------- Plot ----------------
figure('Color','w','Position',[200 200 1400 260]);
hold on

for i = 1:height(sleep_tbl)-1
    st = disp_stage(i);

    if ~isKey(stage_map, st)
        continue
    end

    y  = stage_map(st);
    t1 = sleep_tbl.t_abs(i);
    t2 = sleep_tbl.t_abs(i+1);

    plot([t1 t2], [y y], ...
        'LineWidth',6, ...
        'Color',stage_colors(st));
end

%% ---------------- Axis formatting ----------------
ylim([0.5 numel(stage_names)+0.5])
yticks(stage_y)
yticklabels(stage_names)
set(gca,'YDir','reverse')

xlim([t_start t_end])
xlabel('Clock Time')
ylabel('Stage')
title('MWT Hypnogram (Baseline vs Trials)')
grid on
box on

%% ---------------- Legend (only existing stages) ----------------
h = gobjects(numel(stage_names),1);
for i = 1:numel(stage_names)
    h(i) = plot(nan,nan,'LineWidth',6, ...
        'Color',stage_colors(stage_names(i)));
end

legend(h, stage_names, ...
    'Orientation','horizontal', ...
    'Location','southoutside');

hold off
end
