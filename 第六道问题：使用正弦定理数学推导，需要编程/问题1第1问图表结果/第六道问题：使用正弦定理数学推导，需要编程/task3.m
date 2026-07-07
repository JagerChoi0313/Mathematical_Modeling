%% Q1_3_formation_adjustment.m
% 问题1第(3)小问：圆形无人机编队多轮调整方案
% 思路：
% 1. 用表1初始位置生成无人机当前状态；
% 2. 每轮选择 FY00 和圆周上最多3架无人机发射信号；
% 3. 其余无人机根据接收到的方向角信息估计当前位置；
% 4. 根据估计位置与理想位置的偏差进行调整；
% 5. 多轮调整后，使9架圆周无人机均匀分布在半径100m的圆周上。

clear; clc; close all;

%% ==================== 1. 基本参数 ====================

R = 100;                      % 目标圆形编队半径
lambda = 1.0;                 % 调整比例，lambda=1 表示一次调整到理想位置

% 无人机编号：FY00~FY09
droneNos = 0:9;

% 理想极角，FY00 的角度无意义，这里设为0
thetaIdealDeg = zeros(1, 10);
for i = 1:9
    thetaIdealDeg(i+1) = 40 * (i-1);
end
thetaIdeal = deg2rad(thetaIdealDeg);

% 理想半径
rhoIdeal = zeros(1, 10);
rhoIdeal(1) = 0;
rhoIdeal(2:10) = R;

% 表1给出的初始极坐标
rhoInit = [ ...
    0, ...
    100, ...
    98, ...
    112, ...
    105, ...
    98, ...
    112, ...
    105, ...
    98, ...
    112];

thetaInitDeg = [ ...
    0, ...
    0, ...
    40.10, ...
    80.21, ...
    119.75, ...
    159.86, ...
    199.96, ...
    240.07, ...
    280.17, ...
    320.28];

thetaInit = deg2rad(thetaInitDeg);

% 初始直角坐标
initialXY = zeros(10, 2);
idealXY   = zeros(10, 2);

for idx = 1:10
    initialXY(idx, :) = polar2xy(rhoInit(idx), thetaInit(idx));
    idealXY(idx, :)   = polar2xy(rhoIdeal(idx), thetaIdeal(idx));
end

% 当前状态从初始位置开始
currentXY = initialXY;

%% ==================== 2. 设计多轮发射方案 ====================
% 每轮都选择 FY00 和圆周上最多3架无人机发射信号

txGroups = { ...
    [0, 1, 4, 7], ...     % 第1轮：FY00, FY01, FY04, FY07
    [0, 2, 5, 8], ...     % 第2轮：FY00, FY02, FY05, FY08
    [0, 3, 6, 9]  ...     % 第3轮：FY00, FY03, FY06, FY09
};

numRounds = length(txGroups);

%% ==================== 3. 输出初始误差 ====================

fprintf('========== 初始编队误差 ==========\n');
printFormationErrors(initialXY, idealXY, thetaIdealDeg, R);

%% ==================== 4. 多轮调整 ====================

adjustRecords = struct( ...
    'round', {}, ...
    'txSet', {}, ...
    'receiver', {}, ...
    'rho_est', {}, ...
    'theta_est_deg', {}, ...
    'dx', {}, ...
    'dy', {}, ...
    'err_before', {}, ...
    'err_after', {});

