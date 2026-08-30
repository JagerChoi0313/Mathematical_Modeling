function plot_results(result, data, projectRoot)
%PLOT_RESULTS 绘制最优路线、资源剩余量和资金变化图

caseFigureDir = fullfile(projectRoot, 'figures', ...
    sprintf('case%d', data.caseID));

if ~isfolder(caseFigureDir)
    mkdir(caseFigureDir);
end

arrivalDay = result.arrivalDay;
route = result.position(1:arrivalDay+1);

N = data.numNodes;

fontName = 'Microsoft YaHei';

% 配色保持克制，适合论文图
mapLineColor   = [0.74, 0.79, 0.84];
routeColor     = [0.06, 0.32, 0.52];
normalNodeEdge = [0.42, 0.50, 0.58];

startColor   = [0.22, 0.55, 0.36];
endColor     = [0.72, 0.22, 0.18];
mineColor    = [0.78, 0.48, 0.12];
villageColor = [0.42, 0.32, 0.58];

waterColor = [0.10, 0.42, 0.68];
foodColor  = [0.80, 0.38, 0.12];
moneyColor = [0.16, 0.48, 0.36];


%% 节点坐标

x = zeros(N,1);
y = zeros(N,1);

if data.caseID == 1

    % 第一关按照附件地图的相对位置设置节点中心坐标
    % 这些坐标只用于绘图，不参与模型求解
    coord = [
         1, 1.55, 10.00
         2, 0.75,  8.65
         3, 1.15,  7.45
         4, 2.45,  7.35
         5, 2.65,  5.95
         6, 3.90,  5.20
         7, 4.25,  4.35
         8, 4.55,  3.35
         9, 5.85,  2.75
        10, 5.05,  0.75
        11, 5.05, -0.45
        12, 6.55, -1.25
        13, 5.80, -0.35
        14, 6.75, -0.15
        15, 6.40,  1.05
        16, 7.60,  1.05
        17, 7.40,  2.75
        18, 8.45,  2.75
        19, 9.35,  3.50
        20, 8.90,  4.45
        21, 7.80,  6.00
        22, 6.05,  4.45
        23, 6.05,  6.45
        24, 4.80,  7.10
        25, 3.15,  8.85
        26, 5.90,  8.85
        27, 7.45,  8.95
        ];

    x(coord(:,1)) = coord(:,2);
    y(coord(:,1)) = coord(:,3);

else

    % 第二关按照附件中的8×8交错六边形网格排列
    for node = 1:N

        row = ceil(node / 8);
        col = mod(node - 1, 8) + 1;

        x(node) = col + 0.5 * mod(row - 1, 2);
        y(node) = (8 - row) * 0.86;

    end

end


%% 最优路线地图

fig = figure( ...
    'Color', 'w', ...
    'Position', [70, 50, 1280, 900]);

ax = axes(fig);
hold(ax, 'on');


% 绘制地图邻接边
edges = data.undirectedEdges;

for k = 1:size(edges,1)

    node1 = edges(k,1);
    node2 = edges(k,2);

    plot(ax, ...
        [x(node1), x(node2)], ...
        [y(node1), y(node2)], ...
        '-', ...
        'Color', mapLineColor, ...
        'LineWidth', 1.05);

end


% 普通节点
scatter(ax, ...
    x, y, ...
    34, ...
    'o', ...
    'MarkerFaceColor', 'w', ...
    'MarkerEdgeColor', normalNodeEdge, ...
    'LineWidth', 0.9);


%% 绘制最优路线

% 如果有连续停留，只保留实际移动节点用于显示完整移动路径
moveMask = [true; diff(route(:)) ~= 0];
moveRoute = route(moveMask);

