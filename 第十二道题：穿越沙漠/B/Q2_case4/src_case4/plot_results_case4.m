function plot_results_case4(result, data, projectRoot)
%PLOT_RESULTS_CASE4 绘制第四关最不利保证情形的路线、资源和现金变化

figureDir = fullfile(projectRoot, 'figures', 'case4');

if ~isfolder(figureDir)
    mkdir(figureDir);
end

fontName = 'Microsoft YaHei';

mapColor = [0.76, 0.81, 0.86];
routeColor = [0.08, 0.32, 0.52];
startColor = [0.22, 0.55, 0.36];
endColor = [0.72, 0.22, 0.18];
mineColor = [0.78, 0.48, 0.12];
villageColor = [0.42, 0.32, 0.58];
waterColor = [0.10, 0.42, 0.68];
foodColor = [0.80, 0.38, 0.12];
moneyColor = [0.16, 0.48, 0.36];

x = data.plotX;
y = data.plotY;
daily = result.worstDaily;
travel = daily(daily.Day > 0, :);

if isempty(travel)
    return;
end

%% 路线图
fig = figure('Color', 'w', 'Position', [70, 40, 1250, 900]);
ax = axes(fig);
hold(ax, 'on');

for k = 1:size(data.edges, 1)
    i = data.edges(k, 1);
    j = data.edges(k, 2);

    plot(ax, [x(i), x(j)], [y(i), y(j)], '-', ...
        'Color', mapColor, 'LineWidth', 1.05);
end

scatter(ax, x, y, 42, 'o', ...
    'MarkerFaceColor', 'w', ...
    'MarkerEdgeColor', [0.42, 0.50, 0.58], ...
    'LineWidth', 0.95);

for r = 1:height(travel)
    i = travel.StartRegion(r);
    j = travel.EndRegion(r);

    if i ~= j
        dx = x(j) - x(i);
        dy = y(j) - y(i);

        quiver(ax, ...
            x(i) + 0.10*dx, ...
            y(i) + 0.10*dy, ...
            0.80*dx, ...
            0.80*dy, ...
            0, ...
            'Color', routeColor, ...
            'LineWidth', 3.0, ...
            'MaxHeadSize', 0.18);
    end
end

routeNodes = unique([travel.StartRegion; travel.EndRegion], 'stable');
ordinaryRoute = routeNodes(~ismember(routeNodes, ...
    [data.startRegion, data.endRegion, data.mineRegions, data.villageRegions]));

if ~isempty(ordinaryRoute)
    scatter(ax, x(ordinaryRoute), y(ordinaryRoute), 68, 'o', ...
        'MarkerFaceColor', routeColor, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 1.0);
end

hStart = scatter(ax, x(data.startRegion), y(data.startRegion), 150, 's', ...
    'MarkerFaceColor', startColor, 'MarkerEdgeColor', [0.10,0.34,0.19], ...
    'LineWidth', 1.4);

hMine = scatter(ax, x(data.mineRegions), y(data.mineRegions), 150, '^', ...
    'MarkerFaceColor', mineColor, 'MarkerEdgeColor', [0.52,0.29,0.04], ...
    'LineWidth', 1.4);

hVillage = scatter(ax, x(data.villageRegions), y(data.villageRegions), 150, 'p', ...
    'MarkerFaceColor', villageColor, 'MarkerEdgeColor', [0.26,0.17,0.38], ...
    'LineWidth', 1.4);

hEnd = scatter(ax, x(data.endRegion), y(data.endRegion), 160, 'd', ...
    'MarkerFaceColor', endColor, 'MarkerEdgeColor', [0.46,0.10,0.08], ...
    'LineWidth', 1.4);

hRoute = plot(ax, nan, nan, '-', 'Color', routeColor, 'LineWidth', 3.0);

for i = 1:data.numRegions
    if i == data.startRegion
        label = sprintf('起点  %d', i);
        labelColor = startColor;
    elseif i == data.endRegion
        label = sprintf('终点  %d', i);
        labelColor = endColor;
    elseif i == data.mineRegions
        label = sprintf('%d  矿山', i);
        labelColor = mineColor;
    elseif i == data.villageRegions
        label = sprintf('%d  村庄', i);
        labelColor = villageColor;
    else
        label = num2str(i);
        labelColor = [0.24,0.28,0.32];
    end

    text(ax, x(i)+0.06, y(i)+0.06, label, ...
        'FontName', fontName, 'FontSize', 9, 'Color', labelColor);
end

% 在矿山旁标出最不利情形实际挖矿天数
mineRows = travel.Mine == true;
if any(mineRows)
    text(ax, x(data.mineRegions)+0.16, y(data.mineRegions)-0.20, ...
        sprintf('挖矿 %d 天', sum(mineRows)), ...
        'FontName', fontName, 'FontSize', 9.5, ...
        'Color', mineColor, 'FontWeight', 'bold', ...
        'BackgroundColor', 'w', 'Margin', 1);
end

legend(ax, [hRoute,hStart,hVillage,hMine,hEnd], ...
    {'策略执行路线','起点','村庄','矿山','终点'}, ...
    'FontName', fontName, 'FontSize', 9, 'Location', 'best');

