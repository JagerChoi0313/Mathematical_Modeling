clear; clc; close all;

%% ============================================================
%  问题一第（1）问：纯方位无源定位图表生成
%  功能：
%  1. 生成圆形编队与定位结果示意图
%  2. 生成发射无人机坐标表
%  3. 生成接收夹角观测表
%  4. 生成定位结果对比表
%% ============================================================

%% 1. 创建输出文件夹
outDir = '问题1第1问图表结果';
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% 2. 建立圆形编队标准坐标
R = 100;        % 圆形编队半径 / m
N = 9;          % 圆周无人机数量

% pos(id+1,:) 表示 FYid 的坐标
% FY00 -> pos(1,:)
% FY01 -> pos(2,:)
% ...
% FY09 -> pos(10,:)
pos = zeros(10,2);
pos(1,:) = [0,0];       % FY00 位于圆心

for k = 1:N
    theta = 2*pi*(k-1)/N;
    pos(k+1,:) = [R*cos(theta), R*sin(theta)];
end

%% 3. 选择发射无人机与接收无人机
% 发射无人机：FY00、FY01、FY04
txID = [0, 1, 4];
S = pos(txID+1,:);

% 待定位接收无人机：FY03
rxID = 3;
P_ideal = pos(rxID+1,:);

% 模拟 FY03 的真实偏差位置
P_true = P_ideal + [4, -6];

%% 4. 计算接收夹角
pairs = nchoosek(1:3,2);     % 三架发射机两两组合
obsCos = zeros(size(pairs,1),1);
obsAngDeg = zeros(size(pairs,1),1);

for t = 1:size(pairs,1)
    i = pairs(t,1);
    j = pairs(t,2);

    v1 = S(i,:) - P_true;
    v2 = S(j,:) - P_true;

    obsCos(t) = dot(v1,v2)/(norm(v1)*norm(v2));
    obsCos(t) = max(min(obsCos(t),1),-1);
    obsAngDeg(t) = acosd(obsCos(t));
end

%% 5. 建立最小二乘定位模型并求解
objFun = @(P) angle_objective(P, S, pairs, obsCos);

% 多初值求解，避免局部结果影响
startList = [
    P_ideal;
    P_ideal + [10,0];
    P_ideal + [-10,0];
    P_ideal + [0,10];
    P_ideal + [0,-10];
    P_ideal + [8,-8];
    P_ideal + [-8,8]
];

bestP = [];
bestVal = inf;

options = optimset( ...
    'Display','off', ...
    'TolX',1e-12, ...
    'TolFun',1e-14, ...
    'MaxIter',10000, ...
    'MaxFunEvals',10000);

for s = 1:size(startList,1)
    P0 = startList(s,:);
    [P_est, fval] = fminsearch(objFun, P0, options);

    if fval < bestVal
        bestVal = fval;
        bestP = P_est;
    end
end

P_est = bestP;
locError = norm(P_est - P_true);

%% 6. 生成表 1：发射无人机坐标表
txNames = strings(length(txID),1);
for i = 1:length(txID)
    txNames(i) = sprintf("FY%02d", txID(i));
end

T_tx = table( ...
    txNames, ...
    S(:,1), ...
    S(:,2), ...
    'VariableNames', {'发射无人机编号','x坐标_m','y坐标_m'} ...
);

disp('表1：发射无人机坐标表');
disp(T_tx);

writetable(T_tx, fullfile(outDir,'表1_发射无人机坐标表.xlsx'));
writetable(T_tx, fullfile(outDir,'表1_发射无人机坐标表.csv'));

%% 7. 生成表 2：接收夹角观测表
pairNames = strings(size(pairs,1),1);

for t = 1:size(pairs,1)
    id1 = txID(pairs(t,1));
    id2 = txID(pairs(t,2));
    pairNames(t) = sprintf("FY%02d-FY%02d", id1, id2);
end

T_angle = table( ...
    pairNames, ...
    obsAngDeg, ...
    obsCos, ...
    'VariableNames', {'发射无人机组合','接收夹角_度','夹角余弦值'} ...
);

disp('表2：接收夹角观测表');
disp(T_angle);

writetable(T_angle, fullfile(outDir,'表2_接收夹角观测表.xlsx'));
writetable(T_angle, fullfile(outDir,'表2_接收夹角观测表.csv'));

%% 8. 生成表 3：定位结果对比表
itemName = [
    "FY03理想位置";
    "FY03真实偏差位置";
    "模型估计位置"
];

xValue = [
    P_ideal(1);
    P_true(1);
    P_est(1)
];

yValue = [
    P_ideal(2);
    P_true(2);
    P_est(2)
];

T_result = table( ...
    itemName, ...
    xValue, ...
    yValue, ...
    'VariableNames', {'项目','x坐标_m','y坐标_m'} ...
);

disp('表3：定位结果对比表');
disp(T_result);

writetable(T_result, fullfile(outDir,'表3_定位结果对比表.xlsx'));
writetable(T_result, fullfile(outDir,'表3_定位结果对比表.csv'));

%% 9. 生成补充表：定位误差与目标函数值
T_error = table( ...
    locError, ...
    bestVal, ...
    'VariableNames', {'定位误差_m','目标函数值'} ...
);

disp('补充表：定位误差与目标函数值');
disp(T_error);

writetable(T_error, fullfile(outDir,'表4_定位误差与目标函数值.xlsx'));
writetable(T_error, fullfile(outDir,'表4_定位误差与目标函数值.csv'));

%% 10. 绘制图 1：圆形编队与定位结果示意图
figure('Color','w','Position',[100,100,900,700]);
hold on; grid on; axis equal;