% 实际每天的行动仍然从完整route判断
for day = 1:arrivalDay

    node1 = route(day);
    node2 = route(day+1);

    % 停留或挖矿不画移动箭头
    if node1 == node2
        continue;
    end

    dx = x(node2) - x(node1);
    dy = y(node2) - y(node1);

    % 从节点边缘开始，到目标节点边缘结束
    startRatio = 0.08;
    lineRatio  = 0.84;

    startX = x(node1) + startRatio * dx;
    startY = y(node1) + startRatio * dy;

    quiver(ax, ...
        startX, ...
        startY, ...
        lineRatio * dx, ...
        lineRatio * dy, ...
        0, ...
        'Color', routeColor, ...
        'LineWidth', 3.4, ...
        'MaxHeadSize', 0.18);

    % 第一关路线较短，直接标出每一次移动对应的日期
    if data.caseID == 1

        midX = (x(node1) + x(node2)) / 2;
        midY = (y(node1) + y(node2)) / 2;

        % 标签稍微偏离路线
        len = hypot(dx,dy);

        if len > 0
            offsetX = -dy / len * 0.16;
            offsetY =  dx / len * 0.16;
        else
            offsetX = 0;
            offsetY = 0;
        end

        text(ax, ...
            midX + offsetX, ...
            midY + offsetY, ...
            sprintf('第%d天', day), ...
            'FontName', fontName, ...
            'FontSize', 9.5, ...
            'Color', [0.18,0.24,0.29], ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'BackgroundColor', 'w', ...
            'Margin', 1);

    end

end


%% 突出路线经过节点

routeNodes = unique(route, 'stable');

scatter(ax, ...
    x(routeNodes), ...
    y(routeNodes), ...
    64, ...
    'o', ...
    'MarkerFaceColor', routeColor, ...
    'MarkerEdgeColor', 'w', ...
    'LineWidth', 1.0);


%% 特殊节点

% 起点
hStart = scatter(ax, ...
    x(data.startNode), ...
    y(data.startNode), ...
    145, ...
    's', ...
    'MarkerFaceColor', startColor, ...
    'MarkerEdgeColor', [0.10,0.34,0.19], ...
    'LineWidth', 1.4);


% 终点
hEnd = scatter(ax, ...
    x(data.endNode), ...
    y(data.endNode), ...
    155, ...
    'd', ...
    'MarkerFaceColor', endColor, ...
    'MarkerEdgeColor', [0.46,0.10,0.08], ...
    'LineWidth', 1.4);


% 矿山
hMine = gobjects(0);

if ~isempty(data.mineNodes)

    hMine = scatter(ax, ...
        x(data.mineNodes), ...
        y(data.mineNodes), ...
        135, ...
        '^', ...
        'MarkerFaceColor', mineColor, ...
        'MarkerEdgeColor', [0.52,0.29,0.04], ...
        'LineWidth', 1.35);

end


% 村庄
hVillage = gobjects(0);

if ~isempty(data.villageNodes)

    hVillage = scatter(ax, ...
        x(data.villageNodes), ...
        y(data.villageNodes), ...
        135, ...
        'p', ...
        'MarkerFaceColor', villageColor, ...
        'MarkerEdgeColor', [0.26,0.17,0.38], ...
        'LineWidth', 1.35);

end


%% 节点编号

for node = 1:N

    if node == data.startNode

        labelText = sprintf('起点  %d', node);
        labelSize = 10.5;
        labelWeight = 'bold';
        labelColor = startColor;

    elseif node == data.endNode

        labelText = sprintf('终点  %d', node);
        labelSize = 10.5;
        labelWeight = 'bold';
        labelColor = endColor;

    elseif ismember(node, data.mineNodes)

        labelText = sprintf('%d  矿山', node);
        labelSize = 9.5;
        labelWeight = 'bold';
        labelColor = mineColor;

    elseif ismember(node, data.villageNodes)

        labelText = sprintf('%d  村庄', node);
        labelSize = 9.5;
        labelWeight = 'bold';
        labelColor = villageColor;

    elseif ismember(node, routeNodes)

        labelText = num2str(node);
        labelSize = 10;
        labelWeight = 'bold';
        labelColor = [0.10,0.16,0.22];

    else

        labelText = num2str(node);
        labelSize = 8.2;
        labelWeight = 'normal';
        labelColor = [0.30,0.34,0.38];

    end

    text(ax, ...
        x(node) + 0.08, ...
        y(node) + 0.045, ...
        labelText, ...
        'FontName', fontName, ...
        'FontSize', labelSize, ...
        'FontWeight', labelWeight, ...
        'Color', labelColor);

