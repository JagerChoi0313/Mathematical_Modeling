clc;
clear;
close all;

%% 1. 读取基础数据
filename = 'cumcm2011B附件2_全市六区交通网路和平台设置的数据表pwd.xls';

nodeTable = readtable(filename, ...
    'Sheet', '全市交通路口节点数据', ...
    'VariableNamingRule', 'preserve');

edgeTable = readtable(filename, ...
    'Sheet', '全市交通路口的路线', ...
    'VariableNamingRule', 'preserve');

platformTable = readtable(filename, ...
    'Sheet', '全市交巡警平台', ...
    'VariableNamingRule', 'preserve');

%% 2. 提取 A 区节点
nodeID = nodeTable{:,1};
xCoord = nodeTable{:,2};
yCoord = nodeTable{:,3};
areaName = string(nodeTable{:,4});

isA = areaName == "A";

A_nodeID = nodeID(isA);
A_x = xCoord(isA);
A_y = yCoord(isA);

%% 3. 提取 A 区平台
platformName = string(platformTable{:,1});
platformNode = platformTable{:,2};

isAPlatform = startsWith(platformName, "A");

A_platformName = platformName(isAPlatform);
A_platformNode = platformNode(isAPlatform);

% 排序成 A1, A2, ..., A20
platformNum = zeros(length(A_platformName),1);
for i = 1:length(A_platformName)
    temp = erase(A_platformName(i), "A");
    platformNum(i) = str2double(temp);
end
[~, idx] = sort(platformNum);
A_platformName = A_platformName(idx);
A_platformNode = A_platformNode(idx);

%% 4. 建立节点编号到坐标、区域的映射
xMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
yMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
areaMap = containers.Map('KeyType', 'double', 'ValueType', 'char');

for i = 1:length(nodeID)
    xMap(nodeID(i)) = xCoord(i);
    yMap(nodeID(i)) = yCoord(i);
    areaMap(nodeID(i)) = char(areaName(i));
end

%% 5. 第二问的 13 个封锁口（按你的结果写入）
lockID = (1:13)';

lockNode = [12;22;23;62;48;30;29;28;14;21;24;16;38];

lockOutsideText = [
    "471"
    "372"
    "383,372"
    "190"
    "235"
    "237"
    "239,370"
    "371"
    "459"
    "459"
    "470"
    "560"
    "561"
];

%% 6. 第二问最终调度方案（按你的结果写入）
dispatchPlatformName = [
    "A12"
    "A10"
    "A13"
    "A4"
    "A5"
    "A8"
    "A7"
    "A15"
    "A16"
    "A14"
    "A11"
    "A9"
    "A2"
];

dispatchPlatformNode = [12;10;13;4;5;8;7;15;16;14;11;9;2];

dispatchTime = [ ...
    0.0000
    7.7079
    0.5000
    0.3500
    2.4758
    3.0608
    8.0155
    4.7518
    6.7417
    3.2650
    3.8053
    1.5325
    3.9822
];

%% 7. 参与调度的平台与备用平台
usedPlatformName = dispatchPlatformName;
usedPlatformNode = dispatchPlatformNode;

allPlatformName = A_platformName;
allPlatformNode = A_platformNode;

unusedMask = true(length(allPlatformNode),1);
for i = 1:length(allPlatformNode)
    if any(allPlatformNode(i) == usedPlatformNode)
        unusedMask(i) = false;
    end
end

unusedPlatformName = allPlatformName(unusedMask);
unusedPlatformNode = allPlatformNode(unusedMask);

%% 8. 封锁口坐标
nLock = length(lockNode);
lockX = zeros(nLock,1);
lockY = zeros(nLock,1);
for j = 1:nLock
    lockX(j) = xMap(lockNode(j));
    lockY(j) = yMap(lockNode(j));
end

%% 9. 被调用平台坐标
nUsed = length(usedPlatformNode);
usedX = zeros(nUsed,1);
usedY = zeros(nUsed,1);
for i = 1:nUsed
    usedX(i) = xMap(usedPlatformNode(i));
    usedY(i) = yMap(usedPlatformNode(i));
end

%% 10. 备用平台坐标
nUnused = length(unusedPlatformNode);
unusedX = zeros(nUnused,1);
unusedY = zeros(nUnused,1);
for i = 1:nUnused
    unusedX(i) = xMap(unusedPlatformNode(i));
    unusedY(i) = yMap(unusedPlatformNode(i));
end

%% 11. 为避免"封锁口和平台重合看不见"，对重合平台做轻微偏移显示
usedX_plot = usedX;
usedY_plot = usedY;

for j = 1:nLock
    for i = 1:nUsed
        if abs(usedX(i) - lockX(j)) < 1e-8 && abs(usedY(i) - lockY(j)) < 1e-8
            % 平台轻微偏移，封锁口保留原位置
            usedX_plot(i) = usedX_plot(i) - 2.0;
            usedY_plot(i) = usedY_plot(i) - 2.0;
        end
    end
end

%% 12. 开始绘图：全屏窗口
fig = figure('Color','w', 'Units','normalized', 'OuterPosition',[0 0 1 1]);
hold on;
axis equal;
box on;

%% 12.1 绘制 A 区内部道路网络
edgeStart = edgeTable{:,1};
edgeEnd = edgeTable{:,2};

for e = 1:length(edgeStart)
    u = edgeStart(e);
    v = edgeEnd(e);

    if isKey(areaMap, u) && isKey(areaMap, v)
        if string(areaMap(u)) == "A" && string(areaMap(v)) == "A"
            plot([xMap(u), xMap(v)], [yMap(u), yMap(v)], ...
                'Color', [0.85 0.85 0.85], 'LineWidth', 0.8);
        end
    end
