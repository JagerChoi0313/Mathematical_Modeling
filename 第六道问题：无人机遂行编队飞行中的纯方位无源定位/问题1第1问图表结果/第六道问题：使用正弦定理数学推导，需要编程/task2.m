%% Q1_2_unknown_id_positioning.m
% 问题1第(2)小问：编号未知发射机条件下的有效定位
% 已知 FY00 和 FY01 发射信号；
% 另外还有 1 架圆周无人机发射信号，但其编号未知。
% 程序通过枚举未知编号，调用第一问定位模型，筛选接收机位置。

clear; clc; close all;

%% ==================== 1. 基本参数 ====================

R = 100;

% FY01~FY09 的理想极角，单位：弧度
thetaIdealDeg = 0:40:320;
thetaIdeal = deg2rad(thetaIdealDeg);

% 表1中给出的初始位置，用于模拟接收角度
rhoActual = [100, 98, 112, 105, 98, 112, 105, 98, 112];

thetaActualDeg = [ ...
    0, ...
    40.10, ...
    80.21, ...
    119.75, ...
    159.86, ...
    199.96, ...
    240.07, ...
    280.17, ...
    320.28];

thetaActual = deg2rad(thetaActualDeg);

% 接收机编号
receiverNo = 2;       % 这里以 FY02 为例

% 实际额外发射机编号
% 注意：这个变量只用于模拟接收角度，求解时程序不知道它是谁
unknownTxActual = 4;  % 这里用 FY04 作为真实额外发射机

% 位置邻域阈值
% 用来表达"接收无人机只是位置略有偏差"
delta = 25;           % 单位：m，可根据实际偏差大小调整

if unknownTxActual == receiverNo
    error('接收机不能同时作为额外发射机，请更换 unknownTxActual。');
end

%% ==================== 2. 构造理想坐标与真实接收位置 ====================

O = [0, 0];                         % FY00
A1 = polar2xy(R, thetaIdeal(1));     % FY01

% 接收机真实位置，仅用于模拟其接收到的角度
Ptrue = polar2xy(rhoActual(receiverNo), thetaActual(receiverNo));

% 实际额外发射机位置，仅用于模拟接收角度
Utrue = polar2xy(R, thetaIdeal(unknownTxActual));

%% ==================== 3. 模拟接收机测得的夹角 ====================
% 接收机知道收到 FY00 和 FY01 的信号；
% 还收到一个未知编号发射机 U 的信号。
%
% alpha_01 = angle FY00-P-FY01
% alpha_0U = angle FY00-P-U
% alpha_1U = angle FY01-P-U

alpha_01 = angle2d(O - Ptrue, A1 - Ptrue);
alpha_0U = angle2d(O - Ptrue, Utrue - Ptrue);
alpha_1U = angle2d(A1 - Ptrue, Utrue - Ptrue);

fprintf('========== 模拟接收夹角 ==========\n');
fprintf('接收机：FY%02d\n', receiverNo);
fprintf('已知发射机：FY00, FY01\n');
fprintf('真实未知发射机：FY%02d（仅用于模拟，求解时不使用）\n\n', unknownTxActual);

fprintf('alpha_01 = angle FY00-P-FY01 = %.6f 度\n', rad2deg(alpha_01));
fprintf('alpha_0U = angle FY00-P-U    = %.6f 度\n', rad2deg(alpha_0U));
fprintf('alpha_1U = angle FY01-P-U    = %.6f 度\n\n', rad2deg(alpha_1U));

%% ==================== 4. 枚举未知发射机编号 ====================
% 未知发射机可能是 FY02~FY09，但接收机自身不可能同时发射，所以排除 receiverNo

candidateTx = setdiff(2:9, receiverNo);

allSolutions = struct( ...
    'hypTx', {}, ...
    'caseName', {}, ...
    'rho', {}, ...
    'theta_deg', {}, ...
    'x', {}, ...
    'y', {}, ...
    'err01_deg', {}, ...
    'err0U_deg', {}, ...
    'err1U_deg', {}, ...
    'distToIdeal', {});

