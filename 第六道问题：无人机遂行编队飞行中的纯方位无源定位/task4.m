%% Q2_cone_formation_adjustment.m
% 第二问：锥形编队无人机纯方位无源定位与位置调整
% 建模思路：
% 1. 建立锥形编队理想坐标；
% 2. 给理想坐标加入小范围初始偏差；
% 3. 选择分布较开的无人机作为发射机；
% 4. 其余无人机根据接收方向角进行位置估计；
% 5. 根据估计位置与理想位置计算调整量；
% 6. 多轮调整后评价锥形编队误差。

clear; clc; close all;

%% ==================== 1. 基本参数 ====================

d = 50;                       % 锥形编队中直线上相邻无人机间距
lambda = 1.0;                 % 调整比例，lambda=1 表示直接调整到理想位置
N = 15;                       % 无人机数量

rng(2022);                    % 固定随机种子，保证结果可复现

%% ==================== 2. 生成锥形编队理想坐标 ====================

[idealXY, layerNo, posInLayer, edges, lineSets] = generateConeFormation(d);

%% ==================== 3. 生成初始偏差位置 ====================
% 第二问没有给具体初始偏差数据，因此这里人为加入小范围扰动进行仿真。
% 为了保证整体队形有绝对参考，第一轮作为外轮廓基准的 FY01、FY11、FY15
% 初始位置设为理想位置，其余无人机加入扰动。

perturbRange = 6;             % 初始偏差范围，单位 m
initialXY = idealXY + (2*rand(N,2)-1) * perturbRange;

anchorSet = [1, 11, 15];      % 第一轮基准点
initialXY(anchorSet, :) = idealXY(anchorSet, :);

currentXY = initialXY;

%% ==================== 4. 三轮发射方案 ====================
% 每轮选择 3 架不共线且分布较开的无人机作为发射机

txGroups = { ...
    [1, 11, 15], ...          % 第1轮：外轮廓三角骨架
    [2, 6, 14],  ...          % 第2轮：已调整后的分散节点
    [3, 7, 13]   ...          % 第3轮：复核节点
};

numRounds = length(txGroups);

%% ==================== 5. 输出理想坐标表 ====================

droneNames = strings(N,1);
for i = 1:N
    droneNames(i) = droneName(i);
end

T_ideal = table( ...
    droneNames, ...
    layerNo(:), ...
    posInLayer(:), ...
    idealXY(:,1), ...
    idealXY(:,2), ...
    'VariableNames', {'Drone','Layer','PositionInLayer','IdealX_m','IdealY_m'});

disp('========== 锥形编队理想坐标 ==========');
disp(T_ideal);

%% ==================== 6. 初始误差 ====================

errorHistory = zeros(numRounds+1, 4);
% 列含义：最大位置误差、平均位置误差、最大相邻距离误差、最大共线误差

errorHistory(1,:) = calcConeErrors(currentXY, idealXY, edges, lineSets, d);

fprintf('\n========== 初始锥形编队误差 ==========\n');
printConeErrors(errorHistory(1,:));

%% ==================== 7. 多轮调整 ====================

adjustRecords = struct( ...
    'Round', {}, ...
    'TxSet', {}, ...
    'Receiver', {}, ...
    'EstX_m', {}, ...
    'EstY_m', {}, ...
    'AdjustX_m', {}, ...
    'AdjustY_m', {}, ...
    'ErrBefore_m', {}, ...
    'ErrAfter_m', {});

stateHistory = cell(numRounds+1, 1);
stateHistory{1} = currentXY;

for r = 1:numRounds

    txSet = txGroups{r};
    rxSet = setdiff(1:N, txSet);

    fprintf('\n========== 第 %d 轮调整 ==========\n', r);
    fprintf('发射无人机：%s\n', droneSetName(txSet));
    fprintf('接收并调整无人机：%s\n\n', droneSetName(rxSet));

    txXY = currentXY(txSet, :);

    for k = 1:length(rxSet)

        rxNo = rxSet(k);

        % 当前真实位置，仅用于仿真生成接收方向角
        Ptrue = currentXY(rxNo, :);

        % 1. 根据当前几何关系模拟接收到的方向角
        [angleObs, pairIdx] = getObservedAngles(Ptrue, txXY);

        % 2. 仅根据方向角信息估计接收机位置
        % 初值取该无人机理想位置附近，符合"初始位置略有偏差"的条件
        initGuess = idealXY(rxNo, :);

        Pest = estimatePositionByAngles(txXY, angleObs, pairIdx, initGuess, d);

        % 3. 计算调整向量
        target = idealXY(rxNo, :);
        adjustVec = lambda * (target - Pest);

        errBefore = norm(currentXY(rxNo,:) - target);

        % 4. 执行调整
        currentXY(rxNo,:) = currentXY(rxNo,:) + adjustVec;

        errAfter = norm(currentXY(rxNo,:) - target);

        % 5. 记录
        rec.Round = r;
        rec.TxSet = droneSetName(txSet);
        rec.Receiver = droneName(rxNo);
        rec.EstX_m = Pest(1);
        rec.EstY_m = Pest(2);
        rec.AdjustX_m = adjustVec(1);
        rec.AdjustY_m = adjustVec(2);
        rec.ErrBefore_m = errBefore;
        rec.ErrAfter_m = errAfter;

        adjustRecords(end+1) = rec;

        fprintf('%s: 估计位置 (%.6f, %.6f)，调整量 (%.6f, %.6f)，调整后误差 %.6e m\n', ...
            droneName(rxNo), Pest(1), Pest(2), adjustVec(1), adjustVec(2), errAfter);
    end

    stateHistory{r+1} = currentXY;
    errorHistory(r+1,:) = calcConeErrors(currentXY, idealXY, edges, lineSets, d);

    fprintf('\n第 %d 轮后锥形编队误差：\n', r);
    printConeErrors(errorHistory(r+1,:));
