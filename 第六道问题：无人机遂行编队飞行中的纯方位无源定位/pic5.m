%% draw_Q1_3_figures.m
% 问题1第(3)问论文配图
% 图1：圆形编队初始位置与理想位置对比图
% 图2：三轮发射无人机分组示意图
% 图3：圆形编队调整前后位置对比图
% 图4：多轮调整过程中编队误差变化图

clear; clc; close all;

%% ==================== 1. 基本参数 ====================

R = 100;

% FY00~FY09
droneNos = 0:9;

% 理想极坐标
rhoIdeal = [0, 100, 100, 100, 100, 100, 100, 100, 100, 100];
thetaIdealDeg = [0, 0, 40, 80, 120, 160, 200, 240, 280, 320];
thetaIdeal = deg2rad(thetaIdealDeg);

% 表1初始极坐标
rhoInit = [0, 100, 98, 112, 105, 98, 112, 105, 98, 112];
thetaInitDeg = [0, 0, 40.10, 80.21, 119.75, 159.86, ...
                199.96, 240.07, 280.17, 320.28];
thetaInit = deg2rad(thetaInitDeg);

% 坐标转换
idealXY = zeros(10, 2);
initXY  = zeros(10, 2);

for i = 1:10
    idealXY(i, :) = polar2xy(rhoIdeal(i), thetaIdeal(i));
    initXY(i, :)  = polar2xy(rhoInit(i), thetaInit(i));
end

%% ==================== 2. 三轮发射方案 ====================

txGroups = { ...
    [0, 1, 4, 7], ...
    [0, 2, 5, 8], ...
    [0, 3, 6, 9]};

groupNames = { ...
    '第1轮：FY00, FY01, FY04, FY07', ...
    '第2轮：FY00, FY02, FY05, FY08', ...
    '第3轮：FY00, FY03, FY06, FY09'};

% 输出文件夹
outFolder = 'Q1_3_figures';
if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

%% ==================== 3. 模拟多轮直接调整过程 ====================
% 这里用于生成图3、图4。
% 调整规则：每轮中未发射的圆周无人机作为接收机，
% 定位后直接调整到自身理想位置。

stateXY = initXY;

errorTable = zeros(4, 4);
% 列：最大半径误差、最大极角误差、最大位置误差、最大相邻距离误差

errorTable(1, :) = calcFormationErrors(stateXY, idealXY, thetaIdealDeg, R);

stateHistory = cell(4, 1);
stateHistory{1} = stateXY;

for r = 1:3
    txSet = txGroups{r};
    rxSet = setdiff(1:9, txSet);  % 只调整圆周无人机，不调整 FY00

    for k = 1:length(rxSet)
        rxNo = rxSet(k);
        idx = rxNo + 1;
        stateXY(idx, :) = idealXY(idx, :);
    end

    stateHistory{r+1} = stateXY;
    errorTable(r+1, :) = calcFormationErrors(stateXY, idealXY, thetaIdealDeg, R);
end

finalXY = stateXY;

%% ========================================================================
% 图1：圆形编队初始位置与理想位置对比图
% ========================================================================

fig1 = figure('Color', 'w', 'Position', [100, 100, 850, 760]);
hold on; grid on; axis equal;

drawTargetCircle(R);

% 理想位置
plot(idealXY(:,1), idealXY(:,2), 'ko', ...
    'MarkerSize', 7, 'LineWidth', 1.4);

% 初始位置
plot(initXY(:,1), initXY(:,2), 'kx', ...
    'MarkerSize', 9, 'LineWidth', 1.6);

% 偏差箭头：从初始位置指向理想位置
for no = 1:9
    idx = no + 1;
    quiver(initXY(idx,1), initXY(idx,2), ...
           idealXY(idx,1)-initXY(idx,1), ...
           idealXY(idx,2)-initXY(idx,2), ...
           0, 'k', 'LineWidth', 1.0, 'MaxHeadSize', 0.8);
end

% 标注无人机编号
for no = 0:9
    idx = no + 1;
    text(initXY(idx,1)+2, initXY(idx,2)+2, ...
        droneName(no), 'FontSize', 9);
end

xlabel('x / m');
ylabel('y / m');
title('圆形编队初始位置与理想位置对比图');