for k = candidateTx

    % 假设未知发射机 U = FYk
    % 此时发射机为 FY00, FY01, FYk
    [validSolutions, ~] = solveBySineCases( ...
        R, ...
        thetaIdeal(1), ...      % FY01
        thetaIdeal(k), ...      % 假设未知发射机 FYk
        alpha_01, ...
        alpha_0U, ...
        alpha_1U, ...
        receiverNo);

    % 记录所有通过角度检验的候选解
    for s = 1:length(validSolutions)

        temp.hypTx = k;
        temp.caseName = validSolutions(s).caseName;
        temp.rho = validSolutions(s).rho;
        temp.theta_deg = validSolutions(s).theta_deg;
        temp.x = validSolutions(s).x;
        temp.y = validSolutions(s).y;
        temp.err01_deg = validSolutions(s).err_i_deg;
        temp.err0U_deg = validSolutions(s).err_j_deg;
        temp.err1U_deg = validSolutions(s).err_ij_deg;
        temp.distToIdeal = validSolutions(s).distToIdeal;

        allSolutions(end+1) = temp;
    end
end

%% ==================== 5. 输出枚举结果 ====================

fprintf('========== 枚举得到的候选解 ==========\n');

if isempty(allSolutions)
    fprintf('没有任何候选编号能够解释接收到的角度信息。\n');
else
    T = struct2table(allSolutions);
    disp(T);
end

%% ==================== 6. 根据"略有偏差"进行邻域筛选 ====================

if isempty(allSolutions)
    effectiveSolutions = [];
else
    idx = [allSolutions.distToIdeal] <= delta;
    effectiveSolutions = allSolutions(idx);
end

fprintf('\n========== 邻域筛选结果 ==========\n');
fprintf('允许偏差阈值 delta = %.2f m\n', delta);

if isempty(effectiveSolutions)
    fprintf('没有候选解落在接收机理想位置邻域内，无法有效定位。\n');
else
    Teff = struct2table(effectiveSolutions);
    disp(Teff);
end

%% ==================== 7. 判断是否有效定位 ====================

uniqueEffective = uniqueByPosition(effectiveSolutions, 1e-5);

fprintf('\n========== 有效定位判断 ==========\n');

if isempty(uniqueEffective)
    fprintf('结论：m = 1 时未得到有效候选位置。\n');
elseif length(uniqueEffective) == 1

    bestSolution = uniqueEffective(1);

    fprintf('结论：m = 1 时可以实现有效定位。\n');
    fprintf('识别出的未知发射机编号：FY%02d\n', bestSolution.hypTx);
    fprintf('接收机 FY%02d 定位结果：\n', receiverNo);
    fprintf('rho   = %.6f m\n', bestSolution.rho);
    fprintf('theta = %.6f 度\n', bestSolution.theta_deg);
    fprintf('x     = %.6f m\n', bestSolution.x);
    fprintf('y     = %.6f m\n', bestSolution.y);

    fprintf('\n与模拟真实值对比：\n');
    fprintf('真实 rho   = %.6f m\n', rhoActual(receiverNo));
    fprintf('真实 theta = %.6f 度\n', thetaActualDeg(receiverNo));

else
    fprintf('结论：m = 1 时仍存在多个有效候选位置，不能唯一定位。\n');
end

%% ==================== 8. 画图展示枚举结果 ====================

figure('Color', 'w');
hold on; grid on; axis equal;

t = linspace(0, 2*pi, 500);
plot(R*cos(t), R*sin(t), 'k--', 'LineWidth', 1.2);

% 画 FY00
plot(0, 0, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 7);
text(3, 3, 'FY00', 'FontSize', 10);

% 画理想圆周无人机
for k = 1:9
    Pk = polar2xy(R, thetaIdeal(k));
    plot(Pk(1), Pk(2), 'ko', 'MarkerSize', 5);
    text(Pk(1)+2, Pk(2)+2, sprintf('FY%02d', k), 'FontSize', 8);
end

