%% 不同线光源长度下 B、C 点光线数量变化图
% 功能：
% 1. 计算不同线光源长度 L 下 B、C 点附近的光线数量
% 2. 绘制 N_B(L)、N_C(L) 随 L 的变化曲线
% 3. 标出约束线 N_B=2、N_C=1 以及最优长度 L=3.12 mm
%
% 单位统一采用 mm

clear;
clc;
close all;

%% ===================== 1. 基本参数设置 =====================

% 车灯几何参数
R = 36;                 % 开口半径，mm
h = 21.6;               % 深度，mm

% 抛物面焦距
p = R^2 / (4*h);        % p = 15 mm

% 测试屏位置
screen_x = p + 25000;   % 焦点正前方 25m

% A、B、C 点
A = [screen_x, 0, 0];
B = [screen_x, 1300, 0];
C = [screen_x, 2600, 0];

% 接收圆半径
r_receive = 10;         % mm

% 离散步长
dy_source = 0.1;        % 线光源离散步长
d_surface = 1;          % 抛物面离散步长

% 线光源长度扫描范围
dL = 0.04;              % 长度步长
L_min = 2.0;            % 可根据需要调整
L_max = 4.2;            % 可根据需要调整
L_list = L_min:dL:L_max;

fprintf('抛物面焦距 p = %.2f mm\n', p);
fprintf('开始计算不同线光源长度下的 B、C 点光线数量...\n\n');

%% ===================== 2. 抛物面离散化 =====================

[y_grid, z_grid] = meshgrid(-R:d_surface:R, -R:d_surface:R);
surface_mask = (y_grid.^2 + z_grid.^2 <= R^2);

y0 = y_grid(surface_mask);
z0 = z_grid(surface_mask);
x0 = (y0.^2 + z0.^2) / (4*p);

fprintf('抛物面离散点数量：%d\n\n', length(x0));

%% ===================== 3. 逐个长度计算 NB 和 NC =====================

NB_list = zeros(size(L_list));
NC_list = zeros(size(L_list));

for k = 1:length(L_list)
    L = L_list(k);

    [NB, NC] = count_light_for_length( ...
        L, dy_source, x0, y0, z0, p, screen_x, B, C, r_receive);

    NB_list(k) = NB;
    NC_list(k) = NC;

    fprintf('L = %.2f mm,  NB = %d,  NC = %d\n', L, NB, NC);
end

%% ===================== 4. 找到最小满足条件的长度 =====================

idx_feasible = find(NB_list >= 2 & NC_list >= 1, 1, 'first');

if ~isempty(idx_feasible)
    L_best = L_list(idx_feasible);
    NB_best = NB_list(idx_feasible);
    NC_best = NC_list(idx_feasible);

    fprintf('\n满足条件的最小长度为：L = %.2f mm\n', L_best);
    fprintf('对应 NB = %d, NC = %d\n', NB_best, NC_best);
else
    L_best = NaN;
    fprintf('\n当前扫描范围内没有找到满足条件的长度。\n');
end

%% ===================== 5. 绘图 =====================

figure('Color','w');

plot(L_list, NB_list, '-o', 'LineWidth', 1.8, 'MarkerSize', 4);
hold on;
plot(L_list, NC_list, '-s', 'LineWidth', 1.8, 'MarkerSize', 4);

% 约束线
yline(2, '--', 'LineWidth', 1.5);
yline(1, '--', 'LineWidth', 1.5);

% 标出最优长度
if ~isnan(L_best)
    xline(L_best, '--', 'LineWidth', 1.5);
    plot(L_best, NB_best, 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'auto');
    plot(L_best, NC_best, 's', 'MarkerSize', 8, 'MarkerFaceColor', 'auto');

    text(L_best + 0.03, max([NB_best, NC_best]) + 0.5, ...
        ['L = ', num2str(L_best, '%.2f'), ' mm'], ...
        'FontSize', 11);
end

xlabel('线光源长度 L / mm');
ylabel('光线数量');
title('不同线光源长度下 B、C 点附近光线数量变化图');

legend({'N_B(L)', 'N_C(L)', 'N_B = 2', 'N_C = 1', 'L = 3.12 mm'}, ...
    'Location', 'northwest');

grid on;
box on;

%% ===================== 6. 可选：保存图片 =====================
% set(gcf, 'PaperPositionMode', 'auto');
% print(gcf, '不同线光源长度下B_C点光线数量变化图', '-dpng', '-r600');

%% ===================== 7. 局部函数 =====================
function [NB, NC] = count_light_for_length( ...
    L, dy_source, x0, y0, z0, p, screen_x, B, C, r_receive)

    % 当前线光源长度下的离散点
    num_source = round(L / dy_source) + 1;
    y_source = linspace(-L/2, L/2, num_source);

    x2 = p;
    z2 = 0;

    NB = 0;
    NC = 0;

    for i = 1:length(y_source)

        y2 = y_source(i);

        % 计算法线参数 lambda
        lambda = (y0.*y2 + z0.*z2 + 30*x0 - 30*x2 - y0.^2 - z0.^2) ...
                 ./ (1800 + 2*y0.^2 + 2*z0.^2);

        % 计算对称点 Q
        x3 = 2*x0 - 120*lambda - x2;
        y3 = 2*(2*lambda + 1).*y0 - y2;
        z3 = 2*(2*lambda + 1).*z0 - z2;

        % 反射光线与测试屏交点
        denominator = x3 - x0;

        valid = abs(denominator) > 1e-12;
        mu = zeros(size(x0));
        mu(valid) = (screen_x - x0(valid)) ./ denominator(valid);

        % 只保留朝向测试屏传播的光线
        valid = valid & (mu > 0);

        yG = y0(valid) + mu(valid).*(y3(valid) - y0(valid));
        zG = z0(valid) + mu(valid).*(z3(valid) - z0(valid));

        % 统计 B、C 点附近光线数量
        dist_B_square = (yG - B(2)).^2 + (zG - B(3)).^2;
        dist_C_square = (yG - C(2)).^2 + (zG - C(3)).^2;

        NB = NB + sum(dist_B_square <= r_receive^2);
        NC = NC + sum(dist_C_square <= r_receive^2);
    end
end