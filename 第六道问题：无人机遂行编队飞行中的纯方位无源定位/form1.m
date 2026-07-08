%% generate_Q1_3_tables.m
% 问题一第(3)问：生成论文用三张表
% 表1：三轮发射与接收安排
% 表2：各轮调整后误差变化
% 表3：最终位置结果

clear; clc; close all;

%% ==================== 1. 基本参数 ====================

R = 100;

% 理想极坐标
rhoIdeal = [0, 100, 100, 100, 100, 100, 100, 100, 100, 100];
thetaIdealDeg = [0, 0, 40, 80, 120, 160, 200, 240, 280, 320];

% 表1初始极坐标
rhoInit = [0, 100, 98, 112, 105, 98, 112, 105, 98, 112];
thetaInitDeg = [0, 0, 40.10, 80.21, 119.75, 159.86, ...
                199.96, 240.07, 280.17, 320.28];

% 坐标转换
idealXY = zeros(10, 2);
initXY  = zeros(10, 2);

for i = 1:10
    idealXY(i, :) = polar2xy(rhoIdeal(i), deg2rad(thetaIdealDeg(i)));
    initXY(i, :)  = polar2xy(rhoInit(i), deg2rad(thetaInitDeg(i)));
end

%% ==================== 2. 表1：三轮发射与接收安排 ====================

table1 = {
    '调整轮次', '发射无人机', '接收并调整无人机', '作用';
    '第1轮', 'FY00、FY01、FY04、FY07', ...
    'FY02、FY03、FY05、FY06、FY08、FY09', ...
    '初步调整大部分偏差无人机';
    '第2轮', 'FY00、FY02、FY05、FY08', ...
    'FY01、FY03、FY04、FY06、FY07、FY09', ...
    '调整第1轮中未调整或仍有偏差的无人机';
    '第3轮', 'FY00、FY03、FY06、FY09', ...
    'FY01、FY02、FY04、FY05、FY07、FY08', ...
    '对调整后的编队进行复核';
};

%% ==================== 3. 表2：误差变化表 ====================

txGroups = { ...
    [0, 1, 4, 7], ...
    [0, 2, 5, 8], ...
    [0, 3, 6, 9]};

stateXY = initXY;

errorTable = zeros(4, 4);
errorTable(1, :) = calcFormationErrors(stateXY, idealXY, thetaIdealDeg, R);

% 模拟三轮调整：本轮未发射的圆周无人机直接调整到理想位置
for r = 1:3
    txSet = txGroups{r};
    rxSet = setdiff(1:9, txSet);

    for k = 1:length(rxSet)
        rxNo = rxSet(k);
        idx = rxNo + 1;
        stateXY(idx, :) = idealXY(idx, :);
    end

    errorTable(r+1, :) = calcFormationErrors(stateXY, idealXY, thetaIdealDeg, R);
end

stageNames = {'初始状态'; '第1轮后'; '第2轮后'; '第3轮后'};

table2 = {
    '阶段', '最大半径误差 / m', '最大极角误差 / °', '最大位置误差 / m', '最大相邻距离误差 / m';
};

for i = 1:4
    table2(end+1, :) = { ...
        stageNames{i}, ...
        sprintf('%.6f', errorTable(i,1)), ...
        sprintf('%.6f', errorTable(i,2)), ...
        sprintf('%.6f', errorTable(i,3)), ...
        sprintf('%.6f', errorTable(i,4))};
end

%% ==================== 4. 表3：最终位置结果表 ====================

finalXY = stateXY;

table3 = {
    '无人机', '最终极径 / m', '最终极角 / °', '目标极径 / m', '目标极角 / °';
};

for no = 1:9
    idx = no + 1;

    [rhoFinal, thetaFinalDeg] = xy2polarDeg(finalXY(idx, :));

    table3(end+1, :) = { ...
        droneName(no), ...
        sprintf('%.6f', rhoFinal), ...
        sprintf('%.6f', thetaFinalDeg), ...
        sprintf('%.6f', rhoIdeal(idx)), ...
        sprintf('%.6f', thetaIdealDeg(idx))};
end

%% ==================== 5. 保存为 Excel ====================

outFolder = 'Q1_3_tables';
if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

excelFile = fullfile(outFolder, 'Q1_3_tables.xlsx');

writecell(table1, excelFile, 'Sheet', '表1_三轮发射与接收安排');
writecell(table2, excelFile, 'Sheet', '表2_误差变化');
writecell(table3, excelFile, 'Sheet', '表3_最终位置结果');

%% ==================== 6. 保存为 PNG 图片 ====================

saveTableAsImage(table1, ...
    fullfile(outFolder, '表1_三轮发射与接收安排.png'), ...
    '表1  三轮发射与接收安排', ...
    [1200, 360]);

saveTableAsImage(table2, ...
    fullfile(outFolder, '表2_各轮调整后误差变化.png'), ...
    '表2  各轮调整后误差变化', ...
    [1100, 420]);

saveTableAsImage(table3, ...
    fullfile(outFolder, '表3_最终位置结果.png'), ...
    '表3  最终位置结果', ...
    [900, 620]);

%% ==================== 7. 命令行显示 ====================

fprintf('\n表格已生成，保存位置：%s\n', outFolder);
fprintf('Excel文件：%s\n\n', excelFile);

disp('========== 表1：三轮发射与接收安排 ==========');
disp(table1);

disp('========== 表2：各轮调整后误差变化 ==========');
disp(table2);

disp('========== 表3：最终位置结果 ==========');
disp(table3);

%% ========================================================================
%                              局部函数
% ========================================================================

function P = polar2xy(rho, theta)
    P = [rho*cos(theta), rho*sin(theta)];
end

function [rho, thetaDeg] = xy2polarDeg(P)
    rho = norm(P);
    thetaDeg = atan2d(P(2), P(1));
    thetaDeg = mod(thetaDeg, 360);

    % 避免 360 显示成 360.000000
    if abs(thetaDeg - 360) < 1e-8
        thetaDeg = 0;
    end
end

function name = droneName(no)
    if no == 0
        name = 'FY00';
    else
        name = sprintf('FY%02d', no);
    end
end

function errors = calcFormationErrors(currentXY, idealXY, thetaIdealDeg, R)

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

function saveTableAsImage(cellData, fileName, tableTitle, figSize)

    fig = figure('Color', 'w', ...
                 'Position', [100, 100, figSize(1), figSize(2)], ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'none');

    % 标题
    annotation(fig, 'textbox', [0, 0.91, 1, 0.08], ...
        'String', tableTitle, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 16, ...
        'FontWeight', 'bold', ...
        'EdgeColor', 'none');

    % 表头和数据
    colNames = cellData(1, :);
    data = cellData(2:end, :);

    % 根据不同表格设置列宽
    nCol = size(cellData, 2);

    if nCol == 4
        colWidth = {90, 260, 420, 360};
    elseif nCol == 5
        colWidth = {140, 190, 190, 190, 220};
    else
        colWidth = 'auto';
    end

    uit = uitable(fig, ...
        'Data', data, ...
        'ColumnName', colNames, ...
        'RowName', [], ...
        'Units', 'normalized', ...
        'Position', [0.03, 0.06, 0.94, 0.82], ...
        'FontSize', 12, ...
        'ColumnWidth', colWidth);

    drawnow;

    try
        exportgraphics(fig, fileName, 'Resolution', 300);
    catch
        saveas(fig, fileName);
    end

    close(fig);
end