legend('目标圆周', '理想位置', '初始位置', '调整方向', ...
    'Location', 'bestoutside');

xlim([-125, 125]);
ylim([-125, 125]);

saveFigure(fig1, fullfile(outFolder, '图1_圆形编队初始位置与理想位置对比图.png'));

%% ========================================================================
% 图2：三轮发射无人机分组示意图
% ========================================================================

fig2 = figure('Color', 'w', 'Position', [100, 100, 850, 760]);
hold on; grid on; axis equal;

drawTargetCircle(R);

% 全部理想位置
plot(idealXY(:,1), idealXY(:,2), 'ko', ...
    'MarkerSize', 6, 'LineWidth', 1.0);

% FY00
plot(0, 0, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 8);
text(3, 3, 'FY00', 'FontSize', 10);

markers = {'s', '^', 'd'};
lineStyles = {'-', '--', ':'};

for r = 1:3
    group = txGroups{r};

    % 只画圆周发射机，FY00 单独标注
    circleTx = group(group ~= 0);

    for k = 1:length(circleTx)
        no = circleTx(k);
        idx = no + 1;

        plot(idealXY(idx,1), idealXY(idx,2), ...
            markers{r}, ...
            'MarkerSize', 11, ...
            'LineWidth', 1.8, ...
            'Color', 'k');

        plot([0, idealXY(idx,1)], [0, idealXY(idx,2)], ...
            lineStyles{r}, ...
            'Color', 'k', ...
            'LineWidth', 1.0);
    end
end

% 标注 FY01~FY09
for no = 1:9
    idx = no + 1;
    text(idealXY(idx,1)+2, idealXY(idx,2)+2, ...
        droneName(no), 'FontSize', 9);
end

% 分组说明文字
text(-120, -118, ...
    sprintf(['G_1 = {FY01, FY04, FY07}\n', ...
             'G_2 = {FY02, FY05, FY08}\n', ...
             'G_3 = {FY03, FY06, FY09}']), ...
    'FontSize', 11, ...
    'BackgroundColor', 'w', ...
    'EdgeColor', 'k', ...
    'Margin', 5);

xlabel('x / m');
ylabel('y / m');
title('圆形编队三轮发射无人机分组示意图');

legend('目标圆周', '圆周理想位置', 'FY00', ...
    '第1轮发射机', '第2轮发射机', '第3轮发射机', ...
    'Location', 'bestoutside');

xlim([-125, 125]);
ylim([-125, 125]);

saveFigure(fig2, fullfile(outFolder, '图2_三轮发射无人机分组示意图.png'));

%% ========================================================================
% 图3：圆形编队调整前后位置对比图
% ========================================================================

fig3 = figure('Color', 'w', 'Position', [100, 100, 850, 760]);
hold on; grid on; axis equal;

drawTargetCircle(R);

% 初始位置
plot(initXY(:,1), initXY(:,2), 'kx', ...
    'MarkerSize', 9, 'LineWidth', 1.6);

% 理想位置
plot(idealXY(:,1), idealXY(:,2), 'ko', ...
    'MarkerSize', 7, 'LineWidth', 1.2);

% 最终位置
plot(finalXY(:,1), finalXY(:,2), 'k^', ...
    'MarkerSize', 9, 'LineWidth', 1.6);

% 初始到最终的调整箭头
for no = 1:9
    idx = no + 1;
    quiver(initXY(idx,1), initXY(idx,2), ...
           finalXY(idx,1)-initXY(idx,1), ...
           finalXY(idx,2)-initXY(idx,2), ...
           0, 'k', 'LineWidth', 1.0, 'MaxHeadSize', 0.8);
end

% 标注无人机编号
for no = 0:9
    idx = no + 1;
    text(finalXY(idx,1)+2, finalXY(idx,2)+2, ...
        droneName(no), 'FontSize', 9);
end

xlabel('x / m');
ylabel('y / m');
title('圆形编队调整前后位置对比图');

legend('目标圆周', '初始位置', '理想位置', '最终位置', '调整方向', ...
    'Location', 'bestoutside');

xlim([-125, 125]);
ylim([-125, 125]);

saveFigure(fig3, fullfile(outFolder, '图3_圆形编队调整前后位置对比图.png'));