for r = 1:numRounds

    txSet = txGroups{r};                    % 本轮发射机编号
    rxSet = setdiff(1:9, txSet);            % 圆周上未发射的无人机作为接收机

    fprintf('\n========== 第 %d 轮调整 ==========\n', r);
    fprintf('发射无人机：%s\n', droneSetName(txSet));
    fprintf('接收并调整无人机：%s\n\n', droneSetName(rxSet));

    % 当前发射机坐标
    txXY = zeros(length(txSet), 2);
    for t = 1:length(txSet)
        txXY(t, :) = currentXY(txSet(t)+1, :);
    end

    % 对每架接收机进行定位和调整
    for rr = 1:length(rxSet)

        rxNo = rxSet(rr);
        rxIdx = rxNo + 1;

        Ptrue = currentXY(rxIdx, :);

        % 1. 根据当前几何关系模拟接收无人机获得的方向角
        [angleObs, pairIdx] = getObservedAngles(Ptrue, txXY);

        % 2. 仅根据方向角信息估计接收机位置
        % 初值取该无人机理想位置附近，符合"位置略有偏差"
        initGuess = idealXY(rxIdx, :);

        Pest = estimatePositionByAngles(txXY, angleObs, pairIdx, initGuess, R);

        % 3. 根据估计位置计算调整向量
        target = idealXY(rxIdx, :);

        adjustVec = lambda * (target - Pest);

        % 4. 执行调整
        errBefore = norm(currentXY(rxIdx, :) - target);

        currentXY(rxIdx, :) = currentXY(rxIdx, :) + adjustVec;

        errAfter = norm(currentXY(rxIdx, :) - target);

        % 5. 保存记录
        [rhoEst, thetaEstDeg] = xy2polarDeg(Pest);

        rec.round = r;
        rec.txSet = droneSetName(txSet);
        rec.receiver = droneName(rxNo);
        rec.rho_est = rhoEst;
        rec.theta_est_deg = thetaEstDeg;
        rec.dx = adjustVec(1);
        rec.dy = adjustVec(2);
        rec.err_before = errBefore;
        rec.err_after = errAfter;

        adjustRecords(end+1) = rec;

        fprintf('%s: 估计 rho = %.6f m, theta = %.6f°, 调整量 dx = %.6f, dy = %.6f, 调整后误差 = %.6e\n', ...
            droneName(rxNo), rhoEst, thetaEstDeg, adjustVec(1), adjustVec(2), errAfter);
    end

    fprintf('\n第 %d 轮后编队误差：\n', r);
    printFormationErrors(currentXY, idealXY, thetaIdealDeg, R);
end

%% ==================== 5. 输出调整记录表 ====================

fprintf('\n========== 各轮调整记录 ==========\n');

if ~isempty(adjustRecords)
    T_adjust = struct2table(adjustRecords);
    disp(T_adjust);
end

%% ==================== 6. 输出最终位置表 ====================

summaryRows = struct( ...
    'drone', {}, ...
    'rho_initial', {}, ...
    'theta_initial_deg', {}, ...
    'rho_final', {}, ...
    'theta_final_deg', {}, ...
    'rho_target', {}, ...
    'theta_target_deg', {}, ...
    'pos_error', {});

for no = 0:9
    idx = no + 1;

    [rhoF, thetaFDeg] = xy2polarDeg(currentXY(idx, :));
    posErr = norm(currentXY(idx, :) - idealXY(idx, :));

    row.drone = droneName(no);
    row.rho_initial = rhoInit(idx);
    row.theta_initial_deg = thetaInitDeg(idx);
    row.rho_final = rhoF;
    row.theta_final_deg = thetaFDeg;
    row.rho_target = rhoIdeal(idx);
    row.theta_target_deg = thetaIdealDeg(idx);
    row.pos_error = posErr;

    summaryRows(end+1) = row;
end

fprintf('\n========== 最终位置结果 ==========\n');
T_final = struct2table(summaryRows);
disp(T_final);

fprintf('\n========== 最终编队误差 ==========\n');
printFormationErrors(currentXY, idealXY, thetaIdealDeg, R);

%% ==================== 7. 绘图 ====================

figure('Color', 'w');
hold on; grid on; axis equal;

t = linspace(0, 2*pi, 500);
plot(R*cos(t), R*sin(t), 'k--', 'LineWidth', 1.2);

% 初始位置
plot(initialXY(:,1), initialXY(:,2), 'kx', ...
    'MarkerSize', 9, 'LineWidth', 1.5);

% 理想位置
plot(idealXY(:,1), idealXY(:,2), 'ko', ...
    'MarkerSize', 7, 'LineWidth', 1.2);

% 最终位置
plot(currentXY(:,1), currentXY(:,2), 'k^', ...
    'MarkerSize', 8, 'LineWidth', 1.5);

% 标注
for no = 0:9
    idx = no + 1;
    text(currentXY(idx,1)+2, currentXY(idx,2)+2, ...
        droneName(no), 'FontSize', 9);
end

xlabel('x / m');
ylabel('y / m');
title('问题1第(3)小问：圆形编队调整前后位置对比');
legend('目标圆周', '初始位置', '理想位置', '最终位置', ...
    'Location', 'bestoutside');

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
end

