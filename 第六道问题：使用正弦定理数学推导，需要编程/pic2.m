%% draw_Q1_1_figures.m
% 问题1第(1)小问论文配图
% 图1：圆形编队理想位置与初始位置对比
% 图2：基于正弦定理的纯方位定位几何示意图
% 图3：定位结果验证图

clear; clc; close all;

%% ==================== 1. 参数设置 ====================

R = 100;                         % 理想圆形编队半径
thetaIdealDeg = 0:40:320;        % FY01~FY09 理想极角
thetaIdeal = deg2rad(thetaIdealDeg);

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

% 第一小问算例：FY00、FY01、FY04 发射，FY02 接收
tx_i = 1;             % FY01
tx_j = 4;             % FY04
receiverNo = 2;       % FY02

% 输出文件夹
outFolder = 'Q1_1_figures';
if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

%% ==================== 2. 坐标计算 ====================

O = [0, 0];

idealXY = zeros(9, 2);
actualXY = zeros(9, 2);

for k = 1:9
    idealXY(k, :) = polar2xy(R, thetaIdeal(k));
    actualXY(k, :) = polar2xy(rhoActual(k), thetaActual(k));
end

Ai = idealXY(tx_i, :);
Aj = idealXY(tx_j, :);
Ptrue = actualXY(receiverNo, :);

%% ==================== 3. 计算接收夹角 ====================

alpha_i  = angle2d(O  - Ptrue, Ai - Ptrue);
alpha_j  = angle2d(O  - Ptrue, Aj - Ptrue);
alpha_ij = angle2d(Ai - Ptrue, Aj - Ptrue);

fprintf('========== 接收夹角 ==========\n');
fprintf('alpha_i  = %.6f 度\n', rad2deg(alpha_i));
fprintf('alpha_j  = %.6f 度\n', rad2deg(alpha_j));
fprintf('alpha_ij = %.6f 度\n\n', rad2deg(alpha_ij));

%% ==================== 4. 调用定位模型 ====================

[validSolutions, bestSolution] = solveBySineCases( ...
    R, ...
    thetaIdeal(tx_i), ...
    thetaIdeal(tx_j), ...
    alpha_i, ...
    alpha_j, ...
    alpha_ij, ...
    receiverNo);

if isempty(validSolutions)
    error('没有找到有效定位解，请检查角度或发射机编号。');
end

rhoEst = bestSolution.rho;
thetaEst = deg2rad(bestSolution.theta_deg);
Pest = polar2xy(rhoEst, thetaEst);

fprintf('========== 定位结果 ==========\n');
fprintf('rho   = %.6f m\n', rhoEst);
fprintf('theta = %.6f 度\n', bestSolution.theta_deg);
fprintf('x     = %.6f m\n', Pest(1));
fprintf('y     = %.6f m\n', Pest(2));

%% ========================================================================
% 图1：圆形编队理想位置与初始位置对比图
% ========================================================================

figure('Color', 'w');
hold on; grid on; axis equal;

t = linspace(0, 2*pi, 500);
plot(R*cos(t), R*sin(t), 'k--', 'LineWidth', 1.2);

plot(0, 0, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 7);
text(3, 3, 'FY00', 'FontSize', 10);

for k = 1:9
    plot(idealXY(k,1), idealXY(k,2), 'ko', ...
        'MarkerSize', 6, 'LineWidth', 1.2);
    
    plot(actualXY(k,1), actualXY(k,2), 'kx', ...
        'MarkerSize', 8, 'LineWidth', 1.5);
    
    quiver(idealXY(k,1), idealXY(k,2), ...
        actualXY(k,1)-idealXY(k,1), actualXY(k,2)-idealXY(k,2), ...
        0, 'k', 'LineWidth', 0.8, 'MaxHeadSize', 0.8);
    
    text(actualXY(k,1)+2, actualXY(k,2)+2, ...
        sprintf('FY%02d', k), 'FontSize', 9);
end

xlabel('x / m');
ylabel('y / m');
title('圆形编队理想位置与初始位置对比图');

legend('理想圆周', 'FY00', '理想位置', '初始位置', '偏差方向', ...
    'Location', 'bestoutside');

saveFigure(gcf, fullfile(outFolder, '图1_圆形编队理想位置与初始位置对比.png'));

%% ========================================================================
% 图2：基于正弦定理的定位几何示意图
% ========================================================================

figure('Color', 'w');
hold on; grid on; axis equal;

plot(R*cos(t), R*sin(t), 'k--', 'LineWidth', 1.0);

