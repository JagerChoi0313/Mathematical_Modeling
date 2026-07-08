clear; clc; close all;

%% ================================
%  问题1第1小问：纯方位无源定位模型
%  已知：3架发射无人机位置
%  已知：接收无人机观测到的夹角
%  求解：接收无人机实际位置 P=(x,y)
%% ================================

%% 1. 建立理想圆形编队坐标
R = 100;              % 圆形编队半径，可根据题意设置
N = 9;                % 圆周上无人机数量 FY01~FY09

% pos(id+1,:) 存放 FYid 的坐标
% FY00 对应 pos(1,:)
% FY01 对应 pos(2,:)
% ...
% FY09 对应 pos(10,:)
pos = zeros(10, 2);

% FY00 位于圆心
pos(1,:) = [0, 0];

% FY01~FY09 均匀分布在圆周上
for k = 1:N
    theta = 2*pi*(k-1)/N;
    pos(k+1,:) = [R*cos(theta), R*sin(theta)];
end

%% 2. 选择发射信号的无人机
% 例如选择 FY00、FY01、FY04 作为发射机
txID = [0, 1, 4];

% 发射机坐标
S = pos(txID + 1, :);

%% 3. 设置待定位无人机
% 假设我们要定位 FY03
rxID = 3;

% FY03 的理想位置
P_ideal = pos(rxID + 1, :);

% 为了验证模型，假设 FY03 发生了一个小偏差
% 真实偏差位置如下：
P_true = P_ideal + [4, -6];

%% 4. 根据真实偏差位置，模拟接收到的夹角信息
% 三个发射点两两组成三组夹角：
% 若 txID = [0,1,4]
% pairs = [1,2] 表示 FY00-FY01
% pairs = [1,3] 表示 FY00-FY04
% pairs = [2,3] 表示 FY01-FY04

pairs = nchoosek(1:3, 2);

obsCos = zeros(size(pairs,1), 1);
obsAngDeg = zeros(size(pairs,1), 1);

for t = 1:size(pairs,1)
    i = pairs(t,1);
    j = pairs(t,2);

    v1 = S(i,:) - P_true;
    v2 = S(j,:) - P_true;

    obsCos(t) = dot(v1, v2) / (norm(v1) * norm(v2));
    obsCos(t) = max(min(obsCos(t), 1), -1);  % 防止数值误差

    obsAngDeg(t) = acosd(obsCos(t));
end

disp('模拟得到的观测夹角如下：');
for t = 1:size(pairs,1)
    fprintf('FY%02d - FY%02d 的夹角 = %.6f 度\n', ...
        txID(pairs(t,1)), txID(pairs(t,2)), obsAngDeg(t));
end

%% 5. 如果你有实际观测角度，可以在这里替换
% 例如：
% obsAngDeg = [35.2; 71.6; 42.8];
% obsCos = cosd(obsAngDeg);

%% 6. 建立最小二乘目标函数
% 目标：理论余弦值 与 观测余弦值 的误差平方和最小

objFun = @(P) angle_objective(P, S, pairs, obsCos);

%% 7. 用 fminsearch 求解
% fminsearch 是 MATLAB 基础函数，不需要优化工具箱
% 初始点建议用该编号无人机的理想位置，因为题目说"位置略有偏差"

startList = [
    P_ideal;
    P_ideal + [10, 0];
    P_ideal + [-10, 0];
    P_ideal + [0, 10];
    P_ideal + [0, -10]
];

bestP = [];
bestVal = inf;

options = optimset( ...
    'Display', 'off', ...
    'TolX', 1e-12, ...
    'TolFun', 1e-14, ...
    'MaxIter', 10000, ...
    'MaxFunEvals', 10000);

for s = 1:size(startList,1)
    P0 = startList(s,:);
    [P_est, fval] = fminsearch(objFun, P0, options);

    if fval < bestVal
        bestVal = fval;
        bestP = P_est;
    end
end

%% 8. 输出结果
fprintf('\n========== 定位结果 ==========\n');
fprintf('待定位无人机：FY%02d\n', rxID);
fprintf('理想位置：      x = %.6f, y = %.6f\n', P_ideal(1), P_ideal(2));
fprintf('真实偏差位置：  x = %.6f, y = %.6f\n', P_true(1), P_true(2));
fprintf('模型估计位置：  x = %.6f, y = %.6f\n', bestP(1), bestP(2));
fprintf('定位误差：      %.10f m\n', norm(bestP - P_true));
fprintf('目标函数值：    %.12e\n', bestVal);

%% 9. 画图展示
figure;
hold on; grid on; axis equal;

% 画理想圆
thetaPlot = linspace(0, 2*pi, 400);
plot(R*cos(thetaPlot), R*sin(thetaPlot), 'k--', 'LineWidth', 1);

% 画所有理想无人机
plot(pos(:,1), pos(:,2), 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 7);

% 标注无人机编号
for k = 0:9
    text(pos(k+1,1)+2, pos(k+1,2)+2, sprintf('FY%02d', k), ...
        'FontSize', 9);
end

% 画发射机
plot(S(:,1), S(:,2), 'rp', 'MarkerSize', 14, 'MarkerFaceColor', 'r');

% 画待定位无人机的理想位置、真实位置、估计位置
plot(P_ideal(1), P_ideal(2), 'bo', 'MarkerSize', 10, 'LineWidth', 2);
plot(P_true(1), P_true(2), 'gx', 'MarkerSize', 12, 'LineWidth', 2);
plot(bestP(1), bestP(2), 'ms', 'MarkerSize', 10, 'MarkerFaceColor', 'm');

legend('理想圆周', '理想编队点', '发射无人机', ...
       '接收机理想位置', '接收机真实位置', '模型估计位置', ...
       'Location', 'bestoutside');

xlabel('x / m');
ylabel('y / m');
title('问题1第1小问：纯方位无源定位结果');

hold off;

%% ================================
%  局部函数：角度余弦残差目标函数
%% ================================
function J = angle_objective(P, S, pairs, obsCos)

    P = P(:).';  % 保证 P 是行向量

    % 防止 P 与某个发射点重合，导致除零
    dist = vecnorm(S - P, 2, 2);
    if any(dist < 1e-8)
        J = 1e12;
        return;
    end

    predCos = zeros(size(pairs,1), 1);

    for t = 1:size(pairs,1)
        i = pairs(t,1);
        j = pairs(t,2);

        v1 = S(i,:) - P;
        v2 = S(j,:) - P;

        predCos(t) = dot(v1, v2) / (norm(v1) * norm(v2));
    end

    % 目标函数：理论余弦值与观测余弦值的误差平方和
    J = sum((predCos - obsCos).^2);
end