%% ========================================================================
% 图4：多轮调整过程中编队误差变化图
% ========================================================================

fig4 = figure('Color', 'w', 'Position', [100, 100, 900, 620]);

stageLabels = {'初始', '第1轮后', '第2轮后', '第3轮后'};
x = 1:4;

% 左轴：长度误差
yyaxis left;
hold on; grid on;

plot(x, errorTable(:,1), '-o', 'LineWidth', 1.8, 'MarkerSize', 7);
plot(x, errorTable(:,3), '-s', 'LineWidth', 1.8, 'MarkerSize', 7);
plot(x, errorTable(:,4), '-^', 'LineWidth', 1.8, 'MarkerSize', 7);

ylabel('长度误差 / m');

% 右轴：角度误差
yyaxis right;
plot(x, errorTable(:,2), '-d', 'LineWidth', 1.8, 'MarkerSize', 7);
ylabel('极角误差 / °');

xticks(x);
xticklabels(stageLabels);

xlabel('调整阶段');
title('多轮调整过程中编队误差变化图');

legend('最大半径误差', '最大位置误差', '最大相邻距离误差', '最大极角误差', ...
    'Location', 'northeast');

saveFigure(fig4, fullfile(outFolder, '图4_多轮调整过程中编队误差变化图.png'));

%% ==================== 4. 输出误差表 ====================

fprintf('========== 各阶段误差表 ==========\n');
T = table(stageLabels', ...
          errorTable(:,1), ...
          errorTable(:,2), ...
          errorTable(:,3), ...
          errorTable(:,4), ...
          'VariableNames', {'阶段', '最大半径误差_m', '最大极角误差_deg', ...
                            '最大位置误差_m', '最大相邻距离误差_m'});
disp(T);

fprintf('\n图片已保存到文件夹：%s\n', outFolder);

%% ========================================================================
% 局部函数
% ========================================================================

function P = polar2xy(rho, theta)
    P = [rho*cos(theta), rho*sin(theta)];
end

function drawTargetCircle(R)
    t = linspace(0, 2*pi, 600);
    plot(R*cos(t), R*sin(t), 'k--', 'LineWidth', 1.2);

    plot([-120, 120], [0, 0], 'k:', 'LineWidth', 0.8);
    plot([0, 0], [-120, 120], 'k:', 'LineWidth', 0.8);

    plot(0, 0, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 7);
end

function name = droneName(no)
    if no == 0
        name = 'FY00';
    else
        name = sprintf('FY%02d', no);
    end
end

function errors = calcFormationErrors(currentXY, idealXY, thetaIdealDeg, R)
    % 返回：
    % errors(1)：最大半径误差
    % errors(2)：最大极角误差
    % errors(3)：最大位置误差
    % errors(4)：最大相邻距离误差

    radiusErr = zeros(1, 9);
    angleErr  = zeros(1, 9);
    posErr    = zeros(1, 9);

    for no = 1:9
        idx = no + 1;

        rhoNow = norm(currentXY(idx, :));
        thetaNowDeg = atan2d(currentXY(idx,2), currentXY(idx,1));
        thetaNowDeg = mod(thetaNowDeg, 360);

        radiusErr(no) = abs(rhoNow - R);
        angleErr(no) = abs(wrapTo180Deg(thetaNowDeg - thetaIdealDeg(idx)));
        posErr(no) = norm(currentXY(idx, :) - idealXY(idx, :));
    end

    Lstar = 2 * R * sind(20);
    spacingErr = zeros(1, 9);

    for no = 1:9
        idx1 = no + 1;

        if no < 9
            idx2 = no + 2;
        else
            idx2 = 2;
        end

        Lnow = norm(currentXY(idx1, :) - currentXY(idx2, :));
        spacingErr(no) = abs(Lnow - Lstar);
    end

    errors = [max(radiusErr), max(angleErr), max(posErr), max(spacingErr)];
end

function a = wrapTo180Deg(a)
    a = mod(a + 180, 360) - 180;
end

function saveFigure(figHandle, fileName)
    try
        exportgraphics(figHandle, fileName, 'Resolution', 300);
    catch
        print(figHandle, fileName, '-dpng', '-r300');
    end
end