end

%% ==================== 8. 输出调整记录表 ====================

fprintf('\n========== 各轮调整记录 ==========\n');
T_adjust = struct2table(adjustRecords);
disp(T_adjust);

%% ==================== 9. 输出最终位置表 ====================

posErr = vecnorm(currentXY - idealXY, 2, 2);

T_final = table( ...
    droneNames, ...
    initialXY(:,1), initialXY(:,2), ...
    currentXY(:,1), currentXY(:,2), ...
    idealXY(:,1), idealXY(:,2), ...
    posErr, ...
    'VariableNames', {'Drone','InitialX_m','InitialY_m', ...
                      'FinalX_m','FinalY_m', ...
                      'IdealX_m','IdealY_m','PositionError_m'});

fprintf('\n========== 最终位置结果 ==========\n');
disp(T_final);

%% ==================== 10. 输出误差变化表 ====================

stageNames = strings(numRounds+1,1);
stageNames(1) = "初始状态";
for r = 1:numRounds
    stageNames(r+1) = "第" + string(r) + "轮后";
end

T_error = table( ...
    stageNames, ...
    errorHistory(:,1), ...
    errorHistory(:,2), ...
    errorHistory(:,3), ...
    errorHistory(:,4), ...
    'VariableNames', {'Stage','MaxPositionError_m','MeanPositionError_m', ...
                      'MaxAdjacentDistanceError_m','MaxCollinearityError_m'});

fprintf('\n========== 各阶段误差变化 ==========\n');
disp(T_error);

%% ==================== 11. 保存结果到 Excel ====================

outFolder = 'Q2_cone_results';
if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

excelFile = fullfile(outFolder, 'Q2_cone_results.xlsx');

writetable(T_ideal, excelFile, 'Sheet', '理想坐标');
writetable(T_adjust, excelFile, 'Sheet', '调整记录');
writetable(T_final, excelFile, 'Sheet', '最终位置');
writetable(T_error, excelFile, 'Sheet', '误差变化');

fprintf('\n结果表格已保存至：%s\n', excelFile);

%% ==================== 12. 绘图 ====================

% 图1：初始位置、理想位置、最终位置对比
fig1 = figure('Color','w','Position',[100,100,850,720]);
hold on; grid on; axis equal;

drawConeEdges(idealXY, edges, 'k--', 1.0);
drawConeEdges(initialXY, edges, 'k:', 0.8);

plot(idealXY(:,1), idealXY(:,2), 'ko', ...
    'MarkerSize', 7, 'LineWidth', 1.2);

plot(initialXY(:,1), initialXY(:,2), 'kx', ...
    'MarkerSize', 9, 'LineWidth', 1.5);

plot(currentXY(:,1), currentXY(:,2), 'k^', ...
    'MarkerSize', 8, 'LineWidth', 1.5);

for i = 1:N
    text(currentXY(i,1)+2, currentXY(i,2)+2, droneName(i), 'FontSize', 9);
end

xlabel('x / m');
ylabel('y / m');
title('锥形编队调整前后位置对比图');
legend('理想锥形边', '初始锥形边', '理想位置', '初始位置', '最终位置', ...
    'Location','bestoutside');

saveFigure(fig1, fullfile(outFolder, '图1_锥形编队调整前后位置对比图.png'));

% 图2：三轮发射无人机分组图
fig2 = figure('Color','w','Position',[100,100,850,720]);
hold on; grid on; axis equal;

drawConeEdges(idealXY, edges, 'k--', 1.0);
plot(idealXY(:,1), idealXY(:,2), 'ko', ...
    'MarkerSize', 6, 'LineWidth', 1.0);