% 画真实接收机位置
plot(Ptrue(1), Ptrue(2), 'k^', 'MarkerSize', 10, 'LineWidth', 1.8);
text(Ptrue(1)+3, Ptrue(2)+3, '真实接收位置', 'FontSize', 10);

% 画所有候选位置
for s = 1:length(allSolutions)
    plot(allSolutions(s).x, allSolutions(s).y, 'kx', ...
        'MarkerSize', 9, 'LineWidth', 1.5);
    text(allSolutions(s).x+2, allSolutions(s).y-4, ...
        sprintf('假设U=FY%02d', allSolutions(s).hypTx), ...
        'FontSize', 8);
end

% 画有效候选位置
for s = 1:length(effectiveSolutions)
    plot(effectiveSolutions(s).x, effectiveSolutions(s).y, 'ko', ...
        'MarkerSize', 13, 'LineWidth', 1.8);
end

xlabel('x / m');
ylabel('y / m');
title('问题1第(2)小问：未知编号发射机枚举定位结果');

legend('理想圆周', 'FY00', '理想圆周无人机', ...
    '真实接收位置', '枚举候选位置', '有效候选位置', ...
    'Location', 'bestoutside');

%% ========================================================================
%                              局部函数
% ========================================================================

function [validSolutions, bestSolution] = solveBySineCases( ...
    R, theta_i, theta_j, alpha_i, alpha_j, alpha_ij, receiverNo)
% 基于第一问正弦定理模型，求接收机候选位置

    tol = deg2rad(1e-6);

    % 保证 theta_i < theta_j，方便分情况讨论
    if theta_i > theta_j
        temp = theta_i;
        theta_i = theta_j;
        theta_j = temp;

        temp = alpha_i;
        alpha_i = alpha_j;
        alpha_j = temp;
    end

    si = sin(alpha_i);
    sj = sin(alpha_j);

    if abs(si) < 1e-12 || abs(sj) < 1e-12
        validSolutions = [];
        bestSolution = [];
        return;
    end

    allCandidates = struct('caseName', {}, 'rho', {}, 'theta', {});

    %% ---------- 情况一：theta < theta_i < theta_j ----------
    N1 = sj * sin(alpha_i + theta_i) - si * sin(alpha_j + theta_j);
    D1 = sj * cos(alpha_i + theta_i) - si * cos(alpha_j + theta_j);
    theta0 = atan2(N1, D1);

    allCandidates = addCaseCandidates( ...
        allCandidates, ...
        'case1_left', ...
        theta0, ...
        @(theta) theta < theta_i, ...
        @(theta) R * sin(alpha_i + theta_i - theta) / si);

    %% ---------- 情况二：theta_i < theta < theta_j ----------
    N2 = si * sin(alpha_j + theta_j) - sj * sin(alpha_i - theta_i);
    D2 = sj * cos(alpha_i - theta_i) + si * cos(alpha_j + theta_j);
    theta0 = atan2(N2, D2);

    allCandidates = addCaseCandidates( ...
        allCandidates, ...
        'case2_middle', ...
        theta0, ...
        @(theta) theta > theta_i && theta < theta_j, ...
        @(theta) R * sin(alpha_i + theta - theta_i) / si);

    %% ---------- 情况三：theta_i < theta_j < theta ----------
    N3 = si * sin(alpha_j - theta_j) - sj * sin(alpha_i - theta_i);
    D3 = sj * cos(alpha_i - theta_i) - si * cos(alpha_j - theta_j);
    theta0 = atan2(N3, D3);

    allCandidates = addCaseCandidates( ...
        allCandidates, ...
        'case3_right', ...
        theta0, ...
        @(theta) theta > theta_j, ...
        @(theta) R * sin(alpha_i + theta - theta_i) / si);

    %% ---------- 用三个角度检验候选解 ----------
    O  = [0, 0];
    Ai = polar2xy(R, theta_i);
    Aj = polar2xy(R, theta_j);

    validSolutions = struct( ...
        'caseName', {}, ...
        'rho', {}, ...
        'theta_deg', {}, ...
        'x', {}, ...
        'y', {}, ...
        'err_i_deg', {}, ...
        'err_j_deg', {}, ...
        'err_ij_deg', {}, ...
        'distToIdeal', {});

    thetaIdealReceiver = 2*pi/9*(receiverNo - 1);
    Pideal = polar2xy(R, thetaIdealReceiver);

    for k = 1:length(allCandidates)

        rho_k = allCandidates(k).rho;
        theta_k = allCandidates(k).theta;

        if rho_k <= 0
            continue;
        end

        Pk = polar2xy(rho_k, theta_k);

        alpha_i_hat  = angle2d(O  - Pk, Ai - Pk);
        alpha_j_hat  = angle2d(O  - Pk, Aj - Pk);
        alpha_ij_hat = angle2d(Ai - Pk, Aj - Pk);

        err_i  = abs(alpha_i_hat  - alpha_i);
        err_j  = abs(alpha_j_hat  - alpha_j);
        err_ij = abs(alpha_ij_hat - alpha_ij);

        if max([err_i, err_j, err_ij]) < tol

            v.caseName = allCandidates(k).caseName;
            v.rho = rho_k;
            v.theta_deg = rad2deg(wrap2pi_local(theta_k));
            v.x = Pk(1);
            v.y = Pk(2);
            v.err_i_deg = rad2deg(err_i);
            v.err_j_deg = rad2deg(err_j);
            v.err_ij_deg = rad2deg(err_ij);
            v.distToIdeal = norm(Pk - Pideal);

            validSolutions(end+1) = v;
        end
    end

    validSolutions = removeDuplicateSolutions(validSolutions);

    if isempty(validSolutions)
        bestSolution = [];
    else
        [~, idx] = min([validSolutions.distToIdeal]);
        bestSolution = validSolutions(idx);
    end
