%% 线光源长度为 3.12mm 时测试屏上 B、C 点附近落点分布图
% 功能：
% 1. 固定线光源长度 L = 3.12 mm
% 2. 计算所有反射光线在测试屏上的落点
% 3. 放大显示 B、C 点附近区域
% 4. 标出 B、C 点及其接收圆
%
% 单位统一采用 mm

clear;
clc;
close all;

%% ===================== 1. 基本参数设置 =====================

% 车灯几何参数
R = 36;                 % 车灯开口半径，mm
h = 21.6;               % 车灯深度，mm

% 抛物面焦距
p = R^2 / (4*h);        % p = 15 mm

% 线光源长度
L = 3.12;               % mm

% 测试屏位置
screen_x = p + 25000;   % 焦点正前方 25m

% A、B、C 点坐标
A = [screen_x, 0, 0];
B = [screen_x, 1300, 0];
C = [screen_x, 2600, 0];

% B、C 点附近接收圆半径
r_receive = 10;         % mm

% 离散步长
dy_source = 0.1;        % 线光源离散步长，mm
d_surface = 1;          % 抛物面离散步长，mm

fprintf('===================== 参数设置 =====================\n');
fprintf('线光源长度 L = %.2f mm\n', L);
fprintf('抛物面焦距 p = %.2f mm\n', p);
fprintf('测试屏平面 x = %.2f mm\n', screen_x);
fprintf('B 点坐标为：B = (%.2f, %.2f, %.2f)\n', B(1), B(2), B(3));
fprintf('C 点坐标为：C = (%.2f, %.2f, %.2f)\n', C(1), C(2), C(3));
fprintf('====================================================\n\n');

%% ===================== 2. 抛物面离散化 =====================

[y_grid, z_grid] = meshgrid(-R:d_surface:R, -R:d_surface:R);

% 只保留圆形开口内的点
surface_mask = (y_grid.^2 + z_grid.^2 <= R^2);

y0 = y_grid(surface_mask);
z0 = z_grid(surface_mask);

% 由抛物面方程 y^2 + z^2 = 60x 求 x0
x0 = (y0.^2 + z0.^2) / (4*p);

fprintf('抛物面离散点数量：%d\n', length(x0));

%% ===================== 3. 计算测试屏落点 =====================

[yG_all, zG_all, NB, NC] = get_screen_points_for_length( ...
    L, dy_source, x0, y0, z0, p, screen_x, B, C, r_receive);

fprintf('测试屏落点总数：%d\n', length(yG_all));
fprintf('B 点附近接收圆内光线数量 NB = %d\n', NB);
fprintf('C 点附近接收圆内光线数量 NC = %d\n', NC);

%% ===================== 4. 筛选 B、C 附近局部区域 =====================

% 为了让图更清楚，只显示 B、C 附近一定范围内的落点
% 这里显示 y = 1200 到 2700，z = -80 到 80 的区域
local_mask = (yG_all >= 1200) & (yG_all <= 2700) & ...
             (zG_all >= -80) & (zG_all <= 80);

yG_local = yG_all(local_mask);
zG_local = zG_all(local_mask);

%% ===================== 5. 绘制 B、C 点附近落点分布图 =====================

figure('Color','w');

% 绘制局部落点
plot(yG_local, zG_local, '.', 'MarkerSize', 6);
hold on;

% 标出 B、C 点
plot(B(2), B(3), 'ro', 'MarkerFaceColor', 'r', ...
    'MarkerSize', 8, 'LineWidth', 1.5);

plot(C(2), C(3), 'go', 'MarkerFaceColor', 'g', ...
    'MarkerSize', 8, 'LineWidth', 1.5);

% 绘制 B、C 点附近接收圆
theta = linspace(0, 2*pi, 400);

plot(B(2) + r_receive*cos(theta), ...
     B(3) + r_receive*sin(theta), ...
     'r--', 'LineWidth', 1.5);

plot(C(2) + r_receive*cos(theta), ...
     C(3) + r_receive*sin(theta), ...
     'g--', 'LineWidth', 1.5);

% 文字标注
text(B(2)+15, B(3)+8, 'B 点', ...
    'FontSize', 12, 'Color', 'r', 'FontWeight', 'bold');

text(C(2)+15, C(3)+8, 'C 点', ...
    'FontSize', 12, 'Color', 'g', 'FontWeight', 'bold');

text(B(2)-85, B(3)-35, ['N_B = ', num2str(NB)], ...
    'FontSize', 11, 'Color', 'r');

text(C(2)-85, C(3)-35, ['N_C = ', num2str(NC)], ...
    'FontSize', 11, 'Color', 'g');

xlabel('测试屏水平方向 y / mm');
ylabel('测试屏竖直方向 z / mm');

title('线光源长度 L = 3.12 mm 时测试屏上 B、C 点附近落点分布图');

grid on;
box on;
axis equal;

xlim([1200, 2700]);
ylim([-80, 80]);

legend({'反射光落点', 'B 点', 'C 点', ...
        'B 点接收圆', 'C 点接收圆'}, ...
        'Location', 'northeastoutside');

%% ===================== 6. 可选：保存图片 =====================
% set(gcf, 'PaperPositionMode', 'auto');
% print(gcf, '线光源长度为3_12mm时B_C点附近落点分布图', '-dpng', '-r600');


%% ===================== 7. 局部函数 =====================

function [yG_all, zG_all, NB, NC] = get_screen_points_for_length( ...
    L, dy_source, x0, y0, z0, p, screen_x, B, C, r_receive)

    % 线光源离散化
    num_source = round(L / dy_source) + 1;
    y_source = linspace(-L/2, L/2, num_source);

    % 线光源点 P 的 x、z 坐标固定
    x2 = p;
    z2 = 0;

    % 初始化
    yG_all = [];
    zG_all = [];
    NB = 0;
    NC = 0;

    for i = 1:length(y_source)

        y2 = y_source(i);

        %% ---------- 1. 计算法线参数 lambda ----------
        lambda = (y0.*y2 + z0.*z2 + 30*x0 - 30*x2 - y0.^2 - z0.^2) ...
                 ./ (1800 + 2*y0.^2 + 2*z0.^2);

        %% ---------- 2. 计算对称点 Q ----------
        x3 = 2*x0 - 120*lambda - x2;
        y3 = 2*(2*lambda + 1).*y0 - y2;
        z3 = 2*(2*lambda + 1).*z0 - z2;

        %% ---------- 3. 计算反射光线与测试屏交点 ----------
        denominator = x3 - x0;

        valid = abs(denominator) > 1e-12;

        mu = zeros(size(x0));
        mu(valid) = (screen_x - x0(valid)) ./ denominator(valid);

        % 只保留向测试屏方向传播的反射光线
        valid = valid & (mu > 0);

        yG = y0(valid) + mu(valid).*(y3(valid) - y0(valid));
        zG = z0(valid) + mu(valid).*(z3(valid) - z0(valid));

        yG_all = [yG_all; yG(:)];
        zG_all = [zG_all; zG(:)];

        %% ---------- 4. 统计 B、C 接收圆内落点数量 ----------
        dist_B_square = (yG - B(2)).^2 + (zG - B(3)).^2;
        dist_C_square = (yG - C(2)).^2 + (zG - C(3)).^2;

        NB = NB + sum(dist_B_square <= r_receive^2);
        NC = NC + sum(dist_C_square <= r_receive^2);
    end
end