% 点
plot(O(1), O(2), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 7);
plot(Ai(1), Ai(2), 'ks', 'MarkerFaceColor', 'w', 'MarkerSize', 8, 'LineWidth', 1.5);
plot(Aj(1), Aj(2), 'ks', 'MarkerFaceColor', 'w', 'MarkerSize', 8, 'LineWidth', 1.5);
plot(Ptrue(1), Ptrue(2), 'k^', 'MarkerFaceColor', 'w', 'MarkerSize', 9, 'LineWidth', 1.5);

% 连线
plot([Ptrue(1), O(1)],  [Ptrue(2), O(2)],  'k-', 'LineWidth', 1.2);
plot([Ptrue(1), Ai(1)], [Ptrue(2), Ai(2)], 'k-', 'LineWidth', 1.2);
plot([Ptrue(1), Aj(1)], [Ptrue(2), Aj(2)], 'k-', 'LineWidth', 1.2);

plot([O(1), Ai(1)], [O(2), Ai(2)], 'k:', 'LineWidth', 1.0);
plot([O(1), Aj(1)], [O(2), Aj(2)], 'k:', 'LineWidth', 1.0);
plot([Ai(1), Aj(1)], [Ai(2), Aj(2)], 'k:', 'LineWidth', 1.0);

% 标注点
text(O(1)+3, O(2)-5, 'FY00 / O', 'FontSize', 10);
text(Ai(1)+3, Ai(2)+3, sprintf('FY%02d / A_i', tx_i), 'FontSize', 10);
text(Aj(1)+3, Aj(2)+3, sprintf('FY%02d / A_j', tx_j), 'FontSize', 10);
text(Ptrue(1)+3, Ptrue(2)+3, sprintf('FY%02d / P', receiverNo), 'FontSize', 10);

% 接收点 P 处的三个夹角
drawAngleArc(Ptrue, O,  Ai, 16, '\alpha_i', 1.10);
drawAngleArc(Ptrue, O,  Aj, 23, '\alpha_j', 1.10);
drawAngleArc(Ptrue, Ai, Aj, 31, '\alpha_{ij}', 1.10);

% 圆心处极角示意
xAxisPoint = [R, 0];
drawAngleArc(O, xAxisPoint, Ptrue, 18, '\theta', 1.30);
drawAngleArc(O, xAxisPoint, Ai, 25, '\theta_i', 1.25);
drawAngleArc(O, xAxisPoint, Aj, 32, '\theta_j', 1.20);

xlabel('x / m');
ylabel('y / m');
title('基于正弦定理的纯方位定位几何示意图');

legend('理想圆周', 'FY00', '圆周发射机', '圆周发射机', '接收机', ...
    'Location', 'bestoutside');

saveFigure(gcf, fullfile(outFolder, '图2_正弦定理定位几何示意图.png'));

%% ========================================================================
% 图3：定位结果验证图
% ========================================================================

figure('Color', 'w');
hold on; grid on; axis equal;

plot(R*cos(t), R*sin(t), 'k--', 'LineWidth', 1.0);

% 所有理想位置
for k = 1:9
    plot(idealXY(k,1), idealXY(k,2), 'ko', ...
        'MarkerSize', 5, 'LineWidth', 1.0);
    text(idealXY(k,1)+2, idealXY(k,2)+2, ...
        sprintf('FY%02d', k), 'FontSize', 8);
end

% 发射机
plot(O(1), O(2), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 7);
plot(Ai(1), Ai(2), 'ks', 'MarkerSize', 10, 'LineWidth', 1.8);
plot(Aj(1), Aj(2), 'ks', 'MarkerSize', 10, 'LineWidth', 1.8);

% 真实位置与定位位置
plot(Ptrue(1), Ptrue(2), 'k^', ...
    'MarkerSize', 10, 'LineWidth', 1.8);

plot(Pest(1), Pest(2), 'ko', ...
    'MarkerSize', 13, 'LineWidth', 1.8);

% 为了避免完全重合看不清，额外画一个小圆圈
viscircles_local(Pest, 2.5);

% 连线
plot([Pest(1), O(1)],  [Pest(2), O(2)],  'k-', 'LineWidth', 1.0);
plot([Pest(1), Ai(1)], [Pest(2), Ai(2)], 'k-', 'LineWidth', 1.0);
plot([Pest(1), Aj(1)], [Pest(2), Aj(2)], 'k-', 'LineWidth', 1.0);

% 结果文字框
resultText = sprintf([ ...
    '接收机：FY%02d\n', ...
    '发射机：FY00, FY%02d, FY%02d\n', ...
    '\\rho = %.4f m\n', ...
    '\\theta = %.4f^\\circ\n', ...
    '\\alpha_{ij}误差 = %.2e^\\circ'], ...
    receiverNo, tx_i, tx_j, ...
    rhoEst, bestSolution.theta_deg, bestSolution.err_ij_deg);