end

%% 12.2 绘制普通节点（淡一点）
scatter(A_x, A_y, 8, [0.45 0.45 0.45], 'filled', ...
    'MarkerFaceAlpha', 0.45, 'MarkerEdgeAlpha', 0.45);

%% 12.3 绘制备用平台（浅蓝空心圆）
scatter(unusedX, unusedY, 85, ...
    'MarkerEdgeColor', [0.45 0.70 1.00], ...
    'LineWidth', 1.5);

%% 12.4 绘制参与调度的平台（深蓝实心圆）
scatter(usedX_plot, usedY_plot, 95, [0.10 0.35 0.85], 'filled', ...
    'MarkerEdgeColor','k', 'LineWidth', 0.8);

%% 12.5 绘制封锁口（红色大五角星，放最上层）
scatter(lockX, lockY, 180, 'r', 'p', 'filled', ...
    'MarkerEdgeColor','k', 'LineWidth', 0.8);

%% 12.6 绘制调度连线
maxTime = max(dispatchTime);

for j = 1:nLock

    % 找到该封锁口对应的派出平台位置（偏移后的显示位置）
    idxPlatform = find(usedPlatformNode == dispatchPlatformNode(j), 1, 'first');

    px = usedX_plot(idxPlatform);
    py = usedY_plot(idxPlatform);

    lx = lockX(j);
    ly = lockY(j);

    if abs(dispatchTime(j) - maxTime) < 1e-8
        plot([px, lx], [py, ly], '-', ...
            'Color', [0.78 0.10 0.85], 'LineWidth', 3.2);
    else
        plot([px, lx], [py, ly], '-', ...
            'Color', [0.20 0.60 0.20], 'LineWidth', 2.2);
    end
end

%% 12.7 给参与调度的平台加标签
for i = 1:nUsed
    text(usedX_plot(i)+1.2, usedY_plot(i)-1.2, char(usedPlatformName(i)), ...
        'FontSize', 9, ...
        'Color', [0 0.2 0.6], ...
        'FontWeight', 'bold', ...
        'BackgroundColor', 'w', ...
        'Margin', 0.5);
end

%% 12.8 给封锁口加标签（手动偏移，避免遮挡）
offsets = [
    1.8, -1.6
    1.8,  1.5
    1.8, -1.6
    1.8,  1.3
    1.8,  1.3
    1.8,  1.3
    1.8,  1.3
    1.8,  1.3
    1.8,  1.3
    1.8, -1.6
    1.8,  1.3
    1.8,  1.3
    1.8,  1.3
];

for j = 1:nLock

    labelText = sprintf('L%d(%.2f)', j, dispatchTime(j));

    dx = offsets(j,1);
    dy = offsets(j,2);

    if abs(dispatchTime(j) - maxTime) < 1e-8
        text(lockX(j)+dx, lockY(j)+dy, labelText, ...
            'FontSize', 10, ...
            'FontWeight', 'bold', ...
            'Color', [0.65 0 0.75], ...
            'BackgroundColor', 'w', ...
            'Margin', 0.8);
    else
        text(lockX(j)+dx, lockY(j)+dy, labelText, ...
            'FontSize', 9, ...
            'Color', 'k', ...
            'BackgroundColor', 'w', ...
            'Margin', 0.8);
    end
end

%% 13. 图例
h1 = scatter(nan, nan, 85, 'MarkerEdgeColor', [0.45 0.70 1.00], 'LineWidth', 1.5);
h2 = scatter(nan, nan, 95, [0.10 0.35 0.85], 'filled', 'MarkerEdgeColor','k');
h3 = scatter(nan, nan, 180, 'r', 'p', 'filled', 'MarkerEdgeColor','k');
h4 = plot(nan, nan, '-', 'Color', [0.20 0.60 0.20], 'LineWidth', 2.2);
h5 = plot(nan, nan, '-', 'Color', [0.78 0.10 0.85], 'LineWidth', 3.2);

legend([h1,h2,h3,h4,h5], ...
    {'备用平台','参与调度平台','封锁口','普通调度连线','最晚到达调度线'}, ...
    'Location','southeast', ...
    'FontSize',10);

%% 14. 标题和坐标轴
title('A区交通要道快速封锁调度示意图', ...
    'FontSize', 16, 'FontWeight', 'bold');
xlabel('横坐标', 'FontSize', 12);
ylabel('纵坐标', 'FontSize', 12);

%% 15. 统计信息框
annotation('textbox',[0.68 0.78 0.22 0.12], ...
    'String', { ...
    ['全封锁完成时间: ', num2str(max(dispatchTime), '%.4f'), ' min'], ...
    ['总出警时间: ', num2str(sum(dispatchTime), '%.4f'), ' min'], ...
    ['最晚到达封锁口: L', num2str(find(dispatchTime==max(dispatchTime),1))] ...
    }, ...
    'FitBoxToText','on', ...
    'BackgroundColor','w', ...
    'EdgeColor',[0.6 0.6 0.6], ...
    'FontSize',10);

%% 16. 坐标范围稍微留白
xlim([min(A_x)-12, max(A_x)+12]);
ylim([min(A_y)-12, max(A_y)+12]);

%% 17. 保存图片
exportgraphics(gcf, '第一问第二小问_快速封锁示意图_升级版.png', 'Resolution', 400);
exportgraphics(gcf, '第一问第二小问_快速封锁示意图_升级版.pdf', 'ContentType', 'vector');
savefig(gcf, '第一问第二小问_快速封锁示意图_升级版.fig');

fprintf('升级版快速封锁示意图已保存：PNG、PDF、FIG。\n');