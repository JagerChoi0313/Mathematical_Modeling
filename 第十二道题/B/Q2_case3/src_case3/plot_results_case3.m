function plot_results_case3(result, data, projectRoot)
%PLOT_RESULTS_CASE3 绘制第三关最不利天气情形下的策略执行结果

figureDir = fullfile(projectRoot, 'figures', 'case3');
if ~isfolder(figureDir)
    mkdir(figureDir);
end

fontName = 'Microsoft YaHei';
mapColor = [0.76, 0.81, 0.86];
routeColor = [0.08, 0.32, 0.52];
startColor = [0.22, 0.55, 0.36];
endColor = [0.72, 0.22, 0.18];
mineColor = [0.78, 0.48, 0.12];

x = data.plotX;
y = data.plotY;
daily = result.worstDaily;

%% 路线图
fig = figure('Color', 'w', 'Position', [80, 50, 1200, 820]);
ax = axes(fig);
hold(ax, 'on');

for k = 1:size(data.edges, 1)
    i = data.edges(k, 1);
    j = data.edges(k, 2);
    plot(ax, [x(i), x(j)], [y(i), y(j)], '-', ...
        'Color', mapColor, 'LineWidth', 1.1);
end

scatter(ax, x, y, 48, 'o', 'MarkerFaceColor', 'w', ...
    'MarkerEdgeColor', [0.42, 0.50, 0.58], 'LineWidth', 1.0);

movementRows = daily.Day > 0;
travel = daily(movementRows, :);

for r = 1:height(travel)
    i = travel.StartRegion(r);
    j = travel.EndRegion(r);

    if i ~= j
        dx = x(j) - x(i);
        dy = y(j) - y(i);
        quiver(ax, x(i) + 0.08*dx, y(i) + 0.08*dy, ...
            0.84*dx, 0.84*dy, 0, 'Color', routeColor, ...
            'LineWidth', 3.0, 'MaxHeadSize', 0.22);
    end

    midX = (x(i) + x(j)) / 2;
    midY = (y(i) + y(j)) / 2;
    text(ax, midX, midY + 0.12, sprintf('第%d天', travel.Day(r)), ...
        'FontName', fontName, 'FontSize', 9, ...
        'Color', [0.20, 0.25, 0.30], ...
        'HorizontalAlignment', 'center', 'BackgroundColor', 'w');
end

routeNodes = unique([travel.StartRegion; travel.EndRegion], 'stable');
scatter(ax, x(routeNodes), y(routeNodes), 72, 'o', ...
    'MarkerFaceColor', routeColor, 'MarkerEdgeColor', 'w', 'LineWidth', 1.0);

hStart = scatter(ax, x(data.startRegion), y(data.startRegion), 150, 's', ...
    'MarkerFaceColor', startColor, 'MarkerEdgeColor', [0.10, 0.34, 0.19], ...
    'LineWidth', 1.4);
hMine = scatter(ax, x(data.mineRegions), y(data.mineRegions), 150, '^', ...
    'MarkerFaceColor', mineColor, 'MarkerEdgeColor', [0.52, 0.29, 0.04], ...
    'LineWidth', 1.4);
hEnd = scatter(ax, x(data.endRegion), y(data.endRegion), 160, 'd', ...
    'MarkerFaceColor', endColor, 'MarkerEdgeColor', [0.46, 0.10, 0.08], ...
    'LineWidth', 1.4);
hRoute = plot(ax, nan, nan, '-', 'Color', routeColor, 'LineWidth', 3.0);

for i = 1:data.numRegions
    if i == data.startRegion
        label = sprintf('起点  %d', i);
    elseif i == data.endRegion
        label = sprintf('终点  %d', i);
    elseif ismember(i, data.mineRegions)
        label = sprintf('%d  矿山', i);
    else
        label = num2str(i);
    end

    text(ax, x(i) + 0.08, y(i) + 0.06, label, ...
        'FontName', fontName, 'FontSize', 9.5, ...
        'Color', [0.18, 0.22, 0.26]);
end

legend(ax, [hRoute, hStart, hMine, hEnd], ...
    {'策略执行路线','起点','矿山','终点'}, ...
    'FontName', fontName, 'Location', 'best');

title(ax, { ...
    '第三关最不利天气情形下的策略执行路线', ...
    ['天气序列：', char(result.worstWeatherText)]}, ...
    'FontName', fontName, 'FontSize', 14, 'FontWeight', 'bold');

axis(ax, 'equal');
axis(ax, 'off');
xlim(ax, [min(x)-0.5, max(x)+1.0]);
ylim(ax, [min(y)-0.5, max(y)+0.7]);
hold(ax, 'off');

exportgraphics(fig, fullfile(figureDir, 'case3_worst_route.png'), ...
    'Resolution', 350);
close(fig);

%% 水和食物变化
fig = figure('Color', 'w', 'Position', [120, 100, 1050, 620]);
ax = axes(fig);
hold(ax, 'on');

plot(ax, daily.Day, daily.WaterLeft, '-o', ...
    'LineWidth', 2.0, 'MarkerSize', 5.5);
plot(ax, daily.Day, daily.FoodLeft, '-s', ...
    'LineWidth', 2.0, 'MarkerSize', 5.2);

xlabel(ax, '日期', 'FontName', fontName, 'FontSize', 11);
ylabel(ax, '剩余数量（箱）', 'FontName', fontName, 'FontSize', 11);
title(ax, '第三关最不利天气情形下水和食物剩余量变化', ...
    'FontName', fontName, 'FontSize', 14, 'FontWeight', 'bold');
legend(ax, {'水','食物'}, 'FontName', fontName, 'Location', 'best');
grid(ax, 'on');
box(ax, 'off');
ax.FontName = fontName;
ax.FontSize = 10;
xticks(ax, unique(daily.Day));
hold(ax, 'off');

exportgraphics(fig, fullfile(figureDir, 'case3_worst_resource_change.png'), ...
    'Resolution', 350);
close(fig);

%% 资金变化
fig = figure('Color', 'w', 'Position', [120, 100, 1050, 620]);
ax = axes(fig);
hold(ax, 'on');

plot(ax, daily.Day, daily.CashLeft, '-o', ...
    'LineWidth', 2.0, 'MarkerSize', 5.5);

xlabel(ax, '日期', 'FontName', fontName, 'FontSize', 11);
ylabel(ax, '剩余资金（元）', 'FontName', fontName, 'FontSize', 11);
title(ax, '第三关最不利天气情形下资金变化', ...
    'FontName', fontName, 'FontSize', 14, 'FontWeight', 'bold');
grid(ax, 'on');
box(ax, 'off');
ax.FontName = fontName;
ax.FontSize = 10;
xticks(ax, unique(daily.Day));
hold(ax, 'off');

exportgraphics(fig, fullfile(figureDir, 'case3_worst_money_change.png'), ...
    'Resolution', 350);
close(fig);
end