markers = {'s','^','d'};

for r = 1:numRounds
    txSet = txGroups{r};

    for k = 1:length(txSet)
        no = txSet(k);
        plot(idealXY(no,1), idealXY(no,2), ...
            markers{r}, ...
            'MarkerSize', 12, ...
            'LineWidth', 1.8, ...
            'Color', 'k');
    end
end

for i = 1:N
    text(idealXY(i,1)+2, idealXY(i,2)+2, droneName(i), 'FontSize', 9);
end

text(min(idealXY(:,1))-10, min(idealXY(:,2))-25, ...
    sprintf(['S_1 = {FY01, FY11, FY15}\n', ...
             'S_2 = {FY02, FY06, FY14}\n', ...
             'S_3 = {FY03, FY07, FY13}']), ...
    'FontSize', 11, ...
    'BackgroundColor', 'w', ...
    'EdgeColor', 'k', ...
    'Margin', 5);

xlabel('x / m');
ylabel('y / m');
title('锥形编队三轮发射无人机分组示意图');
legend('理想锥形边', '理想位置', '第1轮发射机', '第2轮发射机', '第3轮发射机', ...
    'Location','bestoutside');

saveFigure(fig2, fullfile(outFolder, '图2_锥形编队发射分组示意图.png'));

% 图3：误差变化图
fig3 = figure('Color','w','Position',[100,100,900,600]);
hold on; grid on;

x = 1:(numRounds+1);

plot(x, errorHistory(:,1), '-o', 'LineWidth', 1.8, 'MarkerSize', 7);
plot(x, errorHistory(:,3), '-s', 'LineWidth', 1.8, 'MarkerSize', 7);
plot(x, errorHistory(:,4), '-^', 'LineWidth', 1.8, 'MarkerSize', 7);

xticks(x);
xticklabels(stageNames);

xlabel('调整阶段');
ylabel('误差 / m');
title('锥形编队多轮调整误差变化图');
legend('最大位置误差', '最大相邻距离误差', '最大共线误差', ...
    'Location','northeast');

saveFigure(fig3, fullfile(outFolder, '图3_锥形编队误差变化图.png'));

fprintf('图片已保存至文件夹：%s\n', outFolder);

%% ========================================================================
%                              局部函数
% ========================================================================

function [idealXY, layerNo, posInLayer, edges, lineSets] = generateConeFormation(d)

    N = 15;
    h = sqrt(3)/2 * d;

    idealXY = zeros(N, 2);
    layerNo = zeros(N, 1);
    posInLayer = zeros(N, 1);

    idxMat = zeros(5, 5);

    idx = 1;
    for r = 1:5
        for j = 1:r
            idealXY(idx, :) = [-(r-1)*h, (j-(r+1)/2)*d];
            layerNo(idx) = r;
            posInLayer(idx) = j;
            idxMat(r,j) = idx;
            idx = idx + 1;
        end
    end

    % 相邻边集：同层相邻、左斜向相邻、右斜向相邻
    edges = [];

    for r = 1:5
        for j = 1:r

            now = idxMat(r,j);

            % 同层相邻
            if j < r
                edges(end+1,:) = [now, idxMat(r,j+1)];
            end

            % 与下一层相邻
            if r < 5
                edges(end+1,:) = [now, idxMat(r+1,j)];
                edges(end+1,:) = [now, idxMat(r+1,j+1)];
            end
        end
    end

    edges = unique(sort(edges,2), 'rows');

    % 共线结构集合
    lineSets = {};

    % 1. 同层直线
    for r = 1:5
        ids = idxMat(r, 1:r);
        if length(ids) >= 3
            lineSets{end+1} = ids;
        end
    end

    % 2. j 不变的斜线
    for j = 1:5
        ids = [];
        for r = j:5
            if idxMat(r,j) ~= 0
                ids(end+1) = idxMat(r,j);
            end
        end
        if length(ids) >= 3
            lineSets{end+1} = ids;
        end
    end

    % 3. j-r 不变的斜线
    for c = -4:0
        ids = [];
        for r = 1:5
            j = r + c;
            if j >= 1 && j <= r && idxMat(r,j) ~= 0
                ids(end+1) = idxMat(r,j);
            end
        end
        if length(ids) >= 3
            lineSets{end+1} = ids;
        end
    end
end

function [angleObs, pairIdx] = getObservedAngles(P, txXY)

    nTx = size(txXY, 1);
    pairIdx = nchoosek(1:nTx, 2);
    angleObs = zeros(size(pairIdx,1), 1);

    for k = 1:size(pairIdx,1)
        a = pairIdx(k,1);
        b = pairIdx(k,2);

        v1 = txXY(a,:) - P;
        v2 = txXY(b,:) - P;

        angleObs(k) = angle2d(v1, v2);
    end
