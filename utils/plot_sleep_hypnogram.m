function plot_sleep_hypnogram(sleep_tbl)
% PLOT_SLEEP_HYPNOGRAM
% MWT hypnogram (TRIALS ONLY)
% - UNSURE shown as dashed gray
% - BASELINE ("?") excluded entirely

%% ---------------- Prepare data ----------------
sleep_tbl = sortrows(sleep_tbl,'t_abs');

plot_stage = sleep_tbl.Stage;
plot_stage(plot_stage == "?") = "";   % REMOVE BASELINE FROM THIS FIGURE

t_start = sleep_tbl.t_abs(1);
t_end   = sleep_tbl.t_abs(end);

%% ---------------- Stage definitions ----------------
stage_order = ["AWAKE","STAGE 1","STAGE 2","STAGE 3","REM","UNSURE"];

stage_colors = containers.Map( ...
    stage_order, ...
    { ...
        [0.60 0.60 0.60], ... % AWAKE
        [0.30 0.75 0.93], ... % STAGE 1
        [0.00 0.45 0.74], ... % STAGE 2
        [0.00 0.20 0.50], ... % STAGE 3
        [0.80 0.40 0.80], ... % REM
        [0.95 0.70 0.40]  ... % UNSURE (neutral gray)
    } ...
);

stage_names = stage_order(ismember(stage_order, unique(plot_stage,'stable')));
stage_y = 1:numel(stage_names);
stage_map = containers.Map(stage_names, stage_y);

%% ---------------- Plot ----------------
figure('Color','w','Position',[200 200 1400 300]);
hold on

for i = 1:height(sleep_tbl)-1
    st = plot_stage(i);
    if ~isKey(stage_map, st)
        continue
    end

    lw = 6;
    ls = '-';

    if st == "UNSURE"
        lw = 4;
        ls = '--';   % dashed for uncertainty
    end

    plot([sleep_tbl.t_abs(i) sleep_tbl.t_abs(i+1)], ...
         [stage_map(st) stage_map(st)], ...
         'LineWidth', lw, ...
         'LineStyle', ls, ...
         'Color', stage_colors(st));
end

%% ---------------- Axis formatting ----------------
ylim([0.5 numel(stage_names)+0.5])
yticks(stage_y)
yticklabels(stage_names)
set(gca,'YDir','reverse')

xlim([t_start t_end])
xlabel('Clock Time')
ylabel('Stage')
title('MWT Hypnogram (Trials Only)')
grid on
box on

%% ---------------- Legend ----------------
h = gobjects(numel(stage_names),1);
for i = 1:numel(stage_names)
    ls = '-'; lw = 6;
    if stage_names(i) == "UNSURE"
        ls = '--'; lw = 4;
    end
    h(i) = plot(nan,nan,'LineWidth',lw,'LineStyle',ls, ...
        'Color',stage_colors(stage_names(i)));
end

legend(h, stage_names, ...
    'Orientation','horizontal', ...
    'Location','southoutside');

hold off
end