end


%% 标出挖矿和补给位置

mineDays = find(result.mineFlag(1:arrivalDay));

if ~isempty(mineDays)

    mineNodeUsed = unique(result.startRegion(mineDays));

    for k = 1:numel(mineNodeUsed)

        node = mineNodeUsed(k);

        numDays = sum(result.startRegion(mineDays) == node);

        text(ax, ...
            x(node) + 0.20, ...
            y(node) - 0.22, ...
            sprintf('挖矿 %d 天', numDays), ...
            'FontName', fontName, ...
            'FontSize', 8.8, ...
            'Color', mineColor, ...
            'FontWeight', 'bold', ...
            'BackgroundColor', 'w', ...
            'Margin', 1);

    end

end


buyDays = find( ...
    result.buyWater(1:arrivalDay) > 0 | ...
    result.buyFood(1:arrivalDay) > 0);

if ~isempty(buyDays)

    villageNodeUsed = unique(result.endRegion(buyDays));

    for k = 1:numel(villageNodeUsed)

        node = villageNodeUsed(k);

        text(ax, ...
            x(node) + 0.20, ...
            y(node) + 0.22, ...
            '补给', ...
            'FontName', fontName, ...
            'FontSize', 8.8, ...
            'Color', villageColor, ...
            'FontWeight', 'bold', ...
            'BackgroundColor', 'w', ...
            'Margin', 1);

    end

end


%% 图例

hRoute = plot(ax, ...
    nan, nan, ...
    '-', ...
    'Color', routeColor, ...
    'LineWidth', 3.4);

if isempty(data.mineNodes)

    legend(ax, ...
        [hRoute,hStart,hEnd], ...
        {'最优路线','起点','终点'}, ...
        'FontName', fontName, ...
        'FontSize', 9, ...
        'Location', 'best');

else

    legend(ax, ...
        [hRoute,hStart,hEnd,hMine,hVillage], ...
        {'最优路线','起点','终点','矿山','村庄'}, ...
        'FontName', fontName, ...
        'FontSize', 9, ...
        'Location', 'best');

end


%% 标题及路线文字

moveRouteText = strjoin(string(moveRoute), ' → ');

title(ax, ...
    { ...
    sprintf('第%d关最优行进路线', data.caseID), ...
    ['移动路径：', char(moveRouteText)] ...
    }, ...
    'FontName', fontName, ...
    'FontSize', 15, ...
    'FontWeight', 'bold', ...
    'Color', [0.12,0.16,0.20]);


axis(ax, 'equal');
axis(ax, 'off');

xRange = max(x)-min(x);
yRange = max(y)-min(y);

xlim(ax, [min(x)-0.10*xRange, max(x)+0.19*xRange]);
ylim(ax, [min(y)-0.08*yRange, max(y)+0.11*yRange]);

hold(ax, 'off');


exportgraphics(fig, ...
    fullfile(caseFigureDir,'optimal_route.png'), ...
    'Resolution', 400);

close(fig);


%% 水和食物剩余量变化

n = arrivalDay + 1;

days = (0:arrivalDay)';
waterLeft = round(result.water(1:n));
foodLeft  = round(result.food(1:n));


fig = figure( ...
    'Color','w', ...
    'Position',[120,100,1100,650]);

ax = axes(fig);
hold(ax,'on');


plot(ax, ...
    days,waterLeft, ...
    '-o', ...
    'Color',waterColor, ...
    'LineWidth',2.0, ...
    'MarkerSize',5.5, ...
    'MarkerFaceColor','w', ...
    'MarkerEdgeColor',waterColor);


plot(ax, ...
    days,foodLeft, ...
    '-s', ...
    'Color',foodColor, ...
    'LineWidth',2.0, ...
    'MarkerSize',5.2, ...
    'MarkerFaceColor','w', ...
    'MarkerEdgeColor',foodColor);


