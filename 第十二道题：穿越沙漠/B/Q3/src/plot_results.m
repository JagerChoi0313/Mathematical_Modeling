function plot_results( ...
    simulation, gameResult, data, projectRoot)
%PLOT_RESULTS 绘制第三问主要结果图

figureDir = fullfile( ...
    projectRoot, 'figures', ...
    sprintf('case%d', data.caseID));

if ~isfolder(figureDir)
    mkdir(figureDir);
end


plot_route_map(simulation, data, figureDir);
plot_resources(simulation, data, figureDir);
plot_cash(simulation, data, figureDir);
plot_iteration_history(gameResult, data, figureDir);

end


function plot_route_map(simulation, data, figureDir)

fig = figure('Position', [100 80 1300 850]);
hold on;

% 背景地图
for e = 1:size(data.edges, 1)

    a = data.edges(e, 1);
    b = data.edges(e, 2);

    plot( ...
        [data.plotX(a), data.plotX(b)], ...
        [data.plotY(a), data.plotY(b)], ...
        'LineWidth', 0.8);

end


scatter( ...
    data.plotX, data.plotY, ...
    65, 'filled', ...
    'MarkerFaceAlpha', 0.15);

for r = 1:data.numRegions

    text( ...
        data.plotX(r) + 0.05, ...
        data.plotY(r) + 0.05, ...
        string(r), ...
        'FontSize', 10);

end


lineHandles = gobjects(1, data.numPlayers);

for i = 1:data.numPlayers

    P = simulation.players(i);

    endDay = min(P.arrivalDay, data.deadline);

    if ~isfinite(endDay)
        endDay = data.deadline;
    end

    x = data.plotX(P.region(1:endDay + 1));
    y = data.plotY(P.region(1:endDay + 1));

    lineHandles(i) = plot( ...
        x, y, '-o', ...
        'LineWidth', 3, ...
        'MarkerSize', 5);

end


scatter( ...
    data.plotX(data.startRegion), ...
    data.plotY(data.startRegion), ...
    180, 's', 'filled');

scatter( ...
    data.plotX(data.endRegion), ...
    data.plotY(data.endRegion), ...
    180, 'd', 'filled');


for r = data.mineRegions

    scatter( ...
        data.plotX(r), ...
        data.plotY(r), ...
        210, '^', 'filled');

end


for r = data.villageRegions

    scatter( ...
        data.plotX(r), ...
        data.plotY(r), ...
        230, 'p', 'filled');

end


axis equal;
axis off;

title(sprintf('第三问第%d关多人稳定策略路线', ...
    data.caseID), ...
    'FontWeight', 'bold');

legendText = strings(1, data.numPlayers);

for i = 1:data.numPlayers
    legendText(i) = sprintf('玩家%d', i);
end

legend(lineHandles, legendText, ...
    'Location', 'best');

exportgraphics( ...
    fig, ...
    fullfile(figureDir, ...
    sprintf('case%d_routes.png', data.caseID)), ...
    'Resolution', 220);

close(fig);

end


function plot_resources(simulation, data, figureDir)

fig = figure('Position', [100 80 1300 760]);
hold on;

for i = 1:data.numPlayers

    P = simulation.players(i);

    days = 0:data.deadline;

    plot(days, P.water, ...
        '-o', ...
        'LineWidth', 1.8, ...
        'MarkerSize', 4);

    plot(days, P.food, ...
        '--s', ...
        'LineWidth', 1.5, ...
        'MarkerSize', 4);

end

xlabel('日期');
ylabel('剩余数量（箱）');

title(sprintf( ...
    '第三问第%d关各玩家水和食物变化', ...
    data.caseID), ...
    'FontWeight', 'bold');

grid on;

legendText = strings(1, 2 * data.numPlayers);

p = 1;

for i = 1:data.numPlayers

    legendText(p) = sprintf('玩家%d-水', i);
    legendText(p + 1) = sprintf('玩家%d-食物', i);

    p = p + 2;

end

legend(legendText, 'Location', 'best');

exportgraphics( ...
    fig, ...
    fullfile(figureDir, ...
    sprintf('case%d_resources.png', data.caseID)), ...
    'Resolution', 220);

close(fig);

end


function plot_cash(simulation, data, figureDir)

fig = figure('Position', [100 80 1300 760]);
hold on;

for i = 1:data.numPlayers

    P = simulation.players(i);

    plot( ...
        0:data.deadline, ...
        P.cash, ...
        '-o', ...
        'LineWidth', 2, ...
        'MarkerSize', 4);

end

xlabel('日期');
ylabel('剩余资金（元）');

title(sprintf( ...
    '第三问第%d关各玩家资金变化', ...
    data.caseID), ...
    'FontWeight', 'bold');

grid on;

legendText = strings(1, data.numPlayers);

for i = 1:data.numPlayers
    legendText(i) = sprintf('玩家%d', i);
end

legend(legendText, 'Location', 'best');

exportgraphics( ...
    fig, ...
    fullfile(figureDir, ...
    sprintf('case%d_cash.png', data.caseID)), ...
    'Resolution', 220);

close(fig);

end


function plot_iteration_history( ...
    gameResult, data, figureDir)

if isempty(gameResult.iterationHistory)
    return;
end

fig = figure('Position', [100 80 1150 700]);
hold on;

iterations = 1:size( ...
    gameResult.iterationHistory, 1);

for i = 1:data.numPlayers

    plot( ...
        iterations, ...
        gameResult.iterationHistory(:, i), ...
        '-o', ...
        'LineWidth', 2, ...
        'MarkerSize', 5);

end

xlabel('最优响应迭代轮次');
ylabel('玩家最终资金（元）');

title(sprintf( ...
    '第三问第%d关最优响应迭代过程', ...
    data.caseID), ...
    'FontWeight', 'bold');

grid on;

legendText = strings(1, data.numPlayers);

for i = 1:data.numPlayers
    legendText(i) = sprintf('玩家%d', i);
end

legend(legendText, 'Location', 'best');

exportgraphics( ...
    fig, ...
    fullfile(figureDir, ...
    sprintf('case%d_iterations.png', data.caseID)), ...
    'Resolution', 220);

close(fig);

end