title(ax, ...
    { ...
    '第四关保证型策略执行路线', ...
    sprintf('沙暴上限=%d天；最不利情形沙暴日：%s', ...
    data.maxStormDays, char(result.worstStormDaysText)) ...
    }, ...
    'FontName', fontName, 'FontSize', 14, 'FontWeight', 'bold');

axis(ax, 'equal');
axis(ax, 'off');
xlim(ax, [0.45, 5.8]);
ylim(ax, [0.45, 5.65]);
hold(ax, 'off');

exportgraphics(fig, ...
    fullfile(figureDir, 'case4_worst_route.png'), ...
    'Resolution', 400);
close(fig);


%% 水和食物变化
fig = figure('Color', 'w', 'Position', [120, 100, 1100, 650]);
ax = axes(fig);
hold(ax, 'on');

plot(ax, daily.Day, daily.WaterLeft, '-o', ...
    'Color', waterColor, 'LineWidth', 2.1, ...
    'MarkerSize', 5.7, 'MarkerFaceColor', 'w');

plot(ax, daily.Day, daily.FoodLeft, '--s', ...
    'Color', foodColor, 'LineWidth', 1.8, ...
    'MarkerSize', 5.2, 'MarkerFaceColor', 'w');

stormRows = find(daily.Weather == "沙暴");
for k = 1:numel(stormRows)
    d = daily.Day(stormRows(k));
    xline(ax, d, '--', 'Color', [0.58,0.58,0.58], 'LineWidth', 0.8);
end

xlabel(ax, '日期', 'FontName', fontName, 'FontSize', 11);
ylabel(ax, '剩余数量（箱）', 'FontName', fontName, 'FontSize', 11);
title(ax, ...
    '第四关最不利情形下水和食物剩余量变化', ...
    'FontName', fontName, 'FontSize', 14, 'FontWeight', 'bold');

legend(ax, {'水','食物'}, 'FontName', fontName, 'Location', 'best');
grid(ax, 'on');
box(ax, 'off');
ax.GridColor = [0.82,0.84,0.86];
ax.GridAlpha = 0.45;
ax.FontName = fontName;
ax.FontSize = 10;
xticks(ax, unique(daily.Day));
xlim(ax, [min(daily.Day), max(daily.Day)]);
ylim(ax, [0, max([daily.WaterLeft;daily.FoodLeft])*1.10+1]);

text(ax, mean(daily.Day), max(daily.WaterLeft)*0.88, ...
    '保证型计算中高温/沙暴的水、食物消耗相同，因此两曲线重合', ...
    'FontName', fontName, 'FontSize', 9, ...
    'HorizontalAlignment', 'center', ...
    'BackgroundColor', 'w', 'Margin', 1);

hold(ax, 'off');

exportgraphics(fig, ...
    fullfile(figureDir, 'case4_worst_resource_change.png'), ...
    'Resolution', 400);
close(fig);


%% 现金变化
fig = figure('Color', 'w', 'Position', [120, 100, 1100, 650]);
ax = axes(fig);
hold(ax, 'on');

plot(ax, daily.Day, daily.CashLeft, '-o', ...
    'Color', moneyColor, 'LineWidth', 2.1, ...
    'MarkerSize', 5.7, 'MarkerFaceColor', 'w');

mineRows = find(daily.Mine == true);
for k = 1:numel(mineRows)
    d = daily.Day(mineRows(k));
    scatter(ax, d, daily.CashLeft(mineRows(k)), 45, '^', ...
        'MarkerFaceColor', mineColor, 'MarkerEdgeColor', 'w');
end

buyRows = find(daily.PurchasePairs > 0);
for k = 1:numel(buyRows)
    d = daily.Day(buyRows(k));
    scatter(ax, d, daily.CashLeft(buyRows(k)), 48, 'p', ...
        'MarkerFaceColor', villageColor, 'MarkerEdgeColor', 'w');
end

xlabel(ax, '日期', 'FontName', fontName, 'FontSize', 11);
ylabel(ax, '剩余现金（元）', 'FontName', fontName, 'FontSize', 11);
title(ax, ...
    '第四关最不利情形下现金变化', ...
    'FontName', fontName, 'FontSize', 14, 'FontWeight', 'bold');

grid(ax, 'on');
box(ax, 'off');
ax.GridColor = [0.82,0.84,0.86];
ax.GridAlpha = 0.45;
ax.FontName = fontName;
ax.FontSize = 10;
xticks(ax, unique(daily.Day));
xlim(ax, [min(daily.Day), max(daily.Day)]);

cashMin = min(daily.CashLeft);
cashMax = max(daily.CashLeft);
if abs(cashMax-cashMin) < 1e-9
    padding = max(100, 0.02*abs(cashMin));
else
    padding = 0.10*(cashMax-cashMin);
end

ylim(ax, [cashMin-padding, cashMax+padding]);
hold(ax, 'off');

exportgraphics(fig, ...
    fullfile(figureDir, 'case4_worst_money_change.png'), ...
    'Resolution', 400);
close(fig);

end