% 绘制理想圆周
thetaPlot = linspace(0,2*pi,500);
plot(R*cos(thetaPlot), R*sin(thetaPlot), 'k--', 'LineWidth', 1.2);

% 绘制所有理想无人机
plot(pos(:,1), pos(:,2), 'ko', ...
    'MarkerSize', 7, ...
    'MarkerFaceColor', 'w', ...
    'LineWidth', 1.2);

% 标注所有无人机编号
for k = 0:9
    text(pos(k+1,1)+2.5, pos(k+1,2)+2.5, sprintf('FY%02d',k), ...
        'FontSize', 10, ...
        'FontName', 'Times New Roman');
end

% 绘制发射无人机
plot(S(:,1), S(:,2), 'kp', ...
    'MarkerSize', 15, ...
    'MarkerFaceColor', [0.65 0.65 0.65], ...
    'LineWidth', 1.2);

% 绘制接收无人机理想位置、真实位置、估计位置
plot(P_ideal(1), P_ideal(2), 'ko', ...
    'MarkerSize', 11, ...
    'LineWidth', 1.8);

plot(P_true(1), P_true(2), 'kx', ...
    'MarkerSize', 13, ...
    'LineWidth', 2.0);

plot(P_est(1), P_est(2), 'ks', ...
    'MarkerSize', 10, ...
    'MarkerFaceColor', [0.85 0.85 0.85], ...
    'LineWidth', 1.5);

% 从真实接收位置向三架发射机连线，表示方向观测
for i = 1:size(S,1)
    plot([P_true(1), S(i,1)], [P_true(2), S(i,2)], ...
        'k-', 'LineWidth', 1.0);
end

% 标注接收夹角
text(P_true(1)+5, P_true(2)-5, ...
    sprintf('P_{true}\\rightarrow P_{est}\\n误差 = %.2e m', locError), ...
    'FontSize', 10, ...
    'FontName', 'Times New Roman');

% 图形设置
xlabel('x / m', 'FontSize', 12);
ylabel('y / m', 'FontSize', 12);
title('问题一第（1）问：纯方位无源定位示意图', 'FontSize', 14);

legend( ...
    '理想圆周', ...
    '理想编队点', ...
    '发射无人机', ...
    '接收机理想位置', ...
    '接收机真实位置', ...
    '模型估计位置', ...
    '方向观测线', ...
    'Location','bestoutside' ...
);

set(gca, 'FontSize', 11, 'FontName', 'Times New Roman');

% 保存图像
exportgraphics(gcf, fullfile(outDir,'图1_纯方位无源定位示意图.png'), 'Resolution', 300);
exportgraphics(gcf, fullfile(outDir,'图1_纯方位无源定位示意图.pdf'), 'ContentType','vector');

%% 11. 绘制图 2：局部放大定位结果图
figure('Color','w','Position',[150,150,700,600]);
hold on; grid on; axis equal;

% 局部范围
plot(P_ideal(1), P_ideal(2), 'ko', ...
    'MarkerSize', 12, ...
    'LineWidth', 1.8);

plot(P_true(1), P_true(2), 'kx', ...
    'MarkerSize', 14, ...
    'LineWidth', 2.2);

plot(P_est(1), P_est(2), 'ks', ...
    'MarkerSize', 11, ...
    'MarkerFaceColor', [0.85 0.85 0.85], ...
    'LineWidth', 1.5);

% 偏差箭头：理想位置 -> 真实位置
quiver(P_ideal(1), P_ideal(2), ...
       P_true(1)-P_ideal(1), P_true(2)-P_ideal(2), ...
       0, 'k', 'LineWidth', 1.5, 'MaxHeadSize', 0.8);

text(P_ideal(1)+1, P_ideal(2)+1, '理想位置', 'FontSize', 11);
text(P_true(1)+1, P_true(2)-2, '真实/估计位置', 'FontSize', 11);

xlabel('x / m', 'FontSize', 12);
ylabel('y / m', 'FontSize', 12);
title('FY03 定位结果局部放大图', 'FontSize', 14);

legend('理想位置','真实偏差位置','模型估计位置','位置偏差方向', ...
    'Location','best');

set(gca, 'FontSize', 11, 'FontName', 'Times New Roman');

% 设置显示范围
xlim([P_ideal(1)-10, P_true(1)+15]);
ylim([P_true(2)-15, P_ideal(2)+10]);

exportgraphics(gcf, fullfile(outDir,'图2_FY03定位结果局部放大图.png'), 'Resolution', 300);
exportgraphics(gcf, fullfile(outDir,'图2_FY03定位结果局部放大图.pdf'), 'ContentType','vector');

%% 12. 输出总结
fprintf('\n================ 结果生成完成 ================\n');
fprintf('所有图表已保存至文件夹：%s\n', outDir);
fprintf('定位误差 = %.12e m\n', locError);
fprintf('目标函数值 = %.12e\n', bestVal);
fprintf('==============================================\n');

%% ============================================================
%  局部函数：角度余弦残差目标函数
%% ============================================================
function J = angle_objective(P, S, pairs, obsCos)

    P = P(:).';

    dist = vecnorm(S-P,2,2);
    if any(dist < 1e-8)
        J = 1e12;
        return;
    end

    predCos = zeros(size(pairs,1),1);

    for t = 1:size(pairs,1)
        i = pairs(t,1);
        j = pairs(t,2);

        v1 = S(i,:) - P;
        v2 = S(j,:) - P;

        predCos(t) = dot(v1,v2)/(norm(v1)*norm(v2));
    end

    J = sum((predCos - obsCos).^2);
end