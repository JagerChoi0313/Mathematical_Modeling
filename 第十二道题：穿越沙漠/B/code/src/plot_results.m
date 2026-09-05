function plot_results(result, data, projectRoot)
%PLOT_RESULTS 绘制路线图、资源变化图和资金变化图
%
% 输入：
%   result      求解结果结构体
%   data        当前关卡数据结构体
%   projectRoot 项目根目录
%
% 输出：
%   无（图像直接保存到 figures/caseX 文件夹）

caseFigureDir = fullfile(projectRoot, 'figures', sprintf('case%d', data.caseID));
if ~isfolder(caseFigureDir)
    mkdir(caseFigureDir);
end

arrivalDay = result.arrivalDay;
days = (0:arrivalDay)';
route = result.position(1:arrivalDay+1);
waterLeft = round(result.water(1:arrivalDay+1));
foodLeft  = round(result.food(1:arrivalDay+1));
cashLeft  = round(result.cash(1:arrivalDay+1), 2);

buyDays  = find(result.buyWater(1:arrivalDay) > 0 | result.buyFood(1:arrivalDay) > 0);
mineDays = find(result.mineFlag(1:arrivalDay) > 0);

fontCN = 'Microsoft YaHei';
fontEN = 'Times New Roman';

% 配色：尽量克制、论文风格
colorMapEdge   = [0.75, 0.79, 0.83];
colorNodeEdge  = [0.35, 0.43, 0.51];
colorRoute     = [0.05, 0.31, 0.52];
colorStart     = [0.20, 0.52, 0.30];
colorEnd       = [0.73, 0.22, 0.15];
colorMine      = [0.78, 0.48, 0.08];
colorVillage   = [0.41, 0.27, 0.60];
colorWater     = [0.12, 0.41, 0.68];
colorFood      = [0.80, 0.39, 0.10];
colorCash      = [0.18, 0.50, 0.36];

[x, y] = getNodeCoordinates(data);

