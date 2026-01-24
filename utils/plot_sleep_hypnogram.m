function plot_sleep_hypnogram(sleep_tbl)
% PLOT_SLEEP_HYPNOGRAM
% Colored hypnogram with proper time bounds (no overrun)

%% ---------------- Define stages & colors ----------------
stage_names = ["AWAKE","STAGE 1","STAGE 2","STAGE 3","REM","UNSURE"];
stage_y     = 1:numel(stage_names);

stage_map = containers.Map(stage_names, stage_y);

% Professional, readable colors
stage_colors = containers.Map( ...
    stage_names, ...
    { ...
        [0.60 0.60 0.60], ... % AWAKE (gray)
        [0.30 0.75 0.93], ... % STAGE 1 (light blue)
        [0.00 0.45 0.74], ... % STAGE 2 (blue)
        [0.00 0.20 0.50], ... % STAGE 3 (dark blue)
        [0.80 0.40 0.80], ... % REM (purple)
        [0.85 0.85 0.85]  ... % UNSURE
    } ...
);

%% ---------------- Prepare time bounds ----------------
t_start = sleep_tbl.t_abs(1);
t_end   = sleep_tbl.t_abs(end);

figure('Color','w','Position',[200 200 1400 260]);
hold on

%% ---------------- Draw hypnogram segments ----------------
for i = 1:height(sleep_tbl)-1
    stage = sleep_tbl.Stage(i);

    if ~isKey(stage_map, stage)
        continue
    end

    y = stage_map(stage);
    t1 = sleep_tbl.t_abs(i);
    t2 = sleep_tbl.t_abs(i+1);

    plot([t1 t2], [y y], ...
        'LineWidth', 6, ...
        'Color', stage_colors(stage));
end

%% ---------------- Axis formatting ----------------
ylim([0.5 numel(stage_names)+0.5])
yticks(stage_y)
yticklabels(stage_names)

xlim([t_start t_end])

xlabel('Clock Time')
ylabel('Sleep Stage')
title('Sleep Hypnogram')
grid on
box on

%% ---------------- Legend ----------------
h = gobjects(numel(stage_names),1);
for i = 1:numel(stage_names)
    h(i) = plot(nan,nan,'LineWidth',6, ...
        'Color', stage_colors(stage_names(i)));
end

legend(h, stage_names, ...
    'Orientation','horizontal', ...
    'Location','southoutside');

hold off
end
