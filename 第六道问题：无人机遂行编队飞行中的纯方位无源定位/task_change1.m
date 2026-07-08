%% Q1_1_sine_positioning.m
% 问题1第(1)小问：基于正弦定理的纯方位无源定位模型
% 已知 FY00 和两架圆周发射机位置，利用接收夹角反推接收机极坐标

clear; clc; close all;

%% ==================== 1. 基本参数设置 ====================

% 圆形编队半径
R = 100;

% 圆周上 9 架无人机的理想极角，单位：弧度
% FY01 = 0°, FY02 = 40°, ..., FY09 = 320°
thetaIdeal = deg2rad(0:40:320);

% 本例中选择的两架圆周发射机
% 发射机为 FY00、FY01、FY04
tx_i = 1;      % FY01
tx_j = 4;      % FY04

% 本例中被动接收的无人机
receiverNo = 2;   % FY02

%% ==================== 2. 用题目表格数据模拟真实位置 ====================
% 注意：这部分只是为了生成"接收夹角"
% 真正定位时，接收机并不知道自己的真实坐标

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

%% ==================== 3. 构造发射机和接收机坐标 ====================

O  = [0, 0];                                   % FY00
Ai = polar2xy(R, thetaIdeal(tx_i));            % 第1架圆周发射机
Aj = polar2xy(R, thetaIdeal(tx_j));            % 第2架圆周发射机

% 接收机真实位置，仅用于模拟其接收到的夹角
Ptrue = polar2xy(rhoActual(receiverNo), thetaActual(receiverNo));

%% ==================== 4. 模拟接收机测得的三个夹角 ====================
% alpha_i  = angle FY00-P-FYi
% alpha_j  = angle FY00-P-FYj
% alpha_ij = angle FYi-P-FYj

alpha_i  = angle2d(O  - Ptrue, Ai - Ptrue);
alpha_j  = angle2d(O  - Ptrue, Aj - Ptrue);
alpha_ij = angle2d(Ai - Ptrue, Aj - Ptrue);

fprintf('========== 模拟接收夹角 ==========\n');
fprintf('接收机：FY%02d\n', receiverNo);
fprintf('发射机：FY00, FY%02d, FY%02d\n\n', tx_i, tx_j);

fprintf('alpha_i  = angle FY00-P-FY%02d = %.6f 度\n', ...
    tx_i, rad2deg(alpha_i));
fprintf('alpha_j  = angle FY00-P-FY%02d = %.6f 度\n', ...
    tx_j, rad2deg(alpha_j));
fprintf('alpha_ij = angle FY%02d-P-FY%02d = %.6f 度\n\n', ...
    tx_i, tx_j, rad2deg(alpha_ij));

%% ==================== 5. 调用正弦定理定位模型 ====================

[validSolutions, bestSolution] = solveBySineCases( ...
    R, ...
    thetaIdeal(tx_i), ...
    thetaIdeal(tx_j), ...
    alpha_i, ...
    alpha_j, ...
    alpha_ij, ...
    receiverNo);

%% ==================== 6. 输出定位结果 ====================

fprintf('========== 候选定位结果 ==========\n');

if isempty(validSolutions)
    fprintf('没有找到满足三个角度检验的候选解。\n');
else
    T = struct2table(validSolutions);
    disp(T);

    fprintf('\n========== 最终定位结果 ==========\n');
    fprintf('接收机 FY%02d 的定位结果：\n', receiverNo);
    fprintf('rho   = %.6f m\n', bestSolution.rho);
    fprintf('theta = %.6f 度\n', bestSolution.theta_deg);

    x_est = bestSolution.rho * cos(deg2rad(bestSolution.theta_deg));
    y_est = bestSolution.rho * sin(deg2rad(bestSolution.theta_deg));

    fprintf('x     = %.6f m\n', x_est);
    fprintf('y     = %.6f m\n', y_est);

    fprintf('\n========== 与模拟真实值对比 ==========\n');
    fprintf('真实 rho   = %.6f m\n', rhoActual(receiverNo));
    fprintf('真实 theta = %.6f 度\n', thetaActualDeg(receiverNo));
end

%% ==================== 7. 简单画图检验 ====================

figure;
hold on; grid on; axis equal;