end

function candidates = addCaseCandidates(candidates, caseName, theta0, conditionFun, rhoFun)
% 因为 tan(theta) 有 pi 周期，所以考虑 theta0 + n*pi

    for n = -4:4
        theta = theta0 + n*pi;

        if conditionFun(theta)
            rho = rhoFun(theta);

            if isfinite(rho) && isreal(rho) && rho > 0
                c.caseName = caseName;
                c.rho = rho;
                c.theta = theta;
                candidates(end+1) = c;
            end
        end
    end
end

function P = polar2xy(rho, theta)
    P = [rho*cos(theta), rho*sin(theta)];
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

function a = wrap2pi_local(a)
    a = mod(a, 2*pi);

    if a < 0
        a = a + 2*pi;
    end
end

function solutions = removeDuplicateSolutions(solutions)

    if isempty(solutions)
        return;
    end

    keep = true(1, length(solutions));

    for i = 1:length(solutions)
        if ~keep(i)
            continue;
        end

        for j = i+1:length(solutions)

            dx = solutions(i).x - solutions(j).x;
            dy = solutions(i).y - solutions(j).y;

            if sqrt(dx^2 + dy^2) < 1e-6
                keep(j) = false;
            end
        end
    end

    solutions = solutions(keep);
end

function uniqueSolutions = uniqueByPosition(solutions, posTol)

    uniqueSolutions = struct( ...
        'hypTx', {}, ...
        'caseName', {}, ...
        'rho', {}, ...
        'theta_deg', {}, ...
        'x', {}, ...
        'y', {}, ...
        'err01_deg', {}, ...
        'err0U_deg', {}, ...
        'err1U_deg', {}, ...
        'distToIdeal', {});

    if isempty(solutions)
        return;
    end

    for i = 1:length(solutions)

        isNew = true;

        for j = 1:length(uniqueSolutions)
            d = sqrt((solutions(i).x - uniqueSolutions(j).x)^2 + ...
                     (solutions(i).y - uniqueSolutions(j).y)^2);

            if d < posTol
                isNew = false;
                break;
            end
        end

        if isNew
            uniqueSolutions(end+1) = solutions(i);
        end
    end
end