function [angleObs, pairIdx] = getObservedAngles(P, txXY)
% 计算接收机 P 看到的所有发射机两两之间的夹角

    nTx = size(txXY, 1);
    pairIdx = nchoosek(1:nTx, 2);
    angleObs = zeros(size(pairIdx, 1), 1);

    for k = 1:size(pairIdx, 1)
        a = pairIdx(k, 1);
        b = pairIdx(k, 2);

        v1 = txXY(a, :) - P;
        v2 = txXY(b, :) - P;

        angleObs(k) = angle2d(v1, v2);
    end
end

function Pest = estimatePositionByAngles(txXY, angleObs, pairIdx, initGuess, R)
% 根据方向角信息估计接收机位置
% 使用 fminsearch，不依赖优化工具箱

    % 多初值设置，提高求解稳定性
    [rho0, theta0Deg] = xy2polarDeg(initGuess);

    if rho0 < 1e-6
        rho0 = R;
        theta0Deg = 0;
    end

    thetaStarts = theta0Deg + [-20, -10, 0, 10, 20];
    rhoStarts = [0.8*R, R, 1.2*R];

    startPoints = [];
    for i = 1:length(rhoStarts)
        for j = 1:length(thetaStarts)
            startPoints(end+1, :) = polar2xy(rhoStarts(i), deg2rad(thetaStarts(j)));
        end
    end

    % 加入理想位置初值
    startPoints(end+1, :) = initGuess;

    bestObj = inf;
    Pest = initGuess;

    options = optimset( ...
        'Display', 'off', ...
        'TolX', 1e-10, ...
        'TolFun', 1e-12, ...
        'MaxIter', 5000, ...
        'MaxFunEvals', 10000);

    for s = 1:size(startPoints, 1)

        p0 = startPoints(s, :);

        objFun = @(p) angleObjective(p, txXY, angleObs, pairIdx);

        [pEst, fval] = fminsearch(objFun, p0, options);

        if fval < bestObj
            bestObj = fval;
            Pest = pEst;
        end
    end
end

function obj = angleObjective(P, txXY, angleObs, pairIdx)
% 角度残差目标函数

    obj = 0;

    for k = 1:size(pairIdx, 1)

        a = pairIdx(k, 1);
        b = pairIdx(k, 2);

        v1 = txXY(a, :) - P;
        v2 = txXY(b, :) - P;

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
% 计算二维向量夹角，返回弧度，范围 [0, pi]

    nu = norm(u);
    nv = norm(v);

    if nu < 1e-12 || nv < 1e-12
        ang = NaN;
        return;
    end

    c = dot(u, v) / (nu * nv);
    c = max(min(c, 1), -1);

    ang = acos(c);
end

function name = droneName(no)
    if no == 0
        name = 'FY00';
    else
        name = sprintf('FY%02d', no);
    end
end

function str = droneSetName(setNos)
    names = cell(1, length(setNos));
    for k = 1:length(setNos)
        names{k} = droneName(setNos(k));
    end
    str = strjoin(names, ', ');
end

function printFormationErrors(currentXY, idealXY, thetaIdealDeg, R)
% 输出编队误差指标

    radiusErr = zeros(1, 9);
    angleErr  = zeros(1, 9);
    posErr    = zeros(1, 9);

    for no = 1:9
        idx = no + 1;

        [rhoNow, thetaNowDeg] = xy2polarDeg(currentXY(idx, :));

        radiusErr(no) = abs(rhoNow - R);
        angleErr(no) = abs(wrapTo180Deg(thetaNowDeg - thetaIdealDeg(idx)));
        posErr(no) = norm(currentXY(idx, :) - idealXY(idx, :));
    end

    % 相邻距离误差
    Lstar = 2 * R * sind(20);
    spacingErr = zeros(1, 9);

    for no = 1:9
        idx1 = no + 1;

        if no < 9
            idx2 = no + 2;
        else
            idx2 = 2;  % FY09 与 FY01 相邻
        end

        Lnow = norm(currentXY(idx1, :) - currentXY(idx2, :));
        spacingErr(no) = abs(Lnow - Lstar);
    end

    fprintf('最大半径误差      = %.6f m\n', max(radiusErr));
    fprintf('最大极角误差      = %.6f 度\n', max(angleErr));
    fprintf('最大位置误差      = %.6f m\n', max(posErr));
    fprintf('最大相邻距离误差  = %.6f m\n', max(spacingErr));
end

function a = wrapTo180Deg(a)
% 将角度差归一化到 [-180, 180]

    a = mod(a + 180, 360) - 180;
end