% 画理想圆
t = linspace(0, 2*pi, 400);
plot(R*cos(t), R*sin(t), 'k--');

% 画圆心
plot(0, 0, 'ko', 'MarkerFaceColor', 'k');
text(0, 0, ' FY00');

% 画 9 架理想圆周无人机
for k = 1:9
    Pk = polar2xy(R, thetaIdeal(k));
    plot(Pk(1), Pk(2), 'bo');
    text(Pk(1), Pk(2), sprintf(' FY%02d', k));
end

% 画发射机
plot(Ai(1), Ai(2), 'rs', 'MarkerSize', 10, 'LineWidth', 2);
plot(Aj(1), Aj(2), 'rs', 'MarkerSize', 10, 'LineWidth', 2);

% 画接收机真实位置
plot(Ptrue(1), Ptrue(2), 'go', 'MarkerSize', 10, 'LineWidth', 2);
text(Ptrue(1), Ptrue(2), ' 真实位置');

% 画定位结果
if ~isempty(validSolutions)
    Pest = polar2xy(bestSolution.rho, deg2rad(bestSolution.theta_deg));
    plot(Pest(1), Pest(2), 'mp', 'MarkerSize', 14, 'LineWidth', 2);
    text(Pest(1), Pest(2), ' 定位结果');
end

title('问题1第(1)小问：纯方位无源定位结果');
xlabel('x / m');
ylabel('y / m');
legend('理想圆周', 'FY00', '理想圆周无人机', '发射机', ...
    '接收机真实位置', '定位结果', 'Location', 'best');


%% ========================================================================
%                              局部函数
% ========================================================================

function [validSolutions, bestSolution] = solveBySineCases( ...
    R, theta_i, theta_j, alpha_i, alpha_j, alpha_ij, receiverNo)
% 基于正弦定理和三种情况讨论，求接收机极坐标位置

    tol = deg2rad(1e-6);

    % 为了使用推导公式，先保证 theta_i < theta_j
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
        error('夹角过小，sin(alpha) 接近 0，定位方程退化。');
    end

    allCandidates = struct('caseName', {}, 'rho', {}, 'theta', {});

    %% ---------- 情况一：theta < theta_i < theta_j ----------
    % rho = R*sin(alpha_i + theta_i - theta)/sin(alpha_i)
    % rho = R*sin(alpha_j + theta_j - theta)/sin(alpha_j)

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
    % rho = R*sin(alpha_i + theta - theta_i)/sin(alpha_i)
    % rho = R*sin(alpha_j + theta_j - theta)/sin(alpha_j)

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
    % rho = R*sin(alpha_i + theta - theta_i)/sin(alpha_i)
    % rho = R*sin(alpha_j + theta - theta_j)/sin(alpha_j)

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

        % 这里同时检验三个角度
        % 其中 alpha_ij 是第三夹角检验
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

    %% ---------- 去除重复解 ----------
    validSolutions = removeDuplicateSolutions(validSolutions);

    %% ---------- 若有多个解，选择最接近对应编号理想位置的解 ----------
    if isempty(validSolutions)
        bestSolution = [];
    else
        [~, idx] = min([validSolutions.distToIdeal]);
        bestSolution = validSolutions(idx);
    end
end


function candidates = addCaseCandidates(candidates, caseName, theta0, conditionFun, rhoFun)
% 由于 tan(theta) 有 pi 周期，需要考虑 theta0 + n*pi

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
% 极坐标转直角坐标
    P = [rho*cos(theta), rho*sin(theta)];
end


function ang = angle2d(u, v)
% 计算二维向量 u 和 v 的夹角，返回弧度，范围 [0, pi]

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
% 将角度归一化到 [0, 2*pi)

    a = mod(a, 2*pi);

    if a < 0
        a = a + 2*pi;
    end
end


function solutions = removeDuplicateSolutions(solutions)
% 去除重复候选解

    if isempty(solutions)
        return;
    end

    keep = true(1, length(solutions));

    for i = 1:length(solutions)
        if ~keep(i)
            continue;
        end

        for j = i+1:length(solutions)
            if abs(solutions(i).rho - solutions(j).rho) < 1e-6 && ...
               abs(solutions(i).theta_deg - solutions(j).theta_deg) < 1e-6
                keep(j) = false;
            end
        end
    end

    solutions = solutions(keep);
end