end

function Pest = estimatePositionByAngles(txXY, angleObs, pairIdx, initGuess, d)

    % 多初值搜索，避免陷入局部极小值
    offsets = [
         0,    0;
         0.2*d, 0;
        -0.2*d, 0;
         0,  0.2*d;
         0, -0.2*d;
         0.2*d,  0.2*d;
         0.2*d, -0.2*d;
        -0.2*d,  0.2*d;
        -0.2*d, -0.2*d;
         0.4*d, 0;
        -0.4*d, 0;
         0,  0.4*d;
         0, -0.4*d];

    startPoints = initGuess + offsets;

    options = optimset( ...
        'Display', 'off', ...
        'TolX', 1e-10, ...
        'TolFun', 1e-12, ...
        'MaxIter', 5000, ...
        'MaxFunEvals', 10000);

    bestObj = inf;
    bestTie = inf;
    Pest = initGuess;

    for s = 1:size(startPoints,1)

        p0 = startPoints(s,:);

        objFun = @(p) angleObjective(p, txXY, angleObs, pairIdx);

        [pEst, fval] = fminsearch(objFun, p0, options);

        % 若多个解角度残差都很小，选更接近理想位置的解
        tieValue = norm(pEst - initGuess);

        if fval < bestObj - 1e-14 || ...
           (abs(fval - bestObj) <= 1e-14 && tieValue < bestTie)

            bestObj = fval;
            bestTie = tieValue;
            Pest = pEst;
        end
    end
end

function obj = angleObjective(P, txXY, angleObs, pairIdx)

    obj = 0;

    for k = 1:size(pairIdx,1)

        a = pairIdx(k,1);
        b = pairIdx(k,2);

        v1 = txXY(a,:) - P;
        v2 = txXY(b,:) - P;

        pred = angle2d(v1, v2);

        if isnan(pred)
            obj = obj + 1e6;
        else
            diff = pred - angleObs(k);
            obj = obj + diff^2;
        end
    end
end

function ang = angle2d(u, v)

    nu = norm(u);
    nv = norm(v);

    if nu < 1e-12 || nv < 1e-12
        ang = NaN;
        return;
    end

    c = dot(u,v)/(nu*nv);
    c = max(min(c,1),-1);

    ang = acos(c);
end

function errors = calcConeErrors(currentXY, idealXY, edges, lineSets, d)

    posErr = vecnorm(currentXY - idealXY, 2, 2);

    maxPosErr = max(posErr);
    meanPosErr = mean(posErr);

    % 相邻距离误差
    adjErr = zeros(size(edges,1),1);
    for k = 1:size(edges,1)
        i = edges(k,1);
        j = edges(k,2);
        adjErr(k) = abs(norm(currentXY(i,:) - currentXY(j,:)) - d);
    end
    maxAdjErr = max(adjErr);

    % 共线误差
    maxLineErr = 0;

    for s = 1:length(lineSets)
        ids = lineSets{s};

        A = currentXY(ids(1),:);
        B = currentXY(ids(end),:);

        for k = 2:length(ids)-1
            P = currentXY(ids(k),:);
            distVal = pointToLineDistance(P, A, B);
            maxLineErr = max(maxLineErr, distVal);
        end
    end

    errors = [maxPosErr, meanPosErr, maxAdjErr, maxLineErr];
end

function d0 = pointToLineDistance(P, A, B)

    AB = B - A;
    AP = P - A;

    if norm(AB) < 1e-12
        d0 = norm(AP);
        return;
    end

    d0 = abs(det([AB; AP])) / norm(AB);
end

function printConeErrors(errors)

    fprintf('最大位置误差        = %.6f m\n', errors(1));
    fprintf('平均位置误差        = %.6f m\n', errors(2));
    fprintf('最大相邻距离误差    = %.6f m\n', errors(3));
    fprintf('最大共线误差        = %.6f m\n', errors(4));
end

function drawConeEdges(XY, edges, lineStyle, lineWidth)

    for k = 1:size(edges,1)
        i = edges(k,1);
        j = edges(k,2);

        plot([XY(i,1), XY(j,1)], [XY(i,2), XY(j,2)], ...
            lineStyle, 'Color', 'k', 'LineWidth', lineWidth);
    end
end

function name = droneName(no)

    name = sprintf('FY%02d', no);
end

function str = droneSetName(setNos)

    names = cell(1, length(setNos));

    for k = 1:length(setNos)
        names{k} = droneName(setNos(k));
    end

    str = strjoin(names, ', ');
end

function saveFigure(figHandle, fileName)

    try
        exportgraphics(figHandle, fileName, 'Resolution', 300);
    catch
        print(figHandle, fileName, '-dpng', '-r300');
    end
end