% 标记补给日
for k = 1:numel(buyDays)

    d = buyDays(k);

    xline(ax, ...
        d, ...
        '--', ...
        'Color',[0.58,0.58,0.58], ...
        'LineWidth',0.9);

    yTop = max([waterLeft;foodLeft]);

    text(ax, ...
        d, ...
        yTop*0.96, ...
        sprintf('补给\n第%d天',d), ...
        'FontName',fontName, ...
        'FontSize',8.5, ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','top', ...
        'Color',[0.38,0.38,0.38], ...
        'BackgroundColor','w');

end


xlabel(ax,'日期', ...
    'FontName',fontName, ...
    'FontSize',11);

ylabel(ax,'剩余数量（箱）', ...
    'FontName',fontName, ...
    'FontSize',11);

title(ax, ...
    sprintf('第%d关水和食物剩余量变化',data.caseID), ...
    'FontName',fontName, ...
    'FontSize',15, ...
    'FontWeight','bold');


legend(ax, ...
    {'水','食物'}, ...
    'FontName',fontName, ...
    'FontSize',10, ...
    'Location','best');


grid(ax,'on');
box(ax,'off');

ax.GridColor = [0.82,0.84,0.86];
ax.GridAlpha = 0.45;
ax.LineWidth = 0.8;
ax.FontName = fontName;
ax.FontSize = 10;

if arrivalDay <= 10
    xticks(ax,0:arrivalDay);
else
    xticks(ax,0:2:arrivalDay);
end

xlim(ax,[0,max(arrivalDay,1)]);

maxResource = max([waterLeft;foodLeft]);

ylim(ax,[0,maxResource*1.10+1]);

hold(ax,'off');


exportgraphics(fig, ...
    fullfile(caseFigureDir,'resource_change.png'), ...
    'Resolution',400);

close(fig);


%% 资金变化

cashLeft = round(result.cash(1:n),2);


fig = figure( ...
    'Color','w', ...
    'Position',[120,100,1100,650]);

ax = axes(fig);
hold(ax,'on');


plot(ax, ...
    days,cashLeft, ...
    '-o', ...
    'Color',moneyColor, ...
    'LineWidth',2.0, ...
    'MarkerSize',5.5, ...
    'MarkerFaceColor','w', ...
    'MarkerEdgeColor',moneyColor);


% 补给时资金通常发生下降
for k = 1:numel(buyDays)

    d = buyDays(k);

    scatter(ax, ...
        d,cashLeft(d+1), ...
        55, ...
        'o', ...
        'MarkerFaceColor',villageColor, ...
        'MarkerEdgeColor','w', ...
        'LineWidth',0.9);

end


% 挖矿日标记
for k = 1:numel(mineDays)

    d = mineDays(k);

    scatter(ax, ...
        d,cashLeft(d+1), ...
        38, ...
        '^', ...
        'MarkerFaceColor',mineColor, ...
        'MarkerEdgeColor','w', ...
        'LineWidth',0.7);

end


xlabel(ax,'日期', ...
    'FontName',fontName, ...
    'FontSize',11);

ylabel(ax,'剩余资金（元）', ...
    'FontName',fontName, ...
    'FontSize',11);

title(ax, ...
    sprintf('第%d关资金变化',data.caseID), ...
    'FontName',fontName, ...
    'FontSize',15, ...
    'FontWeight','bold');


grid(ax,'on');
box(ax,'off');

ax.GridColor = [0.82,0.84,0.86];
ax.GridAlpha = 0.45;
ax.LineWidth = 0.8;
ax.FontName = fontName;
ax.FontSize = 10;


if arrivalDay <= 10
    xticks(ax,0:arrivalDay);
else
    xticks(ax,0:2:arrivalDay);
end

xlim(ax,[0,max(arrivalDay,1)]);

hold(ax,'off');


exportgraphics(fig, ...
    fullfile(caseFigureDir,'money_change.png'), ...
    'Resolution',400);

close(fig);

end