drawRouteFigure();
drawResourceFigure();
drawCashFigure();

    function drawRouteFigure()
        fig = figure('Color', 'w', ...
            'Units', 'centimeters', ...
            'Position', [2, 2, 18, 13]);

        ax = axes(fig);
        hold(ax, 'on');

        % 先画底图边
        edges = data.undirectedEdges;
        for k = 1:size(edges, 1)
            u = edges(k, 1);
            v = edges(k, 2);
            plot(ax, [x(u), x(v)], [y(u), y(v)], '-', ...
                'Color', colorMapEdge, 'LineWidth', 1.1);
        end

        % 普通节点
        scatter(ax, x, y, 48, 'o', ...
            'MarkerFaceColor', [1 1 1], ...
            'MarkerEdgeColor', colorNodeEdge, ...
            'LineWidth', 1.0);

        % 路线节点（去掉连续停留重复）
        moveRoute = route([true; diff(route(:)) ~= 0]);
        routeNodes = unique(moveRoute, 'stable');

        % 画路径箭头
        for t = 1:(numel(moveRoute) - 1)
            u = moveRoute(t);
            v = moveRoute(t+1);

            dx = x(v) - x(u);
            dy = y(v) - y(u);
            L = hypot(dx, dy);
            if L < 1e-8
                continue;
            end

            % 从节点边缘开始，避免箭头扎进圆点中心
            sRatio = 0.12;
            eRatio = 0.82;
            sx = x(u) + sRatio * dx;
            sy = y(u) + sRatio * dy;
            qx = eRatio * dx;
            qy = eRatio * dy;

            quiver(ax, sx, sy, qx, qy, 0, ...
                'Color', colorRoute, ...
                'LineWidth', 2.6, ...
                'MaxHeadSize', 0.22);

            % 只在第一关标一部分"第几天"，避免过满
            if data.caseID == 1
                midx = (x(u) + x(v)) / 2;
                midy = (y(u) + y(v)) / 2;
                nx = -dy / L;
                ny = dx / L;
                text(ax, midx + 0.10 * nx, midy + 0.10 * ny, ...
                    sprintf('第%d天', t), ...
                    'FontName', fontCN, ...
                    'FontSize', 8.5, ...
                    'Color', [0.24 0.28 0.32], ...
                    'HorizontalAlignment', 'center', ...
                    'BackgroundColor', 'w', ...
                    'Margin', 0.8);
            end
        end

        % 路线上的节点再强调一下
        scatter(ax, x(routeNodes), y(routeNodes), 70, 'o', ...
            'MarkerFaceColor', colorRoute, ...
            'MarkerEdgeColor', 'w', ...
            'LineWidth', 1.0);

        % 特殊点
        hStart = scatter(ax, x(data.startNode), y(data.startNode), 110, 's', ...
            'MarkerFaceColor', colorStart, ...
            'MarkerEdgeColor', [0.10 0.33 0.16], ...
            'LineWidth', 1.2);

        hEnd = scatter(ax, x(data.endNode), y(data.endNode), 120, 'd', ...
            'MarkerFaceColor', colorEnd, ...
            'MarkerEdgeColor', [0.46 0.10 0.08], ...
            'LineWidth', 1.2);

        hMine = gobjects(0);
        if ~isempty(data.mineNodes)
            hMine = scatter(ax, x(data.mineNodes), y(data.mineNodes), 120, '^', ...
                'MarkerFaceColor', colorMine, ...
                'MarkerEdgeColor', [0.50 0.30 0.03], ...
                'LineWidth', 1.2);
        end

        hVillage = gobjects(0);
        if ~isempty(data.villageNodes)
            hVillage = scatter(ax, x(data.villageNodes), y(data.villageNodes), 130, 'p', ...
                'MarkerFaceColor', colorVillage, ...
                'MarkerEdgeColor', [0.24 0.15 0.36], ...
                'LineWidth', 1.2);
        end

        % 节点编号：普通节点小一点，路径点加粗，特殊点附文字
        for node = 1:data.numNodes
            labelX = x(node) + 0.07;
            labelY = y(node) + 0.05;

            if node == data.startNode
                txt = sprintf('起点 %d', node);
                fs = 11; fw = 'bold'; col = colorStart;
            elseif node == data.endNode
                txt = sprintf('终点 %d', node);
                fs = 11; fw = 'bold'; col = colorEnd;
            elseif ismember(node, data.mineNodes)
                txt = sprintf('%d 矿山', node);
                fs = 10; fw = 'bold'; col = colorMine;
            elseif ismember(node, data.villageNodes)
                txt = sprintf('%d 村庄', node);
                fs = 10; fw = 'bold'; col = colorVillage;
            elseif ismember(node, routeNodes)
                txt = sprintf('%d', node);
                fs = 10.5; fw = 'bold'; col = [0.12 0.18 0.25];
            else
                txt = sprintf('%d', node);
                fs = 9; fw = 'normal'; col = [0.32 0.36 0.40];
            end

            text(ax, labelX, labelY, txt, ...
                'FontName', fontCN, ...
                'FontSize', fs, ...
                'FontWeight', fw, ...
                'Color', col);
        end

        % 标注挖矿和补给
        annotateMineAndSupply(ax);

        % 标题 + 路线串
        routeText = join(string(moveRoute), ' → ');
        title(ax, {sprintf('第%d关最优行进路线', data.caseID), ...
            ['移动路径：', char(routeText)]}, ...
            'FontName', fontCN, ...
            'FontSize', 15, ...
            'FontWeight', 'bold');

        % 图例
        hRoute = plot(ax, nan, nan, '-', 'Color', colorRoute, 'LineWidth', 2.6);

        if isempty(data.mineNodes) && isempty(data.villageNodes)
            legend(ax, [hRoute, hStart, hEnd], ...
                {'最优路线', '起点', '终点'}, ...
                'FontName', fontCN, 'FontSize', 9.5, ...
                'Location', 'best', 'Box', 'on');
        else
            legend(ax, [hRoute, hStart, hEnd, hMine, hVillage], ...
                {'最优路线', '起点', '终点', '矿山', '村庄'}, ...
                'FontName', fontCN, 'FontSize', 9.5, ...
                'Location', 'best', 'Box', 'on');
        end

        axis(ax, 'equal');
        axis(ax, 'off');

        xr = max(x) - min(x);
        yr = max(y) - min(y);
        xlim(ax, [min(x) - 0.12 * xr, max(x) + 0.20 * xr]);
        ylim(ax, [min(y) - 0.12 * yr, max(y) + 0.13 * yr]);

        hold(ax, 'off');

        exportgraphics(fig, fullfile(caseFigureDir, 'optimal_route.png'), 'Resolution', 600);
        close(fig);
    end

    function annotateMineAndSupply(ax)
        % 矿山累计挖矿天数
        if ~isempty(mineDays)
            mineNodesUsed = unique(result.startRegion(mineDays));
            for k = 1:numel(mineNodesUsed)
                node = mineNodesUsed(k);
                cnt = sum(result.startRegion(mineDays) == node);

                text(ax, x(node) + 0.18, y(node) - 0.20, ...
                    sprintf('挖矿 %d 天', cnt), ...
                    'FontName', fontCN, ...
                    'FontSize', 8.8, ...
                    'Color', colorMine, ...
                    'FontWeight', 'bold', ...
                    'BackgroundColor', 'w', ...
                    'Margin', 0.8);
            end
        end

        if ~isempty(buyDays)
            villageNodesUsed = unique(result.endRegion(buyDays));
            for k = 1:numel(villageNodesUsed)
                node = villageNodesUsed(k);
                text(ax, x(node) + 0.18, y(node) + 0.18, ...
                    '补给', ...
                    'FontName', fontCN, ...
                    'FontSize', 8.8, ...
                    'Color', colorVillage, ...
                    'FontWeight', 'bold', ...
                    'BackgroundColor', 'w', ...
                    'Margin', 0.8);
            end
        end
    end

    function drawResourceFigure()
        fig = figure('Color', 'w', ...
            'Units', 'centimeters', ...
            'Position', [2, 2, 18, 10.5]);

        ax = axes(fig);
        hold(ax, 'on');

        plot(ax, days, waterLeft, '-o', ...
            'Color', colorWater, ...
            'LineWidth', 2.0, ...
            'MarkerSize', 6.3, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', colorWater);

        plot(ax, days, foodLeft, '-s', ...
            'Color', colorFood, ...
            'LineWidth', 2.0, ...
            'MarkerSize', 6.0, ...
            'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', colorFood);

        % 补给日虚线
        for k = 1:numel(buyDays)
            d = buyDays(k);
            xline(ax, d, '--', ...
                'Color', [0.65 0.65 0.65], ...
                'LineWidth', 0.9);

            ymax = max([waterLeft; foodLeft]);
            text(ax, d, ymax * 0.90, sprintf('补给\n第%d天', d), ...
                'FontName', fontCN, ...
                'FontSize', 8.5, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top', ...
                'Color', [0.35 0.35 0.35], ...
                'BackgroundColor', 'w', ...
                'Margin', 0.5);
        end

        xlabel(ax, '日期', 'FontName', fontCN, 'FontSize', 11);
        ylabel(ax, '剩余数量（箱）', 'FontName', fontCN, 'FontSize', 11);
        title(ax, sprintf('第%d关水和食物剩余量变化', data.caseID), ...
            'FontName', fontCN, 'FontSize', 15, 'FontWeight', 'bold');

        legend(ax, {'水', '食物'}, ...
            'FontName', fontCN, 'FontSize', 10, ...
            'Location', 'northeast', 'Box', 'on');

        styleAxis(ax, fontCN);
        if arrivalDay <= 12
            xticks(ax, 0:arrivalDay);
        else
            xticks(ax, 0:2:arrivalDay);
        end
        xlim(ax, [0, max(arrivalDay, 1)]);
        ylim(ax, [0, max([waterLeft; foodLeft]) * 1.12 + 1]);

        hold(ax, 'off');
        exportgraphics(fig, fullfile(caseFigureDir, 'resource_change.png'), 'Resolution', 600);
        close(fig);
    end

    function drawCashFigure()
        fig = figure('Color', 'w', ...
            'Units', 'centimeters', ...
            'Position', [2, 2, 18, 10.5]);

        ax = axes(fig);
        hold(ax, 'on');

        plot(ax, days, cashLeft, '-o', ...
            'Color', colorCash, ...
            'LineWidth', 2.1, ...
            'MarkerSize', 6.3, ...
            'MarkerFaceColor', [0.94 0.98 0.95], ...
            'MarkerEdgeColor', colorCash);

        % 购买点
        if ~isempty(buyDays)
            scatter(ax, buyDays, cashLeft(buyDays+1), 62, 'o', ...
                'MarkerFaceColor', colorVillage, ...
                'MarkerEdgeColor', 'w', ...
                'LineWidth', 0.9);
        end

        % 挖矿点
        if ~isempty(mineDays)
            scatter(ax, mineDays, cashLeft(mineDays+1), 66, '^', ...
                'MarkerFaceColor', colorMine, ...
                'MarkerEdgeColor', 'w', ...
                'LineWidth', 0.9);
        end

        xlabel(ax, '日期', 'FontName', fontCN, 'FontSize', 11);
        ylabel(ax, '剩余资金（元）', 'FontName', fontCN, 'FontSize', 11);
        title(ax, sprintf('第%d关资金变化', data.caseID), ...
            'FontName', fontCN, 'FontSize', 15, 'FontWeight', 'bold');

        styleAxis(ax, fontCN);
        if arrivalDay <= 12
            xticks(ax, 0:arrivalDay);
        else
            xticks(ax, 0:2:arrivalDay);
        end
        xlim(ax, [0, max(arrivalDay, 1)]);

        legendEntries = {'资金'};
        legendHandles = findobj(ax, 'Type', 'Line');
        legendHandles = legendHandles(1);

        if ~isempty(buyDays) && ~isempty(mineDays)
            hBuy = scatter(ax, nan, nan, 62, 'o', ...
                'MarkerFaceColor', colorVillage, ...
                'MarkerEdgeColor', 'w', 'LineWidth', 0.9);
            hMine = scatter(ax, nan, nan, 66, '^', ...
                'MarkerFaceColor', colorMine, ...
                'MarkerEdgeColor', 'w', 'LineWidth', 0.9);
            legend([legendHandles, hBuy, hMine], {'资金', '补给点', '挖矿点'}, ...
                'FontName', fontCN, 'FontSize', 10, ...
                'Location', 'best', 'Box', 'on');
        elseif ~isempty(buyDays)
            hBuy = scatter(ax, nan, nan, 62, 'o', ...
                'MarkerFaceColor', colorVillage, ...
                'MarkerEdgeColor', 'w', 'LineWidth', 0.9);
            legend([legendHandles, hBuy], {'资金', '补给点'}, ...
                'FontName', fontCN, 'FontSize', 10, ...
                'Location', 'best', 'Box', 'on');
        elseif ~isempty(mineDays)
            hMine = scatter(ax, nan, nan, 66, '^', ...
                'MarkerFaceColor', colorMine, ...
                'MarkerEdgeColor', 'w', 'LineWidth', 0.9);
            legend([legendHandles, hMine], {'资金', '挖矿点'}, ...
                'FontName', fontCN, 'FontSize', 10, ...
                'Location', 'best', 'Box', 'on');
        else
            legend(ax, {'资金'}, ...
                'FontName', fontCN, 'FontSize', 10, ...
                'Location', 'best', 'Box', 'on');
        end

        hold(ax, 'off');
        exportgraphics(fig, fullfile(caseFigureDir, 'money_change.png'), 'Resolution', 600);
        close(fig);
    end

    function styleAxis(ax, fontNameUsed)
        grid(ax, 'on');
        box(ax, 'off');
        ax.LineWidth = 0.9;
        ax.FontName = fontNameUsed;
        ax.FontSize = 10.5;
        ax.GridColor = [0.83 0.85 0.87];
        ax.GridAlpha = 0.50;
        ax.XColor = [0.20 0.20 0.20];
        ax.YColor = [0.20 0.20 0.20];
        ax.Layer = 'top';
    end

    function [xCoord, yCoord] = getNodeCoordinates(dataStruct)
        N = dataStruct.numNodes;
        xCoord = zeros(N, 1);
        yCoord = zeros(N, 1);

        if dataStruct.caseID == 1
            % 第一关：按附件地图轮廓手动固定坐标
            coord = [
                 1, 1.30, 10.00
                 2, 0.45,  8.55
                 3, 0.95,  7.20
                 4, 2.30,  7.10
                 5, 2.65,  5.85
                 6, 4.05,  5.10
                 7, 4.40,  4.10
                 8, 4.65,  2.90
                 9, 6.05,  2.35
                10, 5.20,  0.35
                11, 5.20, -0.85
                12, 6.85, -1.45
                13, 6.10, -0.80
                14, 7.05, -0.55
                15, 6.75,  0.75
                16, 8.05,  0.90
                17, 7.80,  2.35
                18, 8.90,  2.35
                19, 9.60,  3.20
                20, 9.20,  4.25
                21, 8.00,  6.10
                22, 6.20,  4.45
                23, 6.25,  6.35
                24, 5.05,  7.00
                25, 3.20,  8.75
                26, 6.20,  8.75
                27, 8.00,  8.85
                ];

            xCoord(coord(:,1)) = coord(:,2);
            yCoord(coord(:,1)) = coord(:,3);

        else
            % 第二关：六边形网格布局
            for node = 1:N
                row = ceil(node / 8);
                col = mod(node - 1, 8) + 1;

                xCoord(node) = col + 0.5 * mod(row - 1, 2);
                yCoord(node) = (8 - row) * 0.90;
            end
        end
    end
end