text(-145, -125, resultText, ...
    'FontSize', 10, ...
    'BackgroundColor', 'w', ...
    'EdgeColor', 'k', ...
    'Margin', 6);

xlabel('x / m');
ylabel('y / m');
title('纯方位无源定位结果验证图');

legend('理想圆周', '理想位置', 'FY00', '发射机', '发射机', ...
    '真实位置', '定位结果', 'Location', 'bestoutside');

saveFigure(gcf, fullfile(outFolder, '图3_定位结果验证图.png'));

fprintf('\n三张论文配图已保存到文件夹：%s\n', outFolder);

%% ========================================================================
% 局部函数
% ========================================================================

function P = polar2xy(rho, theta)
    P = [rho*cos(theta), rho*sin(theta)];
end

function ang = angle2d(u, v)
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

function drawAngleArc(center, p1, p2, radius, labelStr, labelScale)
    a1 = atan2(p1(2)-center(2), p1(1)-center(1));
    a2 = atan2(p2(2)-center(2), p2(1)-center(1));

    d = wrapToPi_local(a2 - a1);

    angleList = linspace(a1, a1 + d, 80);

    xArc = center(1) + radius*cos(angleList);
    yArc = center(2) + radius*sin(angleList);

    plot(xArc, yArc, 'k-', 'LineWidth', 1.0);

    amid = a1 + d/2;
    xText = center(1) + labelScale*radius*cos(amid);
    yText = center(2) + labelScale*radius*sin(amid);

    text(xText, yText, labelStr, ...
        'FontSize', 11, ...
        'Interpreter', 'tex', ...
        'HorizontalAlignment', 'center');
end

function a = wrapToPi_local(a)
    a = mod(a + pi, 2*pi) - pi;
end

function a = wrap2pi_local(a)
    a = mod(a, 2*pi);
    if a < 0
        a = a + 2*pi;
    end
end

function saveFigure(figHandle, fileName)
    try
        exportgraphics(figHandle, fileName, 'Resolution', 300);
    catch
        print(figHandle, fileName, '-dpng', '-r300');
    end
end

function viscircles_local(center, radius)
    t = linspace(0, 2*pi, 100);
    plot(center(1) + radius*cos(t), center(2) + radius*sin(t), ...
        'k-', 'LineWidth', 1.0);
end

function [validSolutions, bestSolution] = solveBySineCases( ...
    R, theta_i, theta_j, alpha_i, alpha_j, alpha_ij, receiverNo)

    tol = deg2rad(1e-6);

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
        error('sin(alpha) 接近 0，定位方程退化。');
    end

    allCandidates = struct('caseName', {}, 'rho', {}, 'theta', {});

    % 情况一：theta < theta_i < theta_j
    N1 = sj * sin(alpha_i + theta_i) - si * sin(alpha_j + theta_j);
    D1 = sj * cos(alpha_i + theta_i) - si * cos(alpha_j + theta_j);
    theta0 = atan2(N1, D1);

    allCandidates = addCaseCandidates( ...
        allCandidates, ...
        'case1_left', ...
        theta0, ...
        @(theta) theta < theta_i, ...
        @(theta) R * sin(alpha_i + theta_i - theta) / si);

    % 情况二：theta_i < theta < theta_j
    N2 = si * sin(alpha_j + theta_j) - sj * sin(alpha_i - theta_i);
    D2 = sj * cos(alpha_i - theta_i) + si * cos(alpha_j + theta_j);
    theta0 = atan2(N2, D2);

    allCandidates = addCaseCandidates( ...
        allCandidates, ...
        'case2_middle', ...
        theta0, ...
        @(theta) theta > theta_i && theta < theta_j, ...
        @(theta) R * sin(alpha_i + theta - theta_i) / si);

    % 情况三：theta_i < theta_j < theta
    N3 = si * sin(alpha_j - theta_j) - sj * sin(alpha_i - theta_i);
    D3 = sj * cos(alpha_i - theta_i) - si * cos(alpha_j - theta_j);
    theta0 = atan2(N3, D3);

    allCandidates = addCaseCandidates( ...
        allCandidates, ...
        'case3_right', ...
        theta0, ...
        @(theta) theta > theta_j, ...
        @(theta) R * sin(alpha_i + theta - theta_i) / si);

    O  = [0, 0];
    Ai = polar2xy(R, theta_i);
    Aj = polar2xy(R, theta_j);

    validSolutions = struct( ...
        'caseName', {}, ...
        'rho', {}, ...
        'theta_deg', {}, ...
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

            dTheta = abs(solutions(i).theta_deg - solutions(j).theta_deg);

            if abs(solutions(i).rho - solutions(j).rho) < 1e-6 && dTheta < 1e-6
                keep(j) = false;
            end
        end
    end

    solutions = solutions(keep);
end